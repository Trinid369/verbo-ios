// VERBOIntents.swift
// App Intents para integração com Siri e Atalhos
// Trinid © 2026

import AppIntents
import SwiftUI

// MARK: - App Shortcuts Provider

struct VERBOShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AskVERBOIntent(),
            phrases: [
                "Pergunte ao VERBO \(.applicationName)",
                "VERBO \(.applicationName)",
                "Fala pro VERBO \(.applicationName)"
            ],
            shortTitle: "Perguntar ao VERBO",
            systemImageName: "cpu.fill"
        )

        AppShortcut(
            intent: CheckMarketIntent(),
            phrases: [
                "Sinal de mercado no \(.applicationName)",
                "Qual é o BTC pelo \(.applicationName)",
                "Preço do Bitcoin no \(.applicationName)"
            ],
            shortTitle: "Sinal de Mercado",
            systemImageName: "chart.line.uptrend.xyaxis"
        )

        AppShortcut(
            intent: CreateAgentIntent(),
            phrases: [
                "Criar agente no \(.applicationName)",
                "Novo agente VERBO pelo \(.applicationName)"
            ],
            shortTitle: "Criar Agente",
            systemImageName: "plus.app.fill"
        )

        AppShortcut(
            intent: QuickNoteIntent(),
            phrases: [
                "Nota rápida no \(.applicationName)",
                "Lembra isso no \(.applicationName)"
            ],
            shortTitle: "Nota Rápida",
            systemImageName: "note.text.badge.plus"
        )
    }
}

// MARK: - Ask VERBO Intent

@MainActor
struct AskVERBOIntent: AppIntent {
    static let title: LocalizedStringResource = "Perguntar ao VERBO"
    static let description = IntentDescription("Envie uma pergunta diretamente para o VERBO.")
    static let openAppWhenRun: Bool = false

    @Parameter(title: "Pergunta", description: "O que você quer perguntar ao VERBO?")
    var question: String

    func perform() async throws -> some ReturnsValue<String> & ProvidesDialog {
        let engine = VERBOEngine.shared
        await engine.process(text: question)
        let reply = engine.messages.last?.content ?? "Sem resposta"
        return .result(value: reply, dialog: IntentDialog(stringLiteral: reply))
    }
}

// MARK: - Check Market Intent

@MainActor
struct CheckMarketIntent: AppIntent {
    static let title: LocalizedStringResource = "Sinal de Mercado"
    static let description = IntentDescription("Obtém o sinal de mercado atual para um ativo.")
    static let openAppWhenRun: Bool = false

    @Parameter(title: "Ativo", description: "Qual ativo? Ex: BTC, ETH, Soja", default: "BTC")
    var asset: String

    func perform() async throws -> some ReturnsValue<String> & ProvidesDialog {
        let prompt = "Qual é o sinal de mercado atual para \(asset)?"
        let engine = VERBOEngine.shared
        await engine.process(text: prompt)
        let reply = engine.messages.last?.content ?? "Dados indisponíveis"
        return .result(value: reply, dialog: IntentDialog(stringLiteral: reply))
    }
}

// MARK: - Create Agent Intent

struct CreateAgentIntent: AppIntent {
    static let title: LocalizedStringResource = "Criar Agente VERBO"
    static let description = IntentDescription("Cria um novo agente especialista no VERBO.")
    static let openAppWhenRun: Bool = true

    @Parameter(title: "Descrição do agente", description: "Descreva o agente que você quer criar")
    var agentDescription: String

    func perform() async throws -> some OpensIntent {
        return .result()
    }
}

// MARK: - Quick Note Intent

@MainActor
struct QuickNoteIntent: AppIntent {
    static let title: LocalizedStringResource = "Nota Rápida para VERBO"
    static let description = IntentDescription("Salva uma nota rápida para o VERBO lembrar.")
    static let openAppWhenRun: Bool = false

    @Parameter(title: "Nota", description: "O que o VERBO deve lembrar?")
    var note: String

    func perform() async throws -> some ReturnsValue<String> & ProvidesDialog {
        let prompt = "Lembra disso: \(note)"
        let engine = VERBOEngine.shared
        await engine.process(text: prompt)
        let reply = "Anotado: \(note)"
        return .result(value: reply, dialog: IntentDialog(stringLiteral: reply))
    }
}

// MARK: - Schedule Meeting Intent

@MainActor
struct ScheduleMeetingIntent: AppIntent {
    static let title: LocalizedStringResource = "Agendar Reunião"
    static let description = IntentDescription("Cria um evento no calendário via VERBO.")
    static let openAppWhenRun: Bool = false

    @Parameter(title: "Título da reunião")
    var title: String

    @Parameter(title: "Data e hora")
    var date: Date

    func perform() async throws -> some ReturnsValue<String> & ProvidesDialog {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "pt_BR")

        let prompt = "Agenda '\(title)' para \(formatter.string(from: date))"
        let engine = VERBOEngine.shared
        await engine.process(text: prompt)
        let reply = engine.messages.last?.content ?? "Evento criado"
        return .result(value: reply, dialog: IntentDialog(stringLiteral: reply))
    }
}
