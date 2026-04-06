// DashboardView.swift
// Dashboard do sistema VERBO — métricas ACCU, status dos agentes, telemetria
// Trinid © 2026

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var engine: VERBOEngine

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    // ACCU metrics
                    SectionHeader(title: "ACCU · Sistema")

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                        StatCard(title: "Φ Potencial",
                                 value: String(format: "%.4f", engine.phi),
                                 icon: "waveform.path.ecg",
                                 color: phiColor)
                        StatCard(title: "Chamadas LLM",
                                 value: "\(engine.apiCalls)",
                                 icon: "arrow.up.arrow.down.circle",
                                 color: .vCyan)
                        StatCard(title: "Mensagens",
                                 value: "\(engine.messages.count)",
                                 icon: "bubble.left.and.bubble.right",
                                 color: .vGreen)
                        StatCard(title: "Agentes Ativos",
                                 value: "\(totalAgents)",
                                 icon: "cpu.fill",
                                 color: .vPurple)
                    }
                    .padding(.horizontal, 16)

                    // Agentes
                    SectionHeader(title: "Agentes")

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(allAgentIDs, id: \.self) { id in
                                AgentStatusCard(agentID: id)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.bottom, 4)

                    // Agentes customizados
                    if !engine.installedAgents.isEmpty {
                        SectionHeader(title: "Agentes Customizados")

                        VStack(spacing: 8) {
                            ForEach(engine.installedAgents) { agent in
                                CustomAgentRow(agent: agent)
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    // Memória e perfil
                    SectionHeader(title: "Perfil & Memória")
                    UserProfileCard()
                        .padding(.horizontal, 16)

                    // Top tools
                    SectionHeader(title: "Agentes mais usados")
                    TopAgentsChart()
                        .padding(.horizontal, 16)
                        .padding(.bottom, 40)
                }
            }
            .background(Color.vBackground.ignoresSafeArea())
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color.vSurface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    private var phiColor: Color {
        if engine.phi < 0.3 { return .vGreen }
        if engine.phi < 0.5 { return .vOrange }
        return .vRed
    }

    private var totalAgents: Int {
        allAgentIDs.count + engine.installedAgents.count
    }

    private let allAgentIDs = ["orchestrator", "operator", "message", "mail",
                                "calendar", "researcher", "social", "coder",
                                "guardian", "memory", "builder"]
}

// Agent Status Card
private struct AgentStatusCard: View {
    let agentID: String
    @EnvironmentObject var engine: VERBOEngine

    var meta: (name: String, icon: String, description: String) {
        engine.agentMeta(for: agentID)
    }

    var uses: Int {
        engine.memory.profile.topAgents[agentID] ?? 0
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(agentBgColor)
                    .frame(width: 44, height: 44)
                Image(systemName: meta.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(agentFgColor)
            }
            Text(meta.name)
                .font(.vCaption2)
                .foregroundColor(.vTextPrimary)
                .fontWeight(.semibold)
            Text("\(uses) usos")
                .font(.system(size: 10))
                .foregroundColor(.vTextTertiary)
        }
        .frame(width: 80)
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
        .background(Color.vSurface2)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.vBorder, lineWidth: 0.5))
    }

    private var agentBgColor: Color { agentFgColor.opacity(0.12) }
    private var agentFgColor: Color {
        switch agentID {
        case "orchestrator": return .vAccent
        case "guardian":     return .vRed
        case "memory":       return Color(hex: "60A5FA")
        case "builder":      return .vGreen
        case "coder":        return Color(hex: "34D399")
        case "researcher":   return Color(hex: "F472B6")
        case "social":       return Color(hex: "FB923C")
        case "calendar":     return .vPurple
        case "mail":         return .vCyan
        default:             return .vTextSecondary
        }
    }
}

