// SpecialistAgents.swift
// Todos os agentes especialistas do VERBO Multiagente
// OperatorAgent · MessageAgent · MailAgent · CalendarAgent
// ResearchAgent · SocialAgent · CoderAgent · ProactiveMonitor
// Trinid © 2026

import Foundation
import EventKit
import UIKit

// MARK: - Protocolo Base

protocol VERBOAgent {
    var agentID   : String { get }
    var agentName : String { get }
    var agentIcon : String { get }
}

// MARK: - Operator Agent
// Executa ações operacionais: abre apps, prepara ações, aciona intents
// @MainActor garante que todas as chamadas UIKit (UIApplication.shared.open) sejam na main thread

@MainActor
final class OperatorAgent: VERBOAgent {
    static let shared = OperatorAgent()
    let agentID   = "operator"
    let agentName = "Operacional"
    let agentIcon = "bolt.fill"

    func handle(text: String, engine: VERBOEngine) async -> String {
        let lower = text.lowercased()

        if lower.contains("whatsapp") {
            if lower.contains("abre") || lower.contains("abrir") || lower.contains("open") {
                let contact = extractContact(from: text)
                let message = extractQuotedText(from: text)
                engine.connections.openWhatsApp(to: contact, message: message)
                return "📱 **WhatsApp:** " + (contact.isEmpty
                    ? "Abrindo WhatsApp…"
                    : "Preparando mensagem para \(contact)\(message.isEmpty ? "" : ": \"\(message)\"")")
            }
            return suggestWhatsApp(text: text, engine: engine)
        }

        if lower.contains("telegram") {
            engine.connections.openTelegram()
            return "✈️ **Telegram:** Abrindo Telegram…"
        }

        if lower.contains("ligar") || lower.contains("chamar") || lower.contains("call") {
            let phone = extractPhone(from: text)
            if !phone.isEmpty {
                if let url = URL(string: "tel://\(phone)") {
                    UIApplication.shared.open(url)
                }
                return "📞 Iniciando chamada para \(phone)…"
            }
        }

        if lower.contains("abre") || lower.contains("abrir") {
            return handleOpen(text: lower, engine: engine)
        }

        return ""
    }

    private func suggestWhatsApp(text: String, engine: VERBOEngine) -> String {
        let contact = extractContact(from: text)
        let message = extractQuotedText(from: text)

        return """
        💬 **Ação WhatsApp planejada:**

        • Destinatário: \(contact.isEmpty ? "não especificado" : contact)
        • Mensagem: \(message.isEmpty ? "não especificada" : "\"\(message)\"")

        Para enviar, o WhatsApp abrirá automaticamente com os dados preenchidos.
        Diga **"confirma"** para prosseguir.
        """
    }

    private func handleOpen(_ text: String, engine: VERBOEngine) -> String {
        let apps: [(String, String)] = [
            ("instagram", "instagram://"), ("twitter", "twitter://"),
            ("linkedin", "linkedin://"), ("spotify", "spotify://"),
            ("youtube", "youtube://"), ("maps", "maps://"),
            ("camera", "camera://"), ("photos", "photos-redirect://"),
        ]
        for (name, scheme) in apps {
            if text.contains(name) {
                if let url = URL(string: scheme) {
                    UIApplication.shared.open(url)
                    return "📲 Abrindo \(name.capitalized)…"
                }
            }
        }
        return ""
    }

    private func extractContact(from text: String) -> String {
        // Extrai número de telefone
        if let match = text.range(of: #"\+?[\d\s\-\(\)]{10,16}"#, options: .regularExpression) {
            return String(text[match]).trimmingCharacters(in: .whitespaces)
        }
        // Extrai nome após "para" ou "pro"
        if let match = try? NSRegularExpression(pattern: #"(?:para|pro|pra)\s+([A-Za-zÀ-ú]{2,20})"#, options: .caseInsensitive)
            .firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
            if let r = Range(match.range(at: 1), in: text) { return String(text[r]) }
        }
        return ""
    }

    private func extractPhone(from text: String) -> String {
        if let match = text.range(of: #"\+?[\d\s\-\(\)]{10,16}"#, options: .regularExpression) {
            return String(text[match]).filter { $0.isNumber }
        }
        return ""
    }

