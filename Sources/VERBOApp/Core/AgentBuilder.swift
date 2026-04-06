// AgentBuilder.swift
// Cria novos agentes declarativos em tempo de execução, apenas com pedido do usuário
// Trinid © 2026

import Foundation

// MARK: - Spec de Agente Customizado

struct AgentPolicy: Codable, Equatable {
    var needsConfirmation   : Bool     = true
    var canRunBackground    : Bool     = false
    var canSendWithoutOK    : Bool     = false
    var maxTokensPerCall    : Int      = 400
    var allowedTools        : [String] = []
}

struct AgentOutputSchema: Codable, Equatable {
    var style  : String = "friendly"
    var format : String = "markdown"
}

struct CustomAgentSpec: Identifiable, Codable, Equatable {
    var id             = UUID()
    var name           : String
    var icon           : String
    var description    : String
    var trigger        : String
    var triggerExamples: [String]
    var requiredTools  : [String]
    var policy         : AgentPolicy
    var outputSchema   : AgentOutputSchema
    var systemPrompt   : String
    var isActive       : Bool = true
    var createdAt      : Date = Date()
    var usageCount     : Int = 0

    static func == (lhs: CustomAgentSpec, rhs: CustomAgentSpec) -> Bool { lhs.id == rhs.id }
}

// MARK: - Agent Builder Service

final class AgentBuilderService {
    static let shared = AgentBuilderService()

    // Templates de agentes prontos por domínio
    private let domainTemplates: [String: CustomAgentSpec] = {
        var templates: [String: CustomAgentSpec] = [:]

        templates["instagram"] = CustomAgentSpec(
            name: "Instagram Post",
            icon: "camera.fill",
            description: "Cria e agenda posts para Instagram",
            trigger: "instagram",
            triggerExamples: ["poste no instagram", "cria post instagram", "prepara conteúdo instagram"],
            requiredTools: ["calendar.reminder", "share_sheet", "photos.picker", "web.search"],
            policy: AgentPolicy(needsConfirmation: true, canRunBackground: true, allowedTools: ["calendar", "share"]),
            outputSchema: AgentOutputSchema(style: "criativo", format: "post_plan"),
            systemPrompt: "Você é um especialista em marketing digital para Instagram. Crie posts envolventes, com hashtags relevantes e call-to-action. Sugira o melhor horário baseado em engajamento."
        )

        templates["twitter"] = CustomAgentSpec(
            name: "Twitter/X",
            icon: "bird.fill",
            description: "Cria threads e tweets",
            trigger: "twitter",
            triggerExamples: ["posta no twitter", "cria tweet", "faz thread"],
            requiredTools: ["share_sheet", "web.search"],
            policy: AgentPolicy(needsConfirmation: true, allowedTools: ["share"]),
            outputSchema: AgentOutputSchema(style: "conciso", format: "tweet"),
            systemPrompt: "Você é um especialista em Twitter/X. Crie tweets concisos e impactantes (max 280 chars). Para threads, numere cada tweet. Use hashtags estratégicas."
        )

        templates["linkedin"] = CustomAgentSpec(
            name: "LinkedIn",
            icon: "briefcase.fill",
            description: "Cria conteúdo profissional para LinkedIn",
            trigger: "linkedin",
            triggerExamples: ["posta no linkedin", "cria post linkedin", "artigo linkedin"],
            requiredTools: ["share_sheet", "web.search"],
            policy: AgentPolicy(needsConfirmation: true, allowedTools: ["share"]),
            outputSchema: AgentOutputSchema(style: "profissional", format: "linkedin_post"),
            systemPrompt: "Você é um especialista em conteúdo profissional para LinkedIn. Crie posts que geram engajamento com tom profissional, histórias de impacto e insights de valor."
        )

        templates["frete"] = CustomAgentSpec(
            name: "Calculadora Frete",
            icon: "truck.box.fill",
            description: "Calcula frete e CIOT conforme ANTT",
            trigger: "frete",
            triggerExamples: ["calcula frete", "quanto custa frete", "CIOT para"],
            requiredTools: ["calculator", "web.search"],
            policy: AgentPolicy(needsConfirmation: false, allowedTools: ["calculator"]),
            outputSchema: AgentOutputSchema(style: "técnico", format: "freight_calculation"),
            systemPrompt: "Você é especialista em logística e cálculo de fretes conforme Resolução ANTT 6.076/2026. Calcule frete mínimo, CIOT (1% do valor), pedágio estimado e total líquido."
        )

        templates["contrato"] = CustomAgentSpec(
            name: "Contratos AGREX",
            icon: "doc.text.fill",
            description: "Gera contratos CCV, CDR e Barter",
            trigger: "contrato",
            triggerExamples: ["gera contrato", "cria contrato CCV", "contrato de venda"],
            requiredTools: ["document.creator", "share_sheet"],
            policy: AgentPolicy(needsConfirmation: true, allowedTools: ["document"]),
            outputSchema: AgentOutputSchema(style: "jurídico", format: "contract_template"),
            systemPrompt: "Você é especialista em contratos agropecuários. Gere contratos CCV (Compra e Venda), CDR (Cédula de Depósito Rural) e Barter com todas as cláusulas legais necessárias."
        )

        templates["trading"] = CustomAgentSpec(
            name: "Trading Signal",
            icon: "chart.line.uptrend.xyaxis",
            description: "Analisa sinais de trading via Λ-FLOW",
            trigger: "trading",
            triggerExamples: ["sinal btc", "analisa mercado", "regime atual"],
            requiredTools: ["web.search", "api.binance"],
            policy: AgentPolicy(needsConfirmation: true, allowedTools: ["web", "api"]),
            outputSchema: AgentOutputSchema(style: "técnico", format: "trading_signal"),
            systemPrompt: "Você é especialista em análise técnica usando o framework Λ-FLOW (Hilbert Phase, RegimeDetection, Confluência). Analise EMA, RSI, ADX, volume e regime para gerar sinais BUY/SELL/NEUTRAL com probabilidade."
        )

        return templates
    }()

