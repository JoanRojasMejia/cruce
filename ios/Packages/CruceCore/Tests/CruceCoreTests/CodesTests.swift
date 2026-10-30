import Foundation
import Testing

@testable import CruceCore

/// "Tengo un código": el prefijo mientras se escribe, los errores separados y el enlace `cruce://codigo/…`.
@MainActor
@Suite("Códigos")
struct CodesTests {
    private let joanID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private let jesusID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    private let anaID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!

    private func data(_ json: String) -> Data { Data(json.utf8) }

    // MARK: - El prefijo mientras se escribe

    @Test(
        "Mayúsculas, sin espacios y con el guion aunque no lo escriban",
        arguments: [
            ("crz4821", "CRZ-4821"), (" CRZ - 4821 ", "CRZ-4821"), ("4821", "CRZ-4821"), ("pch abc234", "PCH-ABC234"),
            ("soy–k7qx2m", "SOY-K7QX2M"), ("PCH-SM4R7A", "PCH-SM4R7A"), ("cr", "CR"), ("48", "48"),
        ])
    func normalize(text: String, expected: String) {
        #expect(EnteredCode.normalize(text) == expected)
    }

    @Test("El tipo se sabe por el prefijo mientras se escribe")
    func kindWhileTyping() {
        #expect(EnteredCode.kind(of: "") == nil)
        #expect(EnteredCode.kind(of: "C") == nil)
        #expect(EnteredCode.kind(of: "CRZ") == .cruce)
        #expect(EnteredCode.kind(of: "crz-48") == .cruce)
        #expect(EnteredCode.kind(of: "48") == .cruce)
        #expect(EnteredCode.kind(of: "pch") == .parche)
        #expect(EnteredCode.kind(of: "SOY-K7") == .place)
        #expect(EnteredCode.kind(of: "HOLA") == nil)
    }

    @Test("Completo, incompleto, prefijo desconocido o mal formado")
    func shapes() {
        #expect(EnteredCode.shape(of: "CRZ-48") == .incomplete(.cruce))
        #expect(EnteredCode.shape(of: "crz4821") == .complete(.cruce, code: "CRZ-4821"))
        #expect(EnteredCode.shape(of: "PCH-SM4R7") == .incomplete(.parche))
        #expect(EnteredCode.shape(of: "pchsm4r7a") == .complete(.parche, code: "PCH-SM4R7A"))
        #expect(EnteredCode.shape(of: "SOY-K7QX2M") == .complete(.place, code: "SOY-K7QX2M"))
        #expect(EnteredCode.shape(of: "SO") == .incomplete(nil))
        #expect(EnteredCode.shape(of: "HOLA") == .unknownPrefix)
        #expect(EnteredCode.shape(of: "CRZ-48A") == .malformed(.cruce))
        #expect(EnteredCode.shape(of: "CRZ-48210") == .malformed(.cruce))
        #expect(EnteredCode.shape(of: "48210") == .malformed(.cruce))
        // Sin 0/O ni 1/I/L: no pueden estar en un código de parche.
        #expect(EnteredCode.shape(of: "PCH-SM0R7A") == .malformed(.parche))
        #expect(EnteredCode.shape(of: "SOY-K7QX2MM") == .malformed(.place))
    }

    // MARK: - Errores separados

    @Test("Cada error tiene su título y solo el de 'no existe' recuerda los prefijos")
    func rejectionTitles() {
        #expect(CodeRejection.invalid.title == "Ese código no existe")
        #expect(CodeRejection.expired.title == "Ese código venció")
        #expect(CodeRejection.used.title == "Ese código ya se usó")
        #expect(CodeRejection.own.title == "Ese código es tuyo")
        #expect(CodeRejection.invalid.showsPrefixes)
        #expect(!CodeRejection.expired.showsPrefixes)
    }