    private func extractQuotedText(from text: String) -> String {
        let patterns = [#""([^"]+)""#, #"'([^']+)'"#, #"dizendo[:\s]+"(.+?)""#]
        for pat in patterns {
            if let match = try? NSRegularExpression(pattern: pat, options: .caseInsensitive)
                .firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
                if let r = Range(match.range(at: 1), in: text) { return String(text[r]) }
            }
        }
        return ""
    }
}

// MARK: - Message Agent
// Triagem de notificações e mensagens proativas

final class MessageAgent: VERBOAgent {
    static let shared = MessageAgent()
    let agentID   = "message"
    let agentName = "Mensagens"
    let agentIcon = "message.fill"

    func handle(text: String, engine: VERBOEngine) async -> String {
        let lower = text.lowercased()
        let profile = engine.memory.profile

        if lower.contains("lê") || lower.contains("leia") || lower.contains("ler") {
            return readNotificationSummary(engine: engine)
        }

        if lower.contains("responde") || lower.contains("responder") || lower.contains("resposta") {
            return suggestReply(text: text, engine: engine)
        }

        if lower.contains("mensagem") && (lower.contains("importante") || lower.contains("urgente")) {
            let contact = profile.contacts["meu pai"] ?? "contato"
            return proactiveNotificationExample(contact: contact)
        }

        return """
        💬 **Agente de Mensagens:**

        O que posso fazer:
        • **Ler** notificações recentes
        • **Resumir** conversas longas
        • **Sugerir** respostas rápidas
        • **Filtrar** por urgência

        Diga "lê minhas mensagens" ou "preciso responder [pessoa]".
        """
    }

    private func readNotificationSummary(engine: VERBOEngine) -> String {
        let name = engine.memory.profile.name
        let greeting = name.isEmpty ? "" : "\(name), "
        return """
        📬 **\(greeting)Resumo de Mensagens:**

        Para ler suas mensagens reais, o VERBO precisa de acesso às notificações.
        Ative em **Configurações → Notificações → VERBO**.

        Uma vez ativo, eu posso:
        • Resumir mensagens não lidas
        • Priorizar por urgência
        • Sugerir respostas prontas
        • Avisar sobre contatos importantes
        """
    }

    private func suggestReply(text: String, engine: VERBOEngine) -> String {
        return """
        ✍️ **Sugestão de Resposta:**

        Baseado no contexto, aqui estão 3 opções:

        1. **Formal:** "Olá! Recebi sua mensagem e retornarei em breve."
        2. **Amigável:** "Oi! Vi sua mensagem, já estou vendo. 😊"
        3. **Rápida:** "Ok, entendido!"

        Quer que eu adapte para alguém específico?
        """
    }

    private func proactiveNotificationExample(contact: String) -> String {
        return """
        🔔 **Mensagem importante de \(contact)!**

        Recebi uma notificação que pode ser relevante.

        O que você gostaria de fazer?
        • **"Lê"** — para ver o conteúdo
        • **"Responde"** — para eu sugerir uma resposta
        • **"Ignora"** — para adiar
        """
    }
}

// MARK: - Mail Agent

final class MailAgent: VERBOAgent {
    static let shared = MailAgent()
    let agentID   = "mail"
    let agentName = "E-mail"
    let agentIcon = "envelope.fill"

    func handle(text: String, engine: VERBOEngine) async -> String {
        let lower = text.lowercased()

        if lower.contains("envia") || lower.contains("manda") || lower.contains("escreve") {
            return composeEmail(text: text, engine: engine)
        }
        if lower.contains("responde") || lower.contains("reply") {
            return suggestEmailReply(text: text)
        }
        if lower.contains("lê") || lower.contains("ler") || lower.contains("lista") {
            return listEmails()
        }

        return emailCapabilities()
    }

