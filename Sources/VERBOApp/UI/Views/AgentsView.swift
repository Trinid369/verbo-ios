// AgentsView.swift
// Gerenciamento de agentes — instalados, templates, criação
// Trinid © 2026

import SwiftUI

struct AgentsView: View {
    @EnvironmentObject var engine: VERBOEngine
    @State private var showBuilder = false
    @State private var searchText  = ""

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Busca
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.vTextTertiary)
                        TextField("Buscar agente…", text: $searchText)
                            .font(.vBody)
                            .foregroundColor(.vTextPrimary)
                            .autocorrectionDisabled()
                    }
                    .padding(12)
                    .background(Color.vSurface2)
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    // Agentes Built-in
                    SectionHeader(title: "Agentes do Sistema")

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2),
                              spacing: 12) {
                        ForEach(builtInAgents.filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) }, id: \.id) { agent in
                            BuiltInAgentCard(spec: agent)
                        }
                    }
                    .padding(.horizontal, 16)

                    // Agentes instalados
                    if !filteredCustomAgents.isEmpty {
                        SectionHeader(title: "Meus Agentes",
                                      trailing: "Gerenciar",
                                      trailingAction: { showBuilder = true })

                        VStack(spacing: 10) {
                            ForEach(filteredCustomAgents) { agent in
                                InstalledAgentCard(agent: agent)
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    // Templates disponíveis
                    SectionHeader(title: "Templates Prontos")

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2),
                              spacing: 12) {
                        ForEach(agentTemplates, id: \.0) { name, icon, desc, trigger in
                            TemplateCard(name: name, icon: icon,
                                         description: desc, trigger: trigger)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
            }
            .background(Color.vBackground.ignoresSafeArea())
            .navigationTitle("Agentes")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color.vSurface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showBuilder = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.vAccent)
                            .font(.system(size: 20))
                    }
                }
            }
            .sheet(isPresented: $showBuilder) {
                AgentBuilderSheet()
                    .environmentObject(engine)
            }
        }
    }

    private var filteredCustomAgents: [CustomAgentSpec] {
        guard !searchText.isEmpty else { return engine.installedAgents }
        return engine.installedAgents.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    // Dados dos agentes built-in
    private var builtInAgents: [AgentInfo] {
        let ids = ["orchestrator", "operator", "message", "mail",
                   "calendar", "researcher", "social", "coder",
                   "guardian", "memory", "builder"]
        return ids.map { id -> AgentInfo in
            let meta = engine.agentMeta(for: id)
            return AgentInfo(id: id, name: meta.name, icon: meta.icon, description: meta.description)
        }
    }

    private let agentTemplates: [(String, String, String, String)] = [
        ("Instagram Post", "camera.fill", "Cria e agenda posts para Instagram", "cria agente instagram"),
        ("Twitter/X",      "bird.fill",   "Tweets e threads impactantes",        "cria agente twitter"),
        ("LinkedIn",       "briefcase.fill", "Conteúdo profissional",            "cria agente linkedin"),
        ("Calculadora Frete","truck.box.fill","Frete + CIOT conforme ANTT",      "cria agente frete"),
        ("Contratos AGREX","doc.text.fill","CCV, CDR e Barter",                  "cria agente contratos"),
        ("Trading Signal", "chart.line.uptrend.xyaxis","Sinais via Λ-FLOW",      "cria agente trading"),
    ]
}

struct AgentInfo: Identifiable {
    let id: String
    let name: String
    let icon: String
    let description: String
}

// MARK: - Built-in Agent Card

private struct BuiltInAgentCard: View {
    let spec: AgentInfo
    @EnvironmentObject var engine: VERBOEngine

