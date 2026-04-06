// SettingsView.swift
// Configurações do app VERBO — perfil, aparência, comportamento, sobre
// Trinid © 2026

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var engine: VERBOEngine
    @StateObject private var settings = AppSettings.shared

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {

                    // Perfil
                    SectionHeader(title: "Perfil")
                    ProfileSettingsCard()
                        .padding(.horizontal, 16)

                    // ACCU
                    SectionHeader(title: "ACCU · Parâmetros")
                    ACCUSettingsCard()
                        .padding(.horizontal, 16)

                    // Comportamento
                    SectionHeader(title: "Comportamento")
                    BehaviorSettingsCard()
                        .padding(.horizontal, 16)

                    // Aparência
                    SectionHeader(title: "Aparência")
                    AppearanceSettingsCard()
                        .padding(.horizontal, 16)

                    // Memória
                    SectionHeader(title: "Memória & Dados")
                    MemorySettingsCard()
                        .padding(.horizontal, 16)

                    // Sobre
                    SectionHeader(title: "Sobre")
                    AboutCard()
                        .padding(.horizontal, 16)
                        .padding(.bottom, 40)
                }
            }
            .background(Color.vBackground.ignoresSafeArea())
            .navigationTitle("Configurações")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color.vSurface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

// MARK: - Profile Settings

private struct ProfileSettingsCard: View {
    @EnvironmentObject var engine: VERBOEngine
    @State private var name  = ""
    @State private var saved = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.vAccentSoft)
                        .frame(width: 52, height: 52)
                    Text(initials)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.vAccent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(engine.memory.profile.name.isEmpty ? "Usuário" : engine.memory.profile.name)
                        .font(.vTitle2)
                        .foregroundColor(.vTextPrimary)
                    Text("\(engine.memory.profile.totalTurns) interações · \(engine.memory.profile.interests.count) interesses")
                        .font(.vCaption)
                        .foregroundColor(.vTextSecondary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Nome preferido").font(.vCaption2).foregroundColor(.vTextTertiary)
                VERBOTextField(placeholder: "Como devo te chamar?",
                               text: $name,
                               icon: "person.fill")
            }
            .onAppear { name = engine.memory.profile.name }

            VERBOButton(
                title: saved ? "✓ Salvo" : "Atualizar nome",
                icon: saved ? nil : "checkmark",
                action: {
                    engine.memory.profile.name = name.trimmingCharacters(in: .whitespaces)
                    engine.memory.save()
                    withAnimation { saved = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { saved = false }
                    }
                },
                style: saved ? .secondary : .primary)
        }
        .padding(14)
        .background(Color.vSurface2)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.vBorder, lineWidth: 0.5))
    }

    private var initials: String {
        let n = engine.memory.profile.name
        guard !n.isEmpty else { return "?" }
        let parts = n.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(n.prefix(2)).uppercased()
    }
}

// MARK: - ACCU Settings

private struct ACCUSettingsCard: View {
    @EnvironmentObject var engine: VERBOEngine

    var body: some View {
        VStack(spacing: 12) {
            // Live phi display
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Φ Potencial Atual")
                        .font(.vCaption2)
                        .foregroundColor(.vTextTertiary)
                    Text(String(format: "%.4f", engine.phi))
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundColor(phiColor)
                }
                Spacer()
                PhiIndicator(value: engine.phi, compact: false)
            }

            Divider().background(Color.vBorder)

            // Alpha
            ACCUSlider(label: "α · Probabilidade",
                       value: .constant(0.35),
                       description: "Peso da certeza na resposta")

            ACCUSlider(label: "β · Coerência",
                       value: .constant(0.30),
                       description: "Peso da consistência lógica")

            ACCUSlider(label: "γ · Energia",
                       value: .constant(0.20),
                       description: "Custo computacional preferencial")

            ACCUSlider(label: "δ · Estabilidade",
                       value: .constant(0.15),
                       description: "Peso da confiabilidade histórica")

            Text("Φ(x) = α(1−p) + β(1−c) + γe + δ(1−d)")
                .font(.vMono)
                .foregroundColor(.vTextTertiary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 4)
        }
        .padding(14)
        .background(Color.vSurface2)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.vBorder, lineWidth: 0.5))
    }

    private var phiColor: Color {
        if engine.phi < 0.3 { return .vGreen }
        if engine.phi < 0.5 { return .vOrange }
        return .vRed
    }
}