    private func composeEmail(text: String, engine: VERBOEngine) -> String {
        let to      = extractEmailAddress(from: text)
        let subject = extractSubject(from: text)
        let body    = extractEmailBody(from: text)

        if !to.isEmpty || !subject.isEmpty {
            engine.connections.composeEmail(to: to, subject: subject, body: body)
            return """
            📧 **E-mail preparado:**

            • Para: \(to.isEmpty ? "não especificado" : to)
            • Assunto: \(subject.isEmpty ? "não especificado" : subject)

            O app de e-mail abrirá automaticamente com os dados preenchidos.
            """
        }

        return """
        📧 **Novo E-mail:**

        Para criar um e-mail, especifique:
        • **Destinatário:** "envia email para [endereço]"
        • **Assunto:** inclua "assunto: [texto]"
        • **Mensagem:** inclua o conteúdo após dois pontos

        Exemplo: "envia email para joao@empresa.com assunto: Reunião"
        """
    }

    private func suggestEmailReply(text: String) -> String {
        return """
        ✍️ **Rascunho de Resposta:**

        Aqui está uma resposta profissional:

        ---
        Prezado(a),

        Agradeço pelo contato. Em resposta à sua mensagem, [conteúdo da resposta].

        Atenciosamente,
        [Seu nome]
        ---

        Quer que eu adapte com informações específicas?
        """
    }

    private func listEmails() -> String {
        return """
        📫 **Caixa de Entrada:**

        Para acessar seus e-mails, preciso de integração com o app de Mail.

        Por enquanto posso:
        • Preparar **rascunhos** completos
        • **Responder** e-mails que você colar aqui
        • Criar **templates** de e-mail profissional
        • Abrir o app de Mail com destinatário e assunto preenchidos

        Diga "escreve email para [pessoa] sobre [assunto]".
        """
    }

    private func emailCapabilities() -> String {
        return """
        📬 **Agente de E-mail:**

        • **Compor:** "escreve email para [email] sobre [assunto]"
        • **Responder:** "responde email: [cole o e-mail aqui]"
        • **Template:** "cria template de proposta comercial"
        • **Urgente:** "email urgente para [pessoa]"
        """
    }

    private func extractEmailAddress(from text: String) -> String {
        if let match = text.range(of: #"[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}"#,
                                   options: .regularExpression) {
            return String(text[match])
        }
        return ""
    }

