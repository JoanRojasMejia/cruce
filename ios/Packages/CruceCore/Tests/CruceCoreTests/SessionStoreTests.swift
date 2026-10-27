import Foundation
import Testing

@testable import CruceCore

@MainActor
@Suite("Sesión")
struct SessionStoreTests {
    private let email = "joan@example.com"
    private let code = "123456"

    /// Sesión con dobles en memoria; por defecto, sin nadie adentro.
    private func makeSession(
        auth: InMemoryAuthService = InMemoryAuthService(code: "123456"),
        directory: InMemoryAccountDirectory = InMemoryAccountDirectory(),
        phase: SessionStore.Phase = .onboarding
    ) -> SessionStore {
        SessionStore(
            phase: phase, me: MockData.joan, partner: MockData.jesus, auth: auth, directory: directory)
    }

    @Test("Busca a cada miembro por su id")
    func memberLooksUpById() {
        let session = makeSession(phase: .main)
        #expect(session.member(MockData.jesus.id) == MockData.jesus)
        #expect(session.member(MockData.joan.id) == MockData.joan)
    }

    @Test("El código de invitación empieza vacío")
    func inviteCodeDefaultsToNil() {
        let session = makeSession(phase: .invite)
        #expect(session.inviteCode == nil)
    }

    @Test("Puede arrancar esperando el código de un correo, para las vistas previas")
    func initRestoresPendingEmail() {
        let session = SessionStore(
            phase: .signUp, me: MockData.joan, partner: MockData.jesus, pendingEmail: email)
        #expect(session.pendingEmail == email)
        #expect(session.userID == nil)
        #expect(session.isReady)
    }

    // MARK: - Etapa de entrada

    @Test("Sin sesión, la etapa es el onboarding")
    func refreshWithoutSessionIsOnboarding() async {
        let session = makeSession(phase: .main)
        await session.refresh()
        #expect(session.phase == .onboarding)
        #expect(session.userID == nil)
        #expect(session.isReady)
    }

    @Test("Con sesión y sin perfil, pide el nombre")
    func refreshWithoutProfileIsSignUp() async {
        let user = UUID()
        let session = makeSession(auth: InMemoryAuthService(signedIn: user))
        await session.refresh()
        #expect(session.phase == .signUp)
        #expect(session.userID == user)
    }

    @Test("Con perfil y sin cuenta compartida, invita")
    func refreshWithoutLedgerIsInvite() async {
        let user = UUID()
        let directory = InMemoryAccountDirectory(profiles: [Profile(id: user, displayName: "Joan")])
        let session = makeSession(auth: InMemoryAuthService(signedIn: user), directory: directory)
        await session.refresh()
        #expect(session.phase == .invite)
        #expect(session.me.id == user)
        #expect(session.me.name == "Joan")
    }

    @Test("Con cuenta compartida, va al inicio")
    func refreshWithLedgerIsMain() async {
        let user = UUID()
        let friend = UUID()
        let directory = InMemoryAccountDirectory(profiles: [
            Profile(id: user, displayName: "Joan"), Profile(id: friend, displayName: "Jesús"),
        ])
        await directory.link(user, friend)
        let session = makeSession(auth: InMemoryAuthService(signedIn: user), directory: directory)
        await session.refresh()
        #expect(session.phase == .main)
        #expect(session.partner.name == "Jesús")
    }

    @Test("Si no se pueden leer los datos, conserva la etapa y avisa")
    func refreshFailureKeepsPhase() async {
        let user = UUID()
        let directory = InMemoryAccountDirectory()
        await directory.setFailing(true)
        let session = makeSession(auth: InMemoryAuthService(signedIn: user), directory: directory, phase: .main)
        await session.refresh()
        #expect(session.phase == .main)
        #expect(session.error == .network)
        #expect(session.isReady)
    }

    // MARK: - Pedir el código

    @Test("Pedir el código con un correo válido lo envía y espera el código")
    func sendCodeWithValidEmail() async {
        let auth = InMemoryAuthService(code: code)
        let session = makeSession(auth: auth)
        let sent = await session.sendCode(to: "  Joan@Example.com ")
        #expect(sent)
        #expect(session.pendingEmail == email)
        #expect(session.error == nil)
        #expect(await auth.sentCodes == [email])
    }

    @Test(
        "Un correo inválido no pide el código",
        arguments: ["", "joan", "joan@", "@example.com", "joan@example", "jo an@example.com", "joan@@example.com"])
    func sendCodeWithInvalidEmail(_ text: String) async {
        let auth = InMemoryAuthService(code: code)
        let session = makeSession(auth: auth)
        let sent = await session.sendCode(to: text)
        #expect(!sent)
        #expect(session.pendingEmail == nil)
        #expect(session.error == .invalidEmail)
        #expect(await auth.sentCodes.isEmpty)
    }