private struct ACCUSlider: View {
    let label: String
    @Binding var value: Double
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.vCaption)
                    .foregroundColor(.vTextSecondary)
                Spacer()
                Text(String(format: "%.2f", value))
                    .font(.vMono)
                    .foregroundColor(.vAccent)
            }
            Slider(value: $value, in: 0...1)
                .tint(.vAccent)
            Text(description)
                .font(.system(size: 10))
                .foregroundColor(.vTextTertiary)
        }
    }
}

// MARK: - Behavior Settings

private struct BehaviorSettingsCard: View {
    @StateObject private var settings = AppSettings.shared

    var body: some View {
        VStack(spacing: 0) {
            SettingsToggleRow(
                icon: "bell.badge.fill",
                iconColor: .vOrange,
                title: "Alertas proativos",
                subtitle: "VERBO monitora e te avisa proativamente",
                isOn: $settings.data.proactiveAlerts)

            Divider().background(Color.vBorder).padding(.leading, 50)

            SettingsToggleRow(
                icon: "waveform",
                iconColor: .vAccent,
                title: "Haptic feedback",
                subtitle: "Vibração ao enviar/receber mensagens",
                isOn: $settings.data.hapticEnabled)

            Divider().background(Color.vBorder).padding(.leading, 50)

            SettingsToggleRow(
                icon: "arrow.up.forward.circle.fill",
                iconColor: .vGreen,
                title: "Auto-escalar para LLM",
                subtitle: "Envia para API quando o QLLM local não é suficiente",
                isOn: $settings.data.autoEscalate)

            Divider().background(Color.vBorder).padding(.leading, 50)

            SettingsToggleRow(
                icon: "brain.head.profile",
                iconColor: Color(hex: "F472B6"),
                title: "Aprendizado contínuo",
                subtitle: "VERBO aprende seu nome, interesses e contatos",
                isOn: $settings.data.continuousLearning)
        }
        .background(Color.vSurface2)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.vBorder, lineWidth: 0.5))
    }
}

// MARK: - Appearance Settings

private struct AppearanceSettingsCard: View {
    @StateObject private var settings = AppSettings.shared

    var body: some View {
        VStack(spacing: 0) {
            SettingsToggleRow(
                icon: "moon.fill",
                iconColor: Color(hex: "60A5FA"),
                title: "Tema escuro",
                subtitle: "Interface com fundo escuro #0D0D12",
                isOn: .constant(true))

            Divider().background(Color.vBorder).padding(.leading, 50)

            SettingsPickerRow(
                icon: "textformat.size",
                iconColor: .vCyan,
                title: "Tamanho da fonte",
                options: ["Pequeno", "Médio", "Grande"],
                selected: $settings.data.fontScale)

            Divider().background(Color.vBorder).padding(.leading, 50)

            SettingsPickerRow(
                icon: "globe",
                iconColor: .vGreen,
                title: "Idioma de resposta",
                options: ["Português", "English", "Español"],
                selected: $settings.data.responseLanguage)
        }
        .background(Color.vSurface2)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.vBorder, lineWidth: 0.5))
    }
}

// MARK: - Memory Settings

private struct MemorySettingsCard: View {
    @EnvironmentObject var engine: VERBOEngine
    @State private var showClearConfirm    = false
    @State private var showProfileConfirm  = false

    var memoryKB: Int {
        let json = (try? JSONEncoder().encode(engine.memory.profile)) ?? Data()
        return json.count / 1024 + 1
    }