    private func extractSubject(from text: String) -> String {
        if let match = try? NSRegularExpression(pattern: #"assunto[:\s]+"?([^".\n]{5,60})"?"#, options: .caseInsensitive)
            .firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let r = Range(match.range(at: 1), in: text) {
            return String(text[r]).trimmingCharacters(in: .whitespaces)
        }
        return ""
    }

    private func extractEmailBody(from text: String) -> String {
        if let match = try? NSRegularExpression(pattern: #"(?:mensagem|body|conteúdo)[:\s]+"([^"]{10,})"#, options: .caseInsensitive)
            .firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let r = Range(match.range(at: 1), in: text) {
            return String(text[r])
        }
        return ""
    }
}

// MARK: - Calendar Agent

final class CalendarAgent: VERBOAgent {
    static let shared = CalendarAgent()
    let agentID   = "calendar"
    let agentName = "Calendário"
    let agentIcon = "calendar.badge.plus"

    private let store = EKEventStore()

    func handle(text: String, engine: VERBOEngine) async -> String {
        let lower = text.lowercased()

        if lower.contains("cria") || lower.contains("adiciona") || lower.contains("agenda") {
            return await createEvent(from: text)
        }
        if lower.contains("lista") || lower.contains("mostra") || lower.contains("próximos") {
            return await listEvents()
        }
        if lower.contains("lembrete") || lower.contains("avisa") {
            return createReminder(from: text)
        }

        return calendarCapabilities()
    }

    private func createEvent(from text: String) async -> String {
        let title = extractEventTitle(from: text)
        let date  = extractDate(from: text)
        let time  = extractTime(from: text)

        let accessGranted: Bool = await withCheckedContinuation { cont in
            store.requestFullAccessToEvents { granted, _ in cont.resume(returning: granted) }
        }

        if accessGranted {
            let event        = EKEvent(eventStore: store)
            event.title      = title.isEmpty ? "Novo evento (VERBO)" : title
            event.startDate  = resolveDate(date: date, time: time)
            event.endDate    = event.startDate.addingTimeInterval(3600)
            event.calendar   = store.defaultCalendarForNewEvents

            do {
                try store.save(event, span: .thisEvent)
                return """
                📅 **Evento criado no Calendário!**

                • **Título:** \(event.title ?? "Evento")
                • **Data:** \(event.startDate.formatted(.dateTime.day().month().year()))
                • **Hora:** \(event.startDate.formatted(.dateTime.hour().minute()))

                Você encontrará em seu app de Calendário.
                """
            } catch {
                return "❌ Não foi possível salvar no calendário: \(error.localizedDescription)"
            }
        } else {
            return calendarPermissionMessage(title: title, date: date, time: time)
        }
    }

    private func listEvents() async -> String {
        let accessGranted: Bool = await withCheckedContinuation { cont in
            store.requestFullAccessToEvents { granted, _ in cont.resume(returning: granted) }
        }

        guard accessGranted else {
            return "⚙️ Para listar eventos, autorize o acesso ao Calendário nas Configurações do iOS."
        }

        let now      = Date()
        let end      = Calendar.current.date(byAdding: .day, value: 7, to: now)!
        let pred     = store.predicateForEvents(withStart: now, end: end, calendars: nil)
        let events   = store.events(matching: pred).prefix(10)

        if events.isEmpty {
            return "📅 Nenhum evento nos próximos 7 dias."
        }

        let lines = events.map { e -> String in
            let date = e.startDate.formatted(.dateTime.weekday(.wide).day().month())
            let time = e.startDate.formatted(.dateTime.hour().minute())
            return "• **\(e.title ?? "Sem título")** — \(date) às \(time)"
        }

        return "📅 **Próximos eventos:**\n\n" + lines.joined(separator: "\n")
    }

    private func createReminder(from text: String) -> String {
        let title = extractEventTitle(from: text)
        let time  = extractTime(from: text)
        return """
        🔔 **Lembrete configurado:**

        • **O quê:** \(title.isEmpty ? "Lembrete" : title)
        • **Quando:** \(time.isEmpty ? "Hoje" : time)

        Lembretes precisam de acesso ao app Lembretes do iOS.
        Ative em **Ajustes → VERBO → Lembretes**.
        """
    }

    private func calendarPermissionMessage(title: String, date: String, time: String) -> String {
        return """
        📅 **Evento planejado:**

        • **Título:** \(title.isEmpty ? "Novo evento" : title)
        • **Data:** \(date.isEmpty ? "a definir" : date)
        • **Hora:** \(time.isEmpty ? "a definir" : time)

        Para salvar automaticamente, autorize o acesso ao Calendário:
        **Ajustes → VERBO → Calendário → Permitir**
        """
    }

    private func calendarCapabilities() -> String {
        return """
        📅 **Agente de Calendário:**

        • **Criar evento:** "agenda reunião amanhã às 14h"
        • **Listar:** "mostra próximos eventos"
        • **Lembrete:** "me lembra de [tarefa] às 10h"
        • **Disponibilidade:** "tenho janela livre esta semana?"
        """
    }

    private func extractEventTitle(from text: String) -> String {
        let skip = ["agenda", "cria", "adiciona", "evento", "reunião", "amanhã", "hoje",
                    "às", "para", "no", "na", "lembrete", "avisa", "me"]
        let words = text.components(separatedBy: .whitespaces)
            .filter { !skip.contains($0.lowercased()) && $0.count > 2 }
            .prefix(5)
        return words.joined(separator: " ")
    }

    private func extractDate(from text: String) -> String {
        let lower = text.lowercased()
        if lower.contains("hoje")   { return "hoje" }
        if lower.contains("amanhã") { return "amanhã" }
        if let match = text.range(of: #"\d{1,2}/\d{1,2}(?:/\d{2,4})?"#, options: .regularExpression) {
            return String(text[match])
        }
        return ""
    }

    private func extractTime(from text: String) -> String {
        if let match = text.range(of: #"\d{1,2}h\d{0,2}|\d{1,2}:\d{2}"#, options: .regularExpression) {
            return String(text[match])
        }
        return ""
    }

    private func resolveDate(date: String, time: String) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: Date())

        if date == "amanhã" {
            components.day = (components.day ?? 0) + 1
        }

        if let hourMatch = time.range(of: #"(\d{1,2})h?:?(\d{0,2})"#, options: .regularExpression) {
            let parts = String(time[hourMatch]).components(separatedBy: CharacterSet(charactersIn: "h:"))
            if let h = Int(parts.first ?? "") { components.hour = h }
            if parts.count > 1, let m = Int(parts[1]) { components.minute = m }
        }

        return Calendar.current.date(from: components) ?? Date().addingTimeInterval(3600)
    }
}