    var uses: Int { engine.memory.profile.topAgents[spec.id] ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ZStack {
                    Circle()
                        .fill(cardColor.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: spec.icon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(cardColor)
                }
                Spacer()
                if uses > 0 {
                    Text("\(uses)×")
                        .font(.vCaption)
                        .foregroundColor(.vTextTertiary)
                }
            }
            Text(spec.name)
                .font(.vBodyMedium)
                .foregroundColor(.vTextPrimary)
            Text(spec.description)
                .font(.vCaption)
                .foregroundColor(.vTextSecondary)
                .lineLimit(2)
        }
        .padding(14)
        .background(Color.vSurface2)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.vBorder, lineWidth: 0.5))
    }

    private var cardColor: Color {
        switch spec.id {
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

// MARK: - Installed Agent Card

private struct InstalledAgentCard: View {
    let agent: CustomAgentSpec
    @EnvironmentObject var engine: VERBOEngine
    @State private var showDelete = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.vGreen.opacity(0.1))
                    .frame(width: 44, height: 44)
                Image(systemName: agent.icon)
                    .font(.system(size: 18))
                    .foregroundColor(.vGreen)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(agent.name)
                        .font(.vBodyMedium)
                        .foregroundColor(.vTextPrimary)
                    Spacer()
                    Text("Customizado")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.vGreen)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.vGreen.opacity(0.1))
                        .cornerRadius(4)
                }
                Text(agent.description)
                    .font(.vCaption)
                    .foregroundColor(.vTextSecondary)
                    .lineLimit(1)
                Text("Gatilho: '\(agent.trigger)'")
                    .font(.system(size: 10))
                    .foregroundColor(.vTextTertiary)
            }

            Button {
                showDelete = true
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(.vTextTertiary)
            }
        }
        .padding(12)
        .background(Color.vSurface2)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.vBorder, lineWidth: 0.5))
        .confirmationDialog(agent.name, isPresented: $showDelete) {
            Button("Remover agente", role: .destructive) {
                engine.removeAgent(agent)
            }
        }
    }
}

// MARK: - Template Card

private struct TemplateCard: View {
    let name        : String
    let icon        : String
    let description : String
    let trigger     : String
    @EnvironmentObject var engine: VERBOEngine
    @State private var installing = false
    @State private var installed  = false

    var isAlreadyInstalled: Bool {
        engine.installedAgents.contains { $0.name.lowercased() == name.lowercased() }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(.vPurple)
                Spacer()
                if isAlreadyInstalled {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.vGreen)
                        .font(.system(size: 16))
                }
            }
            Text(name)
                .font(.vBodyMedium)
                .foregroundColor(.vTextPrimary)
            Text(description)
                .font(.vCaption)
                .foregroundColor(.vTextSecondary)
                .lineLimit(2)

            Spacer()

            Button {
                installTemplate()
            } label: {
                HStack(spacing: 4) {
                    if installing {
                        ProgressView().scaleEffect(0.7).tint(.vAccent)
                    } else {
                        Image(systemName: isAlreadyInstalled ? "checkmark" : "plus")
                            .font(.system(size: 11, weight: .bold))
                    }
                    Text(isAlreadyInstalled ? "Instalado" : "Instalar")
                        .font(.vCaption2)
                        .fontWeight(.semibold)
                }
                .foregroundColor(isAlreadyInstalled ? .vGreen : .vAccent)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isAlreadyInstalled ? Color.vGreen.opacity(0.1) : Color.vAccentSoft)
                .cornerRadius(8)
            }
            .disabled(isAlreadyInstalled || installing)
        }
        .padding(14)
        .frame(minHeight: 130)
        .background(Color.vSurface2)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14)
            .stroke(isAlreadyInstalled ? Color.vGreen.opacity(0.3) : Color.vBorder, lineWidth: 0.5))
    }

    private func installTemplate() {
        installing = true
        Task {
            if let spec = await AgentBuilderService.shared.buildAgent(from: trigger) {
                await MainActor.run {
                    engine.installAgent(spec)
                    installing = false
                    installed  = true
                }
            } else {
                await MainActor.run { installing = false }
            }
        }
    }
}

// MARK: - Agent Builder Sheet

struct AgentBuilderSheet: View {
    @EnvironmentObject var engine: VERBOEngine
    @Environment(\.dismiss) var dismiss
    @State private var description  = ""
    @State private var isBuilding   = false
    @State private var builtAgent   : CustomAgentSpec?
    @State private var showPreview  = false

