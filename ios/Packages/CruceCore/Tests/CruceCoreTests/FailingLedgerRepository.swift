import Foundation

@testable import CruceCore

/// Repositorio de prueba que falla mientras `isFailing` sea verdadero, como un almacenamiento sin conexión.
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

    func loadMovements() async throws -> [Movement] {
        if isFailing { throw Offline() }
        return storage
    }

    func save(_ movement: Movement) async throws {
        if isFailing { throw Offline() }
        storage.append(movement)
    }

    func delete(id: UUID) async throws {
        if isFailing { throw Offline() }
    }
}
