import Foundation
import Testing

@testable import CruceCore

/// Cambios que llegan de la otra persona (Supabase Realtime) aplicados sobre los movimientos de cada cruce.
@MainActor
@Suite("Tiempo real")
struct LedgerRealtimeTests {
    private let joan = MockData.joan
    private let jesus = MockData.jesus

    private func store(feed: InMemoryMovementFeed = InMemoryMovementFeed()) -> LedgerStore {
        let session = SessionStore(
            phase: .main, me: joan, partner: jesus,
            cruces: [MockData.joanAnaCruce, MockData.joanJesusCruce(viewer: joan)])
        session.open(MockData.joanJesusCruceID)
        return LedgerStore(
            session: session, repository: InMemoryLedgerRepository(), movements: MockData.movements(),
            movementsByCruce: [MockData.joanAnaCruceID: MockData.anaMovements()], feed: feed)
    }

    private func market(_ amount: Int = 100_000) -> Movement {
        Movement(
            payerID: jesus.id, amount: amount, concept: "Mercado", category: .mercado,
            date: Date(timeIntervalSince1970: 1_793_000_000), createdBy: jesus.id)
    }

    @Test("Un gasto nuevo de la otra persona aparece y cambia el saldo")
    func applyInsert() {
        let ledger = store()
        let before = ledger.net
        let movement = market()
        ledger.apply(MovementChange(cruce: MockData.joanJesusCruceID, movement: movement))
        #expect(ledger.movement(movement.id) == movement)
        #expect(ledger.net == before - 50_000)
        #expect(ledger.lastSaved == nil)
    }

    @Test("El eco del mismo movimiento no lo duplica")
    func echoDoesNotDuplicate() {
        let ledger = store()
        let change = MovementChange(cruce: MockData.joanJesusCruceID, movement: market())
        ledger.apply(change)
        let count = ledger.movements.count
        ledger.apply(change)
        #expect(ledger.movements.count == count)
    }

    @Test("Una edición reemplaza y un borrado suave lo saca del saldo")
    func applyUpdateAndSoftDelete() {
        let ledger = store()
        var movement = market()
        ledger.apply(MovementChange(cruce: MockData.joanJesusCruceID, movement: movement))
        let withMarket = ledger.net
        movement.amount = 60_000
        ledger.apply(MovementChange(cruce: MockData.joanJesusCruceID, movement: movement))
        #expect(ledger.movement(movement.id)?.amount == 60_000)
        #expect(ledger.net == withMarket + 20_000)
        movement.deletedAt = Date(timeIntervalSince1970: 1_793_000_100)
        ledger.apply(MovementChange(cruce: MockData.joanJesusCruceID, movement: movement))
        #expect(ledger.movement(movement.id) == nil)
        #expect(ledger.net == withMarket + 50_000)
    }

    @Test("Un cambio de otro cruce no toca el cruce abierto")
    func otherCruceIsSeparate() {
        let ledger = store()
        let before = ledger.net
        ledger.apply(MovementChange(cruce: MockData.joanAnaCruceID, movement: market()))
        #expect(ledger.net == before)
        #expect(ledger.net(of: MockData.joanAnaCruceID) == -15_000 - 50_000)
    }

    @Test("Seguir los cambios aplica lo que llega mientras dura la secuencia")
    func followAppliesChanges() async {
        let feed = InMemoryMovementFeed()
        let ledger = store(feed: feed)
        let movement = market()
        let following = Task { await ledger.follow() }
        // Espera a que `follow` abra la secuencia antes de mandar el cambio.
        while !feed.isListening { await Task.yield() }
        feed.send(MovementChange(cruce: MockData.joanJesusCruceID, movement: movement))
        for _ in 0..<1_000 where ledger.movement(movement.id) == nil { await Task.yield() }
        #expect(ledger.movement(movement.id) != nil)
        feed.finish()
        await following.value
    }

    @Test("Las fechas de Realtime con espacio y zona +00 se leen igual que las de PostgREST")
    func realtimeTimestamps() {
        let realtime = ParcheRemote.parseTimestamp("2026-10-27 08:30:00.123456+00")
        let rest = ParcheRemote.parseTimestamp("2026-10-27T08:30:00.123456+00:00")
        #expect(realtime != nil)
        #expect(realtime == rest)
    }
}
