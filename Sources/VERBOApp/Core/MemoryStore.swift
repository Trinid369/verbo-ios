// MemoryStore.swift
// Memória persistente com perfil do usuário — aprende hábitos, preferências e contexto
// Trinid © 2026

import Foundation

// MARK: - Entrada de Memória

struct MemoryEntry: Codable, Identifiable {
    var id      = UUID()
    let role    : String
    let content : String
    let ts      : Date
    var session : String
}

// MARK: - Perfil do Usuário

struct UserProfile: Codable {
    var name          : String = ""
    var preferredName : String = ""
    var language      : String = "pt-BR"
    var timezone      : String = "America/Sao_Paulo"
    var interests     : [String] = []
    var routines      : [String] = []   // "trabalha de manhã", "usa Bitcoin"
    var contacts      : [String: String] = [:] // "meu pai" → "João Silva"
    var preferences   : [String: String] = [:] // "tom" → "direto"
    var lastSeen      : Date = Date()
    var totalTurns    : Int = 0
    var topAgents     : [String: Int] = [:] // agente → usos
}

// MARK: - User Memory Store Principal

final class UserMemoryStore {
    static let shared = UserMemoryStore()

    private var sessions: [String: [MemoryEntry]] = [:]
    private let maxPerSession = 60
    private let queue = DispatchQueue(label: "verbo.memory", qos: .utility)

    var profile = UserProfile()

    init() {
        loadProfile()
        loadSessions()
    }

    // MARK: - Adicionar entrada

    func add(session: String, role: String, content: String) {
        queue.async { [weak self] in
            guard let self else { return }
            var hist = self.sessions[session] ?? []
            let entry = MemoryEntry(role: role,
                                    content: String(content.prefix(800)),
                                    ts: Date(), session: session)
            hist.append(entry)
            if hist.count > self.maxPerSession {
                hist = Array(hist.suffix(self.maxPerSession))
            }
            self.sessions[session] = hist
            self.persistSession(session)
        }
    }

    // MARK: - Observar e aprender sobre o usuário

