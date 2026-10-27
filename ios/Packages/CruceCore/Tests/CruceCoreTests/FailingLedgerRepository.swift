import Foundation

@testable import CruceCore

/// Repositorio de prueba que falla mientras `isFailing` sea verdadero, como un almacenamiento sin conexión.
/// Al recuperarse se comporta como la base: guardar reemplaza por `id` y eliminar marca `deletedAt`.
actor FailingLedgerRepository: LedgerRepository {
    struct Offline: Error {}

    private var storage: [Movement]
    private var isFailing = true

    init(movements: [Movement] = []) {
        storage = movements
    }

    /// Simula que vuelve la conexión.
    func recover() {
        isFailing = false
    }

    func loadMovements(in cruce: UUID) async throws -> [Movement] {
        if isFailing { throw Offline() }
        return storage
    }

    func save(_ movement: Movement, in cruce: UUID) async throws {
        if isFailing { throw Offline() }
        if let index = storage.firstIndex(where: { $0.id == movement.id }) {
            storage[index] = movement
        } else {
            storage.append(movement)
        }
    }

    func delete(id: UUID, in cruce: UUID) async throws {
        if isFailing { throw Offline() }
        if let index = storage.firstIndex(where: { $0.id == id }) {
            storage[index].deletedAt = Date(timeIntervalSince1970: 3_000_000)
        }
    }
}
