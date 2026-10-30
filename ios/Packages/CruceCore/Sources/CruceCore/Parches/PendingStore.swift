import Foundation

/// Una operación que no se pudo enviar por falta de conexión. Reintentarla es idempotente (`upsert` por `id`).
public enum ParchePendingOperation: Codable, Hashable, Sendable {
    case saveExpense(ParcheExpense)
    case deleteExpense(id: UUID, parcheID: UUID, at: Date)
    case recordPayment(ParchePayment)
    case confirmPayment(id: UUID, parcheID: UUID, at: Date)

    public var parcheID: UUID {
        switch self {
        case .saveExpense(let expense): expense.parcheID
        case .recordPayment(let payment): payment.parcheID
        case .deleteExpense(_, let parcheID, _), .confirmPayment(_, let parcheID, _): parcheID
        }
    }

    /// El gasto o pago que cambia: su fila lleva "Sin enviar" mientras la operación siga en la cola.
    public var itemID: UUID {
        switch self {
        case .saveExpense(let expense): expense.id
        case .recordPayment(let payment): payment.id
        case .deleteExpense(let id, _, _), .confirmPayment(let id, _, _): id
        }
    }
}

/// Un par al que se le respondió "No, se salda en el parche". Se guarda en el dispositivo, no en la base.
public struct ParcheDeclinedCruce: Codable, Hashable, Sendable {
    public let parcheID: UUID
    public let otherID: UUID

    public init(parcheID: UUID, otherID: UUID) {
        self.parcheID = parcheID
        self.otherID = otherID
    }
}

/// Lo que `ParcheStore` guarda en el teléfono: la cola sin conexión y las respuestas a "¿Lo pasas a tu cruce?".
public struct ParcheLocalState: Codable, Hashable, Sendable {
    public var pending: [ParchePendingOperation]
    public var declinedCruce: Set<ParcheDeclinedCruce>

    public init(pending: [ParchePendingOperation] = [], declinedCruce: Set<ParcheDeclinedCruce> = []) {
        self.pending = pending
        self.declinedCruce = declinedCruce
    }
}

/// Dónde se guarda `ParcheLocalState` para que sobreviva a cerrar la app.
public protocol PendingStore: Sendable {
    func load() async throws -> ParcheLocalState
    func save(_ state: ParcheLocalState) async throws
}

/// En memoria, para pruebas y vistas previas.
public actor InMemoryPendingStore: PendingStore {
    private var state: ParcheLocalState

    public init(state: ParcheLocalState = ParcheLocalState()) {
        self.state = state
    }

    public func load() async throws -> ParcheLocalState {
        state
    }

    public func save(_ state: ParcheLocalState) async throws {
        self.state = state
    }
}

/// En un archivo JSON del dispositivo. Si el archivo no existe, la cola está vacía.
public struct FilePendingStore: PendingStore {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    /// `Application Support/Cruce/parches.json` del usuario.
    public static func standard() -> FilePendingStore {
        let base =
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return FilePendingStore(url: base.appendingPathComponent("Cruce/parches.json"))
    }

    public func load() async throws -> ParcheLocalState {
        guard FileManager.default.fileExists(atPath: url.path) else { return ParcheLocalState() }
        return try JSONDecoder().decode(ParcheLocalState.self, from: Data(contentsOf: url))
    }

    public func save(_ state: ParcheLocalState) async throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(state).write(to: url, options: .atomic)
    }
}
