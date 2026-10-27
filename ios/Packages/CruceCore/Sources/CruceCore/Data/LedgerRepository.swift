import Foundation

/// Acceso a los movimientos de cada cruce. Cada movimiento vive en un solo cruce (`movements.ledger_id` en la base):
/// lo que se guarda en uno no aparece en otro.
/// Hoy lo implementa `InMemoryLedgerRepository`; en el CP5 entra `SupabaseLedgerRepository` con la misma interfaz.
public protocol LedgerRepository: Sendable {
    /// Todos los movimientos del cruce, incluidos los eliminados (con `deletedAt`).
    func loadMovements(in cruce: UUID) async throws -> [Movement]
    /// Crea el movimiento en ese cruce o reemplaza el que tenga el mismo `id`.
    func save(_ movement: Movement, in cruce: UUID) async throws
    /// Borrado suave en todas las implementaciones: marca `deletedAt` y conserva el movimiento,
    /// igual que `movements.deleted_at` en la base de datos.
    func delete(id: UUID, in cruce: UUID) async throws
}

/// Errores del repositorio que no son falta de red. Cualquier otro error se trata como sin conexión y lo pendiente se
/// reintenta.
public enum LedgerRepositoryError: Error, Equatable, Sendable {
    /// La base rechazó el cambio (por ejemplo, un dato inválido): reintentarlo no sirve.
    case rejected
}

/// Repositorio en memoria, para la app mientras no haya backend, las vistas previas y las pruebas.
public actor InMemoryLedgerRepository: LedgerRepository {
    private var storage: [UUID: [UUID: Movement]]
    /// Reloj del borrado; las pruebas inyectan una fecha fija.
    private let now: @Sendable () -> Date

    /// `movements`: los movimientos de cada cruce, por el id del cruce.
    public init(movements: [UUID: [Movement]] = [:], now: @escaping @Sendable () -> Date = { .now }) {
        storage = movements.mapValues { list in Dictionary(uniqueKeysWithValues: list.map { ($0.id, $0) }) }
        self.now = now
    }

    public func loadMovements(in cruce: UUID) async throws -> [Movement] {
        Array(storage[cruce, default: [:]].values)
    }

    public func save(_ movement: Movement, in cruce: UUID) async throws {
        storage[cruce, default: [:]][movement.id] = movement
    }

    public func delete(id: UUID, in cruce: UUID) async throws {
        // Borrado suave: el movimiento se queda, marcado con el momento del borrado.
        storage[cruce]?[id]?.deletedAt = now()
    }
}
