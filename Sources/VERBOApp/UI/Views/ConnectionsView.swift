// ConnectionsView.swift
// Gerenciamento de todas as conexões: LLM, WhatsApp, Email, Calendário, APIs
// Trinid © 2026

import SwiftUI

struct ConnectionsView: View {
    @EnvironmentObject var engine: VERBOEngine
    @StateObject private var llm         = LLMAdapter.shared
    @StateObject private var connections = ConnectionsManager.shared

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {

                    // Status geral
                    ConnectionSummaryBanner()
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    // LLM
                    SectionHeader(title: "API LLM")
                    LLMConnectionCard()
                        .padding(.horizontal, 16)

                    // Aplicativos
                    SectionHeader(title: "Aplicativos")

                    VStack(spacing: 10) {
                        AppConnectionRow(
                            name: "WhatsApp",
                            icon: "message.fill",
                            color: Color(hex: "25D366"),
                            status: connections.whatsappConnected ? "Instalado" : "Não instalado",
                            isConnected: connections.whatsappConnected,
                            description: "Abrir conversas e preparar mensagens",
                            action: { connections.openWhatsApp() })

                        AppConnectionRow(
                            name: "Telegram",
                            icon: "paperplane.fill",
                            color: Color(hex: "2AABEE"),
                            status: connections.telegramConfigured ? "Instalado" : "Não instalado",
                            isConnected: connections.telegramConfigured,
                            description: "Abrir chats no Telegram",
                            action: { connections.openTelegram() })

                        AppConnectionRow(
                            name: "E-mail",
                            icon: "envelope.fill",
                            color: .vCyan,
                            status: "Nativo iOS",
                            isConnected: true,
                            description: "Composição de e-mails via app nativo",
                            action: { connections.composeEmail() })

                        AppConnectionRow(
                            name: "Calendário",
                            icon: "calendar.badge.plus",
                            color: .vPurple,
                            status: "Requer permissão",
                            isConnected: connections.calendarConnected,
                            description: "Criar e listar eventos",
                            action: {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            })
                    }
                    .padding(.horizontal, 16)

                    // APIs Externas
                    SectionHeader(title: "APIs Externas")

                    VStack(spacing: 10) {
                        APIConnectionRow(
                            name: "Binance",
                            icon: "chart.line.uptrend.xyaxis",
                            color: Color(hex: "F0B90B"),
                            description: "Dados de mercado em tempo real",
                            placeholder: "API Key Binance",
                            settingsKey: "binance_key")

                        APIConnectionRow(
                            name: "AGREX / Logística",
                            icon: "truck.box.fill",
                            color: Color(hex: "34D399"),
                            description: "Fretes, CIOT e cotações agro",
                            placeholder: "Token AGREX",
                            settingsKey: "agrex_token")
                    }
                    .padding(.horizontal, 16)

                    // Notificações
                    SectionHeader(title: "Notificações")
                    NotificationSettingsCard()
                        .padding(.horizontal, 16)
                        .padding(.bottom, 40)
                }
            }
            .background(Color.vBackground.ignoresSafeArea())
            .navigationTitle("Conexões")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color.vSurface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .onAppear { connections.checkInstalledApps() }
        }
    }
}

// MARK: - Connection Summary Banner

private struct ConnectionSummaryBanner: View {
    @StateObject private var llm = LLMAdapter.shared

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(llm.isConfigured ? "LLM Ativo" : "LLM não configurado")
                    .font(.vBodyMedium)
                    .foregroundColor(llm.isConfigured ? .vGreen : .vOrange)
                if llm.isConfigured {
                    Text("\(llm.provider.displayName) · \(llm.model)")
                        .font(.vCaption)
                        .foregroundColor(.vTextSecondary)
                } else {
                    Text("Configure para respostas avançadas")
                        .font(.vCaption)
                        .foregroundColor(.vTextTertiary)
                }
            }

            Spacer()

            Image(systemName: llm.isConfigured ? "checkmark.shield.fill" : "exclamationmark.shield")
                .font(.system(size: 24))
                .foregroundColor(llm.isConfigured ? .vGreen : .vOrange)
        }
        .padding(14)
        .background(llm.isConfigured ? Color.vGreen.opacity(0.08) : Color.vOrange.opacity(0.08))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12)
            .stroke(llm.isConfigured ? Color.vGreen.opacity(0.2) : Color.vOrange.opacity(0.2), lineWidth: 0.5))
    }
}

// MARK: - LLM Connection Card

