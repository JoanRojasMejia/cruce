import Foundation

/// Un cambio de un movimiento que llega de la base (lo anotó, editó o eliminó alguien del cruce).
/// El borrado suave llega como una edición con `deletedAt`.
public struct MovementChange: Equatable, Sendable {
    public let cruce: UUID
    public let movement: Movement

    public init(cruce: UUID, movement: Movement) {
        self.cruce = cruce
        self.movement = movement
    }
}

/// Los cambios de los movimientos de esos cruces mientras dure la secuencia (Supabase Realtime en la app).
/// Al cancelarse la tarea que la recorre, la secuencia termina y se cierran las suscripciones.
public protocol MovementFeed: Sendable {
    func changes(in cruces: [UUID]) -> AsyncStream<MovementChange>
}

/// Doble en memoria de `MovementFeed`, para pruebas: `send` empuja un cambio a quienes estén escuchando ese cruce.
public final class InMemoryMovementFeed: MovementFeed, @unchecked Sendable {
    private let lock = NSLock()
    private var listeners: [(cruces: [UUID], continuation: AsyncStream<MovementChange>.Continuation)] = []

    public init() {}

    /// Alguien está escuchando (para que las pruebas esperen antes de mandar cambios).
    public var isListening: Bool {
        lock.withLock { !listeners.isEmpty }
    }

    public func changes(in cruces: [UUID]) -> AsyncStream<MovementChange> {
        AsyncStream { continuation in
            lock.withLock { listeners.append((cruces, continuation)) }
        }
    }

    public func send(_ change: MovementChange) {
        lock.withLock {
            for listener in listeners where listener.cruces.contains(change.cruce) {
                listener.continuation.yield(change)
            }
        }
    }

    /// Termina todas las secuencias, como cuando se cierra la conexión.
    public func finish() {
        lock.withLock {
            for listener in listeners { listener.continuation.finish() }
            listeners.removeAll()
        }
    }
}