    @Test("CRZ-: no existe, vencido, ya usado y tuyo son errores distintos")
    func cruceRejections() async throws {
        let directory = InMemoryAccountDirectory(
            profiles: [
                Profile(id: joanID, displayName: "Joan"), Profile(id: jesusID, displayName: "Jesús"),
                Profile(id: anaID, displayName: "Ana"),
            ],
            invitesFrom: [joanID, anaID])
        #expect(
            try await directory.previewInvite("CRZ-0000", for: jesusID)
                == .rejected(.invalid, message: CodeRejection.invalid.defaultMessage))
        #expect(
            try await directory.previewInvite("CRZ-4821", for: joanID)
                == .rejected(.own, message: CodeRejection.own.defaultMessage))
        #expect(try await directory.redeemInvite("CRZ-4821", for: jesusID) == .valid(inviterName: "Joan"))
        #expect(
            try await directory.previewInvite("CRZ-4821", for: anaID)
                == .rejected(.used, message: CodeRejection.used.defaultMessage))
        await directory.advance(by: 25 * 60 * 60)
        #expect(
            try await directory.previewInvite("CRZ-4822", for: jesusID)
                == .rejected(.expired, message: CodeRejection.expired.defaultMessage))
        #expect(await directory.attemptCount(for: jesusID) == 2)
    }

    @Test("La vista previa del CRZ- se vuelve la de la pantalla de código")
    func previewFromInviteCheck() {
        #expect(CodePreview(.valid(inviterName: "Joan")) == .cruce(inviterName: "Joan"))
        #expect(CodePreview(.rejected(.used, message: "x")).rejection == .used)
    }

    @Test("El JSON de preview_parche_code: parche, lugar o error")
    func remoteParchePreview() throws {
        #expect(
            try ParcheRemote.codePreview(
                from: data(
                    #"{"ok": true, "kind": "parche", "parche_name": "Santa Marta", "already_member": false}"#))
                == .parche(name: "Santa Marta", alreadyMember: false))
        #expect(
            try ParcheRemote.codePreview(
                from: data(#"{"ok": true, "kind": "place", "parche_name": "Santa Marta", "person_name": "Carlos"}"#))
                == .place(parcheName: "Santa Marta", personName: "Carlos"))
        #expect(
            try ParcheRemote.codePreview(from: data(#"{"ok": false, "error": "used", "message": "Ya se usó"}"#))
                == .rejected(.used, message: "Ya se usó"))
        #expect(
            try ParcheRemote.codePreview(from: data(#"{"ok": false, "error": "nuevo", "message": "Algo"}"#))
                == .rejected(.invalid, message: "Algo"))
        #expect(throws: DecodingError.self) {
            try ParcheRemote.codePreview(from: data(#"{"ok": true, "kind": "place"}"#))
        }
    }

    @Test("PCH- y SOY-: a dónde lleva, ya usado, tuyo y no existe")
    func parcheRejections() async throws {
        let world = ParcheWorld()
        let jesus = world.store(world.jesus)
        let ana = world.store(world.ana)
        let carlosStore = world.store(world.carlos)
        let parche = try #require(await jesus.createParche(name: "Santa Marta"))
        let carlos = try #require(await jesus.addParticipant(name: "Carlos", to: parche.id))
        let diego = try #require(await jesus.addParticipant(name: "Diego", to: parche.id))
        let soy = try #require(carlos.claimCode)

        #expect(
            await ana.previewCode(parche.parche.code.lowercased()) == .parche(name: "Santa Marta", alreadyMember: false)
        )
        #expect(await jesus.previewCode(parche.parche.code) == .parche(name: "Santa Marta", alreadyMember: true))
        #expect(await ana.previewCode(soy) == .place(parcheName: "Santa Marta", personName: "Carlos"))
        #expect(ana.parches.isEmpty, "Ver el código no une a nadie")

        _ = try #require(await carlosStore.enter(code: soy))
        #expect(await carlosStore.previewCode(soy) == .rejected(.own, message: "Ese lugar ya es tuyo."))
        #expect(await ana.previewCode(soy) == .rejected(.used, message: CodeRejection.used.defaultMessage))
        #expect(await ana.previewCode("PCH-ZZZZZZ")?.rejection == .invalid)
        #expect(await carlosStore.previewCode(try #require(diego.claimCode))?.rejection == .alreadyParticipant)
        #expect(await ana.previewCode("CRZ-4821") == nil, "Los CRZ- van por la sesión")
        #expect(await ana.previewCode("PCH-ZZ") == nil, "Un código incompleto no se consulta")
    }

    @Test("Con 5 intentos fallidos, ni un PCH- válido se ve")
    func parcheAttempts() async throws {
        let world = ParcheWorld()
        let jesus = world.store(world.jesus)
        let ana = world.store(world.ana)
        let parche = try #require(await jesus.createParche(name: "Cena"))
        for bad in ["PCH-ZZZZZA", "PCH-ZZZZZB", "SOY-ZZZZZC", "PCH-ZZZZZD", "SOY-ZZZZZE"] {
            _ = await ana.previewCode(bad)
        }
        #expect(await ana.previewCode(parche.parche.code)?.rejection == .tooManyAttempts)
        world.clock.advance(hours: 1.1)
        #expect(await ana.previewCode(parche.parche.code) == .parche(name: "Cena", alreadyMember: false))
    }

    // MARK: - Enlace

    @Test("cruce://codigo/<CÓDIGO> trae el código en su forma normal")
    func linkParser() throws {
        let prod = CodeLink.defaultScheme
        #expect(CodeLink.code(from: try #require(URL(string: "cruce://codigo/CRZ-4821")), scheme: prod) == "CRZ-4821")
        #expect(
            CodeLink.code(from: try #require(URL(string: "CRUCE://Codigo/soy-k7qx2m/")), scheme: prod) == "SOY-K7QX2M")
        #expect(
            CodeLink.code(from: try #require(URL(string: "cruce://codigo/PCH%20SM4R7A")), scheme: prod) == "PCH-SM4R7A")
        #expect(CodeLink.code(from: try #require(URL(string: "cruce://codigo/")), scheme: prod) == nil)
        #expect(CodeLink.code(from: try #require(URL(string: "cruce://otra/CRZ-4821")), scheme: prod) == nil)
        #expect(CodeLink.code(from: try #require(URL(string: "https://codigo/CRZ-4821")), scheme: prod) == nil)
        #expect(CodeLink.url(for: "soy k7qx2m", scheme: prod)?.absoluteString == "cruce://codigo/SOY-K7QX2M")
    }

    @Test(
        "Cada ambiente abre solo los enlaces de su esquema y los crea con el suyo",
        arguments: ["cruce", "cruce-test", "cruce-dev"])
    func linkSchemePerEnvironment(scheme: String) throws {
        let own = try #require(URL(string: "\(scheme)://codigo/crz4821"))
        #expect(CodeLink.code(from: own, scheme: scheme) == "CRZ-4821")
        #expect(CodeLink.url(for: "PCH-SM4R7A", scheme: scheme)?.absoluteString == "\(scheme)://codigo/PCH-SM4R7A")
        for other in ["cruce", "cruce-test", "cruce-dev"] where other != scheme {
            let foreign = try #require(URL(string: "\(other)://codigo/CRZ-4821"))
            #expect(CodeLink.code(from: foreign, scheme: scheme) == nil, "\(scheme) no abre \(other)")
        }
    }

    @Test("El esquema de la app sale del Info.plist; sin reemplazar o vacío, el de prod")
    func linkSchemeFromInfo() {
        #expect(CodeLink.scheme(in: ["CRUCE_URL_SCHEME": "cruce-test"]) == "cruce-test")
        #expect(CodeLink.scheme(in: ["CRUCE_URL_SCHEME": " Cruce-Dev "]) == "cruce-dev")
        #expect(CodeLink.scheme(in: ["CRUCE_URL_SCHEME": "$(APP_URL_SCHEME)"]) == "cruce")
        #expect(CodeLink.scheme(in: ["CRUCE_URL_SCHEME": ""]) == "cruce")
        #expect(CodeLink.scheme(in: [:]) == "cruce")
    }

    @Test("Un enlace sin sesión espera a que entre; con sesión abre Tengo un código")
    func pendingLink() async throws {
        let session = SessionStore(
            phase: .onboarding, me: Member(name: "Tú", avatarColor: .yellow, tikeVariant: .rosa),
            partner: Member(name: "Tu amigo", avatarColor: .violet, tikeVariant: .verde))
        #expect(!session.receive(link: try #require(URL(string: "https://cruce.app")), scheme: "cruce"))
        #expect(session.receive(link: try #require(URL(string: "cruce://codigo/crz4821")), scheme: "cruce"))
        #expect(session.pendingCode == "CRZ-4821")
        #expect(!session.opensPendingCode, "Sin sesión espera")

        let signedIn = SessionStore(
            phase: .invite, me: Member(name: "Joan", avatarColor: .yellow, tikeVariant: .rosa),
            partner: Member(name: "Tu amigo", avatarColor: .violet, tikeVariant: .verde), userID: joanID)
        signedIn.receive(link: try #require(URL(string: "cruce-dev://codigo/PCH-SM4R7A")), scheme: "cruce-dev")
        #expect(signedIn.opensPendingCode)
        signedIn.phase = .connected
        #expect(!signedIn.opensPendingCode, "En Conectados espera al inicio")
    }

    @Test("Abrir Tengo un código desde un enlace no lo apila dos veces")
    func routerShowsEnterCode() {
        let router = Router(path: [.parches])
        router.showEnterCode()
        router.showEnterCode()
        #expect(router.path == [.parches, .enterCode])
    }
}
