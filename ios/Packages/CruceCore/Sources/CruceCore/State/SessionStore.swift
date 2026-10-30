import Foundation
import Observation

/// Quién usa la app, sus cruces y en qué etapa del flujo de entrada va.
/// La etapa sale de la sesión real con `refresh()`: entrar con el código por correo, crear el perfil, invitar o unirse
/// a un cruce y cerrar sesión.
@MainActor
@Observable
public final class SessionStore {
    /// Etapas del flujo de entrada.
    public enum Phase: Equatable, Sendable {
        case onboarding
        case signUp
        case invite
        case join
        case connected
        case main
    }

    /// Lo que salió mal en el último paso, con su mensaje para la pantalla.
    public enum Problem: Equatable, Sendable {
        case invalidEmail
        case invalidCode
        case invalidName
        case tooManyRequests
        case network
        /// La base rechazó el código `CRZ-`; trae su mensaje en español.
        case inviteRejected(String)

        public var message: String {
            switch self {
            case .invalidEmail: "Ese correo no parece válido. Revísalo, por ejemplo: tu@correo.com."
            case .invalidCode: "El código no es correcto o ya venció. Revísalo o pide otro."
            case .invalidName: "Tu nombre debe tener entre 1 y 40 caracteres."
            case .tooManyRequests: "Pediste muchos códigos seguidos. Espera un momento y vuelve a intentarlo."
            case .network: "No pudimos conectarnos. Revisa tu conexión y vuelve a intentarlo."
            case .inviteRejected(let message): message
            }
        }
    }

    /// Largo máximo del nombre (igual que el `check` de `profiles.display_name`).
    public static let maxNameLength = 40
    /// Dígitos del código que llega por correo (`otp_length` en `supabase/config.toml`).
    public static let codeLength = 6
    /// Dígitos del código para unirse a un cruce (`CRZ-4821`).
    public static let inviteDigits = 4

    public var phase: Phase
    /// Quien usa la app. Su color sale de su perfil; su recibo, del cruce abierto.
    public var me: Member
    /// La otra persona del cruce abierto (ver `open(_:)`). Mientras no haya cruces es un marcador que ninguna pantalla
    /// muestra.
    public var partner: Member
    /// Código `CRZ-` del cruce pendiente, para invitar. `nil` hasta `loadInviteCode()`.
    public var inviteCode: String?
    /// Los cruces completos: primero los abiertos y después los cerrados, cada grupo del más reciente al más viejo.
    public private(set) var cruces: [CruceLink] = []
    /// El cruce con el que se trabaja: el inicio, los movimientos, saldar y Ajustes son de este cruce.
    public private(set) var openCruceID: UUID?
    /// Cruce recién creado estando en el inicio (alguien se unió al código o quien usa la app se unió a otro).
    /// Abre "Conectados"; la vista lo vuelve `nil` al cerrarla.
    public var lastLinked: CruceLink?

    /// El cruce abierto, o `nil` si no hay cruces.
    public var openCruce: CruceLink? {
        cruces.first { $0.id == openCruceID }
    }
    /// El cruce abierto está cerrado (se desvinculó): es de solo lectura.
    public var isOpenCruceClosed: Bool {
        openCruce?.isClosed ?? false
    }
    /// El inicio es "Tus cruces" salvo cuando hay un único cruce y sigue abierto: entonces es ese cruce.
    public var showsCruceList: Bool {
        !(cruces.count == 1 && !cruces[0].isClosed)
    }
    /// De quién es el código que se está escribiendo para unirse (`checkCode`).
    public var invitePreview: InviteCheck?
    /// Código `CRZ-` que llegó por "Tengo un código", para que la pantalla de unirse arranque con él.
    public var pendingJoinCode: String?

    /// El usuario con la sesión abierta, o `nil` si nadie ha entrado.
    public private(set) var userID: UUID?
    /// El correo al que se envió el último código, mientras se espera que lo escriban.
    public private(set) var pendingEmail: String?
    /// El problema del último paso, o `nil` si salió bien.
    public private(set) var error: Problem?
    /// Hay una llamada en curso (para desactivar los botones).
    public private(set) var isWorking = false
    /// Ya se sabe la etapa real. `AppStores.live()` arranca en `false` hasta el primer `refresh()`;
    /// los datos de ejemplo arrancan en `true` y `RootView` no los refresca.
    public private(set) var isReady: Bool

