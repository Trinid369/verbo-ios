// ChatView.swift
// Interface de chat do VERBO — mensagens, input de voz/texto, ações rápidas
// Trinid © 2026

import SwiftUI

struct ChatView: View {
    @EnvironmentObject var engine: VERBOEngine
    @State private var input    = ""
    @State private var showMic  = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ChatHeaderBar()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        if engine.messages.isEmpty {
                            WelcomeScreen()
                                .padding(.top, 20)
                        }
                        ForEach(engine.messages) { msg in
                            MessageRow(message: msg)
                                .id(msg.id)
                        }
                        if engine.isThinking {
                            TypingIndicator(agentID: engine.activeAgent)
                        }
                        Color.clear.frame(height: 1).id("end")
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: engine.messages.count) {
                    withAnimation(.spring(duration: 0.3)) { proxy.scrollTo("end") }
                }
                .onChange(of: engine.isThinking) {
                    if engine.isThinking {
                        withAnimation { proxy.scrollTo("end") }
                    }
                }
            }

            ChatInputBar(input: $input, focused: $focused, onSend: send)
        }
        .background(Color.vBackground.ignoresSafeArea())
        .navigationBarHidden(true)
    }

    private func send() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        input = ""
        focused = false
        Task { await engine.process(text: text) }
    }
}

// MARK: - Chat Header

private struct ChatHeaderBar: View {
    @EnvironmentObject var engine: VERBOEngine
    @State private var showClear = false

    var body: some View {
        HStack(spacing: 12) {
            // Logo + status
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.vAccentSoft)
                        .frame(width: 36, height: 36)
                    Image(systemName: "cpu.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.vAccent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("VERBO")
                        .font(.vTitle2)
                        .foregroundColor(.vTextPrimary)
                    HStack(spacing: 6) {
                        if engine.isThinking {
                            PulseCircle(color: .vOrange, size: 5)
                            Text("processando…")
                                .font(.vCaption)
                                .foregroundColor(.vOrange)
                        } else {
                            PulseCircle(color: .vGreen, size: 5)
                            Text("online · Φ \(String(format: "%.3f", engine.phi))")
                                .font(.vCaption)
                                .foregroundColor(.vTextSecondary)
                        }
                    }
                }
            }

            Spacer()

            // API calls counter
            if engine.apiCalls > 0 {
                Text("\(engine.apiCalls) LLM")
                    .font(.vCaption)
                    .foregroundColor(.vTextTertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.vSurface2)
                    .cornerRadius(6)
            }

            // Clear button
            Button {
                showClear = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundColor(.vTextTertiary)
                    .frame(width: 32, height: 32)
                    .background(Color.vSurface2)
                    .cornerRadius(8)
            }
            .confirmationDialog("Limpar conversa?", isPresented: $showClear) {
                Button("Limpar histórico", role: .destructive) { engine.clearMessages() }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.vSurface)
        .overlay(Divider().foregroundColor(Color.vBorder), alignment: .bottom)
    }
}

// MARK: - Message Row

struct MessageRow: View {
    let message: VERBOMessage

    var isUser: Bool      { message.role == .user }
    var isProactive: Bool { message.isProactive }

    var body: some View {
        if isProactive {
            ProactiveRow(message: message)
        } else if isUser {
            UserBubble(message: message)
        } else {
            AssistantBubble(message: message)
        }
    }
}

// User bubble
private struct UserBubble: View {
    let message: VERBOMessage
    @State private var copied = false

    var body: some View {
        HStack {
            Spacer(minLength: 64)
            VStack(alignment: .trailing, spacing: 4) {
                Text(message.content)
                    .font(.vBody)
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.vAccent)
                    .cornerRadius(18, corners: [.topLeft, .topRight, .bottomLeft])
                    .onLongPressGesture { copyContent() }

                HStack(spacing: 6) {
                    Text(message.timestamp.formatted(.dateTime.hour().minute()))
                        .font(.vCaption)
                        .foregroundColor(.vTextTertiary)
                    if copied {
                        Text("copiado ✓")
                            .font(.vCaption)
                            .foregroundColor(.vGreen)
                            .transition(.opacity)
                    }
                }
            }
        }
    }

    private func copyContent() {
        UIPasteboard.general.string = message.content
        withAnimation { copied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { copied = false }
        }
    }
}

// Assistant bubble
private struct AssistantBubble: View {
    let message: VERBOMessage
    @EnvironmentObject var engine: VERBOEngine
    @State private var copied = false
    @State private var expanded = false

    var isLong: Bool { message.content.count > 600 }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            VStack(alignment: .leading, spacing: 6) {
                // Agent badge
                if let id = message.agentID {
                    AgentBadge(agentID: id)
                }

                // Conteúdo
                let displayContent = isLong && !expanded
                    ? String(message.content.prefix(600)) + "…"
                    : message.content

                Text(LocalizedStringKey(displayContent))
                    .font(.vBody)
                    .foregroundColor(.vTextPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.vSurface2)
                    .cornerRadius(18, corners: [.topLeft, .topRight, .bottomRight])
                    .onLongPressGesture { copyContent() }

                // Expand / meta
                HStack(spacing: 10) {
                    if isLong {
                        Button {
                            withAnimation { expanded.toggle() }
                        } label: {
                            Text(expanded ? "ver menos" : "ver mais")
                                .font(.vCaption)
                                .foregroundColor(.vAccent)
                        }
                    }
                    if let lat = message.latencyMs {
                        Text("\(Int(lat))ms")
                            .font(.vCaption)
                            .foregroundColor(.vTextTertiary)
                    }
                    if let phi = message.phiScore {
                        PhiIndicator(value: phi, compact: true)
                    }
                    if copied {
                        Text("✓ copiado")
                            .font(.vCaption)
                            .foregroundColor(.vGreen)
                            .transition(.opacity)
                    }
                }
            }
            Spacer(minLength: 48)
        }
    }

    private func copyContent() {
        UIPasteboard.general.string = message.content
        withAnimation { copied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { copied = false }
        }
    }
}

