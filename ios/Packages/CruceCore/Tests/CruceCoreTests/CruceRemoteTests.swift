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
            ("invalid", InviteRejection.invalid, "El código no es válido o ya venció"),
            ("own", .own, "No puedes usar tu propio código"),
            ("too_many_attempts", .tooManyAttempts, "Hiciste demasiados intentos. Espera una hora e intenta de nuevo."),
            ("already_linked", .alreadyLinked, "Ya tienes un cruce con Joan"),
        ])
    func rejections(error: String, kind: InviteRejection, message: String) throws {
        let json = #"{"ok": false, "error": "\#(error)", "message": "\#(message)"}"#
        #expect(try CruceRemote.inviteCheck(from: data(json)) == .rejected(kind, message: message))
    }

    @Test("Un error que la app no conoce se trata como código inválido, con el mensaje de la base")
    func unknownRejection() throws {
        let json = #"{"ok": false, "error": "nuevo", "message": "Algo nuevo"}"#
        #expect(try CruceRemote.inviteCheck(from: data(json)) == .rejected(.invalid, message: "Algo nuevo"))
    }

    @Test("Las filas de my_cruces se vuelven cruces con la otra persona y los colores de cada lado")
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
        #expect(links[1].myAvatarColor == .violet)
        #expect(links[1].myTikeVariant == .verde)
        #expect(links[0].linkedAt > links[1].linkedAt)
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
