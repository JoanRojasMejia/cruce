import Foundation

/// Lo último que supo la sesión con red: quién entró, sus cruces y el abierto. Sirve para abrir la app sin red.
public struct SessionSnapshot: Codable, Equatable, Sendable {
    public var userID: UUID
    public var me: Member
    public var cruces: [CruceLink]
    public var openCruceID: UUID?

    public init(userID: UUID, me: Member, cruces: [CruceLink], openCruceID: UUID?) {
        self.userID = userID
        self.me = me
        self.cruces = cruces
        self.openCruceID = openCruceID
    }
}

/// Dónde se guarda `SessionSnapshot` (`nil` si no hay nada o se cerró sesión).
public protocol SessionCache: Sendable {
    func load() async throws -> SessionSnapshot?
    func save(_ snapshot: SessionSnapshot?) async throws
}

/// En memoria, para pruebas.
public actor InMemorySessionCache: SessionCache {
    private var snapshot: SessionSnapshot?

    public init(snapshot: SessionSnapshot? = nil) {
        self.snapshot = snapshot
    }

    public func load() async throws -> SessionSnapshot? {
        snapshot
    }

    public func save(_ snapshot: SessionSnapshot?) async throws {
        self.snapshot = snapshot
    }
}

/// En un archivo JSON del dispositivo: `Application Support/Cruce/sesion.json`.
public struct FileSessionCache: SessionCache {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    public static func standard() -> FileSessionCache {
        let base =
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return FileSessionCache(url: base.appendingPathComponent("Cruce/sesion.json"))
    }

    public func load() async throws -> SessionSnapshot? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try JSONDecoder().decode(SessionSnapshot.self, from: Data(contentsOf: url))
    }

    public func save(_ snapshot: SessionSnapshot?) async throws {
        guard let snapshot else {
            try? FileManager.default.removeItem(at: url)
            return
        }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(snapshot).write(to: url, options: .atomic)
    }
}
