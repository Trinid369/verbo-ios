// MemoryStoreTests.swift
// Testes para UserMemoryStore — persistência e aprendizado
// Trinid © 2026

import XCTest
@testable import VERBOApp

final class MemoryStoreTests: XCTestCase {

    var store: UserMemoryStore!

    override func setUp() {
        super.setUp()
        store = UserMemoryStore.shared
        store.resetProfile()
    }

    override func tearDown() {
        store.resetProfile()
        super.tearDown()
    }

    // MARK: - Aprendizado de Nome

    func test_aprende_nome_padrao() {
        store.observe(text: "Meu nome é Trinid")
        XCTAssertEqual(store.profile.name, "Trinid", "Deve aprender nome do padrão 'Meu nome é X'")
    }

    func test_aprende_nome_sou_o() {
        store.observe(text: "sou o Carlos")
        XCTAssertEqual(store.profile.name, "Carlos", "Deve aprender nome do padrão 'sou o X'")
    }

    func test_aprende_nome_me_chamo() {
        store.observe(text: "me chamo Julia")
        XCTAssertEqual(store.profile.name, "Julia", "Deve aprender nome do padrão 'me chamo X'")
    }

    func test_nao_sobrescreve_nome_existente() {
        store.observe(text: "Meu nome é Trinid")
        store.observe(text: "Meu nome é João")
        XCTAssertEqual(store.profile.name, "Trinid", "Não deve sobrescrever nome já aprendido")
    }

    // MARK: - Aprendizado de Interesses

    func test_aprende_interesse_crypto() {
        store.observe(text: "Preciso de informação sobre bitcoin")
        XCTAssertTrue(store.profile.interests.contains("criptomoedas"))
    }

    func test_aprende_interesse_agro() {
        store.observe(text: "Qual o preço da soja hoje?")
        XCTAssertTrue(store.profile.interests.contains("agronegócio"))
    }

    func test_aprende_interesse_programacao() {
        store.observe(text: "Escreve um script Python para mim")
        XCTAssertTrue(store.profile.interests.contains("programação"))
    }

    func test_aprende_interesse_trading() {
        store.observe(text: "Analisa o trading do BTC/USDT")
        XCTAssertTrue(store.profile.interests.contains("mercado financeiro"))
    }

    func test_nao_duplica_interesses() {
        store.observe(text: "BTC está subindo")
        store.observe(text: "Bitcoin análise técnica")
        let count = store.profile.interests.filter { $0 == "criptomoedas" }.count
        XCTAssertEqual(count, 1, "Interesse não deve ser duplicado")
    }

    // MARK: - Contagem de Interações

    func test_incrementa_total_turns() {
        let inicial = store.profile.totalTurns
        store.observe(text: "Olá VERBO")
        XCTAssertEqual(store.profile.totalTurns, inicial + 1)
    }

    // MARK: - Tom Preferido

    func test_aprende_tom_direto() {
        store.observe(text: "Seja mais direto nas respostas")
        XCTAssertEqual(store.profile.preferences["tom"], "direto")
    }

    func test_aprende_tom_detalhado() {
        store.observe(text: "Explica melhor, quero mais detalhado")
        XCTAssertEqual(store.profile.preferences["tom"], "detalhado")
    }

    // MARK: - Sessões de Memória

    func test_adiciona_entrada_na_sessao() {
        store.add(session: "unit-test", role: "user", content: "Mensagem de teste")
        // Dá um instante para o queue async processar
        let exp = expectation(description: "async queue")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) { exp.fulfill() }
        waitForExpectations(timeout: 1.0)

        let entries = store.recent(session: "unit-test", n: 10)
        XCTAssertTrue(entries.contains { $0.content == "Mensagem de teste" })
    }

    func test_build_context_retorna_historico() {
        store.add(session: "ctx-test", role: "user",      content: "Oi VERBO")
        store.add(session: "ctx-test", role: "assistant", content: "Oi! Como posso ajudar?")
        let exp = expectation(description: "async queue")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) { exp.fulfill() }
        waitForExpectations(timeout: 1.0)

        let ctx = store.buildContext(session: "ctx-test")
        XCTAssertTrue(ctx.contains("[user]: Oi VERBO"))
        XCTAssertTrue(ctx.contains("[assistant]: Oi! Como posso ajudar?"))
    }

    func test_limpa_sessao() {
        store.add(session: "clear-test", role: "user", content: "Teste")
        let exp = expectation(description: "async queue")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) { exp.fulfill() }
        waitForExpectations(timeout: 1.0)

        store.clearSession("clear-test")
        let entries = store.recent(session: "clear-test")
        XCTAssertTrue(entries.isEmpty, "Sessão deve estar vazia após limpar")
    }

    // MARK: - Prompt de Perfil

    func test_user_profile_prompt_vazio_sem_dados() {
        let prompt = store.userProfilePrompt()
        XCTAssertTrue(prompt.isEmpty, "Prompt vazio se perfil vazio")
    }

    func test_user_profile_prompt_com_dados() {
        store.profile.name = "Trinid"
        store.profile.interests = ["criptomoedas", "programação"]
        let prompt = store.userProfilePrompt()
        XCTAssertTrue(prompt.contains("Trinid"))
        XCTAssertTrue(prompt.contains("criptomoedas"))
    }

    // MARK: - Reset e Save

    func test_reset_limpa_tudo() {
        store.profile.name = "Trinid"
        store.profile.interests = ["crypto"]
        store.resetProfile()
        XCTAssertTrue(store.profile.name.isEmpty)
        XCTAssertTrue(store.profile.interests.isEmpty)
        XCTAssertEqual(store.profile.totalTurns, 0)
    }

    func test_save_persiste() {
        store.profile.name = "PersisteTest"
        store.save()
        let novo = UserMemoryStore()
        XCTAssertEqual(novo.profile.name, "PersisteTest")
    }
}
