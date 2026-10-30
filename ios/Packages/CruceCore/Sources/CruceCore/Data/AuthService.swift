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
    /// Su color fijo (`profiles.avatar_color`). Al crear el perfil lo elige la base, al azar.
    public var avatarColor: AvatarColor

    public init(id: UUID, displayName: String, avatarColor: AvatarColor = .yellow) {
        self.id = id
        self.displayName = displayName
        self.avatarColor = avatarColor
    }
}

/// Lo que la sesión necesita saber de la cuenta para decidir la etapa de entrada.
/// Va aparte de `AuthService` para no mezclar la autenticación con los datos.
public protocol AccountDirectory: Sendable {
    /// El perfil de ese usuario, o `nil` si todavía no lo creó.
    func profile(for userID: UUID) async throws -> Profile?
    /// Crea el perfil con `id` igual al del usuario. El color no se manda: la base elige uno de la paleta al azar.
    func createProfile(_ profile: Profile) async throws
    /// Cambia el nombre del usuario (`profiles.display_name`). El nombre ya viene validado (1 a 40 caracteres).
    func updateDisplayName(_ name: String, for userID: UUID) async throws
    /// Cambia el color del usuario (`profiles.avatar_color`). La base lo copia a sus lugares en los parches.
    func updateAvatarColor(_ color: AvatarColor, for userID: UUID) async throws
    /// Los cruces completos (de dos personas) del usuario (`my_cruces()`): primero los abiertos y después los cerrados,
    /// cada grupo del más reciente al más viejo. Un cruce pendiente, donde nadie se ha unido, no aparece.
    func cruces(for userID: UUID) async throws -> [CruceLink]
    /// El código `CRZ-` del único cruce pendiente del usuario; lo crea si no hay (`create_ledger_with_invite()`).
    func inviteCode(for userID: UUID) async throws -> String
    /// De quién es un código, sin unirse (`preview_invite`). Los inválidos cuentan para el límite de intentos.
    func previewInvite(_ code: String, for userID: UUID) async throws -> InviteCheck
    /// Canjea un código: el usuario queda como segunda persona de ese cruce (`redeem_invite`).
    func redeemInvite(_ code: String, for userID: UUID) async throws -> InviteCheck
    /// Cambia el reparto por defecto de un cruce (`ledgers.default_other_percent`, de 0 a 100).
    func setDefaultOtherPercent(_ percent: Int, in cruceID: UUID, for userID: UUID) async throws
    /// Cierra un cruce para las dos personas (`close_cruce`) y devuelve cuándo quedó cerrado. Si ya estaba cerrado,
    /// devuelve la fecha de antes.
    func closeCruce(_ cruceID: UUID, for userID: UUID) async throws -> Date
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
    /// El recibo es por cruce; el color no: sale del perfil.
    private struct Membership {
        let user: UUID
        let tikeVariant: TikeVariant
        let joinedAt: Date
    }

    private struct Ledger {
        let id: UUID
        let createdBy: UUID
        var members: [Membership]
        var closedAt: Date?
        var defaultOtherPercent = CruceLink.standardOtherPercent
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

