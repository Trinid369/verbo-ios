// AgentBuilderTests.swift
// Testes para AgentBuilderService — criação dinâmica de agentes
// Trinid © 2026

import XCTest
@testable import VERBOApp

final class AgentBuilderTests: XCTestCase {

    var builder: AgentBuilderService!

    override func setUp() {
        super.setUp()
        builder = AgentBuilderService.shared
    }

    // MARK: - Templates pré-definidos

    func test_builda_agente_instagram() async {
        let spec = await builder.buildAgent(from: "cria agente para instagram")
        XCTAssertNotNil(spec)
        XCTAssertEqual(spec?.name, "Instagram Post")
        XCTAssertEqual(spec?.trigger, "instagram")
        XCTAssertFalse(spec?.systemPrompt.isEmpty ?? true)
    }

    func test_builda_agente_twitter() async {
        let spec = await builder.buildAgent(from: "quero um agente para Twitter")
        XCTAssertNotNil(spec)
        XCTAssertEqual(spec?.name, "Twitter/X")
        XCTAssertEqual(spec?.trigger, "twitter")
    }

    func test_builda_agente_linkedin() async {
        let spec = await builder.buildAgent(from: "cria agente linkedin profissional")
        XCTAssertNotNil(spec)
        XCTAssertEqual(spec?.name, "LinkedIn")
    }

    func test_builda_agente_frete() async {
        let spec = await builder.buildAgent(from: "calculadora de frete ANTT")
        XCTAssertNotNil(spec)
        XCTAssertEqual(spec?.name, "Calculadora Frete")
        XCTAssertFalse(spec?.policy.needsConfirmation ?? true) // frete não precisa confirmação
    }

    func test_builda_agente_trading() async {
        let spec = await builder.buildAgent(from: "analisa sinais de trading btc")
        XCTAssertNotNil(spec)
        XCTAssertEqual(spec?.name, "Trading Signal")
        XCTAssertTrue(spec?.requiredTools.contains("api.binance") ?? false)
    }

    func test_builda_agente_contrato() async {
        let spec = await builder.buildAgent(from: "gera contrato CCV de venda de soja")
        XCTAssertNotNil(spec)
        XCTAssertEqual(spec?.name, "Contratos AGREX")
    }

    // MARK: - Agente genérico

    func test_builda_agente_generico() async {
        let spec = await builder.buildAgent(from: "cria um agente para gestão de projetos")
        XCTAssertNotNil(spec)
        XCTAssertFalse(spec?.name.isEmpty ?? true, "Nome não pode estar vazio")
        XCTAssertFalse(spec?.systemPrompt.isEmpty ?? true, "System prompt não pode estar vazio")
        XCTAssertFalse(spec?.requiredTools.isEmpty ?? true, "Deve ter ao menos uma ferramenta")
    }

    func test_agente_generico_contem_prompt_especializado() async {
        let spec = await builder.buildAgent(from: "cria um agente para análise de dados")
        XCTAssertTrue(spec?.systemPrompt.contains("agente especialista") ?? false)
    }

    // MARK: - IDs únicos

    func test_cada_build_gera_id_unico() async {
        let spec1 = await builder.buildAgent(from: "agente instagram")
        let spec2 = await builder.buildAgent(from: "agente instagram")
        XCTAssertNotEqual(spec1?.id, spec2?.id, "Cada build deve gerar um UUID único")
    }

    // MARK: - Mensagem de confirmação

    func test_confirmation_message_contem_nome() async {
        let spec = await builder.buildAgent(from: "agente instagram")!
        let msg = builder.confirmationMessage(for: spec)
        XCTAssertTrue(msg.contains(spec.name))
        XCTAssertTrue(msg.contains("criado com sucesso"))
    }

    func test_confirmation_message_contem_ferramentas() async {
        let spec = await builder.buildAgent(from: "agente instagram")!
        let msg = builder.confirmationMessage(for: spec)
        XCTAssertFalse(spec.requiredTools.isEmpty)
        // Ao menos uma ferramenta aparece na mensagem
        let temFerramenta = spec.requiredTools.contains { msg.contains($0) }
        XCTAssertTrue(temFerramenta, "Mensagem deve listar as ferramentas do agente")
    }

    // MARK: - CustomAgentSpec

    func test_spec_equalidade_por_id() {
        let spec1 = CustomAgentSpec(
            name: "Teste", icon: "star.fill",
            description: "Agente de teste",
            trigger: "teste",
            triggerExamples: ["exemplo"],
            requiredTools: ["web.search"],
            policy: AgentPolicy(),
            outputSchema: AgentOutputSchema(),
            systemPrompt: "Você é um agente de teste")

        var spec2 = spec1
        spec2.name = "Nome diferente"
        // Igualdade é baseada em ID, não em nome
        XCTAssertEqual(spec1, spec2, "Specs com mesmo ID são iguais mesmo com nome diferente")
    }

    func test_spec_desigualdade_ids_diferentes() {
        let spec1 = CustomAgentSpec(
            name: "A", icon: "star", description: "A",
            trigger: "a", triggerExamples: [],
            requiredTools: [], policy: AgentPolicy(),
            outputSchema: AgentOutputSchema(), systemPrompt: "A")

        let spec2 = CustomAgentSpec(
            name: "A", icon: "star", description: "A",
            trigger: "a", triggerExamples: [],
            requiredTools: [], policy: AgentPolicy(),
            outputSchema: AgentOutputSchema(), systemPrompt: "A")

        XCTAssertNotEqual(spec1, spec2, "Specs com IDs diferentes são desiguais mesmo com mesmos dados")
    }

    func test_spec_codable() throws {
        let spec = CustomAgentSpec(
            name: "Encode Test", icon: "cpu.fill",
            description: "Testando Codable",
            trigger: "encode",
            triggerExamples: ["encoda isso"],
            requiredTools: ["web.search"],
            policy: AgentPolicy(needsConfirmation: false),
            outputSchema: AgentOutputSchema(style: "tech"),
            systemPrompt: "System prompt de teste")

        let data = try JSONEncoder().encode(spec)
        let decoded = try JSONDecoder().decode(CustomAgentSpec.self, from: data)

        XCTAssertEqual(spec.id, decoded.id)
        XCTAssertEqual(spec.name, decoded.name)
        XCTAssertEqual(spec.systemPrompt, decoded.systemPrompt)
        XCTAssertEqual(spec.policy.needsConfirmation, decoded.policy.needsConfirmation)
    }
}
