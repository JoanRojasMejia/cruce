import Foundation
import Testing

@testable import CruceCore

/// Invitar y unirse con dos sesiones que comparten la misma base en memoria, como dos iPhones contra Supabase.
@MainActor
@Suite("Vincular cruces")
struct SessionLinkingTests {
    private let joanID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private let jesusID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    private let anaID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!

    /// Cada quien con su color de perfil: Joan amarillo, Jesús violeta y Ana verde.
    private func makeDirectory() -> InMemoryAccountDirectory {
        InMemoryAccountDirectory(profiles: [
            Profile(id: joanID, displayName: "Joan", avatarColor: .yellow),
            Profile(id: jesusID, displayName: "Jesús", avatarColor: .violet),
            Profile(id: anaID, displayName: "Ana", avatarColor: .green),
        ])
    }

    /// Una sesión ya abierta para esa persona, en la etapa que calcule `refresh()`.
    private func session(_ user: UUID, _ directory: InMemoryAccountDirectory) async -> SessionStore {
        let placeholder = Member(name: "Tu amigo", avatarColor: .violet, tikeVariant: .verde)
        let session = SessionStore(
            phase: .onboarding, me: Member(name: "Tú", avatarColor: .yellow, tikeVariant: .rosa), partner: placeholder,
            auth: InMemoryAuthService(signedIn: user), directory: directory, isReady: false)
        await session.refresh()
        return session
    }

    private func digits(_ code: String?) -> String { String(code?.dropFirst(4) ?? "") }

    // MARK: - Invitar

    @Test("Pedir el código dos veces da el mismo y no crea otra cuenta pendiente")
    func inviteCodeIsStable() async {
        let directory = makeDirectory()
        let joan = await session(joanID, directory)
        await joan.loadInviteCode()
        let first = joan.inviteCode
        await joan.loadInviteCode()
        #expect(first?.hasPrefix("CRZ-") == true)
        #expect(joan.inviteCode == first)
        #expect(await directory.ledgerCount(for: joanID) == 1)
    }

    @Test("Con un cruce pendiente, la etapa sigue en invitar")
    func pendingCruceIsInvite() async {
        let directory = makeDirectory()
        let joan = await session(joanID, directory)
        await joan.loadInviteCode()
        await joan.refresh()
        #expect(joan.phase == .invite)
        #expect(joan.cruces.isEmpty)
    }

    // MARK: - Unirse

    @Test("Ver el código dice de quién es, sin unir a nadie")
    func checkCodeShowsInviter() async throws {
        let directory = makeDirectory()
        let joan = await session(joanID, directory)
        await joan.loadInviteCode()
        let jesus = await session(jesusID, directory)
        jesus.phase = .join
        await jesus.checkCode(digits(joan.inviteCode))
        #expect(jesus.invitePreview == .valid(inviterName: "Joan"))
        #expect(try await directory.cruces(for: jesusID).isEmpty)
    }

    @Test("Unirse con un código válido lleva a Conectados con el nombre, el color del perfil y el recibo de la base")
    func joinValidCode() async throws {
        let directory = makeDirectory()
        let joan = await session(joanID, directory)
        await joan.loadInviteCode()
        let jesus = await session(jesusID, directory)
        jesus.phase = .join
        #expect(await jesus.join(code: digits(joan.inviteCode)))
        #expect(jesus.phase == .connected)
        #expect(jesus.partner.id == joanID)
        #expect(jesus.partner.name == "Joan")
        #expect(jesus.partner.avatarColor == .yellow)
        #expect(jesus.partner.tikeVariant == .rosa)
        #expect(jesus.me.avatarColor == .violet)
        #expect(jesus.me.tikeVariant == .verde)
        #expect(jesus.cruces.count == 1)
    }

