// ContentView.swift
// Navegação principal do VERBO iOS
// Trinid © 2026

import SwiftUI

struct ContentView: View {
    @StateObject private var engine      = VERBOEngine.shared
    @StateObject private var settings    = AppSettings.shared
    @StateObject private var connections = ConnectionsManager.shared
    @StateObject private var proactive   = ProactiveMonitor.shared

    @State private var selectedTab = 0
    @State private var showOnboarding = false

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                ChatView()
                    .tabItem {
                        Label("Chat", systemImage: "bubble.left.and.bubble.right.fill")
                    }
                    .tag(0)

                DashboardView()
                    .tabItem {
                        Label("Dashboard", systemImage: "chart.bar.xaxis")
                    }
                    .tag(1)

                AgentsView()
                    .tabItem {
                        Label("Agentes", systemImage: "cpu.fill")
                    }
                    .tag(2)
                    .badge(engine.installedAgents.count > 0 ? "\(engine.installedAgents.count)" : nil)

                ConnectionsView()
                    .tabItem {
                        Label("Conexões", systemImage: "link.circle.fill")
                    }
                    .tag(3)

                SettingsView()
                    .tabItem {
                        Label("Config", systemImage: "gearshape.fill")
                    }
                    .tag(4)
            }
            .tint(.vAccent)
            .preferredColorScheme(.dark)

            // Proactive alert overlay
            if let proactiveMsg = engine.proactiveQueue.last,
               proactiveMsg.isProactive {
                ProactiveAlertBanner(message: proactiveMsg)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(duration: 0.4), value: engine.proactiveQueue.count)
            }
        }
        .environmentObject(engine)
        .environmentObject(settings)
        .environmentObject(connections)
        .background(Color.vBackground.ignoresSafeArea())
        .onAppear {
            setupApp()
            configureTabBar()
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView()
                .environmentObject(engine)
                .environmentObject(settings)
        }
    }

    private func setupApp() {
        LLMAdapter.shared.loadSaved()
        connections.checkInstalledApps()
        engine.loadPersistedAgents()
        proactive.start(engine: engine)

        if settings.data.firstLaunch {
            showOnboarding = true
            settings.data.firstLaunch = false
            settings.save()
        }
    }

    private func configureTabBar() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.vSurface)
        appearance.stackedLayoutAppearance.normal.iconColor    = UIColor(Color.vTextTertiary)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(Color.vTextTertiary)]
        appearance.stackedLayoutAppearance.selected.iconColor  = UIColor(Color.vAccent)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(Color.vAccent)]
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

// MARK: - Proactive Alert Banner

struct ProactiveAlertBanner: View {
    let message: VERBOMessage
    @EnvironmentObject var engine: VERBOEngine
    @State private var visible = true

    var body: some View {
        if visible {
            VStack {
                HStack(spacing: 12) {
                    PulseCircle(color: .vOrange, size: 8)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("VERBO")
                            .font(.vCaption2)
                            .foregroundColor(.vOrange)
                            .fontWeight(.bold)
                        Text(message.content)
                            .font(.vBody)
                            .foregroundColor(.vTextPrimary)
                            .lineLimit(2)
                    }

                    Spacer()

                    Button {
                        withAnimation { visible = false }
                        engine.proactiveQueue.removeLast()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.vTextTertiary)
                            .font(.system(size: 18))
                    }
                }
                .padding(14)
                .background(Color.vSurface2)
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.vOrange.opacity(0.3), lineWidth: 1))
                .shadow(color: .black.opacity(0.4), radius: 12, y: 4)
                .padding(.horizontal, 16)
                .padding(.top, 60)

                Spacer()
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    withAnimation { visible = false }
                }
            }
        }
    }
}

// MARK: - Onboarding

struct OnboardingView: View {
    @EnvironmentObject var engine: VERBOEngine
    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) var dismiss
    @State private var page = 0

    var body: some View {
        ZStack {
            Color.vBackground.ignoresSafeArea()

            TabView(selection: $page) {
                OnboardingPage(
                    icon: "cpu.fill",
                    title: "Bem-vindo ao VERBO",
                    subtitle: "Seu agente de IA multiagente pessoal. Rápido, local e inteligente.",
                    iconColor: .vAccent)
                .tag(0)

                OnboardingPage(
                    icon: "brain.head.profile",
                    title: "Aprende sobre você",
                    subtitle: "O VERBO aprende seu nome, preferências e contatos para te ajudar melhor.",
                    iconColor: .vPurple)
                .tag(1)

                OnboardingPage(
                    icon: "plus.app.fill",
                    title: "Cria agentes para você",
                    subtitle: "Diga 'cria um agente para Instagram' e ele cria na hora, sem programação.",
                    iconColor: .vGreen)
                .tag(2)

                OnboardingPage(
                    icon: "link.circle.fill",
                    title: "Conecta tudo",
                    subtitle: "Configure WhatsApp, e-mail, calendário e sua API LLM favorita.",
                    iconColor: .vCyan,
                    isLast: true,
                    onFinish: { dismiss() })
                .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
        }
    }
}

private struct OnboardingPage: View {
    let icon: String
    let title: String
    let subtitle: String
    var iconColor: Color = .vAccent
    var isLast = false
    var onFinish: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 120, height: 120)
                Image(systemName: icon)
                    .font(.system(size: 52))
                    .foregroundColor(iconColor)
            }

            VStack(spacing: 12) {
                Text(title)
                    .font(.vLargeTitle)
                    .foregroundColor(.vTextPrimary)
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .font(.vBody)
                    .foregroundColor(.vTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Spacer()

            if isLast {
                VERBOButton(title: "Começar agora", icon: "arrow.right", action: { onFinish?() })
                    .padding(.horizontal, 32)
                    .padding(.bottom, 48)
            }
        }
    }
}
