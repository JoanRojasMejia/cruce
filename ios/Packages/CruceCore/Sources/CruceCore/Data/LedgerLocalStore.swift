import Foundation

/// Un cambio de un cruce que todavía no llegó a la base. Reenviarlo es seguro: guardar es `upsert` por `id` y eliminar
/// marca `deleted_at`. Saldar es un `save` del pago.
public enum LedgerPendingOperation: Codable, Hashable, Sendable {
    case save(Movement, cruce: UUID)
    case delete(id: UUID, cruce: UUID, at: Date)
}

/// Lo que `LedgerStore` guarda en el teléfono: los movimientos de cada cruce (para abrir sin red) y la cola de
/// pendientes. `userID` es de quién son: lo de otra persona no se muestra.
public struct LedgerLocalState: Codable, Hashable, Sendable {
    public var userID: UUID?
    public var movementsByCruce: [UUID: [Movement]]
    public var pending: [LedgerPendingOperation]

    public init(userID: UUID? = nil, movementsByCruce: [UUID: [Movement]] = [:], pending: [LedgerPendingOperation] = [])
    {
        self.userID = userID
        self.movementsByCruce = movementsByCruce
        self.pending = pending
    }
}

/// Dónde se guarda `LedgerLocalState` para que sobreviva a cerrar la app.
public protocol LedgerLocalStore: Sendable {
    func load() async throws -> LedgerLocalState
    func save(_ state: LedgerLocalState) async throws
}

/// En memoria, para pruebas.
public actor InMemoryLedgerLocalStore: LedgerLocalStore {
    private var state: LedgerLocalState

    public init(state: LedgerLocalState = LedgerLocalState()) {
        self.state = state
    }

    public func load() async throws -> LedgerLocalState {
        state
    }

    public func save(_ state: LedgerLocalState) async throws {
        self.state = state
    }
}

/// En un archivo JSON del dispositivo (decisión de Joan: archivo, no SwiftData). Si no existe, el estado está vacío.
public struct FileLedgerLocalStore: LedgerLocalStore {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    /// `Application Support/Cruce/movimientos.json` del usuario.
    public static func standard() -> FileLedgerLocalStore {
        let base =
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return FileLedgerLocalStore(url: base.appendingPathComponent("Cruce/movimientos.json"))
    }

    public func load() async throws -> LedgerLocalState {
        guard FileManager.default.fileExists(atPath: url.path) else { return LedgerLocalState() }
        return try JSONDecoder().decode(LedgerLocalState.self, from: Data(contentsOf: url))
    }

    public func save(_ state: LedgerLocalState) async throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(state).write(to: url, options: .atomic)
    }
}