    @Test("Un código inválido deja el mensaje en español y sigue en unirse")
    func joinInvalidCode() async {
        let directory = makeDirectory()
        let jesus = await session(jesusID, directory)
        jesus.phase = .join
        #expect(!(await jesus.join(code: "0000")))
        #expect(jesus.phase == .join)
        #expect(jesus.error?.message == "El código no es válido o ya venció")
    }

    @Test("Un código con menos de 4 dígitos no se consulta")
    func shortCodeIsNotChecked() async {
        let directory = makeDirectory()
        let jesus = await session(jesusID, directory)
        await jesus.checkCode("12")
        #expect(jesus.invitePreview == nil)
        #expect(await directory.attemptCount(for: jesusID) == 0)
    }

    @Test("Un segundo cruce con la misma persona se rechaza con su nombre")
    func joinAlreadyLinked() async {
        let directory = makeDirectory()
        let joan = await session(joanID, directory)
        await joan.loadInviteCode()
        let jesus = await session(jesusID, directory)
        _ = await jesus.join(code: digits(joan.inviteCode))
        await joan.loadInviteCode()  // Joan pide otro código: sale de una cuenta pendiente nueva.
        jesus.phase = .join
        #expect(!(await jesus.join(code: digits(joan.inviteCode))))
        #expect(jesus.error?.message == "Ya tienes un cruce con Joan")
        #expect(jesus.cruces.count == 1)
    }

