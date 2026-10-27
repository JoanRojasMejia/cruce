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
    /// Crea el perfil con `id` igual al del usuario.
    func createProfile(_ profile: Profile) async throws
    /// Los cruces completos (de dos personas) del usuario, del más reciente al más viejo (`my_cruces()`).
    /// Un cruce pendiente, donde nadie se ha unido, no aparece.
    func cruces(for userID: UUID) async throws -> [CruceLink]
    /// El código `CRZ-` del único cruce pendiente del usuario; lo crea si no hay (`create_ledger_with_invite()`).
    func inviteCode(for userID: UUID) async throws -> String
    /// De quién es un código, sin unirse (`preview_invite`). Los inválidos cuentan para el límite de intentos.
    func previewInvite(_ code: String, for userID: UUID) async throws -> InviteCheck
    /// Canjea un código: el usuario queda como segunda persona de ese cruce (`redeem_invite`).
    func redeemInvite(_ code: String, for userID: UUID) async throws -> InviteCheck
}
// En Supabase las funciones usan la sesión abierta (`auth.uid()`): el `userID` que se pasa debe ser el de esa sesión.
// El doble en memoria lo necesita para saber quién llama.

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

/// Doble en memoria de `AccountDirectory`, para pruebas y vistas previas. Reproduce las reglas de la base:
/// un cruce pendiente por persona, un cruce por pareja, códigos que vencen a las 24 horas y 5 intentos fallidos por hora.
public actor InMemoryAccountDirectory: AccountDirectory {
    private struct Membership {
        let user: UUID
        let avatarColor: AvatarColor
        let tikeVariant: TikeVariant
        let joinedAt: Date
    }

    private struct Ledger {
        let id: UUID
        let createdBy: UUID
        var members: [Membership]
    }

    private struct Invite {
        let ledgerID: UUID
        let createdBy: UUID
        var expiresAt: Date
        var redeemedBy: UUID?
    }

    private var profiles: [UUID: Profile]
    private var ledgers: [Ledger] = []
    private var invites: [String: Invite] = [:]
    private var attempts: [UUID: [Date]] = [:]
    private var now: Date
    private var nextCode = 4821
    private var isFailing = false

    /// Error de las lecturas mientras `isFailing` sea verdadero, como sin conexión.
    public struct Offline: Error {}

    /// `invitesFrom`: personas que ya tienen su cruce pendiente con un código vigente, en orden (`CRZ-4821`,
    /// `CRZ-4822`…), para las vistas previas de la pantalla de unirse.
    public init(
        profiles: [Profile] = [], invitesFrom creators: [UUID] = [],
        now: Date = Date(timeIntervalSince1970: 1_793_000_000)
    ) {
        self.profiles = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
        self.now = now
        for creator in creators {
            let ledgerID = UUID()
            ledgers.append(
                Ledger(
                    id: ledgerID, createdBy: creator,
                    members: [Membership(user: creator, avatarColor: .yellow, tikeVariant: .rosa, joinedAt: now)]))
            invites["CRZ-" + String(format: "%04d", nextCode % 10_000)] = Invite(
                ledgerID: ledgerID, createdBy: creator, expiresAt: now + 24 * 60 * 60)
            nextCode += 1
        }
    }

    /// Simula que se cae (o vuelve) la conexión.
    public func setFailing(_ failing: Bool) {
        isFailing = failing
    }

    /// Adelanta el reloj (para que venzan códigos o pase la hora de los intentos).
    public func advance(by seconds: TimeInterval) {
        now += seconds
    }

    /// Crea un cruce completo entre dos personas: `creator` queda amarillo y rosa, `joiner` violeta y verde.
    /// Cada llamada es un segundo más tarde, así el último cruce creado es el más reciente.
    public func link(_ creator: UUID, _ joiner: UUID) {
        now += 1
        ledgers.append(
            Ledger(
                id: UUID(), createdBy: creator,
                members: [
                    Membership(user: creator, avatarColor: .yellow, tikeVariant: .rosa, joinedAt: now),
                    Membership(user: joiner, avatarColor: .violet, tikeVariant: .verde, joinedAt: now),
                ]))
    }

    /// Cuántas cuentas (completas o pendientes) tiene esa persona (para revisar en las pruebas).
    public func ledgerCount(for userID: UUID) -> Int {
        ledgers.filter { $0.members.contains { $0.user == userID } }.count
    }

    /// Cuántos intentos fallidos tiene registrados esa persona (para revisar en las pruebas).
    public func attemptCount(for userID: UUID) -> Int {
        attempts[userID, default: []].count
    }

    /// El perfil guardado, sin fallar (para revisar en las pruebas).
    public func storedProfile(for userID: UUID) -> Profile? {
        profiles[userID]
    }

    public func profile(for userID: UUID) async throws -> Profile? {
        if isFailing { throw Offline() }
        return profiles[userID]
    }

    public func createProfile(_ profile: Profile) async throws {
        if isFailing { throw Offline() }
        profiles[profile.id] = profile
    }

    public func cruces(for userID: UUID) async throws -> [CruceLink] {
        if isFailing { throw Offline() }
        return
            ledgers
            .filter { $0.members.count == 2 }
            .compactMap { ledger -> CruceLink? in
                guard let mine = ledger.members.first(where: { $0.user == userID }),
                    let other = ledger.members.first(where: { $0.user != userID })
                else { return nil }
                let partner = Member(
                    id: other.user, name: profiles[other.user]?.displayName ?? "", avatarColor: other.avatarColor,
                    tikeVariant: other.tikeVariant)
                return CruceLink(
                    id: ledger.id, partner: partner, myAvatarColor: mine.avatarColor, myTikeVariant: mine.tikeVariant,
                    linkedAt: max(mine.joinedAt, other.joinedAt))
            }
            .sorted { $0.linkedAt > $1.linkedAt }
    }

    public func inviteCode(for userID: UUID) async throws -> String {
        if isFailing { throw Offline() }
        let ledgerID: UUID
        if let pending = ledgers.last(where: { $0.createdBy == userID && $0.members.count == 1 }) {
            if let current = invites.first(where: {
                $0.value.ledgerID == pending.id && $0.value.redeemedBy == nil && $0.value.expiresAt > now
            }) {
                return current.key
            }
            ledgerID = pending.id
        } else {
            ledgerID = UUID()
            ledgers.append(
                Ledger(
                    id: ledgerID, createdBy: userID,
                    members: [Membership(user: userID, avatarColor: .yellow, tikeVariant: .rosa, joinedAt: now)]))
        }
        let code = "CRZ-" + String(format: "%04d", nextCode % 10_000)
        nextCode += 1
        invites[code] = Invite(ledgerID: ledgerID, createdBy: userID, expiresAt: now + 24 * 60 * 60)
        return code
    }

    public func previewInvite(_ code: String, for userID: UUID) async throws -> InviteCheck {
        if isFailing { throw Offline() }
        return check(code, for: userID).result
    }

    public func redeemInvite(_ code: String, for userID: UUID) async throws -> InviteCheck {
        if isFailing { throw Offline() }
        let (result, normalized) = check(code, for: userID)
        guard case .valid = result, let normalized, var invite = invites[normalized],
            let index = ledgers.firstIndex(where: { $0.id == invite.ledgerID })
        else { return result }
        ledgers[index].members.append(
            Membership(user: userID, avatarColor: .violet, tikeVariant: .verde, joinedAt: now))
        invite.redeemedBy = userID
        invites[normalized] = invite
        return result
    }

    /// Las mismas reglas que `check_invite` en la base, en el mismo orden.
    private func check(_ code: String, for userID: UUID) -> (result: InviteCheck, code: String?) {
        let recent = attempts[userID, default: []].filter { $0 > now - 60 * 60 }
        if recent.count >= 5 {
            return (
                .rejected(
                    .tooManyAttempts, message: "Hiciste demasiados intentos. Espera una hora e intenta de nuevo."), nil
            )
        }
        let normalized = code.trimmingCharacters(in: .whitespaces).uppercased()
        guard let invite = invites[normalized], invite.redeemedBy == nil, invite.expiresAt > now else {
            attempts[userID, default: []].append(now)
            return (.rejected(.invalid, message: CruceRemote.invalidMessage), nil)
        }
        if invite.createdBy == userID {
            attempts[userID, default: []].append(now)
            return (.rejected(.own, message: "No puedes usar tu propio código"), nil)
        }
        let name = profiles[invite.createdBy]?.displayName ?? ""
        let linked = ledgers.contains { ledger in
            ledger.members.contains { $0.user == userID } && ledger.members.contains { $0.user == invite.createdBy }
        }
        if linked {
            return (.rejected(.alreadyLinked, message: "Ya tienes un cruce con \(name)"), nil)
        }
        return (.valid(inviterName: name), normalized)
    }
}
