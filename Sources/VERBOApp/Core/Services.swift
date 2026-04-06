// Services.swift
// LLMAdapter · GuardianService · ConnectionsManager · AppSettings
// Trinid © 2026

import Foundation
import Combine
import UIKit

// MARK: - LLM Provider

enum LLMProvider: String, CaseIterable, Identifiable, Codable {
    case anthropic = "anthropic"
    case openai    = "openai"
    case ollama    = "ollama"
    case custom    = "custom"

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .anthropic: return "Anthropic (Claude)"
        case .openai:    return "OpenAI / GPT"
        case .ollama:    return "Ollama (Local)"
        case .custom:    return "URL Customizada"
        }
    }
    var defaultModel: String {
        switch self {
        case .anthropic: return "claude-haiku-4-5-20251001"
        case .openai:    return "gpt-4o-mini"
        case .ollama:    return "llama3"
        case .custom:    return "custom-model"
        }
    }
    var icon: String {
        switch self {
        case .anthropic: return "atom"
        case .openai:    return "brain"
        case .ollama:    return "desktopcomputer"
        case .custom:    return "server.rack"
        }
    }
    var baseURL: String {
        switch self {
        case .anthropic: return "https://api.anthropic.com/v1/messages"
        case .openai:    return "https://api.openai.com/v1/chat/completions"
        case .ollama:    return "http://localhost:11434/api/chat"
        case .custom:    return ""
        }
    }
}

// MARK: - LLM Adapter

@MainActor
final class LLMAdapter: ObservableObject {
    static let shared = LLMAdapter()

    @Published var provider     : LLMProvider = .anthropic
    @Published var isConfigured : Bool        = false
    @Published var model        : String      = "claude-haiku-4-5-20251001"
    @Published var isStreaming  : Bool        = false

    private var apiKey  : String = ""
    private var baseURL : String = ""
    private let session = URLSession.shared

    func configure(provider: LLMProvider, apiKey: String, model: String, baseURL: String = "") {
        self.provider     = provider
        self.apiKey       = apiKey
        self.model        = model.isEmpty ? provider.defaultModel : model
        self.baseURL      = baseURL.isEmpty ? provider.baseURL : baseURL
        self.isConfigured = !apiKey.isEmpty || provider == .ollama

        AppSettings.shared.llmConfig = LLMConfig(
            provider: provider.rawValue,
            apiKey: apiKey,
            model: self.model,
            baseURL: baseURL)
        AppSettings.shared.save()
    }

    func loadSaved() {
        let cfg = AppSettings.shared.llmConfig
        if let p = LLMProvider(rawValue: cfg.provider) {
            provider      = p
            apiKey        = cfg.apiKey
            model         = cfg.model.isEmpty ? p.defaultModel : cfg.model
            baseURL       = cfg.baseURL.isEmpty ? p.baseURL : cfg.baseURL
            isConfigured  = !cfg.apiKey.isEmpty || p == .ollama
        }
    }

    // MARK: - Chat principal

    func chat(prompt: String, context: String = "",
              agentName: String = "VERBO",
              extraSystem: String = "",
              maxTokens: Int = 800) async -> String {
        guard isConfigured else {
            return "⚙️ Configure a API LLM em **Conexões → LLM** para respostas avançadas."
        }

        let agentDesc = buildAgentDesc(agentName)
        let system = [agentDesc, extraSystem, context.isEmpty ? "" : "Contexto:\n\(context)"]
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")

        switch provider {
        case .anthropic: return await callAnthropic(prompt: prompt, system: system, maxTokens: maxTokens)
        case .openai:    return await callOpenAI(prompt: prompt, system: system, maxTokens: maxTokens)
        case .ollama:    return await callOllama(prompt: prompt, system: system)
        case .custom:    return await callOpenAI(prompt: prompt, system: system, maxTokens: maxTokens)
        }
    }

    private func buildAgentDesc(_ agentName: String) -> String {
        """
        Você é \(agentName.capitalized), agente especialista do VERBO Multiagente.
        Responda em português brasileiro. Seja direto, útil e eficiente.
        Use markdown leve (negrito, listas) para clareza quando necessário.
        """
    }

    // MARK: - Anthropic

    private func callAnthropic(prompt: String, system: String, maxTokens: Int) async -> String {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else { return errMsg() }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json",  forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey,              forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01",        forHTTPHeaderField: "anthropic-version")
        req.timeoutInterval = 30

        let body: [String: Any] = [
            "model": model, "max_tokens": maxTokens,
            "system": system,
            "messages": [["role": "user", "content": prompt]]
        ]
        do {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, _) = try await session.data(for: req)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let content = (json?["content"] as? [[String: Any]])?.first?["text"] as? String
            if let err = json?["error"] as? [String: Any],
               let msg = err["message"] as? String { return "❌ API: \(msg)" }
            return content ?? errMsg()
        } catch { return "❌ \(error.localizedDescription)" }
    }

    // MARK: - OpenAI / Compatível

    private func callOpenAI(prompt: String, system: String, maxTokens: Int) async -> String {
        let url = URL(string: baseURL.isEmpty ? LLMProvider.openai.baseURL : baseURL)
        guard let url else { return errMsg() }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json",      forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)",       forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 30

        let body: [String: Any] = [
            "model": model, "max_tokens": maxTokens,
            "messages": [
                ["role": "system",  "content": system],
                ["role": "user",    "content": prompt]
            ]
        ]
        do {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, _) = try await session.data(for: req)
            let json     = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let choices  = json?["choices"] as? [[String: Any]]
            let message  = choices?.first?["message"] as? [String: Any]
            if let err = json?["error"] as? [String: Any],
               let msg = err["message"] as? String { return "❌ API: \(msg)" }
            return message?["content"] as? String ?? errMsg()
        } catch { return "❌ \(error.localizedDescription)" }
    }

    // MARK: - Ollama (local)

    private func callOllama(prompt: String, system: String) async -> String {
        guard let url = URL(string: "http://localhost:11434/api/chat") else { return errMsg() }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 60

        let body: [String: Any] = [
            "model": model, "stream": false,
            "messages": [
                ["role": "system",  "content": system],
                ["role": "user",    "content": prompt]
            ]
        ]
        do {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, _) = try await session.data(for: req)
            let json      = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let msg       = json?["message"] as? [String: Any]
            return msg?["content"] as? String ?? errMsg()
        } catch { return "❌ Ollama: \(error.localizedDescription)" }
    }

    private func errMsg() -> String { "❌ Falha na chamada LLM. Verifique configurações." }
}

