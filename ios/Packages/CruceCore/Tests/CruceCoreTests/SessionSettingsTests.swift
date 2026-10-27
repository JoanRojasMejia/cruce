import Foundation
import Testing

@testable import CruceCore

/// Ajustes del CP11 con la base en memoria: cambiar el nombre, el reparto por defecto y desvincular (cerrar el cruce).
@MainActor
@Suite("Ajustes de la sesión")
struct SessionSettingsTests {
    private let joanID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private let jesusID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    private let anaID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!

    private func makeDirectory() -> InMemoryAccountDirectory {
        InMemoryAccountDirectory(profiles: [
            Profile(id: joanID, displayName: "Joan"),
            Profile(id: jesusID, displayName: "Jesús"),
            Profile(id: anaID, displayName: "Ana"),
        ])
    }

    private func session(_ user: UUID, _ directory: InMemoryAccountDirectory) async -> SessionStore {
        let session = SessionStore(
            phase: .onboarding, me: Member(name: "Tú", avatarColor: .yellow, tikeVariant: .rosa),
            partner: Member(name: "Tu amigo", avatarColor: .violet, tikeVariant: .verde),
            auth: InMemoryAuthService(signedIn: user), directory: directory, isReady: false)
        await session.refresh()
        return session
    }

    // MARK: - Nombre

    @Test("Cambiar el nombre lo recorta, lo guarda y la otra persona lo ve al recargar")
    func updateName() async {
        let directory = makeDirectory()
        await directory.link(joanID, jesusID)
        let joan = await session(joanID, directory)
        #expect(await joan.updateName("  Joan R.  "))
        #expect(joan.me.name == "Joan R.")
        #expect(await directory.storedProfile(for: joanID)?.displayName == "Joan R.")
        let jesus = await session(jesusID, directory)
        #expect(jesus.partner.name == "Joan R.")
    }

    @Test(
        "Un nombre vacío o de más de 40 caracteres no se guarda", arguments: ["   ", String(repeating: "a", count: 41)])
    func invalidName(_ name: String) async {
        let directory = makeDirectory()
        let joan = await session(joanID, directory)
        #expect(await !joan.updateName(name))
        #expect(joan.error == .invalidName)
        #expect(joan.me.name == "Joan")
    }

    @Test("Sin red el nombre sigue siendo el anterior")
    func updateNameOffline() async {
        let directory = makeDirectory()
        let joan = await session(joanID, directory)
        await directory.setFailing(true)
        #expect(await !joan.updateName("Joan R."))
        #expect(joan.error == .network)
        #expect(joan.me.name == "Joan")
    }

    // MARK: - Reparto por defecto

    @Test("El reparto por defecto es del cruce: lo ven los dos y no cambia el de otro cruce")
    func defaultSplit() async {
        let directory = makeDirectory()
        await directory.link(joanID, jesusID)
        await directory.link(joanID, anaID)
        let joan = await session(joanID, directory)
        let jesusCruce = joan.cruces.first { $0.partner.id == jesusID }!.id
        joan.open(jesusCruce)
        #expect(await joan.setDefaultSplit(70))
        #expect(joan.openCruce?.defaultOtherPercent == 70)
        #expect(joan.cruces.first { $0.partner.id == anaID }?.defaultOtherPercent == 50)
        let jesus = await session(jesusID, directory)
        #expect(jesus.openCruce?.defaultOtherPercent == 70)
    }

    @Test("Sin red el reparto sigue siendo el anterior")
    func defaultSplitOffline() async {
        let directory = makeDirectory()
        await directory.link(joanID, jesusID)
        let joan = await session(joanID, directory)
        await directory.setFailing(true)
        #expect(await !joan.setDefaultSplit(70))
        #expect(joan.openCruce?.defaultOtherPercent == 50)
    }

    // MARK: - Desvincular

    @Test("Desvincular cierra el cruce para los dos y el inicio pasa a la lista")
    func closeCruce() async {
        let directory = makeDirectory()
        await directory.link(joanID, jesusID)
        let joan = await session(joanID, directory)
        #expect(!joan.showsCruceList)
        #expect(await joan.closeOpenCruce())
        #expect(joan.isOpenCruceClosed)
        #expect(joan.showsCruceList)
        #expect(joan.phase == .main)
        let jesus = await session(jesusID, directory)
        #expect(jesus.isOpenCruceClosed)
        #expect(jesus.showsCruceList)
    }

    @Test("Un cruce cerrado no cambia de reparto ni se vuelve a cerrar")
    func closedIsReadOnly() async {
        let directory = makeDirectory()
        await directory.link(joanID, jesusID)
        let joan = await session(joanID, directory)
        await joan.closeOpenCruce()
        #expect(await !joan.setDefaultSplit(70))
        #expect(await !joan.closeOpenCruce())
    }

    @Test("Los abiertos van primero y se abre el abierto más reciente")
    func openFirst() async {
        let directory = makeDirectory()
        await directory.link(joanID, anaID)
        await directory.link(joanID, jesusID)
        let joan = await session(joanID, directory)
        #expect(joan.partner.id == jesusID)
        await joan.closeOpenCruce()
        await joan.refresh()
        #expect(joan.cruces.map(\.partner.id) == [anaID, jesusID])
        #expect(joan.cruces.map(\.isClosed) == [false, true])
        let fresh = await session(joanID, directory)
        #expect(fresh.partner.id == anaID)
    }

    @Test("Sin red, desvincular no cambia nada")
    func closeOffline() async {
        let directory = makeDirectory()
        await directory.link(joanID, jesusID)
        let joan = await session(joanID, directory)
        await directory.setFailing(true)
        #expect(await !joan.closeOpenCruce())
        #expect(!joan.isOpenCruceClosed)
        #expect(joan.error == .network)
    }

    @Test("Con el cruce cerrado, la pareja vuelve con un código nuevo y queda un cruce nuevo abierto")
    func relink() async {
        let directory = makeDirectory()
        await directory.link(joanID, jesusID)
        let joan = await session(joanID, directory)
        await joan.closeOpenCruce()
        await joan.loadInviteCode()
        let jesus = await session(jesusID, directory)
        #expect(await jesus.join(code: joan.inviteCode ?? ""))
        #expect(jesus.cruces.map(\.isClosed) == [false, true])
        #expect(!jesus.isOpenCruceClosed)
        #expect(jesus.openCruce?.partner.id == joanID)
    }
}
