// GuardianServiceTests.swift
// Testes para GuardianService — segurança e privacidade
// Trinid © 2026

import XCTest
@testable import VERBOApp

final class GuardianServiceTests: XCTestCase {

    var guardian: GuardianService!

    override func setUp() {
        super.setUp()
        guardian = GuardianService.shared
    }

    // MARK: - Detecção de conteúdo bloqueado

    func test_bloqueia_jwt_like() {
        let jwt = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ1c2VyMTIzIn0.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"
        XCTAssertTrue(guardian.isBlocked(text: jwt), "JWT deve ser bloqueado")
    }

    func test_bloqueia_texto_normal() {
        XCTAssertFalse(guardian.isBlocked(text: "Qual o preço do bitcoin?"), "Texto normal não deve ser bloqueado")
    }

    func test_bloqueia_rm_rf() {
        XCTAssertTrue(guardian.isBlocked(text: "rm -rf /home/user"), "rm -rf deve ser bloqueado")
    }

    func test_bloqueia_delete_all() {
        XCTAssertTrue(guardian.isBlocked(text: "delete all files now"), "delete all deve ser bloqueado")
    }

    func test_permite_mensagem_agenda() {
        XCTAssertFalse(guardian.isBlocked(text: "agenda uma reunião para amanhã às 14h"))
    }

    func test_permite_pesquisa_mercado() {
        XCTAssertFalse(guardian.isBlocked(text: "pesquisa dados de mercado de soja"))
    }

    // MARK: - Auditoria

    func test_auditoria_detecta_senha() {
        let aviso = guardian.auditMessage("minha senha é 1234")
        XCTAssertNotNil(aviso, "Deve gerar aviso para referência a senha")
        XCTAssertTrue(aviso!.contains("sensíveis"))
    }

    func test_auditoria_detecta_token() {
        let aviso = guardian.auditMessage("meu token de acesso é abc123")
        XCTAssertNotNil(aviso, "Deve gerar aviso para referência a token")
    }

    func test_auditoria_nil_para_texto_normal() {
        let aviso = guardian.auditMessage("Boa tarde, como posso te ajudar?")
        XCTAssertNil(aviso, "Não deve gerar aviso para texto normal")
    }
}