    private let auth: any AuthService
    private let directory: any AccountDirectory
    /// Lo último que supo la sesión, para abrir sin red; `nil` en las vistas previas.
    private let cache: (any SessionCache)?

    public init(
        phase: Phase,
        me: Member,
        partner: Member,
        inviteCode: String? = nil,
        cruces: [CruceLink] = [],
        auth: any AuthService = InMemoryAuthService(),
        directory: any AccountDirectory = InMemoryAccountDirectory(),
        cache: (any SessionCache)? = nil,
        isReady: Bool = true,
        userID: UUID? = nil,
        pendingEmail: String? = nil
    ) {
        self.phase = phase
        self.me = me
        self.partner = partner
        self.inviteCode = inviteCode
        self.auth = auth
        self.directory = directory
        self.cache = cache
        self.isReady = isReady
        self.userID = userID
        self.pendingEmail = pendingEmail
        // Datos de ejemplo: abre el primer cruce (el más reciente) como hace `refresh()`.
        if !cruces.isEmpty { apply(cruces) }
    }

    /// El miembro con ese `id`: quien usa la app o el otro.
    public func member(_ id: UUID) -> Member {
        id == me.id ? me : partner
    }

    /// Calcula la etapa desde la sesión real: sin usuario, onboarding; sin perfil, pedir el nombre;
    /// sin un cruce completo, invitar (un cruce pendiente no cuenta); con cruce, inicio.
    /// Si no se puede leer, conserva la etapa y avisa.
    public func refresh() async {
        defer { isReady = true }
        guard let user = await auth.currentUserID() else {
            userID = nil
            phase = .onboarding
            return
        }
        userID = user
        do {
            guard let profile = try await directory.profile(for: user) else {
                phase = .signUp
                return
            }
            me = Member(
                id: user, name: profile.displayName, avatarColor: profile.avatarColor, tikeVariant: me.tikeVariant)
            apply(try await directory.cruces(for: user))
            phase = cruces.isEmpty ? .invite : .main
            error = nil
            await saveSnapshot()
        } catch {
            self.error = .network
        }
    }

    /// Al arrancar, antes de `refresh()`: si hay lo último guardado (con cruces), abre la app en el inicio con eso,
    /// aunque no haya red. `refresh()` después lo confirma o lo corrige.
    public func restore() async {
        guard let cache, let snapshot = try? await cache.load(), !snapshot.cruces.isEmpty else { return }
        userID = snapshot.userID
        me = snapshot.me
        cruces = snapshot.cruces
        open(snapshot.openCruceID ?? snapshot.cruces[0].id)
        phase = .main
        isReady = true
    }

    /// Guarda lo que se sabe ahora (solo con sesión y cruces).
    private func saveSnapshot() async {
        guard let cache, let user = userID, !cruces.isEmpty else { return }
        try? await cache.save(SessionSnapshot(userID: user, me: me, cruces: cruces, openCruceID: openCruceID))
    }

    /// Pide el código para ese correo. Devuelve `true` si se envió; si no, deja el problema en `error`.
    @discardableResult
    public func sendCode(to email: String) async -> Bool {
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard Self.isValidEmail(normalized) else {
            error = .invalidEmail
            return false
        }
        return await perform {
            try await auth.sendCode(to: normalized)
            pendingEmail = normalized
        }
    }

    /// Vuelve a pedir el código para el correo pendiente.
    @discardableResult
    public func resendCode() async -> Bool {
        guard let pendingEmail else { return false }
        return await sendCode(to: pendingEmail)
    }

    /// Olvida el correo pendiente para escribir otro.
    public func cancelCode() {
        pendingEmail = nil
        error = nil
    }

    /// Verifica el código del correo pendiente y, si es correcto, abre la sesión y pasa a la etapa que corresponde.
    @discardableResult
    public func verify(code: String) async -> Bool {
        let digits = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let email = pendingEmail, digits.count == Self.codeLength, digits.allSatisfy(\.isASCIIDigit) else {
            error = .invalidCode
            return false
        }
        let ok = await perform {
            _ = try await auth.verify(email: email, code: digits)
            pendingEmail = nil
        }
        if ok { await refresh() }
        return ok
    }