    /// Lo que la base rechaza: cerrar un cruce que no es de quien llama.
    public struct NotFound: Error {}

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
                    members: [Membership(user: creator, tikeVariant: .rosa, joinedAt: now)]))
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

    /// Crea un cruce completo entre dos personas: `creator` queda con el recibo rosa y `joiner` con el verde.
    /// Cada llamada es un segundo más tarde, así el último cruce creado es el más reciente.
    public func link(_ creator: UUID, _ joiner: UUID) {
        now += 1
        ledgers.append(
            Ledger(
                id: UUID(), createdBy: creator,
                members: [
                    Membership(user: creator, tikeVariant: .rosa, joinedAt: now),
                    Membership(user: joiner, tikeVariant: .verde, joinedAt: now),
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

    /// Como la base: el color del perfil nuevo es uno de la paleta, al azar (el del perfil que llega no se usa).
    public func createProfile(_ profile: Profile) async throws {
        if isFailing { throw Offline() }
        var created = profile
        created.avatarColor = AvatarColor.palette.randomElement() ?? .yellow
        profiles[profile.id] = created
    }

    public func updateDisplayName(_ name: String, for userID: UUID) async throws {
        if isFailing { throw Offline() }
        guard profiles[userID] != nil else { throw NotFound() }
        profiles[userID]?.displayName = name
    }

    public func updateAvatarColor(_ color: AvatarColor, for userID: UUID) async throws {
        if isFailing { throw Offline() }
        guard profiles[userID] != nil else { throw NotFound() }
        profiles[userID]?.avatarColor = color
    }

    public func setDefaultOtherPercent(_ percent: Int, in cruceID: UUID, for userID: UUID) async throws {
        if isFailing { throw Offline() }
        guard let index = ledgers.firstIndex(where: { $0.id == cruceID && $0.members.contains { $0.user == userID } })
        else { throw NotFound() }
        ledgers[index].defaultOtherPercent = percent
    }

    public func closeCruce(_ cruceID: UUID, for userID: UUID) async throws -> Date {
        if isFailing { throw Offline() }
        guard
            let index = ledgers.firstIndex(where: {
                $0.id == cruceID && $0.members.count == 2 && $0.members.contains { $0.user == userID }
            })
        else { throw NotFound() }
        if let closed = ledgers[index].closedAt { return closed }
        ledgers[index].closedAt = now
        return now
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
                    id: other.user, name: profiles[other.user]?.displayName ?? "",
                    avatarColor: profiles[other.user]?.avatarColor ?? .yellow, tikeVariant: other.tikeVariant)
                return CruceLink(
                    id: ledger.id, partner: partner, myTikeVariant: mine.tikeVariant,
                    linkedAt: max(mine.joinedAt, other.joinedAt), closedAt: ledger.closedAt,
                    defaultOtherPercent: ledger.defaultOtherPercent)
            }
            .sorted { ($0.isClosed ? 1 : 0, $1.linkedAt) < ($1.isClosed ? 1 : 0, $0.linkedAt) }
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
                    members: [Membership(user: userID, tikeVariant: .rosa, joinedAt: now)]))
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
            Membership(user: userID, tikeVariant: .verde, joinedAt: now))
        invite.redeemedBy = userID
        invites[normalized] = invite
        return result
    }

    /// Las mismas reglas que `check_invite` en la base, en el mismo orden.
    private func check(_ code: String, for userID: UUID) -> (result: InviteCheck, code: String?) {
        let recent = attempts[userID, default: []].filter { $0 > now - 60 * 60 }
        if recent.count >= 5 {
            return (
                .rejected(.tooManyAttempts, message: CodeRejection.tooManyAttempts.defaultMessage), nil
            )
        }
        let normalized = code.trimmingCharacters(in: .whitespaces).uppercased()
        func reject(_ rejection: CodeRejection) -> (result: InviteCheck, code: String?) {
            attempts[userID, default: []].append(now)
            return (.rejected(rejection, message: rejection.defaultMessage), nil)
        }
        // Primero si no existe, después si es tuyo (aunque haya vencido o se haya usado), si ya se usó o si venció.
        guard let invite = invites[normalized] else { return reject(.invalid) }
        if invite.createdBy == userID { return reject(.own) }
        if invite.redeemedBy != nil { return reject(.used) }
        if invite.expiresAt <= now { return reject(.expired) }
        let name = profiles[invite.createdBy]?.displayName ?? ""
        let linked = ledgers.contains { ledger in
            ledger.closedAt == nil && ledger.members.contains { $0.user == userID }
                && ledger.members.contains { $0.user == invite.createdBy }
        }
        if linked {
            return (.rejected(.alreadyLinked, message: "Ya tienes un cruce con \(name)"), nil)
        }
        return (.valid(inviterName: name), normalized)
    }
}