    private let examples = [
        "Cria um agente para fazer posts no Instagram com fotos do produto",
        "Quero um agente que calcula frete e gera CIOT automaticamente",
        "Preciso de um agente que monitora preços de cripto e me avisa",
        "Cria agente para enviar email de follow-up para clientes",
        "Agente para resumir e responder mensagens do WhatsApp",
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "plus.app.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.vGreen)
                            Spacer()
                        }
                        Text("Criar Novo Agente")
                            .font(.vLargeTitle)
                            .foregroundColor(.vTextPrimary)
                        Text("Descreva o que o agente deve fazer e o VERBO cria automaticamente.")
                            .font(.vBody)
                            .foregroundColor(.vTextSecondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    // Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Descrição do agente")
                            .font(.vCaption2)
                            .foregroundColor(.vTextTertiary)
                            .padding(.horizontal, 20)

                        TextEditor(text: $description)
                            .font(.vBody)
                            .foregroundColor(.vTextPrimary)
                            .frame(height: 120)
                            .padding(12)
                            .background(Color.vSurface2)
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.vBorder, lineWidth: 0.5))
                            .padding(.horizontal, 16)

                        if description.isEmpty {
                            Text("Ex.: Cria um agente para postar no Instagram todo dia às 18h")
                                .font(.vCaption)
                                .foregroundColor(.vTextTertiary)
                                .padding(.horizontal, 20)
                        }
                    }

                    // Exemplos
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Exemplos rápidos")
                            .font(.vCaption2)
                            .foregroundColor(.vTextTertiary)
                            .padding(.horizontal, 20)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(examples, id: \.self) { example in
                                    Button {
                                        description = example
                                    } label: {
                                        Text(example)
                                            .font(.vCaption)
                                            .foregroundColor(.vAccent)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(Color.vAccentSoft)
                                            .cornerRadius(20)
                                            .lineLimit(1)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }

                    // Preview resultado
                    if let agent = builtAgent {
                        AgentPreviewCard(agent: agent)
                            .padding(.horizontal, 16)
                    }

                    // Botão principal
                    VERBOButton(
                        title: builtAgent == nil ? "Criar Agente" : "Instalar Agente",
                        icon: builtAgent == nil ? "sparkles" : "checkmark",
                        action: { builtAgent == nil ? buildAgent() : installAgent() },
                        isLoading: isBuilding)
                    .padding(.horizontal, 16)
                    .disabled(description.trimmingCharacters(in: .whitespaces).isEmpty)
                    .padding(.bottom, 40)
                }
            }
            .background(Color.vBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") { dismiss() }
                        .foregroundColor(.vTextSecondary)
                }
            }
        }
    }

    private func buildAgent() {
        let text = description.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        isBuilding = true
        Task {
            let spec = await AgentBuilderService.shared.buildAgent(from: text)
            await MainActor.run {
                builtAgent = spec
                isBuilding  = false
            }
        }
    }

    private func installAgent() {
        guard let agent = builtAgent else { return }
        engine.installAgent(agent)
        dismiss()
    }
}

private struct AgentPreviewCard: View {
    let agent: CustomAgentSpec

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: agent.icon)
                    .font(.system(size: 22))
                    .foregroundColor(.vGreen)
                VStack(alignment: .leading, spacing: 2) {
                    Text(agent.name)
                        .font(.vTitle2)
                        .foregroundColor(.vTextPrimary)
                    Text("Pronto para instalar")
                        .font(.vCaption)
                        .foregroundColor(.vGreen)
                }
                Spacer()
            }

            Divider().background(Color.vBorder)

            VStack(alignment: .leading, spacing: 6) {
                InfoRow(label: "Gatilho", value: agent.trigger)
                InfoRow(label: "Confirmação", value: agent.policy.needsConfirmation ? "Sim" : "Não")
                if !agent.requiredTools.isEmpty {
                    InfoRow(label: "Ferramentas", value: agent.requiredTools.joined(separator: ", "))
                }
            }
        }
        .padding(14)
        .background(Color.vGreen.opacity(0.06))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.vGreen.opacity(0.3), lineWidth: 0.5))
    }
}

private struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text(label + ":")
                .font(.vCaption)
                .foregroundColor(.vTextTertiary)
                .frame(width: 90, alignment: .leading)
            Text(value)
                .font(.vCaption)
                .foregroundColor(.vTextPrimary)
        }
    }
}
