import Foundation
import Testing

@testable import CruceCore

/// Sin conexión (CP7): lo del cruce se guarda en el teléfono, lo pendiente queda en una cola y se envía al volver la red,
/// sin perder ni duplicar nada.
@MainActor
@Suite("Sin conexión")
struct LedgerOfflineTests {
    private let joan = MockData.joan
    private let jesus = MockData.jesus
    private let cruce = MockData.joanJesusCruceID

    private func session(userID: UUID = MockData.joan.id) -> SessionStore {
        SessionStore(
            phase: .main, me: joan, partner: jesus, cruces: [MockData.joanJesusCruce(viewer: joan)], userID: userID)
    }

    private func expense(_ amount: Int, day: Int = 1) -> Movement {
        Movement(
            payerID: joan.id, amount: amount, concept: "Prueba", category: .otro,
            date: Date(timeIntervalSince1970: TimeInterval(day) * 86_400), createdBy: joan.id)
    }

    private func store(
        _ repository: any LedgerRepository, local: InMemoryLedgerLocalStore = InMemoryLedgerLocalStore(),
        session: SessionStore? = nil
    ) -> LedgerStore {
        LedgerStore(session: session ?? self.session(), repository: repository, localStore: local)
    }

    @Test("Sin red, guardar deja el gasto en pantalla, uno pendiente y la cola en el teléfono")
    func saveOffline() async throws {
        let local = InMemoryLedgerLocalStore()
        let ledger = store(FailingLedgerRepository(), local: local)
        let dinner = expense(60_000)
        await ledger.save(dinner)
        #expect(ledger.visibleMovements == [dinner])
        #expect(ledger.pendingSyncCount == 1)
        #expect(ledger.isOffline)
        let saved = try await local.load()
        #expect(saved.pending == [.save(dinner, cruce: cruce)])
        #expect(saved.movementsByCruce[cruce] == [dinner])
    }

    @Test("Al volver la red, lo pendiente llega a la base una sola vez y la cola queda vacía")
    func retrySendsPending() async throws {
        let stored = expense(50_000, day: 2)
        let repository = FailingLedgerRepository(movements: [stored])
        let local = InMemoryLedgerLocalStore()
        let ledger = store(repository, local: local)
        let dinner = expense(60_000)
        await ledger.save(dinner)
        await repository.recover()
        await ledger.retrySync()
        #expect(!ledger.isOffline)
        #expect(ledger.pendingSyncCount == 0)
        #expect(Set(ledger.visibleMovements) == [stored, dinner])
        #expect(try await repository.loadMovements(in: cruce).filter { $0.id == dinner.id }.count == 1)
        #expect(try await local.load().pending.isEmpty)
    }

    @Test("Recargar sin red no borra lo pendiente")
    func reloadOfflineKeepsPending() async {
        let ledger = store(FailingLedgerRepository())
        let dinner = expense(60_000)
        await ledger.save(dinner)
        await ledger.load()
        #expect(ledger.movement(dinner.id) != nil)
        #expect(ledger.pendingSyncCount == 1)
    }

    @Test("Anotar y luego eliminar sin red llegan en orden: el gasto queda eliminado en la base")
    func ordersAreKept() async throws {
        let repository = FailingLedgerRepository()
        let ledger = store(repository)
        let dinner = expense(60_000)
        await ledger.save(dinner)
        await ledger.delete(dinner.id)
        #expect(ledger.pendingSyncCount == 2)
        await repository.recover()
        await ledger.retrySync()
        #expect(ledger.pendingSyncCount == 0)
        #expect(try await repository.loadMovements(in: cruce).first { $0.id == dinner.id }?.isDeleted == true)
    }

    @Test("Al abrir sin red se ve lo guardado de la misma persona, con lo pendiente")
    func restoreSameUser() async {
        let local = InMemoryLedgerLocalStore()
        let first = store(FailingLedgerRepository(), local: local)
        let dinner = expense(60_000)
        await first.save(dinner)

        let reopened = store(FailingLedgerRepository(), local: local)
        await reopened.restore()
        #expect(reopened.movement(dinner.id) != nil)
        #expect(reopened.pendingSyncCount == 1)
    }

    @Test("Lo guardado de otra persona no se muestra")
    func restoreOtherUserIsIgnored() async throws {
        let local = InMemoryLedgerLocalStore()
        await store(FailingLedgerRepository(), local: local).save(expense(60_000))
        let other = store(FailingLedgerRepository(), local: local, session: session(userID: UUID()))
        await other.restore()
        #expect(other.movements.isEmpty)
        #expect(other.pendingSyncCount == 0)
    }

    @Test("Sin red la app queda sin conexión; al volver, envía lo pendiente")
    func networkChanges() async {
        let repository = FailingLedgerRepository()
        let ledger = store(repository)
        await ledger.networkChanged(isAvailable: false)
        #expect(ledger.isOffline)
        await ledger.save(expense(60_000))
        await repository.recover()
        await ledger.networkChanged(isAvailable: true)
        #expect(!ledger.isOffline)
        #expect(ledger.pendingSyncCount == 0)
    }

    @Test("Una operación que la base rechaza sale de la cola para no trabarla")
    func rejectedOperationLeavesQueue() async {
        let ledger = store(RejectingLedgerRepository())
        await ledger.save(expense(60_000))
        #expect(ledger.pendingSyncCount == 0)
        #expect(!ledger.isOffline)
    }

    @Test("Cargar sin sesión ni cruces (al arrancar) no pisa lo guardado en el teléfono")
    func loadWithoutSessionKeepsFile() async throws {
        let local = InMemoryLedgerLocalStore()
        await store(FailingLedgerRepository(), local: local).save(expense(60_000))
        let starting = LedgerStore(
            session: SessionStore(phase: .onboarding, me: joan, partner: jesus), repository: FailingLedgerRepository(),
            localStore: local)
        await starting.load()
        #expect(try await local.load().pending.count == 1)
    }

    @Test("Cerrar sesión vacía lo guardado en el teléfono")
    func resetClearsEverything() async throws {
        let local = InMemoryLedgerLocalStore()
        let ledger = store(FailingLedgerRepository(), local: local)
        await ledger.save(expense(60_000))
        await ledger.reset()
        #expect(ledger.movementsByCruce.isEmpty)
        #expect(ledger.pendingSyncCount == 0)
        #expect(try await local.load() == LedgerLocalState())
    }

    @Test("El archivo del teléfono guarda y lee el estado")
    func fileStoreRoundTrip() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("cruce-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let file = FileLedgerLocalStore(url: url)
        #expect(try await file.load() == LedgerLocalState())
        let dinner = expense(60_000)
        let state = LedgerLocalState(
            userID: joan.id, movementsByCruce: [cruce: [dinner]],
            pending: [.delete(id: dinner.id, cruce: cruce, at: .now)])
        try await file.save(state)
        #expect(try await file.load() == state)
    }
}

/// Repositorio cuya base rechaza todo lo que se guarda (por ejemplo, un dato inválido): no es falta de red.
private actor RejectingLedgerRepository: LedgerRepository {
    func loadMovements(in cruce: UUID) async throws -> [Movement] { [] }
    func save(_ movement: Movement, in cruce: UUID) async throws { throw LedgerRepositoryError.rejected }
    func delete(id: UUID, in cruce: UUID) async throws { throw LedgerRepositoryError.rejected }
}
