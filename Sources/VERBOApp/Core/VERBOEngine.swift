// VERBOEngine.swift
// Motor central do VERBO Multiagente iOS v3
// Arquitetura: PicoClaw runtime + ACCU Φ router + QLLM meta-controller + agentes especialistas
// Trinid © 2026

import Foundation
import Combine
import os.log

// MARK: - Enumerações Centrais

enum VERBOIntent: String, CaseIterable {
    case conversar   = "conversar"
    case pesquisar   = "pesquisar"
    case agir        = "agir"
    case resumir     = "resumir"
    case alertar     = "alertar"
    case automatizar = "automatizar"
    case escalar     = "escalar"
    case lembrar     = "lembrar"
    case construir   = "construir"   // cria novo agente

    var icon: String {
        switch self {
        case .conversar:   return "bubble.left.fill"
        case .pesquisar:   return "magnifyingglass"
        case .agir:        return "bolt.fill"
        case .resumir:     return "doc.text.fill"
        case .alertar:     return "exclamationmark.triangle.fill"
        case .automatizar: return "gearshape.2.fill"
        case .escalar:     return "arrow.up.circle.fill"
        case .lembrar:     return "brain.head.profile"
        case .construir:   return "plus.app.fill"
        }
    }
    var color: String {
        switch self {
        case .conversar:   return "blue"
        case .pesquisar:   return "purple"
        case .agir:        return "orange"
        case .resumir:     return "teal"
        case .alertar:     return "red"
        case .automatizar: return "indigo"
        case .escalar:     return "mint"
        case .lembrar:     return "cyan"
        case .construir:   return "green"
        }
    }
}

enum VERBOComplexity: Int, Comparable {
    case simples  = 1
    case media    = 2
    case alta     = 3
    case critica  = 4