    var body: some View {
        VStack(spacing: 12) {
            // Stats
            HStack {
                MemoryStat(label: "Interações", value: "\(engine.memory.profile.totalTurns)")
                Divider().frame(height: 36).background(Color.vBorder)
                MemoryStat(label: "Interesses", value: "\(engine.memory.profile.interests.count)")
                Divider().frame(height: 36).background(Color.vBorder)
                MemoryStat(label: "Contatos", value: "\(engine.memory.profile.contacts.count)")
                Divider().frame(height: 36).background(Color.vBorder)
                MemoryStat(label: "Tamanho", value: "\(memoryKB) KB")
            }

            Divider().background(Color.vBorder)

            // Export
            Button {
                exportProfile()
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14))
                    Text("Exportar perfil (JSON)")
                        .font(.vBody)
                }
                .foregroundColor(.vAccent)
                .frame(maxWidth: .infinity)
            }

            // Clear chat
            Button {
                showClearConfirm = true
            } label: {
                HStack {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 14))
                    Text("Limpar histórico de chat")
                        .font(.vBody)
                }
                .foregroundColor(.vOrange)
                .frame(maxWidth: .infinity)
            }
            .confirmationDialog("Limpar histórico?", isPresented: $showClearConfirm) {
                Button("Limpar", role: .destructive) { engine.clearMessages() }
            } message: {
                Text("As mensagens serão apagadas. O perfil e memória são mantidos.")
            }

            // Reset profile
            Button {
                showProfileConfirm = true
            } label: {
                HStack {
                    Image(systemName: "person.crop.circle.badge.minus")
                        .font(.system(size: 14))
                    Text("Redefinir perfil e memória")
                        .font(.vBody)
                }
                .foregroundColor(.vRed)
                .frame(maxWidth: .infinity)
            }
            .confirmationDialog("Redefinir perfil?", isPresented: $showProfileConfirm) {
                Button("Redefinir", role: .destructive) {
                    engine.memory.resetProfile()
                }
            } message: {
                Text("Todos os dados aprendidos serão apagados permanentemente.")
            }
        }
        .padding(14)
        .background(Color.vSurface2)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.vBorder, lineWidth: 0.5))
    }

    private func exportProfile() {
        guard let data = try? JSONEncoder().encode(engine.memory.profile),
              let json = String(data: data, encoding: .utf8) else { return }
        let av = UIActivityViewController(activityItems: [json], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(av, animated: true)
        }
    }
}

private struct MemoryStat: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(.vTextPrimary)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.vTextTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - About Card

private struct AboutCard: View {
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.vAccentSoft)
                        .frame(width: 56, height: 56)
                    Image(systemName: "cpu.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.vAccent)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("VERBO Multiagente")
                        .font(.vTitle2)
                        .foregroundColor(.vTextPrimary)
                    Text("Versão 3.0 · iOS 18+")
                        .font(.vCaption)
                        .foregroundColor(.vTextSecondary)
                    Text("Trinid © 2026")
                        .font(.vCaption)
                        .foregroundColor(.vTextTertiary)
                }
                Spacer()
            }

            Divider().background(Color.vBorder)

            VStack(alignment: .leading, spacing: 6) {
                AboutRow(icon: "atom",           label: "Motor ACCU",      value: "Φ v3.0")
                AboutRow(icon: "cpu",            label: "Agentes nativos", value: "11 especialistas")
                AboutRow(icon: "brain",          label: "QLLM local",      value: "100M params")
                AboutRow(icon: "lock.shield",    label: "Privacidade",     value: "100% on-device")
                AboutRow(icon: "arrow.triangle.2.circlepath", label: "Arquitetura", value: "PicoClaw-iOS")
            }
        }
        .padding(14)
        .background(Color.vSurface2)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.vBorder, lineWidth: 0.5))
    }
}

private struct AboutRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.vAccent)
                .frame(width: 20)
            Text(label)
                .font(.vCaption)
                .foregroundColor(.vTextSecondary)
            Spacer()
            Text(value)
                .font(.vCaption)
                .foregroundColor(.vTextPrimary)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Reusable Setting Rows

struct SettingsToggleRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(iconColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.vBodyMedium).foregroundColor(.vTextPrimary)
                Text(subtitle).font(.vCaption).foregroundColor(.vTextSecondary).lineLimit(1)
            }
            Spacer()
            Toggle("", isOn: $isOn).tint(.vAccent).labelsHidden()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }
}

struct SettingsPickerRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let options: [String]
    @Binding var selected: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(iconColor)
            }
            Text(title).font(.vBodyMedium).foregroundColor(.vTextPrimary)
            Spacer()
            Menu {
                ForEach(options, id: \.self) { opt in
                    Button(opt) { selected = opt }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(selected)
                        .font(.vCaption)
                        .foregroundColor(.vTextSecondary)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(.vTextTertiary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }
}

// AppSettings is defined in Services.swift — no redeclaration needed here.