    // MARK: - Construção de Agente a partir de Texto

    func buildAgent(from text: String) async -> CustomAgentSpec? {
        let lower = text.lowercased()

        // 1. Verifica templates prontos
        for (keyword, template) in domainTemplates {
            if lower.contains(keyword) {
                var spec = template
                spec.id = UUID()
                return spec
            }
        }

        // 2. Template genérico baseado na solicitação
        return buildGenericAgent(from: text)
    }

    private func buildGenericAgent(from text: String) -> CustomAgentSpec {
        // Extrai nome do agente do texto
        let nameMatch = extractAgentName(from: text)
        let domain    = extractDomain(from: text)
        let tools     = extractTools(from: text)

        return CustomAgentSpec(
            name: nameMatch,
            icon: iconFor(domain: domain),
            description: "Agente especialista para: \(text.prefix(80))",
            trigger: domain,
            triggerExamples: [text.lowercased().prefix(50).description],
            requiredTools: tools,
            policy: AgentPolicy(needsConfirmation: true, allowedTools: tools),
            outputSchema: AgentOutputSchema(style: "assistente", format: "markdown"),
            systemPrompt: """
            Você é um agente especialista criado especificamente para: \(text)
            Seja preciso, eficiente e proativo. Responda em português.
            Quando precisar de confirmação do usuário, pergunte claramente.
            """
        )
    }

    private func extractAgentName(from text: String) -> String {
        let patterns = [
            #"agente (de |para |do |da |)?([A-Za-zÀ-ú\s]{3,30})"#,
            #"assistente (de |para )?([A-Za-zÀ-ú\s]{3,20})"#,
        ]
        for pat in patterns {
            if let match = try? NSRegularExpression(pattern: pat, options: .caseInsensitive)
                .firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
                let range = match.range(at: 2)
                if let r = Range(range, in: text) {
                    let name = String(text[r]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if name.count > 2 {
                        return name.prefix(1).uppercased() + name.dropFirst()
                    }
                }
            }
        }
        return "Agente \(Date().formatted(.dateTime.hour().minute()))"
    }

    private func extractDomain(from text: String) -> String {
        let lower = text.lowercased()
        let domains: [(String, String)] = [
            ("instagram", "instagram"), ("twitter", "twitter"), ("facebook", "facebook"),
            ("email", "email"), ("whatsapp", "whatsapp"), ("telegram", "telegram"),
            ("frete", "frete"), ("contrato", "contrato"), ("agro", "agronegócio"),
            ("bitcoin", "crypto"), ("trading", "trading"),
            ("agenda", "calendário"), ("reunião", "calendário"),
            ("código", "programação"), ("script", "programação"),
        ]
        for (kw, domain) in domains {
            if lower.contains(kw) { return domain }
        }
        return "geral"
    }

    private func extractTools(from text: String) -> [String] {
        var tools: [String] = []
        let lower = text.lowercased()
        if lower.contains("post") || lower.contains("social") { tools.append("share_sheet") }
        if lower.contains("email") || lower.contains("e-mail") { tools.append("mail.compose") }
        if lower.contains("agenda") || lower.contains("calendário") { tools.append("calendar") }
        if lower.contains("busca") || lower.contains("pesquisa") { tools.append("web.search") }
        if lower.contains("foto") || lower.contains("imagem") { tools.append("photos.picker") }
        if lower.contains("notificação") || lower.contains("alerta") { tools.append("notifications") }
        if tools.isEmpty { tools = ["web.search", "notifications"] }
        return tools
    }

    private func iconFor(domain: String) -> String {
        switch domain {
        case "instagram":    return "camera.fill"
        case "twitter":      return "bird.fill"
        case "email":        return "envelope.fill"
        case "whatsapp":     return "message.fill"
        case "calendário":   return "calendar.badge.plus"
        case "programação":  return "curlybraces"
        case "frete":        return "truck.box.fill"
        case "crypto", "trading": return "chart.line.uptrend.xyaxis"
        case "agronegócio":  return "leaf.fill"
        default:             return "sparkles"
        }
    }

    // MARK: - Mensagem de confirmação

    func confirmationMessage(for agent: CustomAgentSpec) -> String {
        """
        ✅ **Agente '\(agent.name)' criado com sucesso!**

        • **Função:** \(agent.description)
        • **Gatilho:** '\(agent.trigger)'
        • **Ferramentas:** \(agent.requiredTools.joined(separator: ", "))
        • **Confirmação necessária:** \(agent.policy.needsConfirmation ? "Sim" : "Não")

        Para usar, basta mencionar '\(agent.trigger)' em qualquer mensagem.
        Você pode gerenciá-lo em **Agentes → Meus Agentes**.
        """
    }
}