    @Test("Con 5 códigos inválidos, hasta uno válido se rechaza")
    func tooManyAttempts() async {
        let directory = makeDirectory()
        let joan = await session(joanID, directory)
        await joan.loadInviteCode()
        let jesus = await session(jesusID, directory)
        for bad in ["0001", "0002", "0003", "0004", "0005"] { await jesus.checkCode(bad) }
        await jesus.checkCode(digits(joan.inviteCode))
        #expect(
            jesus.invitePreview
                == .rejected(
                    .tooManyAttempts, message: "Hiciste demasiados intentos. Espera una hora e intenta de nuevo."))
    }

    // MARK: - Quien invita se entera

    @Test("Quien invita pasa a Conectados cuando el otro se une")
    func inviterNoticesJoin() async {
        let directory = makeDirectory()
        let joan = await session(joanID, directory)
        await joan.loadInviteCode()
        await joan.checkForPartner()
        #expect(joan.phase == .invite)

        let jesus = await session(jesusID, directory)
        _ = await jesus.join(code: digits(joan.inviteCode))
        await joan.checkForPartner()
        #expect(joan.phase == .connected)
        #expect(joan.partner.name == "Jesús")
        #expect(joan.partner.avatarColor == .violet)
        #expect(joan.me.tikeVariant == .rosa)
    }

    // MARK: - Varios cruces

    @Test("Con un cruce completo, el inicio usa el cruce más reciente")
    func mainUsesMostRecentCruce() async {
        let directory = makeDirectory()
        await directory.link(joanID, jesusID)
        await directory.link(anaID, joanID)
        let joan = await session(joanID, directory)
        #expect(joan.phase == .main)
        #expect(joan.cruces.map(\.partner.name) == ["Ana", "Jesús"])
        #expect(joan.partner.name == "Ana")
        #expect(joan.me.tikeVariant == .verde)  // En el cruce con Ana, Joan fue quien se unió.
    }

    @Test("Quien entra después de cerrar sesión no hereda el nombre ni los colores de la persona anterior")
    func signOutResetsMe() async {
        let directory = makeDirectory()
        await directory.link(joanID, jesusID)
        let jesus = await session(jesusID, directory)
        #expect(jesus.me.avatarColor == .violet)
        await jesus.signOut()
        #expect(jesus.me.name != "Jesús")
        #expect(jesus.me.avatarColor == .yellow)
        #expect(jesus.me.tikeVariant == .rosa)
    }

    @Test("Sin cruces, quien usa la app queda con el recibo rosa (va a crear su cruce) y el color de su perfil")
    func noCrucesIsCreatorColors() async {
        let directory = makeDirectory()
        let session = SessionStore(
            phase: .onboarding, me: Member(name: "Tú", avatarColor: .violet, tikeVariant: .verde),
            partner: MockData.jesus, auth: InMemoryAuthService(signedIn: anaID), directory: directory)
        await session.refresh()
        #expect(session.phase == .invite)
        #expect(session.me.avatarColor == .green)
        #expect(session.me.tikeVariant == .rosa)
    }

    @Test("Cerrar sesión olvida los cruces y el código")
    func signOutClearsLinking() async {
        let directory = makeDirectory()
        await directory.link(joanID, jesusID)
        let joan = await session(joanID, directory)
        await joan.loadInviteCode()
        joan.pendingJoinCode = "CRZ-1234"
        await joan.signOut()
        #expect(joan.cruces.isEmpty)
        #expect(joan.inviteCode == nil)
        #expect(joan.pendingJoinCode == nil)
        #expect(joan.invitePreview == nil)
    }

    // MARK: - Cruce abierto

    @Test("Abrir otro cruce cambia la otra persona y el recibo de quien usa la app, no su color")
    func openChangesPartnerAndColors() {
        let session = SessionStore(
            phase: .main, me: MockData.joan, partner: MockData.jesus,
            cruces: [MockData.joanAnaCruce, MockData.joanJesusCruce(viewer: MockData.joan)])
        #expect(session.openCruceID == MockData.joanAnaCruceID)
        #expect(session.partner.name == "Ana")
        #expect(session.me.tikeVariant == .verde)
        #expect(session.me.avatarColor == .yellow)
        session.open(MockData.joanJesusCruceID)
        #expect(session.partner.name == "Jesús")
        #expect(session.me.tikeVariant == .rosa)
        #expect(session.me.avatarColor == .yellow)
        #expect(session.openCruce?.id == MockData.joanJesusCruceID)
    }

    @Test("Recargar la sesión conserva el cruce abierto")
    func refreshKeepsOpenCruce() async {
        let directory = makeDirectory()
        await directory.link(joanID, jesusID)
        await directory.link(anaID, joanID)
        let joan = await session(joanID, directory)
        #expect(joan.partner.name == "Ana")
        let jesusCruce = joan.cruces.first { $0.partner.id == jesusID }!.id
        joan.open(jesusCruce)
        await joan.refresh()
        #expect(joan.openCruceID == jesusCruce)
        #expect(joan.partner.name == "Jesús")
    }

    @Test("Con un cruce ya, quien invita ve el cruce nuevo sin salir del inicio")
    func inviterInMainNoticesNewCruce() async {
        let directory = makeDirectory()
        await directory.link(joanID, jesusID)
        let joan = await session(joanID, directory)
        #expect(joan.phase == .main)
        await joan.loadInviteCode()
        await joan.checkForPartner()
        #expect(joan.lastLinked == nil)

        let ana = await session(anaID, directory)
        _ = await ana.join(code: digits(joan.inviteCode))
        await joan.checkForPartner()
        #expect(joan.phase == .main)
        #expect(joan.lastLinked?.partner.name == "Ana")
        #expect(joan.partner.name == "Ana")
        #expect(joan.cruces.count == 2)
    }

    @Test("Con un cruce ya, unirse a otro abre el cruce nuevo sin salir del inicio")
    func joinFromMainOpensNewCruce() async {
        let directory = makeDirectory()
        await directory.link(joanID, jesusID)
        let ana = await session(anaID, directory)
        await ana.loadInviteCode()
        let jesus = await session(jesusID, directory)
        #expect(jesus.phase == .main)
        #expect(await jesus.join(code: digits(ana.inviteCode)))
        #expect(jesus.phase == .main)
        #expect(jesus.lastLinked?.partner.name == "Ana")
        #expect(jesus.partner.name == "Ana")
        #expect(jesus.me.tikeVariant == .verde)
        #expect(jesus.cruces.count == 2)
    }
}