    @Test("Si el envío falla, avisa y no pasa al código")
    func sendCodeFailure() async {
        let auth = InMemoryAuthService(code: code)
        await auth.setSendError(AuthServiceError.rateLimited)
        let session = makeSession(auth: auth)
        let sent = await session.sendCode(to: email)
        #expect(!sent)
        #expect(session.pendingEmail == nil)
        #expect(session.error == .tooManyRequests)
    }

    @Test("Cambiar el correo vuelve a pedirlo")
    func cancelCodeClearsPendingEmail() async {
        let session = makeSession()
        _ = await session.sendCode(to: email)
        session.cancelCode()
        #expect(session.pendingEmail == nil)
    }

    // MARK: - Verificar el código

    @Test("El código correcto abre la sesión y pide el nombre la primera vez")
    func verifyCorrectCodeForNewPerson() async {
        let session = makeSession()
        _ = await session.sendCode(to: email)
        let ok = await session.verify(code: code)
        #expect(ok)
        #expect(session.userID != nil)
        #expect(session.pendingEmail == nil)
        #expect(session.phase == .signUp)
    }

    @Test("El código correcto de alguien con perfil no pide el nombre otra vez")
    func verifyCorrectCodeForReturningPerson() async {
        let user = UUID()
        let auth = InMemoryAuthService(code: code, users: [email: user])
        let directory = InMemoryAccountDirectory(profiles: [Profile(id: user, displayName: "Joan")])
        let session = makeSession(auth: auth, directory: directory)
        _ = await session.sendCode(to: email)
        _ = await session.verify(code: " 123456 ")
        #expect(session.userID == user)
        #expect(session.phase == .invite)
    }

    @Test("Un código equivocado no abre la sesión y avisa", arguments: ["654321", "12345", "abcdef", ""])
    func verifyWrongCode(_ wrong: String) async {
        let session = makeSession()
        _ = await session.sendCode(to: email)
        let ok = await session.verify(code: wrong)
        #expect(!ok)
        #expect(session.userID == nil)
        #expect(session.pendingEmail == email)
        #expect(session.error == .invalidCode)
        #expect(session.phase == .onboarding)
    }

    @Test("Pedir otro código lo vuelve a enviar al mismo correo")
    func resendCode() async {
        let auth = InMemoryAuthService(code: code)
        let session = makeSession(auth: auth)
        _ = await session.sendCode(to: email)
        _ = await session.verify(code: "000000")
        let sent = await session.resendCode()
        #expect(sent)
        #expect(session.error == nil)
        #expect(await auth.sentCodes == [email, email])
    }

    // MARK: - Perfil

    @Test("Guardar el nombre crea el perfil y pasa a invitar")
    func createProfileWithValidName() async {
        let user = UUID()
        let directory = InMemoryAccountDirectory()
        let session = makeSession(auth: InMemoryAuthService(signedIn: user), directory: directory)
        await session.refresh()
        let ok = await session.createProfile(name: "  Joan  ")
        #expect(ok)
        #expect(await directory.storedProfile(for: user) == Profile(id: user, displayName: "Joan"))
        #expect(session.me.name == "Joan")
        #expect(session.phase == .invite)
    }

    @Test("El nombre puede tener hasta 40 caracteres")
    func createProfileAcceptsFortyCharacters() async {
        let user = UUID()
        let session = makeSession(auth: InMemoryAuthService(signedIn: user))
        await session.refresh()
        #expect(await session.createProfile(name: String(repeating: "a", count: 40)))
    }

    @Test(
        "Un nombre vacío o de más de 40 caracteres no se guarda",
        arguments: ["", "   ", String(repeating: "a", count: 41)])
    func createProfileRejectsInvalidName(_ name: String) async {
        let user = UUID()
        let directory = InMemoryAccountDirectory()
        let session = makeSession(auth: InMemoryAuthService(signedIn: user), directory: directory)
        await session.refresh()
        let ok = await session.createProfile(name: name)
        #expect(!ok)
        #expect(session.error == .invalidName)
        #expect(await directory.storedProfile(for: user) == nil)
        #expect(session.phase == .signUp)
    }

    // MARK: - Cerrar sesión

    @Test("Cerrar sesión termina la sesión y vuelve al onboarding")
    func signOutReturnsToOnboarding() async {
        let user = UUID()
        let auth = InMemoryAuthService(signedIn: user)
        let session = makeSession(auth: auth, phase: .main)
        await session.refresh()
        await session.signOut()
        #expect(session.phase == .onboarding)
        #expect(session.userID == nil)
        #expect(await auth.currentUserID() == nil)
    }

    @Test("Cerrar sesión vuelve al onboarding aunque falle la red")
    func signOutFailureStillReturnsToOnboarding() async {
        let auth = InMemoryAuthService(signedIn: UUID())
        await auth.setSignOutError(URLError(.notConnectedToInternet))
        let session = makeSession(auth: auth, phase: .main)
        await session.refresh()
        await session.signOut()
        #expect(session.phase == .onboarding)
        #expect(session.userID == nil)
    }
}