    static func < (lhs: VERBOComplexity, rhs: VERBOComplexity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Modelos de Dados

struct VERBOMessage: Identifiable {
    let id        = UUID()
    let role      : MessageRole
    let content   : String
    let agentID   : String?
    let agentIcon : String?
    let intent    : VERBOIntent?
    let timestamp : Date = Date()
    var latencyMs : Double?
    var phiScore  : Double?
    var isProactive: Bool = false
}

enum MessageRole { case user, assistant, system, proactive }

// MARK: - ACCU Φ Router
// Baseado no Algoritmo de Auto-Consistência Computacional Universal
// Φ(x) = α(1-p) + β(1-c) + γe + δd

struct ACCUState {
    var p: Double = 0.80   // probabilidade de correção
    var c: Double = 0.85   // coerência lógica
    var e: Double = 0.20   // custo energético normalizado
    var d: Double = 0.70   // estabilidade adaptativa

    var alpha: Double = 0.4
    var beta:  Double = 0.3
    var gamma: Double = 0.2
    var delta: Double = 0.1

    var phi: Double {
        alpha * (1 - p) + beta * (1 - c) + gamma * e + delta * (1 - d)
    }

    mutating func update(latencyMs: Double, wasEscalated: Bool, success: Bool) {
        let lr = 0.05
        p = p + lr * (success ? 1 : -1) * (1 - p)
        c = c + lr * (success ? 0.5 : -0.2)
        e = min(1.0, latencyMs / 5000.0)
        d = d + lr * (wasEscalated ? -0.1 : 0.1)
        p = max(0.1, min(0.99, p))
        c = max(0.1, min(0.99, c))
        d = max(0.1, min(0.99, d))
    }
}

@MainActor
final class ACCURouter {

    private var state = ACCUState()

    // Padrões de intent por keywords
    private let intentPatterns: [(VERBOIntent, NSRegularExpression)] = {
        let patterns: [(VERBOIntent, String)] = [
            (.pesquisar,   #"\b(busca|pesquisa|qual|quem|onde|como|dados|mostra|informa|notícia|preço|cotação)\b"#),
            (.agir,        #"\b(compra|vende|cria|gera|agenda|envia|posta|publica|executa|faz|calcula|abre|faz)\b"#),
            (.resumir,     #"\b(resume|sintetiza|consolida|sumariza|histórico|mostra|lista)\b"#),
            (.alertar,     #"\b(alerta|risco|urgente|perigo|falha|problema|erro|avisa)\b"#),
            (.automatizar, #"\b(automati|agendar|repetir|toda hora|todo dia|cron|schedule|rotina|sempre)\b"#),
            (.lembrar,     #"\b(lembra|histórico|recall|sessão|contexto|antes|aprende|aprendi|sabe|sei)\b"#),
            (.construir,   #"\b(cria(r)? (um )?(agente|assistente|bot)|novo agente|quero (um )?agente|cria agente)\b"#),
        ]
        return patterns.compactMap { (intent, pattern) in
            guard let re = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
            return (intent, re)
        }
    }()

    // Mapeamento keyword → agente especialista
    private let agentKeywords: [(String, NSRegularExpression)] = {
        let kw: [(String, String)] = [
            ("social",     #"\b(instagram|twitter|tiktok|linkedin|facebook|post|postar|publicar|rede social)\b"#),
            ("mail",       #"\b(email|e-mail|correio|mensagem email|responde email|manda email)\b"#),
            ("calendar",   #"\b(agenda|reunião|evento|lembrete|compromisso|horário|meeting|calendário)\b"#),
            ("message",    #"\b(whatsapp|telegram|mensagem|notificação|leu|chegou|recebeu)\b"#),
            ("researcher", #"\b(pesquisa|analisa|dados|série|causal|relatório|descobre|encontra)\b"#),
            ("coder",      #"\b(código|script|python|swift|api|endpoint|programa|automatiza|função)\b"#),
            ("guardian",   #"\b(alerta|bloqueia|segurança|chave|senha|token|privad|criptografia|auditoria)\b"#),
            ("memory",     #"\b(lembra|histórico|recall|sessão|contexto|aprende|sei que|você sabe)\b"#),
            ("builder",    #"\b(cria(r)? (um )?(agente|bot|assistente)|novo agente|quero agente)\b"#),
        ]
        return kw.compactMap { (agent, pattern) in
            guard let re = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
            return (agent, re)
        }
    }()

    func route(text: String) -> (VERBOIntent, VERBOComplexity, String) {
        let range = NSRange(text.startIndex..., in: text)

        // 1. Busca agente especialista direto
        for (agentID, regex) in agentKeywords {
            if regex.firstMatch(in: text, range: range) != nil {
                return (intentFor(agent: agentID), complexityFor(text: text), agentID)
            }
        }

        // 2. Busca intent genérico
        for (intent, regex) in intentPatterns {
            if regex.firstMatch(in: text, range: range) != nil {
                return (intent, complexityFor(text: text), agentFor(intent: intent))
            }
        }

        return (.conversar, .simples, "orchestrator")
    }

    var phi: Double { state.phi }
    var p: Double { state.p }
    var c: Double { state.c }

    func recordOutcome(latencyMs: Double, wasEscalated: Bool, success: Bool) {
        state.update(latencyMs: latencyMs, wasEscalated: wasEscalated, success: success)
    }

    private func intentFor(agent: String) -> VERBOIntent {
        switch agent {
        case "social", "mail": return .agir
        case "calendar":       return .automatizar
        case "message":        return .agir
        case "researcher":     return .pesquisar
        case "coder":          return .agir
        case "guardian":       return .alertar
        case "memory":         return .lembrar
        case "builder":        return .construir
        default:               return .conversar
        }
    }

    private func agentFor(intent: VERBOIntent) -> String {
        switch intent {
        case .pesquisar:   return "researcher"
        case .agir:        return "operator"
        case .resumir:     return "memory"
        case .alertar:     return "guardian"
        case .automatizar: return "calendar"
        case .lembrar:     return "memory"
        case .construir:   return "builder"
        default:           return "orchestrator"
        }
    }

    private func complexityFor(text: String) -> VERBOComplexity {
        let words = text.split(separator: " ").count
        switch words {
        case ..<8:    return .simples
        case 8..<20:  return .media
        case 20..<45: return .alta
        default:      return .critica
        }
    }
}

// MARK: - VERBO Engine Principal

@MainActor
final class VERBOEngine: ObservableObject {
    static let shared = VERBOEngine()

    // Estado publicado
    @Published var messages      : [VERBOMessage]     = []
    @Published var isThinking    : Bool               = false
    @Published var activeAgent   : String             = ""
    @Published var phi           : Double             = 0.47
    @Published var sigmaLoss     : Double             = 0.0024
    @Published var apiCalls      : Int                = 0
    @Published var installedAgents: [CustomAgentSpec] = []
    @Published var proactiveQueue : [VERBOMessage]    = []

    // Serviços
    private let router     = ACCURouter()
    let llm                = LLMAdapter.shared
    let memory             = UserMemoryStore.shared
    let guardian           = GuardianService.shared
    let agentBuilder       = AgentBuilderService.shared
    let connections        = ConnectionsManager.shared

    private let logger = Logger(subsystem: "verbo.ios", category: "engine")
    private var turnCount = 0

    // MARK: - Processamento Principal

    func process(text: String, session: String = "main") async {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        messages.append(VERBOMessage(role: .user, content: trimmed,
                                      agentID: nil, agentIcon: nil, intent: nil))
        isThinking = true
        let t0 = Date()

        defer {
            isThinking = false
            activeAgent = ""
            phi = router.phi
        }

        // 1. Guardian — segurança primeiro
        if guardian.isBlocked(text: trimmed) {
            append(content: "🛡 **Guardian:** Conteúdo sensível detectado. Por segurança, não posso processar dados como chaves, senhas ou tokens.",
                   agent: "guardian", icon: "lock.shield.fill", intent: .alertar, t0: t0)
            return
        }

        // 2. Routing ACCU
        let (intent, complexity, agentID) = router.route(text: trimmed)
        activeAgent = agentID

        logger.info("Route: intent=\(intent.rawValue) complexity=\(complexity.rawValue) agent=\(agentID)")

        // 3. Aprender sobre o usuário
        memory.observe(text: trimmed)

        // 4. Executar agente local
        let (localResponse, handled) = await dispatchAgent(
            id: agentID, text: trimmed, session: session,
            intent: intent, complexity: complexity)

        // 5. Escalar para LLM se necessário
        var finalContent = localResponse
        var wasEscalated = false

        let shouldEscalate = !handled || complexity >= .alta
        if shouldEscalate && llm.isConfigured {
            wasEscalated = true
            apiCalls    += 1
            let ctx       = memory.buildContext(session: session, recentN: 6)
            let userProfile = memory.userProfilePrompt()
            finalContent  = await llm.chat(
                prompt: trimmed,
                context: ctx,
                agentName: agentID,
                extraSystem: userProfile)
        } else if !handled && !llm.isConfigured {
            finalContent = localResponse.isEmpty
                ? "⚙️ Configure uma API LLM em **Conexões → LLM** para respostas completas."
                : localResponse
        }

        // 6. Persistir memória
        memory.add(session: session, role: "user",      content: trimmed)
        memory.add(session: session, role: "assistant", content: finalContent)

        // 7. Registrar outcome no ACCU
        let latency = Date().timeIntervalSince(t0) * 1000
        router.recordOutcome(latencyMs: latency, wasEscalated: wasEscalated, success: !finalContent.isEmpty)
        turnCount += 1

        // 8. Publicar resposta
        let agentMeta = agentMeta(for: agentID)
        append(content: finalContent, agent: agentID,
               icon: agentMeta.icon, intent: intent,
               t0: t0, phiScore: router.phi)
    }

    // MARK: - Dispatcher de Agentes

    private func dispatchAgent(id: String, text: String, session: String,
                                intent: VERBOIntent, complexity: VERBOComplexity) async -> (String, Bool) {
        switch id {
        case "orchestrator": return (orchestratorResponse(text: text, intent: intent), false)
        case "operator":     return (await OperatorAgent.shared.handle(text: text, engine: self), true)
        case "message":      return (await MessageAgent.shared.handle(text: text, engine: self), true)
        case "mail":         return (await MailAgent.shared.handle(text: text, engine: self), true)
        case "calendar":     return (await CalendarAgent.shared.handle(text: text, engine: self), true)
        case "researcher":   return (await ResearchAgent.shared.handle(text: text, engine: self), true)
        case "social":       return (await SocialAgent.shared.handle(text: text, engine: self), true)
        case "coder":        return (CoderAgent.shared.handle(text: text), true)
        case "guardian":     return ("🛡 Guardian ativo. Sistema monitorado.", true)
        case "memory":
            let recall = memory.recall(session: session, query: text)
            return (recall, true)
        case "builder":
            let result = await agentBuilder.buildAgent(from: text)
            if let newAgent = result {
                installedAgents.append(newAgent)
                return (agentBuilder.confirmationMessage(for: newAgent), true)
            }
            return ("", false)
        default:
            // Verifica agentes customizados
            if let custom = installedAgents.first(where: { $0.id.uuidString == id || $0.name.lowercased() == id }) {
                return (await executeCustomAgent(custom, text: text), true)
            }
            return ("", false)
        }
    }

    private func orchestratorResponse(text: String, intent: VERBOIntent) -> String {
        "" // Orquestrador escala para LLM com contexto completo
    }

    // MARK: - Agentes Customizados

    private func executeCustomAgent(_ agent: CustomAgentSpec, text: String) async -> String {
        let basePrompt = """
        Você é o agente especialista '\(agent.name)': \(agent.description)
        Gatilho ativado por: '\(agent.trigger)'
        Política: confirmação necessária = \(agent.policy.needsConfirmation)
        """
        if llm.isConfigured {
            apiCalls += 1
            return await llm.chat(prompt: text, context: basePrompt, agentName: agent.name)
        }
        return "⚙️ Agente '\(agent.name)' pronto. Configure LLM para execução completa."
    }

    // MARK: - Helpers

    private func append(content: String, agent: String, icon: String,
                        intent: VERBOIntent, t0: Date, phiScore: Double? = nil) {
        let latency = Date().timeIntervalSince(t0) * 1000
        let msg = VERBOMessage(role: .assistant, content: content,
                               agentID: agent, agentIcon: icon,
                               intent: intent, latencyMs: latency, phiScore: phiScore)
        messages.append(msg)
    }

    func agentMeta(for id: String) -> (name: String, icon: String, description: String) {
        let builtIn: [String: (String, String, String)] = [
            "orchestrator": ("Orquestrador", "wand.and.stars",    "Coordena todos os agentes"),
            "operator":     ("Operacional",  "bolt.fill",         "Executa ações práticas"),
            "message":      ("Mensagens",    "message.fill",      "Triagem de notificações"),
            "mail":         ("E-mail",       "envelope.fill",     "Gerencia e-mails"),
            "calendar":     ("Calendário",   "calendar.badge.plus","Eventos e lembretes"),
            "researcher":   ("Pesquisa",     "magnifyingglass",   "Busca e síntese"),
            "social":       ("Social",       "square.and.pencil", "Redes sociais"),
            "coder":        ("Código",       "curlybraces",       "Scripts e automações"),
            "guardian":     ("Guardian",     "lock.shield.fill",  "Segurança e privacidade"),
            "memory":       ("Memória",      "brain.head.profile","Contexto e perfil"),
            "builder":      ("AgentBuilder", "plus.app.fill",     "Cria novos agentes"),
        ]
        if let meta = builtIn[id] { return meta }
        if let custom = installedAgents.first(where: { $0.name.lowercased() == id }) {
            return (custom.name, custom.icon, custom.description)
        }
        return (id.capitalized, "cpu", "Agente especialista")
    }

    // MARK: - Proactive

    func enqueueProactive(message: String, agentID: String) {
        let msg = VERBOMessage(role: .proactive, content: message,
                               agentID: agentID, agentIcon: agentMeta(for: agentID).icon,
                               intent: .alertar, isProactive: true)
        proactiveQueue.append(msg)
        messages.append(msg)
    }

    // MARK: - Controle

    func clearMessages() {
        messages = []
        memory.clearSession("main")
    }

    func installAgent(_ spec: CustomAgentSpec) {
        guard !installedAgents.contains(where: { $0.id == spec.id }) else { return }
        installedAgents.append(spec)
        AgentPersistence.save(installedAgents)
        logger.info("Agent installed: \(spec.name)")
    }

    func removeAgent(_ spec: CustomAgentSpec) {
        installedAgents.removeAll { $0.id == spec.id }
        AgentPersistence.save(installedAgents)
    }

    func loadPersistedAgents() {
        installedAgents = AgentPersistence.load()
    }
}

// MARK: - Persistência de Agentes

enum AgentPersistence {
    private static let key = "verbo_custom_agents_v3"

    static func save(_ agents: [CustomAgentSpec]) {
        if let data = try? JSONEncoder().encode(agents) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func load() -> [CustomAgentSpec] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let agents = try? JSONDecoder().decode([CustomAgentSpec].self, from: data)
        else { return [] }
        return agents
    }
}