// MARK: - Guardian Service

final class GuardianService {
    static let shared = GuardianService()

    private let blockedPatterns: [NSRegularExpression] = [
        #"PRIVATE[_\s]?KEY\s*="#,
        #"\bapi[_\s]?key\s*=[a-zA-Z0-9_\-]{10,}"#,
        #"\bpassword\s*=.{4,}"#,
        #"\bsecret\s*=.{4,}"#,
        #"[a-zA-Z0-9_\-]{32,}\.[a-zA-Z0-9_\-]{10,}\.[a-zA-Z0-9_\-]{10,}"#, // JWT-like
    ].compactMap { try? NSRegularExpression(pattern: $0, options: .caseInsensitive) }

    private let riskyActions = ["delete all", "rm -rf", "format disk", "wipe"]

    func isBlocked(text: String) -> Bool {
        let range = NSRange(text.startIndex..., in: text)
        let hasCredential = blockedPatterns.contains { $0.firstMatch(in: text, range: range) != nil }
        let hasRiskyAction = riskyActions.contains { text.lowercased().contains($0) }
        return hasCredential || hasRiskyAction
    }

    func auditMessage(_ text: String) -> String? {
        let lower = text.lowercased()
        if lower.contains("senha") || lower.contains("token") {
            return "⚠️ Detectei referência a dados sensíveis. Nunca compartilhe credenciais."
        }
        return nil
    }
}

// MARK: - Connections Manager

@MainActor
final class ConnectionsManager: ObservableObject {
    static let shared = ConnectionsManager()

    @Published var whatsappConnected   : Bool = false
    @Published var emailConfigured     : Bool = false
    @Published var calendarConnected   : Bool = false
    @Published var telegramConfigured  : Bool = false
    @Published var webEnabled          : Bool = true

    func openWhatsApp(to contact: String = "", message: String = "") {
        let encoded = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let phone   = contact.filter { $0.isNumber }
        let urlStr  = phone.isEmpty
            ? "whatsapp://send?text=\(encoded)"
            : "whatsapp://send?phone=\(phone)&text=\(encoded)"
        if let url = URL(string: urlStr) {
            UIApplication.shared.open(url)
        }
    }

    func composeEmail(to: String = "", subject: String = "", body: String = "") {
        let bodyEnc    = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let subjectEnc = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlStr     = "mailto:\(to)?subject=\(subjectEnc)&body=\(bodyEnc)"
        if let url = URL(string: urlStr) {
            UIApplication.shared.open(url)
        }
    }

    func openTelegram(to username: String = "") {
        let urlStr = username.isEmpty ? "tg://" : "tg://resolve?domain=\(username)"
        if let url = URL(string: urlStr) {
            UIApplication.shared.open(url)
        }
    }

    func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }

    func checkInstalledApps() {
        whatsappConnected  = canOpen("whatsapp://")
        telegramConfigured = canOpen("tg://")
    }

    private func canOpen(_ scheme: String) -> Bool {
        guard let url = URL(string: scheme) else { return false }
        return UIApplication.shared.canOpenURL(url)
    }
}

// MARK: - App Settings

struct LLMConfig: Codable {
    var provider : String = "anthropic"
    var apiKey   : String = ""
    var model    : String = ""
    var baseURL  : String = ""
}

struct NotificationConfig: Codable {
    var enabled         : Bool   = true
    var proactiveAlerts : Bool   = true
    var quietHoursStart : Int    = 22
    var quietHoursEnd   : Int    = 7
}

struct AppSettingsData: Codable {
    var llmConfig           : LLMConfig          = LLMConfig()
    var notifications       : NotificationConfig = NotificationConfig()
    var theme               : String             = "dark"
    var haptics             : Bool               = true
    var showLatency         : Bool               = true
    var showPhi             : Bool               = true
    var firstLaunch         : Bool               = true
    var userName            : String             = ""
    var language            : String             = "pt-BR"
    // UI preference settings (used by SettingsView)
    var proactiveAlerts     : Bool               = true
    var hapticEnabled       : Bool               = true
    var autoEscalate        : Bool               = true
    var continuousLearning  : Bool               = true
    var fontScale           : String             = "Médio"
    var responseLanguage    : String             = "Português"
}

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var data = AppSettingsData()

    private let key = "verbo_settings_v3"

    var llmConfig: LLMConfig {
        get { data.llmConfig }
        set { data.llmConfig = newValue }
    }

    init() { load() }

    func save() {
        if let d = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(d, forKey: key)
        }
    }

    func load() {
        guard let d = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode(AppSettingsData.self, from: d)
        else { return }
        data = decoded
    }

    func reset() {
        data = AppSettingsData()
        save()
    }
}

// UIKit is imported at the top of this file.
// UIApplication.shared is provided natively by UIKit — no extension needed.