    /// Crea el perfil con ese nombre (de 1 a 40 caracteres, sin espacios a los lados) y pasa a la etapa siguiente.
    @discardableResult
    public func createProfile(name: String) async -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let user = userID, (1...Self.maxNameLength).contains(trimmed.count) else {
            error = .invalidName
            return false
        }
        let ok = await perform {
            try await directory.createProfile(Profile(id: user, displayName: trimmed))
        }
        if ok { await refresh() }
        return ok
    }

    // MARK: - Ajustes

    /// Cambia el nombre de quien usa la app (de 1 a 40 caracteres, sin espacios a los lados).
    /// Sin red deja el error y conserva el nombre anterior.
    @discardableResult
    public func updateName(_ name: String) async -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let user = userID, (1...Self.maxNameLength).contains(trimmed.count) else {
            error = .invalidName
            return false
        }
        let ok = await perform {
            try await directory.updateDisplayName(trimmed, for: user)
        }
        if ok {
            me.name = trimmed
            await saveSnapshot()
        }
        return ok
    }

    /// Cambia el color de quien usa la app (Tu perfil). Se ve igual en todos sus cruces y parches.
    /// Sin red deja el error y conserva el color anterior.
    @discardableResult
    public func updateColor(_ color: AvatarColor) async -> Bool {
        guard let user = userID else { return false }
        let ok = await perform {
            try await directory.updateAvatarColor(color, for: user)
        }
        if ok {
            me.avatarColor = color
            await saveSnapshot()
        }
        return ok
    }

    /// Cambia el reparto por defecto del cruce abierto (lo que le toca a quien no pagó, de 0 a 100).
    /// En un cruce cerrado no hace nada; sin red deja el error y conserva el anterior.
    @discardableResult
    public func setDefaultSplit(_ percent: Int) async -> Bool {
        guard let user = userID, let cruce = openCruce, !cruce.isClosed, (0...100).contains(percent) else {
            return false
        }
        let ok = await perform {
            try await directory.setDefaultOtherPercent(percent, in: cruce.id, for: user)
        }
        if ok, let index = cruces.firstIndex(where: { $0.id == cruce.id }) {
            cruces[index].defaultOtherPercent = percent
            await saveSnapshot()
        }
        return ok
    }

    /// Desvincula: cierra el cruce abierto para los dos y vuelve a cargar los cruces (el cerrado pasa al final).
    /// El cruce sigue abierto en la app para ver su historial. Sin red deja el error y no cambia nada.
    /// La navegación la limpia quien llama (`Router.popToRoot()`).
    @discardableResult
    public func closeOpenCruce() async -> Bool {
        guard let user = userID, let cruce = openCruce, !cruce.isClosed else { return false }
        var closedAt: Date?
        let ok = await perform {
            closedAt = try await directory.closeCruce(cruce.id, for: user)
        }
        guard ok else { return false }
        if let links = try? await directory.cruces(for: user) {
            apply(links)
        } else if let index = cruces.firstIndex(where: { $0.id == cruce.id }) {
            // Se cerró pero no se pudo recargar: se marca aquí y se ordena como lo haría la base.
            cruces[index].closedAt = closedAt
            cruces.sort { !$0.isClosed && $1.isClosed }
        }
        await saveSnapshot()
        return true
    }

    // MARK: - Vincular

    /// Trae el código del cruce pendiente (lo crea si no hay). Pedirlo otra vez devuelve el mismo.
    public func loadInviteCode() async {
        guard let user = userID else { return }
        await perform {
            inviteCode = try await directory.inviteCode(for: user)
        }
    }

    /// Dice de quién es el código (4 dígitos, o completo con `CRZ-`) sin unirse. Con menos dígitos no consulta.
    public func checkCode(_ code: String) async {
        invitePreview = nil
        guard let user = userID, let full = Self.inviteCode(from: code) else { return }
        await perform {
            invitePreview = try await directory.previewInvite(full, for: user)
        }
    }

    /// Se une al cruce de ese código. Si sale bien, carga los cruces y pasa a "Conectados";
    /// si no, deja el mensaje de la base en `error` y sigue en la misma etapa.
    @discardableResult
    public func join(code: String) async -> Bool {
        guard let user = userID, let full = Self.inviteCode(from: code) else {
            error = .inviteRejected(CruceRemote.invalidMessage)
            return false
        }
        var joined = false
        await perform {
            switch try await directory.redeemInvite(full, for: user) {
            case .valid:
                let known = Set(cruces.map(\.id))
                let links = try await directory.cruces(for: user)
                apply(links)
                pendingJoinCode = nil
                invitePreview = nil
                // Se abre el cruce nuevo. Sin cruces (etapa de unirse) se pasa a "Conectados"; con cruces se queda en
                // el inicio y `lastLinked` muestra "Conectados" encima.
                if let new = links.first(where: { !known.contains($0.id) }) {
                    open(new.id)
                    if phase == .main { lastLinked = new }
                }
                if phase != .main { phase = .connected }
                joined = true
            case .rejected(_, let message):
                error = .inviteRejected(message)
            }
        }
        return joined
    }

    /// Mientras se espera en la pantalla de invitar, revisa si la otra persona ya se unió y, si sí, abre ese cruce:
    /// sin cruces pasa a "Conectados"; desde el inicio deja `lastLinked`. Si falla la red no hace nada: se vuelve a
    /// revisar en unos segundos.
    public func checkForPartner() async {
        guard phase == .invite || phase == .main, let user = userID else { return }
        let known = Set(cruces.map(\.id))
        guard let links = try? await directory.cruces(for: user),
            let new = links.first(where: { !known.contains($0.id) })
        else { return }
        apply(links)
        open(new.id)
        if phase == .invite {
            phase = .connected
        } else {
            lastLinked = new
        }
    }

    /// Abre ese cruce: `partner` pasa a ser su otra persona y el recibo de `me` es el de ese cruce. El color de `me` no
    /// cambia: es el de su perfil.
    public func open(_ id: UUID) {
        guard let cruce = cruces.first(where: { $0.id == id }) else { return }
        openCruceID = id
        me.tikeVariant = cruce.myTikeVariant
        partner = cruce.partner
    }

    /// `CRZ-` y 4 dígitos a partir de lo que se escribió, o `nil` si no son 4 dígitos.
    public static func inviteCode(from text: String) -> String? {
        var digits = text.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if digits.hasPrefix("CRZ-") { digits.removeFirst(4) }
        guard digits.count == inviteDigits, digits.allSatisfy(\.isASCIIDigit) else { return nil }
        return "CRZ-" + digits
    }

    /// Guarda los cruces y deja abierto el mismo cruce si sigue existiendo; si no, el más reciente.
    /// Sin cruces, `me` queda con el recibo rosa: quien no tiene cruce es quien va a crear el suyo al invitar.
    private func apply(_ links: [CruceLink]) {
        cruces = links
        if let current = openCruceID, links.contains(where: { $0.id == current }) {
            open(current)
        } else if let latest = links.first {
            open(latest.id)
        } else {
            openCruceID = nil
            me.tikeVariant = .rosa
        }
    }

    /// Cierra la sesión y vuelve al onboarding, aunque falle la red (la sesión guardada se borra igual).
    /// La navegación la limpia quien llama (`Router.popToRoot()`).
    public func signOut() async {
        try? await auth.signOut()
        try? await cache?.save(nil)
        userID = nil
        pendingEmail = nil
        error = nil
        // Quien entre después no hereda el nombre ni los colores de esta persona.
        me = Member(name: "Tú", avatarColor: .yellow, tikeVariant: .rosa)
        cruces = []
        openCruceID = nil
        lastLinked = nil
        inviteCode = nil
        invitePreview = nil
        pendingJoinCode = nil
        phase = .onboarding
    }

    /// Validación sencilla: una sola `@`, algo antes, y un dominio con punto, sin espacios.
    public static func isValidEmail(_ email: String) -> Bool {
        let parts = email.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, !email.contains(where: \.isWhitespace) else { return false }
        let domain = parts[1].split(separator: ".", omittingEmptySubsequences: false)
        return domain.count >= 2 && domain.allSatisfy { !$0.isEmpty }
    }

    /// Corre una llamada con `isWorking` y traduce su error a un `Problem`.
    @discardableResult
    private func perform(_ work: () async throws -> Void) async -> Bool {
        isWorking = true
        error = nil
        defer { isWorking = false }
        do {
            try await work()
            return true
        } catch AuthServiceError.invalidCode {
            error = .invalidCode
        } catch AuthServiceError.rateLimited {
            error = .tooManyRequests
        } catch {
            self.error = .network
        }
        return false
    }
}

extension Character {
    fileprivate var isASCIIDigit: Bool { ("0"..."9").contains(self) }
}
