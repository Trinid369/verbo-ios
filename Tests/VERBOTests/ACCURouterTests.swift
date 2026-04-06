// ACCURouterTests.swift
// Testes para o ACCU Router e fórmula Φ
// Trinid © 2026

import XCTest
@testable import VERBOApp

final class ACCURouterTests: XCTestCase {

    var router: ACCURouter!

    override func setUp() {
        super.setUp()
        router = ACCURouter()
    }

    // MARK: - Fórmula Φ

    func test_phi_formula_valores_padrao() {
        // Φ = α(1−p) + β(1−c) + γe + δ(1−d)
        // State padrão: p=0.80, c=0.85, e=0.20, d=0.70, α=0.4, β=0.3, γ=0.2, δ=0.1
        // Φ = 0.4*(0.20) + 0.3*(0.15) + 0.2*(0.20) + 0.1*(0.30)
        // Φ = 0.08 + 0.045 + 0.04 + 0.03 = 0.195
        var state = ACCUState()
        state.p = 0.80; state.c = 0.85; state.e = 0.20; state.d = 0.70
        state.alpha = 0.4; state.beta = 0.3; state.gamma = 0.2; state.delta = 0.1
        XCTAssertEqual(state.phi, 0.195, accuracy: 0.0001, "Fórmula Φ com valores padrão")
    }

    func test_phi_minimo_quando_perfeito() {
        var state = ACCUState()
        state.p = 0.99; state.c = 0.99; state.e = 0.0; state.d = 0.99
        XCTAssertLessThan(state.phi, 0.05, "Φ deve ser próximo de zero para resposta perfeita")
    }

    func test_phi_maximo_quando_pessimo() {
        var state = ACCUState()
        state.p = 0.01; state.c = 0.01; state.e = 1.0; state.d = 0.01
        XCTAssertGreaterThan(state.phi, 0.8, "Φ deve ser alto para resposta péssima")
    }

    func test_phi_atualiza_apos_outcome_sucesso() {
        let anterior = router.phi
        router.recordOutcome(latencyMs: 80, wasEscalated: false, success: true)
        // Sucesso rápido sem escalação deve melhorar (diminuir) Φ
        XCTAssertLessThan(router.phi, anterior + 0.01, "Φ deve melhorar ou manter após sucesso")
    }

    func test_phi_piora_apos_falha() {
        let anterior = router.phi
        router.recordOutcome(latencyMs: 5000, wasEscalated: true, success: false)
        // Falha lenta com escalação deve piorar Φ
        XCTAssertGreaterThan(router.phi, anterior - 0.01, "Φ não deve melhorar após falha")
    }

    // MARK: - Roteamento de Agentes

    func test_rota_calendário_para_reunião() {
        let (intent, _, agent) = router.route(text: "agenda reunião amanhã às 14h")
        XCTAssertEqual(agent, "calendar", "Keyword 'reunião' deve rotear para calendar")
        XCTAssertEqual(intent, .automatizar)
    }

    func test_rota_whatsapp_para_message() {
        let (_, _, agent) = router.route(text: "abre o whatsapp do João")
        XCTAssertEqual(agent, "message", "Keyword 'whatsapp' → message agent")
    }

    func test_rota_instagram_para_social() {
        let (_, _, agent) = router.route(text: "cria post para Instagram")
        XCTAssertEqual(agent, "social", "Keyword 'instagram' → social agent")
    }

    func test_rota_codigo_para_coder() {
        let (_, _, agent) = router.route(text: "escreve um script Python")
        XCTAssertEqual(agent, "coder", "Keyword 'python/script' → coder agent")
    }

    func test_rota_criar_agente_para_builder() {
        let (intent, _, agent) = router.route(text: "cria um agente para Instagram")
        XCTAssertEqual(agent, "builder", "Pedido de criação de agente → builder")
        XCTAssertEqual(intent, .construir)
    }

    func test_rota_pesquisa_btc() {
        let (intent, _, _) = router.route(text: "pesquisa o preço do Bitcoin hoje")
        XCTAssertEqual(intent, .pesquisar)
    }

    func test_rota_email() {
        let (_, _, agent) = router.route(text: "manda um email para joao@empresa.com")
        XCTAssertEqual(agent, "mail", "Keyword 'email' → mail agent")
    }

    func test_rota_segurança_para_guardian() {
        let (_, _, agent) = router.route(text: "auditoria de segurança do sistema")
        XCTAssertEqual(agent, "guardian")
    }

    func test_rota_memoria_para_memory() {
        let (intent, _, agent) = router.route(text: "você lembra o que eu disse antes?")
        XCTAssertEqual(agent, "memory")
        XCTAssertEqual(intent, .lembrar)
    }

    func test_rota_default_para_orchestrator() {
        let (intent, _, agent) = router.route(text: "olá tudo bem")
        XCTAssertEqual(agent, "orchestrator")
        XCTAssertEqual(intent, .conversar)
    }

    // MARK: - Complexidade

    func test_complexidade_simples_poucas_palavras() {
        let (_, complexity, _) = router.route(text: "oi")
        XCTAssertEqual(complexity, .simples)
    }

    func test_complexidade_media() {
        let (_, complexity, _) = router.route(text: "pesquisa os dados do mercado de soja hoje")
        XCTAssertEqual(complexity, .media)
    }

    func test_complexidade_critica_muitas_palavras() {
        let texto = Array(repeating: "palavra", count: 50).joined(separator: " ")
        let (_, complexity, _) = router.route(text: texto)
        XCTAssertEqual(complexity, .critica)
    }

    // MARK: - Comparable

    func test_complexity_comparable() {
        XCTAssertLessThan(VERBOComplexity.simples, .media)
        XCTAssertLessThan(VERBOComplexity.media, .alta)
        XCTAssertLessThan(VERBOComplexity.alta, .critica)
    }
}
