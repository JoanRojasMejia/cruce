import Foundation
import Testing

@testable import CruceCore

/// El @usuario único (S2 y S3): formato, sugerencia, JSON de la base y el paso de la entrada y Tu perfil.
@Suite("@usuario")
struct UsernameRulesTests {
    private func data(_ json: String) -> Data { Data(json.utf8) }

    @Test(
        "Se guarda sin espacios a los lados, sin la @ y en minúsculas",
        arguments: [(" @Joan.R ", "joan.r"), ("ANA_1", "ana_1"), ("@@jesus", "@jesus")])
    func normalize(_ input: String, _ expected: String) {
        #expect(Username.normalize(input) == expected)
    }

    @Test("De 3 a 20 caracteres: minúsculas, números, punto y guion bajo")
    func format() {
        #expect(Username.isValid("joan"))
        #expect(Username.isValid("@Joan.R_2"))
        #expect(Username.isValid(String(repeating: "a", count: 20)))
        #expect(!Username.isValid("jo"))
        #expect(!Username.isValid(String(repeating: "a", count: 21)))
        #expect(!Username.isValid("joan rojas"))
        #expect(!Username.isValid("josé"))
        #expect(!Username.isValid("joan-r"))
    }

    @Test("La sugerencia sale del nombre, igual que username_suggestion en la base")
    func suggestion() {
        #expect(Username.suggestion(from: "Jesús") == "jesus")
        #expect(Username.suggestion(from: "  Joan R. Rojas-Peña ") == "joan.r.rojas.pena")
        #expect(Username.suggestion(from: "Al") == "al.cruce")
        #expect(Username.suggestion(from: "🥳🥳") == "usuario")
        #expect(Username.suggestion(from: "Maximiliano Alejandro de la Torre") == "maximiliano.alejandr")
    }

