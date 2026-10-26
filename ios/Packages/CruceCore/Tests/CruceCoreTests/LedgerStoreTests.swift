import Foundation
import Testing

@testable import CruceCore

@MainActor
@Suite("Estado de los movimientos")
struct LedgerStoreTests {
    private let joan = MockData.joan
    private let jesus = MockData.jesus
    private let deletedAt = Date(timeIntervalSince1970: 2_000_000)

    private func session() -> SessionStore {
        SessionStore(phase: .main, me: joan, partner: jesus)
    }

    private func expense(_ payer: Member, _ amount: Int, day: Int = 1) -> Movement {
        Movement(
            payerID: payer.id, amount: amount, concept: "Prueba", category: .otro,
            date: Date(timeIntervalSince1970: TimeInterval(day) * 86_400), createdBy: payer.id)
    }

    /// Store con el repositorio en memoria sembrado con los mismos movimientos.
    private func store(_ movements: [Movement]) -> (LedgerStore, InMemoryLedgerRepository) {
        let repository = InMemoryLedgerRepository(movements: movements, now: { deletedAt })
        let store = LedgerStore(
            session: session(), repository: repository, movements: movements, now: { deletedAt })
        return (store, repository)
    }

    @Test("Guardar uno nuevo abre la hoja de guardado; editar no")
    func saveSetsLastSavedOnlyForNewMovements() async {
        let existing = expense(joan, 10_000)
        let (store, _) = store([existing])
        var edited = existing
        edited.amount = 12_000
        await store.save(edited)
        #expect(store.lastSaved == nil)
        #expect(store.movement(existing.id)?.amount == 12_000)

        let new = expense(jesus, 8_000, day: 2)
        await store.save(new)
        #expect(store.lastSaved == new)
        #expect(store.visibleMovements.count == 2)
    }

    @Test("Eliminar marca el movimiento, baja el saldo y el repositorio lo conserva")
    func deleteMarksMovement() async throws {
        let dinner = expense(joan, 6_000, day: 1)
        let market = expense(jesus, 100_000, day: 2)
        let (store, repository) = store([dinner, market])
        let before = store.net
        await store.delete(dinner.id)
        #expect(store.net == before - 3_000)
        #expect(!store.visibleMovements.contains { $0.id == dinner.id })
        #expect(store.movement(dinner.id) == nil)
        #expect(store.movements.first { $0.id == dinner.id }?.deletedAt == deletedAt)
        let stored = try await repository.loadMovements()
        #expect(stored.first { $0.id == dinner.id }?.deletedAt == deletedAt)
    }

    @Test("Eliminar el único movimiento deja el inicio vacío")
    func deletingOnlyMovementLeavesEmpty() async {
        let only = expense(joan, 6_000)
        let (store, _) = store([only])
        #expect(!store.isEmpty)
        await store.delete(only.id)
        #expect(store.isEmpty)
        #expect(store.balance == .settled)
    }

    @Test("Saldar agrega el pago y abre \"A paz y salvo\"")
    func settleAddsPayment() async throws {
        // Datos de ejemplo en el pasado, para que el pago (con la fecha de hoy) quede de último.
        let (store, _) = store(MockData.movements(reference: Date(timeIntervalSince1970: 86_400 * 30)))
        await store.settle(paymentMethod: "Nequi")
        let payment = try #require(store.lastSettlement)
        #expect(payment.kind == .settlement)
        #expect(payment.amount == 20_000)
        #expect(store.balance == .settled)
        #expect(store.movementsSinceLastSettlement == 0)
    }

    @Test("Saldar en $0 no hace nada")
    func settleDoesNothingWhenSettled() async {
        let (store, _) = store([])
        await store.settle(paymentMethod: "Efectivo")
        #expect(store.lastSettlement == nil)
        #expect(store.movements.isEmpty)
    }

    @Test("Si el almacenamiento falla, el gasto queda pendiente y la app sin conexión")
    func failingRepositoryMarksPendingSync() async {
        let store = LedgerStore(session: session(), repository: FailingLedgerRepository())
        let new = expense(joan, 10_000)
        await store.save(new)
        #expect(store.visibleMovements == [new])
        #expect(store.pendingSyncCount == 1)
        #expect(store.isOffline)
    }

    @Test("Reintentar limpia lo pendiente y vuelve a cargar")
    func retrySyncClearsAndReloads() async {
        let stored = expense(jesus, 50_000)
        let repository = FailingLedgerRepository(movements: [stored])
        let store = LedgerStore(session: session(), repository: repository)
        await store.save(expense(joan, 10_000))
        #expect(store.isOffline)
        await repository.recover()
        await store.retrySync()
        #expect(!store.isOffline)
        #expect(store.pendingSyncCount == 0)
        #expect(store.visibleMovements == [stored])
    }

    @Test("Las lecturas usan a quien tiene la sesión en ese momento")
    func readsFollowSession() {
        let movements = MockData.movements()
        let session = SessionStore(phase: .main, me: jesus, partner: joan)
        let store = LedgerStore(session: session, repository: InMemoryLedgerRepository(), movements: movements)
        #expect(store.balance == .youOwe(20_000))
        #expect(store.phrase(forNet: store.net) == "Le debes $20.000 a Joan")
    }
}