// Proactive row
private struct ProactiveRow: View {
    let message: VERBOMessage

    var body: some View {
        HStack(spacing: 10) {
            PulseCircle(color: .vOrange, size: 7)
            Text(LocalizedStringKey(message.content))
                .font(.vBody)
                .foregroundColor(.vTextPrimary)
            Spacer()
        }
        .padding(12)
        .background(Color.vOrange.opacity(0.08))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12)
            .stroke(Color.vOrange.opacity(0.2), lineWidth: 0.5))
    }
}

// MARK: - Typing Indicator

private struct TypingIndicator: View {
    let agentID: String
    @EnvironmentObject var engine: VERBOEngine
    @State private var phase = 0
    let timer = Timer.publish(every: 0.35, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                if !agentID.isEmpty {
                    AgentBadge(agentID: agentID)
                }
                HStack(spacing: 5) {
                    ForEach(0..<3) { i in
                        Circle()
                            .fill(Color.vTextSecondary)
                            .frame(width: 7, height: 7)
                            .scaleEffect(phase == i ? 1.3 : 0.8)
                            .animation(.spring(duration: 0.2), value: phase)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.vSurface2)
                .cornerRadius(18, corners: [.topLeft, .topRight, .bottomRight])
            }
            Spacer(minLength: 64)
        }
        .onReceive(timer) { _ in phase = (phase + 1) % 3 }
    }
}

// MARK: - Chat Input Bar

private struct ChatInputBar: View {
    @Binding var input: String
    var focused: FocusState<Bool>.Binding
    let onSend: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider().background(Color.vBorder)
            HStack(spacing: 10) {
                TextField("Mensagem…", text: $input, axis: .vertical)
                    .font(.vBody)
                    .foregroundColor(.vTextPrimary)
                    .lineLimit(1...6)
                    .focused(focused)
                    .submitLabel(.send)
                    .onSubmit { onSend() }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.vSurface2)
                    .cornerRadius(22)
                    .overlay(RoundedRectangle(cornerRadius: 22)
                        .stroke(Color.vBorder, lineWidth: 0.5))

                Button(action: onSend) {
                    Image(systemName: input.isEmpty ? "mic.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(input.isEmpty ? .vTextTertiary : .vAccent)
                        .animation(.spring(duration: 0.2), value: input.isEmpty)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.vSurface)
        }
    }
}

// MARK: - Welcome Screen

private struct WelcomeScreen: View {
    @EnvironmentObject var engine: VERBOEngine

    private let quickActions: [(String, String, String)] = [
        ("Sinal de mercado", "Qual é o sinal atual do BTC?", "chart.line.uptrend.xyaxis"),
        ("Criar agente",     "Cria um agente para Instagram", "plus.app.fill"),
        ("Calendário",       "Agenda reunião amanhã às 10h",  "calendar.badge.plus"),
        ("Post social",      "Cria post sobre IA para LinkedIn", "square.and.pencil"),
        ("Frete AGREX",      "Calcula frete de soja 600km",   "truck.box.fill"),
        ("Código Python",    "Cria script de análise de dados", "curlybraces"),
    ]

    var greeting: String {
        let name = engine.memory.profile.name
        let hour = Calendar.current.component(.hour, from: Date())
        let base = hour < 12 ? "Bom dia" : hour < 18 ? "Boa tarde" : "Boa noite"
        return name.isEmpty ? "\(base)! Sou o VERBO." : "\(base), \(name)!"
    }

    var body: some View {
        VStack(spacing: 24) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.vAccentSoft)
                    .frame(width: 88, height: 88)
                Image(systemName: "cpu.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.vAccent)
            }
            .shadow(color: Color.vAccent.opacity(0.3), radius: 20)

            // Greeting
            VStack(spacing: 6) {
                Text(greeting)
                    .font(.vLargeTitle)
                    .foregroundColor(.vTextPrimary)
                Text("Agente multiagente local. Como posso ajudar?")
                    .font(.vBody)
                    .foregroundColor(.vTextSecondary)
                    .multilineTextAlignment(.center)
            }

            // Profile summary
            if !engine.memory.profileSummary().isEmpty {
                Text(engine.memory.profileSummary())
                    .font(.vCaption)
                    .foregroundColor(.vTextTertiary)
                    .padding(.horizontal, 24)
                    .multilineTextAlignment(.center)
            }

            // Quick actions
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                ForEach(quickActions, id: \.0) { title, prompt, icon in
                    QuickActionChip(title: title, prompt: prompt, icon: icon)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
    }
}

private struct QuickActionChip: View {
    @EnvironmentObject var engine: VERBOEngine
    let title: String
    let prompt: String
    let icon: String

    var body: some View {
        Button {
            Task { await engine.process(text: prompt) }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.vAccent)
                    .frame(width: 18)
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.vTextPrimary)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(Color.vSurface2)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.vBorder, lineWidth: 0.5))
        }
    }
}