    @Test("Si la sugerencia está ocupada agrega 2, 3… sin pasar de 20")
    func suggestionSkipsTaken() {
        #expect(Username.suggestion(from: "Juan", isTaken: { $0 == "juan" }) == "juan2")
        #expect(Username.suggestion(from: "Juan", isTaken: { ["juan", "juan2"].contains($0) }) == "juan3")
        #expect(
            Username.suggestion(from: "Maximiliano Alejandro", isTaken: { $0 == "maximiliano.alejandr" })
                == "maximiliano.alejand2")
    }

    @Test("El @usuario se muestra con la arroba")
    func display() {
        #expect(Username.display("joan") == "@joan")
    }

    @Test("check_username y set_username: disponible o el error con el mensaje de la base")
    func checkFromJSON() throws {
        #expect(
            try CruceRemote.usernameCheck(from: data(#"{"ok": true, "username": "ana_1"}"#)) == .available("ana_1"))
        let taken = #"{"ok": false, "error": "taken", "message": "Ese @usuario ya está ocupado. Prueba con otro."}"#
        #expect(
            try CruceRemote.usernameCheck(from: data(taken))
                == .rejected(.taken, message: "Ese @usuario ya está ocupado. Prueba con otro."))
        #expect(
            try CruceRemote.usernameCheck(from: data(#"{"ok": false, "error": "nuevo"}"#))
                == .rejected(.format, message: UsernameRejection.format.defaultMessage))
    }

    @Test("La vista previa de un CRZ- trae el @usuario de quien invita; una base vieja no lo trae")
    func inviterUsername() throws {
        let json = #"{"ok": true, "inviter_name": "Joan", "inviter_username": "joan"}"#
        #expect(try CruceRemote.inviteCheck(from: data(json)) == .valid(inviterName: "Joan", username: "joan"))
        #expect(
            try CruceRemote.inviteCheck(from: data(#"{"ok": true, "inviter_name": "Joan"}"#))
                == .valid(inviterName: "Joan", username: nil))
        #expect(
            CodePreview(.valid(inviterName: "Joan", username: "joan")) == .cruce(inviterName: "Joan", username: "joan"))
    }

    @Test("my_cruces trae el @usuario y si la otra cuenta se borró")
    func cruceRowsWithUsername() throws {
        let json = """
            [
              {"ledger_id": "aaaaaaaa-0000-0000-0000-000000000002", "partner_id": "33333333-3333-3333-3333-333333333333",
               "partner_name": "Ana", "my_tike": "rosa", "my_avatar": "yellow", "partner_tike": "verde",
               "partner_avatar": "violet", "linked_at": "2026-10-27T10:00:00+00:00", "partner_color": "green",
               "my_username": "joan", "partner_username": "ana", "partner_deleted": false},
              {"ledger_id": "aaaaaaaa-0000-0000-0000-000000000001", "partner_id": "11111111-1111-1111-1111-111111111111",
               "partner_name": "Cuenta borrada", "my_tike": "verde", "my_avatar": "violet", "partner_tike": "rosa",
               "partner_avatar": "yellow", "linked_at": "2026-10-26T10:00:00+00:00", "partner_color": null,
               "closed_at": "2026-10-28T10:00:00+00:00", "my_username": "joan", "partner_username": null,
               "partner_deleted": true}
            ]
            """
        let links = try CruceRemote.cruceLinks(from: data(json))
        #expect(links[0].partner.username == "ana")
        #expect(!links[0].partner.isDeleted)
        #expect(links[1].partner.username == nil)
        #expect(links[1].partner.isDeleted)
        #expect(links[1].partner.name == "Cuenta borrada")
        #expect(links[1].partner.avatarColor == .yellow)
    }

    @Test("Un miembro guardado antes del @usuario se lee sin @usuario y sin borrar")
    func memberFromOldCache() throws {
        let json =
            #"{"id": "11111111-1111-1111-1111-111111111111", "name": "Joan", "avatarColor": "yellow", "tikeVariant": "rosa"}"#
        let member = try JSONDecoder().decode(Member.self, from: data(json))
        #expect(member.username == nil)
        #expect(!member.isDeleted)
        var copy = member
        copy.username = "joan"
        copy.isDeleted = true
        #expect(try JSONDecoder().decode(Member.self, from: JSONEncoder().encode(copy)) == copy)
    }
}

/// El paso "Elige tu @usuario", Tu perfil y la vista previa con la base en memoria.
@MainActor
@Suite("@usuario en la sesión")
struct SessionUsernameTests {
    private let joanID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private let jesusID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!

    private func session(_ user: UUID, _ directory: InMemoryAccountDirectory) async -> SessionStore {
        let session = SessionStore(
            phase: .onboarding, me: Member(name: "Tú", avatarColor: .yellow, tikeVariant: .rosa),
            partner: Member(name: "Tu amigo", avatarColor: .violet, tikeVariant: .verde),
            auth: InMemoryAuthService(signedIn: user), directory: directory, isReady: false)
        await session.refresh()
        return session
    }

    @Test("Después del nombre viene el paso del @usuario, con la sugerencia del nombre")
    func signUpGoesToUsernameStep() async {
        let directory = InMemoryAccountDirectory(profiles: [Profile(id: joanID, displayName: "Joan", username: "jesus")]
        )
        let jesus = await session(jesusID, directory)
        #expect(jesus.phase == .signUp)
        #expect(await jesus.createProfile(name: "Jesús"))
        #expect(jesus.phase == .chooseUsername)
        // "jesus" ya es de otra persona: la sugerencia lleva un 2.
        #expect(jesus.me.username == "jesus2")
        #expect(await directory.storedProfile(for: jesusID)?.username == "jesus2")
    }

    @Test("Seguir con la sugerencia pasa a invitar sin cambiarla")
    func keepSuggestion() async {
        let directory = InMemoryAccountDirectory()
        let joan = await session(joanID, directory)
        _ = await joan.createProfile(name: "Joan")
        #expect(await joan.chooseUsername("@joan"))
        #expect(joan.phase == .invite)
        #expect(joan.me.username == "joan")
    }

    @Test("Elegir otro @usuario lo guarda y pasa a invitar")
    func chooseOther() async {
        let directory = InMemoryAccountDirectory()
        let joan = await session(joanID, directory)
        _ = await joan.createProfile(name: "Joan")
        #expect(await joan.chooseUsername("Joan.R"))
        #expect(joan.phase == .invite)
        #expect(joan.me.username == "joan.r")
        #expect(await directory.storedProfile(for: joanID)?.username == "joan.r")
    }

    @Test("Uno ocupado o con formato inválido no se guarda y la etapa no cambia")
    func chooseRejected() async {
        let directory = InMemoryAccountDirectory(profiles: [
            Profile(id: jesusID, displayName: "Jesús", username: "jesus")
        ])
        let joan = await session(joanID, directory)
        _ = await joan.createProfile(name: "Joan")
        #expect(!(await joan.chooseUsername("JESUS")))
        #expect(joan.error == .usernameRejected(UsernameRejection.taken.defaultMessage))
        #expect(joan.phase == .chooseUsername)
        #expect(!(await joan.chooseUsername("jo")))
        #expect(joan.error == .usernameRejected(UsernameRejection.format.defaultMessage))
        #expect(joan.me.username == "joan")
    }

    @Test("Mientras se escribe dice si está disponible; el formato se revisa sin preguntarle a la base")
    func checkWhileTyping() async {
        let directory = InMemoryAccountDirectory(profiles: [
            Profile(id: jesusID, displayName: "Jesús", username: "jesus")
        ])
        let joan = await session(joanID, directory)
        _ = await joan.createProfile(name: "Joan")
        await joan.checkUsername("jesus")
        #expect(joan.usernameCheck == .rejected(.taken, message: UsernameRejection.taken.defaultMessage))
        await joan.checkUsername("j o")
        #expect(joan.usernameCheck == .rejected(.format, message: UsernameRejection.format.defaultMessage))
        await joan.checkUsername("@Joan.R")
        #expect(joan.usernameCheck == .available("joan.r"))
        await joan.checkUsername("joan")
        #expect(joan.usernameCheck == .available("joan"))
    }

    @Test("En Tu perfil se cambia, el anterior queda libre y sin red se conserva")
    func updateUsername() async {
        let directory = InMemoryAccountDirectory(profiles: [
            Profile(id: joanID, displayName: "Joan", username: "joan"),
            Profile(id: jesusID, displayName: "Jesús", username: "jesus"),
        ])
        await directory.link(joanID, jesusID)
        let joan = await session(joanID, directory)
        #expect(joan.me.username == "joan")
        #expect(await joan.updateUsername("joan.r"))
        #expect(joan.me.username == "joan.r")
        #expect(joan.phase == .main)
        let jesus = await session(jesusID, directory)
        #expect(jesus.partner.username == "joan.r")
        #expect(await jesus.updateUsername("joan"))

        await directory.setFailing(true)
        #expect(!(await joan.updateUsername("joan.rojas")))
        #expect(joan.error == .network)
        #expect(joan.me.username == "joan.r")
    }

    @Test("La vista previa de un CRZ- trae el @usuario de quien invita")
    func previewShowsUsername() async {
        let directory = InMemoryAccountDirectory(
            profiles: [
                Profile(id: joanID, displayName: "Joan", username: "joan"),
                Profile(id: jesusID, displayName: "Jesús", username: "jesus"),
            ], invitesFrom: [joanID])
        let jesus = await session(jesusID, directory)
        await jesus.checkCode("4821")
        #expect(jesus.invitePreview == .valid(inviterName: "Joan", username: "joan"))
    }
}