// MARK: - Research Agent

final class ResearchAgent: VERBOAgent {
    static let shared = ResearchAgent()
    let agentID   = "researcher"
    let agentName = "Pesquisa"
    let agentIcon = "magnifyingglass"

    func handle(text: String, engine: VERBOEngine) async -> String {
        let lower = text.lowercased()

        // Pesquisa de mercado financeiro
        if lower.contains("btc") || lower.contains("bitcoin") || lower.contains("crypto") {
            return await cryptoResearch(text: text)
        }

        // Dados macroeconômicos
        if lower.contains("inflação") || lower.contains("juros") || lower.contains("pib") {
            return macroResearch(text: text)
        }

        // Agronegócio
        if lower.contains("soja") || lower.contains("milho") || lower.contains("boi") {
            return agroResearch(text: text)
        }

        return searchCapabilities()
    }

    private func cryptoResearch(text: String) async -> String {
        return """
        📊 **Pesquisa Crypto (Λ-FLOW):**

        Para dados em tempo real, configure a API em **Conexões → APIs**.

        **Análise estrutural atual:**
        • Framework: Hilbert Phase Transform
        • Modelo: VERBO QLLM (classificador)
        • Regime: detectado via ADX + HMM
        • Signal: aguardando confirmação de confluência

        **Para análise completa diga:**
        "Analisa BTC/USDT com Λ-FLOW"
        """
    }

    private func macroResearch(text: String) -> String {
        return """
        🌍 **Pesquisa Macroeconômica:**

        • **Fonte:** FRED, Banco Central, IBGE
        • **Dados disponíveis:** inflação, PIB, juros, câmbio, liquidez

        Para dados em tempo real, configure as fontes em **Conexões → APIs → Macro**.

        Posso analisar:
        • Impacto de juros em ativos de risco
        • Correlação DXY × BTC × Commodities
        • Regime de mercado global
        """
    }

    private func agroResearch(text: String) -> String {
        return """
        🌾 **Pesquisa Agronegócio (AGREX):**

        • **Cotações:** CBOT, B3, ESALQ
        • **Frete:** ANTT Resolução 6.076/2026
        • **Contratos:** CCV, CDR, Barter

        Configure acesso à API AGREX em **Conexões → APIs → Agro**.

        Posso calcular:
        • Basis e arbitragem de mercado
        • Custo logístico total (frete + CIOT + pedágio)
        • Preço PPI do diesel
        """
    }

    private func searchCapabilities() -> String {
        return """
        🔬 **Agente de Pesquisa (SINGULARIS + ΛNCT):**

        • **Mercado:** cotações, sinais, regime
        • **Macro:** juros, inflação, liquidez global
        • **Agro:** soja, milho, frete, contratos
        • **Web:** busca e síntese de informações

        Pergunte diretamente: "Pesquisa sobre [tema]"
        """
    }
}

// MARK: - Social Agent

final class SocialAgent: VERBOAgent {
    static let shared = SocialAgent()
    let agentID   = "social"
    let agentName = "Social"
    let agentIcon = "square.and.pencil"

    func handle(text: String, engine: VERBOEngine) async -> String {
        let lower = text.lowercased()

        if lower.contains("instagram") { return createInstagramPost(text: text) }
        if lower.contains("twitter") || lower.contains("tweet") { return createTweet(text: text) }
        if lower.contains("linkedin") { return createLinkedInPost(text: text) }
        if lower.contains("tiktok") { return createTikTokScript(text: text) }

        return socialCapabilities()
    }

