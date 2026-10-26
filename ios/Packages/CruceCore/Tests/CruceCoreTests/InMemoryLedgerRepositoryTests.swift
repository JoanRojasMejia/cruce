import Foundation
import Testing

@testable import CruceCore

@Suite("Repositorio en memoria")
struct InMemoryLedgerRepositoryTests {
    private let deletedAt = Date(timeIntervalSince1970: 1_000_000)

    private func expense(_ amount: Int) -> Movement {
        Movement(
            payerID: MockData.joan.id, amount: amount, concept: "Prueba", category: .otro,
            createdBy: MockData.joan.id)
    }

    @Test("Eliminar conserva el movimiento marcado con la fecha del borrado")
    func deleteKeepsMovementMarked() async throws {
        let movement = expense(6_000)
        let repository = InMemoryLedgerRepository(movements: [movement], now: { deletedAt })
        try await repository.delete(id: movement.id)
        let stored = try await repository.loadMovements()
        #expect(stored.count == 1)
        #expect(stored.first?.id == movement.id)
        #expect(stored.first?.deletedAt == deletedAt)
    }

    @Test("Guardar reemplaza el movimiento con el mismo id")
    func saveReplacesById() async throws {
        var movement = expense(6_000)
        let repository = InMemoryLedgerRepository(movements: [movement])
        movement.amount = 9_000
        try await repository.save(movement)
        let stored = try await repository.loadMovements()
        #expect(stored.count == 1)
        #expect(stored.first?.amount == 9_000)
    }
}