    func observe(text: String) {
        profile.totalTurns += 1
        profile.lastSeen = Date()

        let lower = text.lowercased()

        // Aprende nome
        if profile.name.isEmpty {
            let patterns = [
                #"meu nome (é|e) ([A-ZÀ-Ú][a-záàâãéêíóôõúüç]+)"#,
                #"sou o ([A-ZÀ-Ú][a-záàâãéêíóôõúüç]+)"#,
                #"me chamo ([A-ZÀ-Ú][a-záàâãéêíóôõúüç]+)"#,
            ]
            for pat in patterns {
                if let range = text.range(of: pat, options: .regularExpression, locale: .current),
                   let match = try? NSRegularExpression(pattern: pat, options: .caseInsensitive).firstMatch(
                       in: text, range: NSRange(text.startIndex..., in: text)) {
                    let groups = (1..<match.numberOfRanges).compactMap { i -> String? in
                        let r = match.range(at: i)
                        guard let swiftRange = Range(r, in: text) else { return nil }
                        return String(text[swiftRange])
                    }
                    if let name = groups.last, name.count > 1 {
                        profile.name = name
                        profile.preferredName = name
                    }
                }
            }
            _ = text.range(of: "meu nome")   // suppress warning
        }

        // Aprende interesses
        let interestKeywords = [
            "bitcoin": "criptomoedas", "btc": "criptomoedas", "eth": "criptomoedas",
            "soja": "agronegócio", "frete": "logística", "ciot": "logística",
            "instagram": "redes sociais", "twitter": "redes sociais",
            "python": "programação", "swift": "programação", "api": "programação",
            "trading": "mercado financeiro", "bolsa": "mercado financeiro",
        ]
        for (kw, category) in interestKeywords {
            if lower.contains(kw) && !profile.interests.contains(category) {
                profile.interests.append(category)
            }
        }

        // Aprende contatos
        let contactPatterns = [
            (#"meu pai (.+?)(?:\.|,|$)"#, "meu pai"),
            (#"minha mãe (.+?)(?:\.|,|$)"#, "minha mãe"),
            (#"meu chefe (.+?)(?:\.|,|$)"#, "meu chefe"),
            (#"minha esposa (.+?)(?:\.|,|$)"#, "minha esposa"),
        ]
        for (pat, key) in contactPatterns {
            if let match = try? NSRegularExpression(pattern: pat, options: .caseInsensitive)
                .firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
                if let r = Range(match.range(at: 1), in: text) {
                    profile.contacts[key] = String(text[r]).trimmingCharacters(in: .whitespaces)
                }
            }
        }

        // Aprende tom preferido
        if lower.contains("seja mais direto") || lower.contains("resposta curta") {
            profile.preferences["tom"] = "direto"
        }
        if lower.contains("mais detalhado") || lower.contains("explica melhor") {
            profile.preferences["tom"] = "detalhado"
        }

        saveProfile()
    }

    func recordAgentUse(_ agentID: String) {
        profile.topAgents[agentID, default: 0] += 1
        saveProfile()
    }

    // MARK: - Contexto para LLM

    func buildContext(session: String, recentN: Int = 8) -> String {
        let entries = recent(session: session, n: recentN)
        guard !entries.isEmpty else { return "" }
        return entries
            .map { "[\($0.role)]: \($0.content)" }
            .joined(separator: "\n")
    }

    func userProfilePrompt() -> String {
        var lines: [String] = []
        if !profile.name.isEmpty {
            lines.append("Usuário: \(profile.name)")
        }
        if !profile.interests.isEmpty {
            lines.append("Interesses: \(profile.interests.joined(separator: ", "))")
        }
        if !profile.contacts.isEmpty {
            let c = profile.contacts.map { "\($0.key) = \($0.value)" }.joined(separator: ", ")
            lines.append("Contatos conhecidos: \(c)")
        }
        if let tom = profile.preferences["tom"] {
            lines.append("Tom preferido: \(tom)")
        }
        if !lines.isEmpty {
            return "Perfil do usuário:\n" + lines.joined(separator: "\n")
        }
        return ""
    }

    // MARK: - Recall inteligente

    func recall(session: String, query: String = "") -> String {
        let entries = sessions[session] ?? []
        guard !entries.isEmpty else {
            return "📭 Nenhum histórico nesta sessão ainda.\n\n\(profileSummary())"
        }
        let recent = entries.suffix(12)
        var lines = recent.map { "[\($0.role)]: \($0.content.prefix(120))…" }

        if !profile.name.isEmpty {
            lines.insert("👤 Usuário: \(profile.name)", at: 0)
        }
        if !profile.interests.isEmpty {
            lines.insert("🎯 Interesses: \(profile.interests.joined(separator: ", "))", at: 1)
        }

        return "🧠 **Memória ativa:**\n\n" + lines.joined(separator: "\n")
    }

    func profileSummary() -> String {
        guard !profile.name.isEmpty else { return "" }
        var s = "Sei que seu nome é **\(profile.name)**"
        if !profile.interests.isEmpty {
            s += " e você tem interesse em \(profile.interests.prefix(3).joined(separator: ", "))"
        }
        return s + "."
    }

    // MARK: - Acesso

    func recent(session: String, n: Int = 8) -> [MemoryEntry] {
        Array((sessions[session] ?? []).suffix(n))
    }

    func clearSession(_ session: String) {
        sessions[session] = []
        queue.async { [weak self] in
            let url = self?.fileURL(session: session)
            url.flatMap { try? FileManager.default.removeItem(at: $0) }
        }
    }

    func allSessions() -> [String] { Array(sessions.keys) }

    /// Expõe `saveProfile` como API pública (chamada por SettingsView)
    func save() { saveProfile() }

    /// Reseta o perfil do usuário para os valores padrão
    func resetProfile() {
        profile = UserProfile()
        saveProfile()
        sessions = [:]
        let dir = documentsURL()
        let files = (try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil))?.filter {
            $0.lastPathComponent.hasPrefix("vs_")
        } ?? []
        for file in files { try? FileManager.default.removeItem(at: file) }
    }

    // MARK: - Persistência

    private func persistSession(_ session: String) {
        guard let entries = sessions[session],
              let data = try? JSONEncoder().encode(entries) else { return }
        let url = fileURL(session: session)
        try? data.write(to: url, options: .atomic)
    }

    private func loadSessions() {
        let dir = documentsURL()
        let files = (try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil))?.filter {
            $0.lastPathComponent.hasPrefix("vs_")
        } ?? []
        for file in files {
            if let data = try? Data(contentsOf: file),
               let entries = try? JSONDecoder().decode([MemoryEntry].self, from: data) {
                let session = file.deletingPathExtension().lastPathComponent
                    .replacingOccurrences(of: "vs_", with: "")
                sessions[session] = entries
            }
        }
    }

    private func saveProfile() {
        if let data = try? JSONEncoder().encode(profile) {
            let url = documentsURL().appendingPathComponent("verbo_profile.json")
            try? data.write(to: url, options: .atomic)
        }
    }

    private func loadProfile() {
        let url = documentsURL().appendingPathComponent("verbo_profile.json")
        if let data = try? Data(contentsOf: url),
           let p = try? JSONDecoder().decode(UserProfile.self, from: data) {
            profile = p
        }
    }

    private func fileURL(session: String) -> URL {
        let safe = session.replacingOccurrences(of: "[^\\w-]", with: "_", options: .regularExpression)
        return documentsURL().appendingPathComponent("vs_\(safe).json")
    }

    private func documentsURL() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