struct LLMConnectionCard: View {
    @StateObject private var llm      = LLMAdapter.shared
    @State private var selectedProvider = LLMProvider.anthropic
    @State private var apiKey         = ""
    @State private var model          = ""
    @State private var baseURL        = ""
    @State private var isSaved        = false
    @State private var showKey        = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Provider picker
            VStack(alignment: .leading, spacing: 6) {
                Text("Provedor").font(.vCaption2).foregroundColor(.vTextTertiary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(LLMProvider.allCases) { provider in
                            ProviderChip(
                                provider: provider,
                                isSelected: selectedProvider == provider,
                                action: {
                                    selectedProvider = provider
                                    if model.isEmpty { model = provider.defaultModel }
                                })
                        }
                    }
                }
            }

            // API Key
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("API Key").font(.vCaption2).foregroundColor(.vTextTertiary)
                    Spacer()
                    Button {
                        showKey.toggle()
                    } label: {
                        Image(systemName: showKey ? "eye.slash" : "eye")
                            .font(.system(size: 12))
                            .foregroundColor(.vTextTertiary)
                    }
                }
                VERBOTextField(placeholder: "sk-… ou anthropic key",
                               text: $apiKey,
                               icon: "key.fill",
                               isSecure: !showKey)
            }

            // Model
            VStack(alignment: .leading, spacing: 6) {
                Text("Modelo").font(.vCaption2).foregroundColor(.vTextTertiary)
                VERBOTextField(placeholder: selectedProvider.defaultModel,
                               text: $model, icon: "cpu")
            }

            // Base URL (para custom/ollama)
            if selectedProvider == .custom || selectedProvider == .ollama {
                VStack(alignment: .leading, spacing: 6) {
                    Text("URL Base").font(.vCaption2).foregroundColor(.vTextTertiary)
                    VERBOTextField(placeholder: selectedProvider.baseURL,
                                   text: $baseURL, icon: "link",
                                   keyboardType: .URL)
                }
            }

            // Save button
            VERBOButton(
                title: isSaved ? "✓ Salvo" : "Salvar Configuração",
                icon: isSaved ? nil : "checkmark",
                action: save,
                style: isSaved ? .secondary : .primary)

            if isSaved {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.vGreen)
                        .font(.system(size: 13))
                    Text("API configurada com sucesso!")
                        .font(.vCaption)
                        .foregroundColor(.vGreen)
                }
                .transition(.opacity)
            }
        }
        .padding(14)
        .background(Color.vSurface2)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.vBorder, lineWidth: 0.5))
        .onAppear { loadCurrent() }
    }

    private func save() {
        let key = apiKey.trimmingCharacters(in: .whitespaces)
        let mod = model.trimmingCharacters(in: .whitespaces)
        let url = baseURL.trimmingCharacters(in: .whitespaces)
        llm.configure(provider: selectedProvider, apiKey: key,
                      model: mod.isEmpty ? selectedProvider.defaultModel : mod,
                      baseURL: url)
        withAnimation { isSaved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation { isSaved = false }
        }
    }

    private func loadCurrent() {
        selectedProvider = llm.provider
        model            = llm.model
    }
}

private struct ProviderChip: View {
    let provider: LLMProvider
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: provider.icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(provider.displayName)
                    .font(.vCaption2)
                    .fontWeight(.medium)
            }
            .foregroundColor(isSelected ? .white : .vTextSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isSelected ? Color.vAccent : Color.vSurface3)
            .cornerRadius(20)
        }
    }
}

// MARK: - App Connection Row

private struct AppConnectionRow: View {
    let name       : String
    let icon       : String
    let color      : Color
    let status     : String
    let isConnected: Bool
    let description: String
    let action     : () -> Void

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.vBodyMedium)
                    .foregroundColor(.vTextPrimary)
                Text(description)
                    .font(.vCaption)
                    .foregroundColor(.vTextSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(isConnected ? Color.vGreen : Color.vTextTertiary)
                        .frame(width: 6, height: 6)
                    Text(status)
                        .font(.system(size: 10))
                        .foregroundColor(isConnected ? .vGreen : .vTextTertiary)
                }
                if isConnected {
                    Button("Abrir") { action() }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.vAccent)
                }
            }
        }
        .padding(12)
        .background(Color.vSurface2)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.vBorder, lineWidth: 0.5))
    }
}

// MARK: - API Connection Row

private struct APIConnectionRow: View {
    let name        : String
    let icon        : String
    let color       : Color
    let description : String
    let placeholder : String
    let settingsKey : String

    @State private var apiKey  = ""
    @State private var saved   = false
    @State private var showKey = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(color.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(color)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).font(.vBodyMedium).foregroundColor(.vTextPrimary)
                    Text(description).font(.vCaption).foregroundColor(.vTextSecondary)
                }
                Spacer()
                if saved {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.vGreen)
                }
            }

            HStack(spacing: 8) {
                if showKey {
                    TextField(placeholder, text: $apiKey)
                        .font(.vMono)
                        .foregroundColor(.vTextPrimary)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } else {
                    SecureField(placeholder, text: $apiKey)
                        .font(.vMono)
                        .foregroundColor(.vTextPrimary)
                }

                Button {
                    showKey.toggle()
                } label: {
                    Image(systemName: showKey ? "eye.slash" : "eye")
                        .font(.system(size: 13))
                        .foregroundColor(.vTextTertiary)
                }

                Button {
                    UserDefaults.standard.set(apiKey, forKey: settingsKey)
                    withAnimation { saved = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { saved = false }
                    }
                } label: {
                    Text("Salvar")
                        .font(.vCaption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.vAccent)
                        .cornerRadius(6)
                }
            }
            .padding(10)
            .background(Color.vSurface3)
            .cornerRadius(8)
        }
        .padding(12)
        .background(Color.vSurface2)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.vBorder, lineWidth: 0.5))
        .onAppear {
            apiKey = UserDefaults.standard.string(forKey: settingsKey) ?? ""
        }
    }
}

// MARK: - Notification Settings

private struct NotificationSettingsCard: View {
    @StateObject private var settings = AppSettings.shared
    @State private var proactiveEnabled = true

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Alertas Proativos")
                        .font(.vBodyMedium)
                        .foregroundColor(.vTextPrimary)
                    Text("VERBO te avisa sobre eventos importantes")
                        .font(.vCaption)
                        .foregroundColor(.vTextSecondary)
                }
                Spacer()
                Toggle("", isOn: $proactiveEnabled)
                    .tint(.vAccent)
            }

            Divider().background(Color.vBorder)

            HStack {
                Image(systemName: "info.circle")
                    .font(.system(size: 13))
                    .foregroundColor(.vTextTertiary)
                Text("Para notificações em segundo plano, ative nas Configurações do iOS → VERBO → Notificações")
                    .font(.vCaption)
                    .foregroundColor(.vTextTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(Color.vSurface2)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.vBorder, lineWidth: 0.5))
    }
}
