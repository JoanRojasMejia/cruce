import Foundation
import Testing

@testable import CruceCore

/// Pago parcial ("Cambiar monto" en Saldar) y el cruce cerrado como solo lectura en `LedgerStore`.
@MainActor
@Suite("Pago parcial y cruce cerrado")
struct PartialSettlementTests {
    private let joan = MockData.joan
    private let jesus = MockData.jesus

    /// Joan pagó un mercado de $100.000 a medias: Jesús le debe $50.000.
    private func store(closed: Bool = false) -> LedgerStore {
        var cruce = MockData.joanJesusCruce(viewer: joan)
        cruce.closedAt = closed ? Date(timeIntervalSince1970: 1_000) : nil
        let session = SessionStore(phase: .main, me: joan, partner: jesus, cruces: [cruce])
        let market = Movement(
            payerID: joan.id, amount: 100_000, concept: "Mercado", category: .mercado,
            date: Date(timeIntervalSince1970: 86_400), createdBy: joan.id)
        return LedgerStore(
            session: session, repository: InMemoryLedgerRepository(movements: [MockData.joanJesusCruceID: [market]]),
            movements: [market])
    }

    @Test("Un pago parcial lo hace quien debe y el saldo baja sin llegar a $0")
    func partial() async throws {
        let store = store()
        await store.settle(paymentMethod: "Nequi", amount: 20_000)
        let payment = try #require(store.lastSettlement)
        #expect(payment.kind == .settlement)
        #expect(payment.payerID == jesus.id)
        #expect(payment.amount == 20_000)
        #expect(payment.split == .fullOther)
        #expect(store.net == 30_000)
    }

    @Test("Pagar exactamente el total deja el saldo en $0")
    func fullAmount() async {
        let store = store()
        await store.settle(paymentMethod: "Efectivo", amount: 50_000)
        #expect(store.balance == .settled)
    }

    @Test("Un monto de $0 o mayor al total no registra nada", arguments: [0, 50_001])
    func outOfRange(_ amount: Int) async {
        let store = store()
        await store.settle(paymentMethod: "Nequi", amount: amount)
        #expect(store.lastSettlement == nil)
        #expect(store.net == 50_000)
    }

    @Test("En un cruce cerrado no se anota, no se elimina ni se salda")
    func closedCruce() async {
        let store = store(closed: true)
        let market = store.movements[0]
        await store.save(
            Movement(payerID: joan.id, amount: 1_000, concept: "Tarde", category: .otro, createdBy: joan.id))
        await store.delete(market.id)
        await store.settle(paymentMethod: "Nequi")
        #expect(store.movements.count == 1)
        #expect(store.movements[0].deletedAt == nil)
        #expect(store.lastSettlement == nil)
        #expect(store.net == 50_000)
    }

    // MARK: - Saldar primero (desvincular)

    @Test("Con saldo pendiente, desvincular ofrece \"Saldar primero\"")
    func offersSettleFirst() {
        #expect(store().offersSettleBeforeUnlink)
    }

    @Test("A paz y salvo, desvincular no ofrece saldar")
    func noSettleFirstWhenSettled() async {
        let store = store()
        await store.settle(paymentMethod: "Nequi")
        #expect(store.balance == .settled)
        #expect(!store.offersSettleBeforeUnlink)
    }

    @Test("Un cruce cerrado no ofrece saldar, aunque quede saldo")
    func noSettleFirstWhenClosed() {
        let store = store(closed: true)
        #expect(store.net == 50_000)
        #expect(!store.offersSettleBeforeUnlink)
    }
}