    private func createInstagramPost(text: String) -> String {
        let topic = extractTopic(from: text)
        return """
        📸 **Plano de Post — Instagram:**

        **Caption sugerida:**
        "\(generateCaption(topic: topic))"

        **Hashtags:**
        #\(topic.replacingOccurrences(of: " ", with: "")) #verbo #ia #brasil #inovacao

        **Melhor horário:** 18h–21h (maior engajamento)
        **Formato:** Carrossel 4–8 slides ou Reels 15–30s

        **Próximo passo:**
        Diga "confirma" para eu abrir o Instagram com o texto copiado,
        ou "adapta para [público-alvo]" para personalizar.
        """
    }

    private func createTweet(text: String) -> String {
        let topic = extractTopic(from: text)
        let tweet = String("💡 \(generateCaption(topic: topic)) #\(topic.prefix(15)) #verbo".prefix(280))
        return """
        🐦 **Tweet pronto:**

        "\(tweet)"

        (\(tweet.count)/280 caracteres)

        **Thread sugerida:**
        1/3 — Contexto
        2/3 — Desenvolvimento
        3/3 — Call-to-action

        Diga "cria thread completa" para expandir.
        """
    }

    private func createLinkedInPost(text: String) -> String {
        let topic = extractTopic(from: text)
        return """
        💼 **Post LinkedIn:**

        **Título:** [Hook impactante sobre \(topic)]

        **Estrutura:**
        🎯 Problema que todo profissional enfrenta em \(topic)...

        Aprendi que [insight valioso].

        3 lições que mudaram minha perspectiva:
        1️⃣ ...
        2️⃣ ...
        3️⃣ ...

        O que você acha? Comente abaixo! 👇

        **Tom:** Profissional mas próximo
        **Ideal:** 150–300 palavras
        """
    }

    private func createTikTokScript(text: String) -> String {
        let topic = extractTopic(from: text)
        return """
        🎵 **Script TikTok (60s):**

        **Hook (0–3s):** "Você sabia que \(topic) pode [fato surpreendente]?"

        **Desenvolvimento (3–45s):**
        • Ponto 1: [dado ou história]
        • Ponto 2: [exemplo prático]
        • Ponto 3: [dica actionável]

        **CTA (45–60s):** "Segue para mais sobre \(topic)! Link na bio. 💡"

        **Sons sugeridos:** trending na semana
        **Legenda:** 3 hashtags + 1 pergunta para engajamento
        """
    }

    private func socialCapabilities() -> String {
        return """
        📱 **Agente Social:**

        • **Instagram:** posts, reels, stories, carrossel
        • **Twitter/X:** tweets e threads
        • **LinkedIn:** artigos e posts profissionais
        • **TikTok:** scripts de vídeo

        Diga: "cria post [plataforma] sobre [tema]"
        """
    }

    private func extractTopic(from text: String) -> String {
        let skip = ["cria", "post", "poste", "instagram", "twitter", "linkedin", "tiktok",
                    "posta", "para", "sobre", "um", "uma", "de", "do", "da"]
        let words = text.lowercased().components(separatedBy: .whitespaces)
            .filter { !skip.contains($0) && $0.count > 2 }
            .prefix(4)
        return words.isEmpty ? "tecnologia" : words.joined(separator: " ")
    }

    private func generateCaption(topic: String) -> String {
        let templates = [
            "Descobri algo incrível sobre \(topic) que vai mudar sua perspectiva.",
            "A verdade sobre \(topic) que ninguém te conta.",
            "\(topic.prefix(1).uppercased() + topic.dropFirst()): o que aprendi depois de [X] anos.",
            "Por que \(topic) é mais importante do que você imagina.",
        ]
        return templates.randomElement() ?? "Sobre \(topic)…"
    }
}

// MARK: - Coder Agent

final class CoderAgent: VERBOAgent {
    static let shared = CoderAgent()
    let agentID   = "coder"
    let agentName = "Código"
    let agentIcon = "curlybraces"

    func handle(text: String) -> String {
        let lower = text.lowercased()

        if lower.contains("python") || lower.contains("script") {
            return pythonTemplate(text: text)
        }
        if lower.contains("swift") || lower.contains("ios") {
            return swiftTemplate(text: text)
        }
        if lower.contains("api") || lower.contains("endpoint") {
            return apiTemplate(text: text)
        }
        if lower.contains("backtest") || lower.contains("estratégia") {
            return backtestTemplate(text: text)
        }

        return coderCapabilities()
    }

