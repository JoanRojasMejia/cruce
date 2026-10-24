import Foundation

/// Acceso a los movimientos de la cuenta compartida.
/// Hoy lo implementa `InMemoryLedgerRepository` con datos de ejemplo.
/// En el punto 2 se agrega `SupabaseLedgerRepository` con la misma interfaz.
protocol LedgerRepository: Sendable {
    func loadMovements() async throws -> [Movement]
    func save(_ movement: Movement) async throws
    func delete(id: UUID) async throws
}

actor InMemoryLedgerRepository: LedgerRepository {
    private var storage: [UUID: Movement]

    init(movements: [Movement] = []) {
        storage = Dictionary(uniqueKeysWithValues: movements.map { ($0.id, $0) })
    }

    func loadMovements() async throws -> [Movement] {
        Array(storage.values)
    }

    func save(_ movement: Movement) async throws {
        storage[movement.id] = movement
    }

    func delete(id: UUID) async throws {
        storage[id] = nil
    }
}
