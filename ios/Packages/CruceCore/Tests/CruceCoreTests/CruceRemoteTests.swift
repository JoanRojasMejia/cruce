import Foundation
import Testing

@testable import CruceCore

@Suite("JSON de la vinculación")
struct CruceRemoteTests {
    private func data(_ json: String) -> Data { Data(json.utf8) }

    @Test("Un código válido trae el nombre de quien invitó")
    func validInvite() throws {
        let check = try CruceRemote.inviteCheck(from: data(#"{"ok": true, "inviter_name": "Joan"}"#))
        #expect(check == .valid(inviterName: "Joan"))
    }

    @Test("Unirse también trae el nombre, aunque venga el id de la cuenta")
    func redeemedInvite() throws {
        let json = #"{"ok": true, "ledger_id": "aaaaaaaa-0000-0000-0000-000000000001", "inviter_name": "Joan"}"#
        #expect(try CruceRemote.inviteCheck(from: data(json)) == .valid(inviterName: "Joan"))
    }

    @Test(
        "Cada rechazo de la base conserva su tipo y su mensaje en español",
        arguments: [
            ("invalid", CodeRejection.invalid, "Ese código no existe. Revisa que esté bien escrito."),
            ("expired", .expired, "Ese código ya venció. Pídele uno nuevo a quien te lo mandó."),
            ("used", .used, "Ese código ya se usó. Pídele uno nuevo a quien te lo mandó."),
            ("own", .own, "Ese código es tuyo. Mándaselo a la otra persona para que lo use."),
            ("too_many_attempts", .tooManyAttempts, "Hiciste demasiados intentos. Espera una hora e intenta de nuevo."),
            ("already_linked", .alreadyLinked, "Ya tienes un cruce con Joan"),
        ])
    func rejections(error: String, kind: CodeRejection, message: String) throws {
        let json = #"{"ok": false, "error": "\#(error)", "message": "\#(message)"}"#
        #expect(try CruceRemote.inviteCheck(from: data(json)) == .rejected(kind, message: message))
    }

    @Test("Un error que la app no conoce se trata como código inválido, con el mensaje de la base")
    func unknownRejection() throws {
        let json = #"{"ok": false, "error": "nuevo", "message": "Algo nuevo"}"#
        #expect(try CruceRemote.inviteCheck(from: data(json)) == .rejected(.invalid, message: "Algo nuevo"))
    }

    @Test("Las filas de my_cruces se vuelven cruces con la otra persona, su color y el recibo de cada lado")
    func cruceRows() throws {
        let json = """
            [
              {"ledger_id": "aaaaaaaa-0000-0000-0000-000000000002", "partner_id": "33333333-3333-3333-3333-333333333333",
               "partner_name": "Ana", "my_tike": "rosa", "my_avatar": "yellow", "partner_tike": "verde",
               "partner_avatar": "violet", "linked_at": "2026-10-27T10:00:00.5+00:00"},
              {"ledger_id": "aaaaaaaa-0000-0000-0000-000000000001", "partner_id": "11111111-1111-1111-1111-111111111111",
               "partner_name": "Joan", "my_tike": "verde", "my_avatar": "violet", "partner_tike": "rosa",
               "partner_avatar": "yellow", "linked_at": "2026-10-26T10:00:00+00:00"}
            ]
            """
        let links = try CruceRemote.cruceLinks(from: data(json))
        #expect(links.map(\.partner.name) == ["Ana", "Joan"])
        #expect(links[1].id == UUID(uuidString: "aaaaaaaa-0000-0000-0000-000000000001"))
        #expect(
            links[1].partner
                == Member(
                    id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!, name: "Joan", avatarColor: .yellow,
                    tikeVariant: .rosa))
        #expect(links[1].myTikeVariant == .verde)
        #expect(links[0].linkedAt > links[1].linkedAt)
    }

    @Test("Las filas traen si el cruce está cerrado y su reparto por defecto")
    func closedAndDefaultSplit() throws {
        let json = """
            [
              {"ledger_id": "aaaaaaaa-0000-0000-0000-000000000002", "partner_id": "33333333-3333-3333-3333-333333333333",
               "partner_name": "Ana", "my_tike": "rosa", "my_avatar": "yellow", "partner_tike": "verde",
               "partner_avatar": "violet", "linked_at": "2026-10-27T10:00:00+00:00", "closed_at": null,
               "default_other_percent": 70},
              {"ledger_id": "aaaaaaaa-0000-0000-0000-000000000001", "partner_id": "11111111-1111-1111-1111-111111111111",
               "partner_name": "Joan", "my_tike": "verde", "my_avatar": "violet", "partner_tike": "rosa",
               "partner_avatar": "yellow", "linked_at": "2026-10-26T10:00:00+00:00",
               "closed_at": "2026-10-27T18:00:00.25+00:00", "default_other_percent": 50}
            ]
            """
        let links = try CruceRemote.cruceLinks(from: data(json))
        #expect(links.map(\.isClosed) == [false, true])
        #expect(links.map(\.defaultOtherPercent) == [70, 50])
    }

    @Test("La fecha que devuelve close_cruce se lee con sus fracciones de segundo")
    func closedAtDate() throws {
        let date = try CruceRemote.closedAt(from: data("\"2026-10-27T18:00:00.25+00:00\""))
        #expect(date == Date(timeIntervalSince1970: 1_793_124_000.25))
    }

    @Test("Una sesión guardada antes del CP11 se lee como cruce abierto y a medias")
    func oldSnapshot() throws {
        let json = """
            {"id": "aaaaaaaa-0000-0000-0000-000000000001", "linkedAt": 0, "myAvatarColor": "yellow",
             "myTikeVariant": "rosa",
             "partner": {"id": "22222222-2222-2222-2222-222222222222", "name": "Jesús", "avatarColor": "violet",
                         "tikeVariant": "verde"}}
            """
        let link = try JSONDecoder().decode(CruceLink.self, from: data(json))
        #expect(!link.isClosed)
        #expect(link.defaultOtherPercent == 50)
        let again = try JSONDecoder().decode(CruceLink.self, from: JSONEncoder().encode(link))
        #expect(again == link)
    }

    @Test("El reparto por defecto se vuelve el reparto de un movimiento nuevo")
    func splitFromDefault() {
        #expect(SplitRule(otherPercent: 50) == .equal)
        #expect(SplitRule(otherPercent: 100) == .fullOther)
        #expect(SplitRule(otherPercent: 70) == .percentage(otherShare: 70))
        #expect(SplitRule(otherPercent: 70).defaultTitle == "70 %")
        #expect(SplitRule(otherPercent: 50).defaultTitle == "50/50")
        #expect(SplitRule(otherPercent: 100).defaultTitle == "Todo es del otro")
        #expect(SplitRule.equal.otherPercent == 50)
    }

    @Test("Una fila con un color desconocido no se acepta")
    func badRow() {
        let json = """
            [{"ledger_id": "aaaaaaaa-0000-0000-0000-000000000001", "partner_id": "11111111-1111-1111-1111-111111111111",
              "partner_name": "Joan", "my_tike": "azul", "my_avatar": "violet", "partner_tike": "rosa",
              "partner_avatar": "yellow", "linked_at": "2026-10-26T10:00:00+00:00"}]
            """
        #expect(throws: (any Error).self) { try CruceRemote.cruceLinks(from: data(json)) }
    }
}
