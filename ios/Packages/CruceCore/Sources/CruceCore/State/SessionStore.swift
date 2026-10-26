import Foundation
import Observation

/// Quién usa la app, con quién comparte la cuenta y en qué etapa del flujo de entrada va.
/// La etapa sale de la sesión real con `refresh()`: entrar con el código por correo, crear el perfil y cerrar sesión.
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

        public var message: String {
            switch self {
            case .invalidEmail: "Ese correo no parece válido. Revísalo, por ejemplo: tu@correo.com."
            case .invalidCode: "El código no es correcto o ya venció. Revísalo o pide otro."
            case .invalidName: "Tu nombre debe tener entre 1 y 40 caracteres."
            case .tooManyRequests: "Pediste muchos códigos seguidos. Espera un momento y vuelve a intentarlo."
            case .network: "No pudimos conectarnos. Revisa tu conexión y vuelve a intentarlo."
            }
        }
    }

    /// Largo máximo del nombre (igual que el `check` de `profiles.display_name`).
    public static let maxNameLength = 40
    /// Dígitos del código que llega por correo (`otp_length` en `supabase/config.toml`).
    public static let codeLength = 6

    public var phase: Phase
    public var me: Member
    public var partner: Member
    /// Código para invitar al otro. `nil` mientras no exista (lo trae el CP4).
    public var inviteCode: String?

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

    public init(
        phase: Phase,
        me: Member,
        partner: Member,
        inviteCode: String? = nil,
        auth: any AuthService = InMemoryAuthService(),
        directory: any AccountDirectory = InMemoryAccountDirectory(),
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
        self.isReady = isReady
        self.userID = userID
        self.pendingEmail = pendingEmail
    }

    /// El miembro con ese `id`: quien usa la app o el otro.
    public func member(_ id: UUID) -> Member {
        id == me.id ? me : partner
    }

    /// Calcula la etapa desde la sesión real: sin usuario, onboarding; sin perfil, pedir el nombre;
    /// sin cuenta compartida, invitar; con cuenta, inicio. Si no se puede leer, conserva la etapa y avisa.
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
            me = Member(id: user, name: profile.displayName, avatarColor: me.avatarColor, tikeVariant: me.tikeVariant)
            phase = try await directory.hasLedger(user) ? .main : .invite
        } catch {
            self.error = .network
        }
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

    /// Cierra la sesión y vuelve al onboarding, aunque falle la red (la sesión guardada se borra igual).
    /// La navegación la limpia quien llama (`Router.popToRoot()`).
    public func signOut() async {
        try? await auth.signOut()
        userID = nil
        pendingEmail = nil
        error = nil
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
