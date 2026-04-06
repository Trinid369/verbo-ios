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
        � **Mensagem importante de \(contact)!**

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
        � **Lembrete configurado:**

        • **L]pꎊ��
]K�\�[\H��[X��]H��]JB�8�(�
��]X[�Ί��
[YK�\�[\H��ڙH��[YJB��[X��]\��X�\�[HHX�\���[�\[X��]\��S�˂�]]�H[H
��Z�\�\�8����T���8���[X��]\ʊ�������B���]�]H�[���[[�\�\�Z\��[ۓY\��Y�J]N���[��]N���[��[YN���[��HO���[���]\������<'��H
��]�[��[�Z�YΊ����8�(�
��0�][Ί��
]K�\�[\H���ݛ�]�[�Ȉ�]JB�8�(�
��]N���
]K�\�[\H��HY�[�\���]JB�8�(�
��ܘN���
[YK�\�[\H��HY�[�\���[YJB��\�H�[�\�]]�X]X�[Y[�K]]ܚ^�H�X�\���[��[[�0�\�[΂�
��Z�\�\�8����T���8����[[�0�\�[�8���\�Z]\��������B���]�]H�[���[[�\��\X�[]Y\�
HO���[���]\������<'��H
��Y�[�HH�[[�0�\�[Ί����8�(�
��ܚX\�]�[�Ί���Y�[�H�][�p���[X[�0��0��M��8�(�
��\�\�����[���H���[[��]�[��Ȃ�8�(�
��[X��]N����YH[X��HH�\�Y�WH0��L��8�(�
��\�ۚX�[YYN����[���[�[H]��H\�H�[X[�OȂ�����B���]�]H�[��^�X�]�[�]J���H^���[��HO���[��]��\HȘY�[�H��ܚXH��YX�[ۘH��]�[�ȋ��][�p��ȋ�[X[�0�ȋ�ڙH����ȋ�\�H���ȋ��H��[X��]H��]�\�H��YH�B�]�ܙ�H^���\ۙ[���\\�]Y�N���]\�X�\�B���[\��\��\��۝Z[��	���\��\�Y

JH	��	���[���B���Y�^

JB��]\���ܙ˚��[�Y
�\\�]܎���B�B���]�]H�[��^�X�]J���H^���[��HO���[��]��\�H^���\��\�Y

B�Y���\���۝Z[���ڙH�H��]\���ڙH�B�Y���\���۝Z[���[X[�0�ȊH��]\���[X[�0�ȈB�Y�]X]�H^��[��Jَ�ȗ�K�K��K�J΋�̋
JOȈ��[ۜΈ��Y�[\�^�\��[ۊH�]\����[��^�X]�JB�B��]\�����B���]�]H�[��^�X�[YJ���H^���[��HO���[��Y�]X]�H^��[��Jَ�ȗ�K�Z��_�K�N�̟H���[ۜΈ��Y�[\�^�\��[ۊH�]\����[��^�X]�JB�B��]\�����B���]�]H�[���\���Q]J]N���[��[YN���[��HO�]H�\���\ۙ[��H�[[�\���\��[��]P��\ۙ[��˞YX\��[۝�^K��\��Z[�]WK���N�]J
JB��Y�]HOH�[X[�0�Ȉ��\ۙ[�˙^HH
��\ۙ[�˙^H��
H
�B�B��Y�]�\�X]�H[YK��[��Jَ�Ȋ�K�JZΏ���JH���[ۜΈ��Y�[\�^�\��[ۊH]\��H��[��[YV��\�X]�JK���\ۙ[���\\�]Y�N��\�X�\��]
�\�X�\��[�����JB�Y�]H[�
\�˙�\������H���\ۙ[�˚�\�HB�Y�\�˘��[��K]HH[�
\���WJH���\ۙ[�˛Z[�]HHHB�B���]\���[[�\���\��[��]J���N���\ۙ[��H��]J
K�Y[��[YR[�\��[
͌
B�B�B����PT�ΈH�\�X\��Y�[����[�[�\���\�X\��Y�[���T���Y�[��]X�]�\�YH�\�X\��Y�[�

B�]Y�[�QH��\�X\��\���]Y�[��[YHH�\�]Z\�H��]Y�[�X�ۈH�XYۚY�Z[���\�Ȃ���[��[�J^���[��[��[�N��T���[��[�JH\�[��O���[��]��\�H^���\��\�Y

B����\�]Z\�HHY\��Y��[�[��Z\�Y���\���۝Z[����ȊH��\���۝Z[����]��[��H��\���۝Z[���ܞ\ȊH�]\��]�Z]ܞ\ԙ\�X\��
^�^
B�B����Y��XXܛ�X�۰�ZX��Y���\���۝Z[���[��p����ȊH��\���۝Z[��&�W&�2"�����vW"�6��F��2�'�""���&WGW&��7&�&W6V&6��FW�C�FW�B��Р���w&��V|;66���b��vW"�6��F��2�'6��"�����vW"�6��F��2�&֖Ɔ�"�����vW"�6��F��2�&&��"���&WGW&�w&�&W6V&6��FW�C�FW�B��Р�&WGW&�6V&6�6&�ƗF�W2���Р�&�fFRgV�27'�F�&W6V&6��FW�C�7G&��r�7��2��7G&��r��&WGW&�"" �	�8���W7V�67'�F����d��r������&FF�2V�FV��&V��6��f�wW&R�V���6��W�;VW2(i"�2��ࠢ���:Ɨ6RW7G'WGW&�GVâ���(
"g&�Wv�&�����&W'B�6RG&�6f�&Т(
"��FV��dU$$�����6�76�f�6F�"��(
"&Vv��S�FWFV7FF�f�E����Т(
"6�v�âwV&F�F�6��f�&�:|:6�FR6��f�\:��6�����&�:Ɨ6R6���WFF�v����$�Ɨ6%D2�U4EB6����d��r �"" �Р�&�fFRgV�2�7&�&W6V&6��FW�C�7G&��r���7G&��r��&WGW&�"" �	�����W7V�6�7&�V6��;F֖6�����(
"��f��FS���e$TB�&�6�6V�G&���$tP�(
"��FF�2F�7��:�fV�3�����f�:|:6���"��W&�2�<:&�&���ƗV�FW���&FF�2V�FV��&V��6��f�wW&R2f��FW2V���6��W�;VW2(i"�2(i"�7&𢢢ࠢ�76��Ɨ6#��(
"��7F�FR�W&�2V�F�f�2FR&�66�(
"6�'&V�:|:6�E��9r%D29r6����F�F�W0�(
"&Vv��RFR�W&6F�v��&��"" �Р�&�fFRgV�2w&�&W6V&6��FW�C�7G&��r���7G&��r��&WGW&�"" �	�����W7V�6w&��V|;66���u$U�������(
"��6�F:|;VW3���4$�B�#"�U4��(
"��g&WFS����EB&W6��\:|:6�b�sb�##`�(
"��6��G&F�3���45b�4E"�&'FW ��6��f�wW&R6W76�:�u$U�V���6��W�;VW2(i"�2(i"w&�ࠢ�76�6�7V�#��(
"&6�2R&&�G&vV�FR�W&6F�(
"7W7F���|:�7F�6�F�F��g&WFR�4��B�VL:v��(
"&\:v��F�F�W6V��"" �Р�&�fFRgV�26V&6�6&�ƗF�W2����7G&��r��&WGW&�"" �	�J���vV�FRFRW7V�6�4��uT�$�2���5B������(
"���W&6F󢢢6�F:|;VW2�6���2�&Vv��P�(
"���7&󢢢�W&�2���f�:|:6��ƗV�FW�v��&��(
"��w&󢢢6���֖Ɔ��g&WFR�6��G&F�0�(
"��vV#���'W66R<:��FW6RFR��f�&�:|;VW0��W&wV�FRF�&WF�V�FS�%W7V�66�'&R�FV�� �"" �ЧР����$���6�6��vV�@��f���6�726�6��vV�C�dU$$�vV�B��7FF�2�WB6�&VB�6�6��vV�B����WBvV�D�B�'6�6�� ��WBvV�D��R�%6�6�� ��WBvV�D�6���'7V&R��B�V�6�� ��gV�2��F�R�FW�C�7G&��r�V�v��S�dU$$�V�v��R�7��2��7G&��r���WB��vW"�FW�B���vW&66VB�����b��vW"�6��F��2�&��7Fw&�"��&WGW&�7&VFT��7Fw&��7B�FW�C�FW�B�Т�b��vW"�6��F��2�'Gv�GFW""�����vW"�6��F��2�'GvVWB"��&WGW&�7&VFUGvVWB�FW�C�FW�B�Т�b��vW"�6��F��2�&Ɩ�VF��"��&WGW&�7&VFTƖ�VD���7B�FW�C�FW�B�Т�b��vW"�6��F��2�'F��F��"��&WGW&�7&VFUF��F��67&�B�FW�C�FW�B�Р�&WGW&�6�6��6&�ƗF�W2���Р�&�fFRgV�27&VFT��7Fw&��7B�FW�C�7G&��r���7G&��r���WBF��2�W�G&7EF��2�g&�ӢFW�B��&WGW&�"" �	�;������FR�7B(	B��7Fw&Ӣ������6F���7VvW&�F����%vV�W&FT6F���F��3�F��2�� �����6�Fw3����5F��2�&W�6��t�67W'&V�6W2��c�""�v�F��""��7fW&&�6�6'&6��6���f6����VƆ�"��,:&�󢢢��(	3#�����"V�v��V�F���f�&�F󢢢6'&�76V�N(	3�6ƖFW2�R&VV�2^(	330����,;7����76󢢠�F�v&6��f�&�"&WR'&�"���7Fw&�6���FW�F�6��F����R&FF&�;�&Ɩ6���f��"&W'6��Ɨ�"�"" �Р�&�fFRgV�27&VFUGvVWB�FW�C�7G&��r���7G&��r���WBF��2�W�G&7EF��2�g&�ӢFW�B���WBGvVWB�7G&��r�/	�*vV�W&FT6F���F��3�F��2��5F��2�&Vf���R��7fW&&�"�&Vf���#����&WGW&�"" �	�
bGvVWB&��F󢢠��%GvVWB� ���GvVWB�6�V�B��#�6&7FW&W2�����F�&VB7VvW&�F�����2(	B6��FW�F�"�2(IBFW6V�f��f��V�F�2�2(	B6���F��7F��ࠢF�v&7&�F�&VB6���WF"&W��F�"�"" �Р�&�fFRgV�27&VFTƖ�VD���7B�FW�C�7G&��r���7G&��r���WBF��2�W�G&7EF��2�g&�ӢFW�B��&WGW&�"" �	�+����7BƖ�VD�㢢�����L:�GV�󢢢�������7F�FR6�'&RF��2�Р���W7G'WGW&����	���&�&�V�VRF�F�&�f�76����V�g&V�FV�F��2���ࠢ&V�F�VR���6�v�BfƖ�6��ࠢ2Ɯ:|;VW2VR�VF&�֖�W'7V7F�f�����(:2���.���(:2���>���(:2��ࠢ�VRf�<:�6��6��V�FR&���	�p����F�Ӣ��&�f�76�����2,;7�������FVâ��S(	33�g&0�"" �Р�&�fFRgV�27&VFUF��F��67&�B�FW�C�7G&��r���7G&��r���WBF��2�W�G&7EF��2�g&�ӢFW�B��&WGW&�"" �	��R��67&�BF��F���c2�������������(	372����%f�<:�6&�VRF��2��FR�fF�7W'&VV�FV�FU�� ����FW6V�f��f��V�F��>(	3CW2�����(
"��F���FF��R��7L;7&�Т(
"��F�#��W�V���,:F�6�Т(
"��F�3��F�67F���:fV�Р���5D�C^(	3c2����%6VwVR&��26�'&RF��2�Ɩ��&���	�* ����6��27VvW&�F�3���G&V�F��r�6V������VvV�F���2�6�Fw2�W&wV�F&V�v��V�F�"" �Р�&�fFRgV�26�6��6&�ƗF�W2����7G&��r��&WGW&�"" �	�;��vV�FR6�6�â����(
"����7Fw&Ӣ���7G2�&VV�2�7F�&�W2�6'&�76V��(
"��Gv�GFW"�����GvVWG2RF�&VG0�(
"��Ɩ�VD�㢢�'F�v�2R�7G2&�f�76����0�(
"��F��F�����67&�G2FRl:�FV�F�v�&7&��7B��Ff�&��6�'&R�FV�� �"" �Р�&�fFRgV�2W�G&7EF��2�g&��FW�C�7G&��r���7G&��r���WB6����&7&�"�'�7B"�'�7FR"�&��7Fw&�"�'Gv�GFW""�&Ɩ�VF��"�'F��F��"��'�7F"�'&"�'6�'&R"�'V�"�'V�"�&FR"�&F�"�&F%Т�WBv�&G2�FW�B���vW&66VB���6����V�G2�6W&FVD'���v��FW76W2���f��FW"�6���6��F��2�C�bbC�6�V�B�"Т�&Vf���B��&WGW&�v�&G2�4V�G��'FV6����v�"�v�&G2����VB�6W&F�#�""��Р�&�fFRgV�2vV�W&FT6F���F��3�7G&��r���7G&��r���WBFV��FW2���$FW66�'&��v���7,:�fV�6�'&RF��2�VRf��VF"7VW'7V7F�f�"��$fW&FFR6�'&RF��2�VR��w\:��FR6��F�"��%F��2�&Vf�����WW&66VB���F��2�G&�f�'7B�����VR&V�F�FW��2FR�����2�"��%�"VRF��2�:R��2���'F�FRF�VRf�<:���v���"��Т&WGW&�FV��FW2�&�F��V�V�V�B����%6�'&RF��2�(
n �ЧР����$���6�FW"vV�@��f���6�726�FW$vV�C�dU$$�vV�B��7FF�2�WB6�&VB�6�FW$vV�B����WBvV�D�B�&6�FW" ��WBvV�D��R�$<;6F�v� ��WBvV�D�6���&7W&ǖ'&6W2 ��gV�2��F�R�FW�C�7G&��r���7G&��r���WB��vW"�FW�B���vW&66VB�����b��vW"�6��F��2�'�F���"�����vW"�6��F��2�'67&�B"���&WGW&��F���FV��FR�FW�C�FW�B��Т�b��vW"�6��F��2�'7v�gB"�����vW"�6��F��2�&��2"���&WGW&�7v�gEFV��FR�FW�C�FW�B��Т�b��vW"�6��F��2�&�"�����vW"�6��F��2�&V�G���B"���&WGW&��FV��FR�FW�C�FW�B��Т�b��vW"�6��F��2�&&6�FW7B"�����vW"�6��F��2�&W7G&L:�v�"���&WGW&�&6�FW7EFV��FR�FW�C�FW�B��Р�&WGW&�6�FW$6&�ƗF�W2���Р�&�fFRgV�2�F���FV��FR�FW�C�7G&��r���7G&��r��&WGW&�"" �	�+���67&�B�F����FV��FR�������F���2dU$$�67&�B(IBvW&F�WF��F�6�V�FP����'B�F22@����'B�V��2� ��FVb��ₓ��2D�D����V�V�F"�;6v�6V��70���b����U����%�������#����ₐ� ��FW67&Wf�;6v�6V�FWFƆW2R�vW&,:�<;6F�v�6���WF���R6��V7FR����&<;6F�v�&�f�76������7F�L:&�V��"" �Р�&�fFRgV�27v�gEFV��FR�FW�C�7G&��r���7G&��r��&WGW&�"" �	�;��7v�gET�6����V�B�FV��FR������7v�g@�7G'V7Bוf�Ws�f�Wr��7FFR&�fFRf"f�VR�" ��f"&�G��6��Rf�Wr��e7F6���FW�B�$��:dU$$�"���f��B��F�F�R��FW�Df�V�B�%f��""�FW�C�Gf�VR��Т�FF��r���ТТ ��F�vV�6����V�FR&V6�6RvW&��<;6F�v�6���WF��"" �Р�&�fFRgV�2�FV��FR�FW�C�7G&��r���7G&��r��&WGW&�"" �	�H����f7D��FV��FR�������F���g&��f7F����'Bf7D��g&���F�F�2���'B&6T��FV����f7D��F�F�S�%dU$$��"���6�72&WVW7B�&6T��FV���W76vS�7G ����7B�"�6�B"��7��2FVb6�B�&W�&WVW7B���&WGW&��'&W7��6R#�b%&�6W76�F��&W��W76vW�'Т ��6��f�wW&RFWFƆW2F�V�G���BRvW&�fW'<:6�6���WF�"" �Р�&�fFRgV�2&6�FW7EFV��FR�FW�C�7G&��r���7G&��r��&WGW&�"" �	�8���&6�FW7BFV��FR���d��r�������F���2dU$$�G&F��r(	B��d��r&6�FW7@����'B�F22@��6�727G&FVw���FVb����E��6V�b�7��&���$%D2�U4EB"���6V�b�7��&���7��&���6V�b��6�F���2��Р�FVb6�v�6V�b�Fb���2���&W'B�6R�T��%4��V�#�Fe�&6��6R%��Wv҇7��#���Vₐ�V�S�Fe�&6��6R%��Wv҇7��S���Vₐ�&WGW&�$%U�"�bV�#���5����V�S���5���V�6R%4T�� � ��6��V7FR����&�6�7FV�6���WF�6��&6�FW7F��r&V��"" �Р�&�fFRgV�26�FW$6&�ƗF�W2����7G&��r��&WGW&�"" �	�+���vV�FRFR<;6F�v󢢠��(
"���F��㢢�67&�G2��:Ɨ6R�WF��:|:6�(
"��7v�gB���3���6����V�FW27v�gET��(
"������f7D��V�G���G2$U5@�(
"��G&F��s���&6�FW7F��r��d��p�(
"��w&󢢢<:�7V��2u$U��4��@��F�v�&7&�V�67&�B�F���&�F&Vf� �"" �ЧР����$���&�7F�fR���F� �����7F� �f���6�72&�7F�fT���F�#��'6W'f&�T�&�V7B��7FF�2�WB6�&VB�&�7F�fT���F�"����V&Ɨ6�VBf"�47F�fR�f�6P��&�fFRvV�f"V�v��S�dU$$�V�v��S�&�fFRf"F��W#�F��W#�gV�27F'B�V�v��S�dU$$�V�v��R���6V�b�V�v��R�V�v��P��47F�fR�G'VP���fW&�f�6:|:6�W&�;6F�66FR֖�WF�0�F��W"�F��W"�66�VGV�VEF��W"�v�F�F��T��FW'fâ3�&WVG3�G'VR���vV�6V�e����F6��v�B6V�c��6�V6���ТТР�gV�27F�����F��W#���fƖFFR���F��W"�����47F�fR�f�6P�Р�&�fFRgV�26�V6���7��2��wV&B�WBV�v��RV�6R�&WGW&�Р���fW&�f�6:|:6�FR��&F�F�&7VvW7L;VW0��WB��W"�6�V�F"�7W'&V�B�6����V�B���W"�g&�ӢFFR������b��W"�����V�v��R�V�VWVU&�7F�fR���W76vS�.)������&��F���V�W7L:6WR'&�Vf��r�F�����wV�F&Vf&��&�L:&�&���S�"��vV�D�C�&�&6�W7G&F�""��Р��b��W"�����V�v��R�V�VWVU&�7F�fR���W76vS�/	�ɒ��f��FRW�VF�V�FR��VW"VRWR&W7V��VR6��FV6WR���RR&W&R&��23�"��vV�D�C�&�V��'�"��ТР�gV�26V�D���VF�FT�W'B��W76vS�7G&��r�vV�D�C�7G&��r�&wV&F��"���V�v��S��V�VWVU&�7F�fR��W76vS��W76vR�vV�D�C�vV�D�B��Р����6��F�V��$u&�7F�fUv�&�W"GW&�FR&6�w&�V�BF6�0�gV�2'V�&6�w&�V�D6�V6���7��2���WB��W"�6�V�F"�7W'&V�B�6����V�B���W"�g&�ӢFFR����wV&B��W"���bb��W"��#"V�6R�&WGW&�Т��f�&Vw&�V�B6�V6�VRFW76��W'F&V�v��R6RV�W7F�fW"F�f�v�B6�V6����Ч�
