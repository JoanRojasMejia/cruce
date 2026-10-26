import Foundation

/// Inicio de sesión con un código de un solo uso enviado por correo.
/// En la app lo implementa `SupabaseAuthService` (supabase-swift); aquí hay un doble en memoria
/// para las pruebas y las vistas previas, así CruceCore no depende de la red.
public protocol AuthService: Sendable {
    /// El usuario con la sesión guardada, o `nil` si nadie ha entrado.
    func currentUserID() async -> UUID?
    /// Pide un código de 6 dígitos para ese correo. Sirve para crear la cuenta y para volver a entrar.
    func sendCode(to email: String) async throws
    /// Verifica el código y abre la sesión. Devuelve el id del usuario.
    func verify(email: String, code: String) async throws -> UUID
    /// Termina la sesión y borra la guardada.
    func signOut() async throws
}

/// Errores conocidos del inicio de sesión. Cualquier otro error se trata como falla de conexión.
public enum AuthServiceError: Error, Equatable, Sendable {
    /// El código no es correcto o ya venció.
    case invalidCode
    /// Se pidieron demasiados códigos seguidos.
    case rateLimited
}

/// El perfil de una persona (`profiles` en la base de datos).
public struct Profile: Equatable, Sendable {
    public let id: UUID
    public var displayName: String

    public init(id: UUID, displayName: String) {
        self.id = id
        self.displayName = displayName
    }
}

/// Lo que la sesión necesita saber de la cuenta para decidir la etapa de entrada.
/// Va aparte de `AuthService` para no mezclar la autenticación con los datos.
public protocol AccountDirectory: Sendable {
    /// El perfil de ese usuario, o `nil` si todavía no lo creó.
    func profile(for userID: UUID) async throws -> Profile?
    /// Si el usuario ya pertenece a una cuenta compartida (`ledger_members`).
    func hasLedger(_ userID: UUID) async throws -> Bool
    /// Crea el perfil con `id` igual al del usuario.
    func createProfile(_ profile: Profile) async throws
}

/// Doble en memoria de `AuthService`, para pruebas y vistas previas. Todos los correos reciben el mismo código.
public actor InMemoryAuthService: AuthService {
    private let code: String
    private var users: [String: UUID]
    private var current: UUID?
    private var sendError: (any Error & Sendable)?
    private var signOutError: (any Error & Sendable)?
    /// Correos a los que se pidió un código, en orden.
    public private(set) var sentCodes: [String] = []

    public init(code: String = "123456", users: [String: UUID] = [:], signedIn: UUID? = nil) {
        self.code = code
        self.users = users
        current = signedIn
    }

    /// Hace fallar los próximos envíos (`nil` los vuelve a permitir).
    public func setSendError(_ error: (any Error & Sendable)?) {
        sendError = error
    }

    /// Hace fallar el próximo cierre de sesión en el servidor; la sesión local se borra igual.
    public func setSignOutError(_ error: (any Error & Sendable)?) {
        signOutError = error
    }

    public func currentUserID() async -> UUID? {
        current
    }

    public func sendCode(to email: String) async throws {
        if let sendError { throw sendError }
        sentCodes.append(email)
    }

    public func verify(email: String, code: String) async throws -> UUID {
        guard sentCodes.contains(email), code == self.code else { throw AuthServiceError.invalidCode }
        let id = users[email] ?? UUID()
        users[email] = id
        current = id
        return id
    }

    public func signOut() async throws {
        current = nil
        if let signOutError { throw signOutError }
    }
}

/// Doble en memoria de `AccountDirectory`, para pruebas y vistas previas.
public actor InMemoryAccountDirectory: AccountDirectory {
    private var profiles: [UUID: Profile]
    private var ledgerMembers: Set<UUID>
    private var isFailing = false

    /// Error de las lecturas mientras `isFailing` sea verdadero, como sin conexión.
    public struct Offline: Error {}

    public init(profiles: [Profile] = [], ledgerMembers: Set<UUID> = []) {
        self.profiles = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
        self.ledgerMembers = ledgerMembers
    }

    /// Simula que se cae (o vuelve) la conexión.
    public func setFailing(_ failing: Bool) {
        isFailing = failing
    }

    public func profile(for userID: UUID) async throws -> Profile? {
        if isFailing { throw Offline() }
        return profiles[userID]
    }

    public func hasLedger(_ userID: UUID) async throws -> Bool {
        if isFailing { throw Offline() }
        return ledgerMembers.contains(userID)
    }

    public func createProfile(_ profile: Profile) async throws {
        if isFailing { throw Offline() }
        profiles[profile.id] = profile
    }

    /// El perfil guardado, sin fallar (para revisar en las pruebas).
    public func storedProfile(for userID: UUID) -> Profile? {
        profiles[userID]
    }
}
