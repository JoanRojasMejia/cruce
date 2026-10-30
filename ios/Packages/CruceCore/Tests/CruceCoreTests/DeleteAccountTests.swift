import Foundation
import Testing

@testable import CruceCore

/// Borrar la cuenta (S4) con la base en memoria, el lugar de una cuenta borrada en los parches y los intentos fallidos
/// de unirse y quedarse con un lugar (S5).
@MainActor
@Suite("Borrar la cuenta")
struct DeleteAccountTests {
    private let joanID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private let jesusID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    private let anaID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!

    private func makeDirectory() -> InMemoryAccountDirectory {
        InMemoryAccountDirectory(profiles: [
            Profile(id: joanID, displayName: "Joan", username: "joan"),
            Profile(id: jesusID, displayName: "Jesús", username: "jesus"),
            Profile(id: anaID, displayName: "Ana", username: "ana"),
        ])
    }

    private func session(
        _ user: UUID, _ directory: InMemoryAccountDirectory, cache: (any SessionCache)? = nil
    ) async -> SessionStore {
        let session = SessionStore(
            phase: .onboarding, me: Member(name: "Tú", avatarColor: .yellow, tikeVariant: .rosa),
            partner: Member(name: "Tu amigo", avatarColor: .violet, tikeVariant: .verde),
            auth: InMemoryAuthService(signedIn: user), directory: directory, cache: cache, isReady: false)
        await session.refresh()
        return session
    }

    @Test("Borrar la cuenta cierra la sesión, olvida a la persona y borra lo guardado")
    func deleteSignsOut() async throws {
        let directory = makeDirectory()
        await directory.link(joanID, jesusID)
        let cache = InMemorySessionCache()
        let joan = await session(joanID, directory, cache: cache)
        #expect(try await cache.load() != nil)
        #expect(await joan.deleteAccount())
        #expect(joan.phase == .onboarding)
        #expect(joan.userID == nil)
        #expect(joan.cruces.isEmpty)
        #expect(joan.me.name == "Tú")
        #expect(joan.me.username == nil)
        #expect(try await cache.load() == nil)
        #expect(await directory.storedProfile(for: joanID)?.deletedAt != nil)
    }

    @Test("La otra persona conserva el cruce cerrado con «Cuenta borrada», sin @usuario")
    func partnerSeesDeletedAccount() async {
        let directory = makeDirectory()
        await directory.link(joanID, jesusID)
        let joan = await session(joanID, directory)
        _ = await joan.deleteAccount()
        let jesus = await session(jesusID, directory)
        #expect(jesus.cruces.count == 1)
        #expect(jesus.isOpenCruceClosed)
        #expect(jesus.partner.name == Profile.deletedName)
        #expect(jesus.partner.isDeleted)
        #expect(jesus.partner.username == nil)
    }

    @Test("El @usuario queda libre de inmediato")
    func usernameFreed() async {
        let directory = makeDirectory()
        let joan = await session(joanID, directory)
        _ = await joan.deleteAccount()
        let ana = await session(anaID, directory)
        #expect(await ana.updateUsername("joan"))
        #expect(ana.me.username == "joan")
    }

    @Test("Sin conexión no borra nada y la sesión sigue")
    func offlineKeepsAccount() async {
        let directory = makeDirectory()
        await directory.link(joanID, jesusID)
        let joan = await session(joanID, directory)
        await directory.setFailing(true)
        #expect(!(await joan.deleteAccount()))
        #expect(joan.error == .network)
        #expect(joan.phase == .main)
        #expect(joan.userID == joanID)
        #expect(await directory.storedProfile(for: joanID)?.deletedAt == nil)
    }

    // MARK: - Parches

    @Test("Al borrar la cuenta se olvidan los parches y lo que quedó sin enviar en el teléfono")
    func parcheResetForgets() async throws {
        let pending = InMemoryPendingStore()
        let session = SessionStore(phase: .main, me: MockData.joan, partner: MockData.jesus, userID: MockData.joan.id)
        let store = ParcheStore(
            session: session,
            repository: InMemoryParcheRepository(backend: MockParches.backend(), userID: MockData.joan.id),
            pendingStore: pending)
        await store.load()
        #expect(!store.parches.isEmpty)
        await store.reset()
        #expect(store.parches.isEmpty)
        #expect(store.pending.isEmpty)
        #expect(try await pending.load() == ParcheLocalState())
    }

