import Foundation
import Testing

@testable import CruceCore

@Suite("Repositorio en memoria")
struct InMemoryLedgerRepositoryTests {
    private let deletedAt = Date(timeIntervalSince1970: 1_000_000)
    private let cruce = MockData.joanJesusCruceID

    private func expense(_ amount: Int) -> Movement {
        Movement(
            payerID: MockData.joan.id, amount: amount, concept: "Prueba", category: .otro,
            createdBy: MockData.joan.id)
    }

    @Test("Eliminar conserva el movimiento marcado con la fecha del borrado")
    func deleteKeepsMovementMarked() async throws {
        let movement = expense(6_000)
        let repository = InMemoryLedgerRepository(movements: [cruce: [movement]], now: { deletedAt })
        try await repository.delete(id: movement.id, in: cruce)
        let stored = try await repository.loadMovements(in: cruce)
        #expect(stored.count == 1)
        #expect(stored.first?.id == movement.id)
        #expect(stored.first?.deletedAt == deletedAt)
    }

    @Test("Guardar reemplaza el movimiento con el mismo id")
    func saveReplacesById() async throws {
        var movement = expense(6_000)
        let repository = InMemoryLedgerRepository(movements: [cruce: [movement]])
        movement.amount = 9_000
        try await repository.save(movement, in: cruce)
        let stored = try await repository.loadMovements(in: cruce)
        #expect(stored.count == 1)
        #expect(stored.first?.amount == 9_000)
    }

    @Test("Lo que se guarda en un cruce no aparece en otro")
    func movementsBelongToOneCruce() async throws {
        let repository = InMemoryLedgerRepository()
        let dinner = expense(40_000)
        try await repository.save(dinner, in: MockData.joanAnaCruceID)
        #expect(try await repository.loadMovements(in: MockData.joanAnaCruceID) == [dinner])
        #expect(try await repository.loadMovements(in: cruce).isEmpty)
        try await repository.delete(id: dinner.id, in: cruce)
        #expect(try await repository.loadMovements(in: MockData.joanAnaCruceID).first?.deletedAt == nil)
    }
}