// Custom Agent Row
private struct CustomAgentRow: View {
    let agent: CustomAgentSpec
    @EnvironmentObject var engine: VERBOEngine
    @State private var showDelete = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.vGreen.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: agent.icon)
                    .font(.system(size: 16))
                    .foregroundColor(.vGreen)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(agent.name)
                    .font(.vBodyMedium)
                    .foregroundColor(.vTextPrimary)
                Text(agent.description)
                    .font(.vCaption)
                    .foregroundColor(.vTextSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Toggle("", isOn: .constant(agent.isActive))
                .labelsHidden()
                .tint(.vGreen)

            Button {
                showDelete = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13))
                    .foregroundColor(.vTextTertiary)
            }
        }
        .padding(12)
        .background(Color.vSurface2)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.vBorder, lineWidth: 0.5))
        .confirmationDialog("Remover agente?", isPresented: $showDelete) {
            Button("Remover '\(agent.name)'", role: .destructive) {
                engine.removeAgent(agent)
            }
        }
    }
}

// User Profile Card
private struct UserProfileCard: View {
    @EnvironmentObject var engine: VERBOEngine

    var profile: UserProfile { engine.memory.profile }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.vAccent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.name.isEmpty ? "Usuário" : profile.name)
                        .font(.vTitle2)
                        .foregroundColor(.vTextPrimary)
                    Text("\(profile.totalTurns) interações")
                        .font(.vCaption)
                        .foregroundColor(.vTextSecondary)
                }
                Spacer()
            }

            if !profile.interests.isEmpty {
                FlowLayout(items: profile.interests.prefix(6).map { $0 })
            }

            if !profile.contacts.isEmpty {
                Divider().background(Color.vBorder)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Contatos aprendidos")
                        .font(.vCaption2)
                        .foregroundColor(.vTextTertiary)
                    ForEach(Array(profile.contacts.prefix(4)), id: \.key) { key, val in
                        HStack {
                            Text(key).font(.vCaption).foregroundColor(.vTextSecondary)
                            Text("→").foregroundColor(.vTextTertiary)
                            Text(val).font(.vCaption).foregroundColor(.vTextPrimary)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(Color.vSurface2)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.vBorder, lineWidth: 0.5))
    }
}

// Top Agents Chart
private struct TopAgentsChart: View {
    @EnvironmentObject var engine: VERBOEngine

    var topAgents: [(String, Int)] {
        engine.memory.profile.topAgents
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { ($0.key, $0.value) }
    }

    var maxValue: Int { topAgents.first?.1 ?? 1 }

    var body: some View {
        if topAgents.isEmpty {
            Text("Nenhum agente usado ainda.")
                .font(.vBody)
                .foregroundColor(.vTextTertiary)
                .padding()
        } else {
            VStack(spacing: 10) {
                ForEach(topAgents, id: \.0) { id, count in
                    let meta = engine.agentMeta(for: id)
                    HStack(spacing: 10) {
                        Image(systemName: meta.icon)
                            .font(.system(size: 12))
                            .foregroundColor(.vAccent)
                            .frame(width: 16)
                        Text(meta.name)
                            .font(.vCaption)
                            .foregroundColor(.vTextSecondary)
                            .frame(width: 80, alignment: .leading)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.vSurface3)
                                Capsule()
                                    .fill(Color.vAccent)
                                    .frame(width: geo.size.width * CGFloat(count) / CGFloat(maxValue))
                            }
                        }
                        .frame(height: 6)
                        Text("\(count)")
                            .font(.vCaption)
                            .foregroundColor(.vTextTertiary)
                            .frame(width: 24, alignment: .trailing)
                    }
                }
            }
            .padding(14)
            .background(Color.vSurface2)
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.vBorder, lineWidth: 0.5))
        }
    }
}

// Flow Layout para tags
private struct FlowLayout: View {
    let items: any Collection<String>

    var body: some View {
        let itemsArray = Array(items)
        LazyVGrid(columns: Array(repeating: GridItem(.adaptive(minimum: 80)), count: 3), spacing: 6) {
            ForEach(itemsArray, id: \.self) { item in
                Text(item)
                    .font(.vCaption2)
                    .foregroundColor(.vAccent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.vAccentSoft)
                    .cornerRadius(6)
            }
        }
    }
}