    @Test("El lugar de una cuenta borrada se lee de la base: «Cuenta borrada», sin «sin la app» ni @usuario")
    func deletedParticipant() throws {
        let json = """
            {"id": "20000000-0000-0000-0000-000000000001", "parche_id": "10000000-0000-0000-0000-000000000001",
             "user_id": null, "display_name": "Cuenta borrada", "claim_code": null,
             "joined_at": "2026-10-20T10:00:00+00:00", "last_seen_at": null, "avatar_color": "green",
             "account_deleted_at": "2026-10-30T10:00:00+00:00", "participant_username": null}
            """
        let person = try ParcheRemote.participant(from: Data(json.utf8))
        #expect(person.isDeletedAccount)
        #expect(!person.hasApp)
        #expect(person.label == "Cuenta borrada")
        #expect(person.username == nil)
    }

    @Test("Quien tiene la app trae su @usuario; quien está sin la app sigue diciendo «sin la app»")
    func participantUsername() throws {
        let withApp = """
            {"id": "20000000-0000-0000-0000-000000000002", "user_id": "00000000-0000-0000-0000-0000000000a1",
             "display_name": "Ana", "claim_code": null, "joined_at": "2026-10-20T10:00:00+00:00",
             "avatar_color": "pink", "participant_username": "ana"}
            """
        let ana = try ParcheRemote.participant(from: Data(withApp.utf8))
        #expect(ana.username == "ana")
        #expect(!ana.isDeletedAccount)
        #expect(ana.label == "Ana")
        let withoutApp = """
            {"id": "20000000-0000-0000-0000-000000000003", "user_id": null, "display_name": "Carlos",
             "claim_code": "SOY-K7QX2M", "joined_at": "2026-10-20T10:00:00+00:00"}
            """
        let carlos = try ParcheRemote.participant(from: Data(withoutApp.utf8))
        #expect(carlos.label == "Carlos (sin la app)")
        #expect(carlos.username == nil)
        #expect(!carlos.isDeletedAccount)
        #expect(ParcheRemote.detailSelect.contains("parche_participants(*, participant_username)"))
    }

    @Test("Un participante guardado antes del @usuario se lee igual")
    func participantFromOldFile() throws {
        let person = ParcheParticipant(
            displayName: "Joan", joinedAt: Date(timeIntervalSince1970: 1_793_000_000), avatarColor: .green)
        var copy = person
        copy.username = "joan"
        copy.accountDeletedAt = Date(timeIntervalSince1970: 1_793_000_100)
        let decoded = try JSONDecoder().decode(ParcheParticipant.self, from: JSONEncoder().encode(copy))
        #expect(decoded == copy)
        let old = #"{"id": "\#(person.id)", "displayName": "Joan", "joinedAt": 0}"#
        let legacy = try JSONDecoder().decode(ParcheParticipant.self, from: Data(old.utf8))
        #expect(legacy.username == nil)
        #expect(legacy.accountDeletedAt == nil)
    }

    // MARK: - Intentos fallidos al unirse o quedarse con un lugar

    @Test("Unirse o quedarse con un lugar con un código que no sirve devuelve null: es «Ese código no existe»")
    func nullJoinIsInvalidCode() throws {
        #expect(throws: ParcheRepositoryError.invalidCode) { try ParcheRemote.joinedParcheID(from: Data("null".utf8)) }
        let id = UUID()
        #expect(try ParcheRemote.joinedParcheID(from: Data("\"\(id)\"".utf8)) == id)
    }

    @Test("Con 5 intentos la base lanza tooManyAttempts y la app muestra el mensaje de siempre")
    func tooManyAttempts() {
        #expect(ParcheRepositoryError(databaseCode: "P0001", hint: "tooManyAttempts") == .tooManyAttempts)
        #expect(ParcheRepositoryError(databaseCode: "P0001", hint: "invalidCode") == .invalidCode)
        #expect(ParcheStore.Problem.tooManyAttempts.message == CodeRejection.tooManyAttempts.defaultMessage)
    }
}