    private func pythonTemplate(text: String) -> String {
        return """
        💻 **Script Python (template):**

        ```python
        # VERBO Script — gerado automaticamente
        import pandas as pd
        import numpy as np

        def main():
            # TODO: implementar lógica aqui
            pass

        if __name__ == "__main__":
            main()
        ```

        Descreva a lógica em detalhes e a IA gerará o código completo.
        Ou conecte a API LLM para código profissional instantâneo.
        """
    }

    private func swiftTemplate(text: String) -> String {
        return """
        📱 **SwiftUI Component (template):**

        ```swift
        struct MyView: View {
            @State private var value = ""

            var body: some View {
                VStack {
                    Text("Olá VERBO!")
                        .font(.title)
                    TextField("Valor", text: $value)
                }
                .padding()
            }
        }
        ```

        Diga qual componente precisa e gero o código completo.
        """
    }

    private func apiTemplate(text: String) -> String {
        return """
        🔌 **API FastAPI (template):**

        ```python
        from fastapi import FastAPI
        from pydantic import BaseModel

        app = FastAPI(title="VERBO API")

        class Request(BaseModel):
            message: str

        @app.post("/chat")
        async def chat(req: Request):
            return {"response": f"Processando: {req.message}"}
        ```

        Configure detalhes do endpoint e gero a versão completa.
        """
    }

    private func backtestTemplate(text: String) -> String {
        return """
        📊 **Backtest Template (Λ-FLOW):**

        ```python
        # VERBO Trading — Λ-FLOW Backtest
        import pandas as pd

        class Strategy:
            def __init__(self, symbol="BTC/USDT"):
                self.symbol = symbol
                self.positions = []

            def signal(self, df):
                # Hilbert Phase + EMA + RSI
                ema20 = df["close"].ewm(span=20).mean()
                ema50 = df["close"].ewm(span=50).mean()
                return "BUY" if ema20.iloc[-1] > ema50.iloc[-1] else "SELL"
        ```

        Conecte a API LLM para o sistema completo com backtesting real.
        """
    }

    private func coderCapabilities() -> String {
        return """
        💻 **Agente de Código:**

        • **Python:** scripts, análise, automação
        • **Swift/iOS:** componentes SwiftUI
        • **API:** FastAPI, endpoints REST
        • **Trading:** backtesting Λ-FLOW
        • **Agro:** cálculos AGREX, CIOT

        Diga: "cria um script Python para [tarefa]"
        """
    }
}

// MARK: - Proactive Monitor

@MainActor
final class ProactiveMonitor: ObservableObject {
    static let shared = ProactiveMonitor()

    @Published var isActive = false

    private weak var engine: VERBOEngine?
    private var timer: Timer?

    func start(engine: VERBOEngine) {
        self.engine = engine
        isActive    = true
        // Verificação periódica a cada 5 minutos
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { await self?.check() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer    = nil
        isActive = false
    }

    private func check() async {
        guard let engine else { return }

        // Verificação de hora do dia para sugestões
        let hour = Calendar.current.component(.hour, from: Date())

        if hour == 9 {
            engine.enqueueProactive(
                message: "☀️ **Bom dia!** Aqui está seu briefing matinal. Alguma tarefa prioritária para hoje?",
                agentID: "orchestrator")
        }

        if hour == 18 {
            engine.enqueueProactive(
                message: "🌙 **Fim de expediente!** Quer que eu resuma o que aconteceu hoje e prepare para amanhã?",
                agentID: "memory")
        }
    }

    func sendImmediateAlert(message: String, agentID: String = "guardian") {
        engine?.enqueueProactive(message: message, agentID: agentID)
    }

    /// Chamado pelo BGProactiveWorker durante background tasks
    func runBackgroundCheck() async {
        let hour = Calendar.current.component(.hour, from: Date())
        guard hour >= 8 && hour <= 22 else { return }
        // Foreground check que despacha alerta para a engine se ela estiver ativa
        await check()
    }
}
