import Foundation

/// Acceso a los movimientos de la cuenta compartida.
/// Hoy lo implementa `InMemoryLedgerRepository`; en el CP5 entra `SupabaseLedgerRepository` con la misma interfaz.
public protocol LedgerRepository: Sendable {
    /// Todos los movimientos de la cuenta, incluidos los eliminados (con `deletedAt`).
    func loadMovements() async throws -> [Movement]
    /// Crea el movimiento o reemplaza el que tenga el mismo `id`.
    func save(_ movement: Movement) async throws
    /// Borrado suave en todas las implementaciones: marca `deletedAt` y conserva el movimiento,
    /// igual que `movements.deleted_at` en la base de datos.
    func delete(id: UUID) async throws
}

/// Repositorio en memoria, para la app mientras no haya backend, las vistas previas y las pruebas.
public actor InMemoryLedgerRepository: LedgerRepository {
    private var storage: [UUID: Movement]
    /// Reloj del borrado; las pruebas inyectan una fecha fija.
    private let now: @Sendable () -> Date

    public init(movements: [Movement] = [], now: @escaping @Sendable () -> Date = { .now }) {
        storage = Dictionary(uniqueKeysWithValues: movements.map { ($0.id, $0) })
        self.now = now
    }

    public func loadMovements() async throws -> [Movement] {
        Array(storage.values)
    }

    public func save(_ movement: Movement) async throws {
        storage[movement.id] = movement
    }

    public func delete(id: UUID) async throws {
        // Borrado suave: el movimiento se queda, marcado con el momento del borrado.
        storage[id]?.deletedAt = now()
    }
}
