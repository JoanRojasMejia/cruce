import Foundation

/// Lo que se escribe en "Tengo un código": de qué tipo es (por el prefijo, mientras se escribe) y si ya está completo.
/// Los formatos no cambian (D2): `CRZ-` y 4 dígitos; `PCH-` y `SOY-` con 6 caracteres de `ParcheCode.alphabet`.
public enum EnteredCode {
    /// En qué va lo que se escribió.
    public enum Shape: Equatable, Sendable {
        /// Todavía le falta; el tipo, si ya se sabe por el prefijo.
        case incomplete(ParcheCode.Kind?)
        /// Completo y bien formado, en su forma normal (`CRZ-4821`).
        case complete(ParcheCode.Kind, code: String)
        /// No empieza como ninguno de los códigos de Cruce.
        case unknownPrefix
        /// El prefijo se reconoce, pero lo demás no puede ser un código (letras en un `CRZ-`, caracteres de más…).
        case malformed(ParcheCode.Kind)
    }

    /// Dígitos de un código `CRZ-` (igual que `SessionStore.inviteDigits`).
    public static let cruceDigits = 4
    private static let kinds: [ParcheCode.Kind] = [.cruce, .parche, .place]
    private static let dashes: Set<Character> = ["-", "‐", "‑", "–", "—", "−"]

    /// Cuántos caracteres van después del prefijo.
    public static func bodyLength(of kind: ParcheCode.Kind) -> Int {
        kind == .cruce ? cruceDigits : ParcheCode.length
    }

    /// Mayúsculas, sin espacios y con el guion del prefijo aunque no lo escriban ("crz 4821" → "CRZ-4821",
    /// "pchabc234" → "PCH-ABC234"). Cuatro dígitos solos son un código de cruce ("4821" → "CRZ-4821").
    public static func normalize(_ text: String) -> String {
        let compact = String(text.uppercased().filter { !$0.isWhitespace && !dashes.contains($0) })
        if !compact.isEmpty, compact.count <= cruceDigits, compact.allSatisfy(\.isASCIIDigitCharacter) {
            return compact.count == cruceDigits ? ParcheCode.Kind.cruce.rawValue + compact : compact
        }
        for kind in kinds {
            let letters = String(kind.rawValue.dropLast())
            if compact.hasPrefix(letters) && compact.count > letters.count {
                return kind.rawValue + compact.dropFirst(letters.count)
            }
        }
        return compact
    }

    /// El tipo según el prefijo, o `nil` si todavía no se sabe o no es ninguno. Los dígitos solos son de un cruce.
    public static func kind(of text: String) -> ParcheCode.Kind? {
        switch shape(of: text) {
        case .incomplete(let kind): kind
        case .complete(let kind, _), .malformed(let kind): kind
        case .unknownPrefix: nil
        }
    }

    public static func shape(of text: String) -> Shape {
        let normalized = normalize(text)
        if normalized.isEmpty { return .incomplete(nil) }
        if normalized.allSatisfy(\.isASCIIDigitCharacter) {
            return normalized.count < cruceDigits ? .incomplete(.cruce) : .malformed(.cruce)
        }
        guard let kind = kinds.first(where: { normalized.hasPrefix($0.rawValue) }) else {
            // "C", "CR", "P", "SO"…: puede ser el comienzo de un prefijo; con sus tres letras ya se sabe cuál es.
            guard let started = kinds.first(where: { $0.rawValue.dropLast().hasPrefix(normalized) }) else {
                return .unknownPrefix
            }
            return .incomplete(normalized.count == started.rawValue.count - 1 ? started : nil)
        }
        let body = normalized.dropFirst(kind.rawValue.count)
        let allowed: (Character) -> Bool =
            kind == .cruce ? { $0.isASCIIDigitCharacter } : { ParcheCode.alphabet.contains($0) }
        guard body.allSatisfy(allowed), body.count <= bodyLength(of: kind) else { return .malformed(kind) }
        return body.count == bodyLength(of: kind) ? .complete(kind, code: normalized) : .incomplete(kind)
    }
}

/// Por qué un código no sirve. Es el campo `error` de `preview_invite`, `redeem_invite` y `preview_parche_code`.
public enum CodeRejection: String, Equatable, Sendable {
    /// No existe (o no es un código de Cruce).
    case invalid
    /// Venció (los `CRZ-` duran 24 horas).
    case expired
    /// Ya se usó: alguien se unió con ese `CRZ-` o se quedó con ese lugar `SOY-`.
    case used
    /// Es de quien lo usa: su propio `CRZ-`, o un lugar `SOY-` que ya es suyo.
    case own
    /// 5 intentos fallidos en la última hora (`CRZ-`, `PCH-` y `SOY-` cuentan juntos).
    case tooManyAttempts = "too_many_attempts"
    /// Ya hay un cruce con quien invitó (un cruce por pareja).
    case alreadyLinked = "already_linked"
    /// Ya está en ese parche, con otro lugar: no se queda con uno más.
    case alreadyParticipant = "already_participant"

    /// El título del aviso en "Tengo un código"; el detalle es el mensaje de la base.
    public var title: String {
        switch self {
        case .invalid: "Ese código no existe"
        case .expired: "Ese código venció"
        case .used: "Ese código ya se usó"
        case .own: "Ese código es tuyo"
        case .tooManyAttempts: "Demasiados intentos"
        case .alreadyLinked: "Ya tienen un cruce"
        case .alreadyParticipant: "Ya estás en ese parche"
        }
    }

    /// El mensaje de la base para cada error (igual que `code_error` en `20261029140000_codigos.sql`). Lo usan los
    /// dobles en memoria y es el respaldo si la base no manda uno.
    public var defaultMessage: String {
        switch self {
        case .invalid: "Ese código no existe. Revisa que esté bien escrito."
        case .expired: "Ese código ya venció. Pídele uno nuevo a quien te lo mandó."
        case .used: "Ese código ya se usó. Pídele uno nuevo a quien te lo mandó."
        case .own: "Ese código es tuyo. Mándaselo a la otra persona para que lo use."
        case .tooManyAttempts: "Hiciste demasiados intentos. Espera una hora e intenta de nuevo."
        case .alreadyLinked: "Ya tienes un cruce con esa persona"
        case .alreadyParticipant: "Ya estás en ese parche, así que no puedes quedarte con ese lugar."
        }
    }

    /// Si conviene recordar cómo empiezan los códigos: solo cuando el problema es lo que se escribió.
    public var showsPrefixes: Bool { self == .invalid }
}

/// Lo que se sabe de un código completo antes de usarlo: a dónde lleva o por qué no sirve.
public enum CodePreview: Equatable, Sendable {
    /// `CRZ-`: el cruce de esa persona ("Cuenta de Joan").
    case cruce(inviterName: String)
    /// `PCH-`: ese parche; `alreadyMember` si quien lo usa ya está.
    case parche(name: String, alreadyMember: Bool)
    /// `SOY-`: el lugar de esa persona en ese parche.
    case place(parcheName: String, personName: String)
    case rejected(CodeRejection, message: String)

    /// La vista previa de un `CRZ-` (`preview_invite`).
    public init(_ check: InviteCheck) {
        switch check {
        case .valid(let name): self = .cruce(inviterName: name)
        case .rejected(let rejection, let message): self = .rejected(rejection, message: message)
        }
    }

    public var rejection: CodeRejection? {
        if case .rejected(let rejection, _) = self { return rejection }
        return nil
    }
}

/// El enlace que abre "Tengo un código" con el campo lleno: `cruce://codigo/<CÓDIGO>` (D5; el enlace universal queda
/// para el CP13).
public enum CodeLink {
    public static let scheme = "cruce"
    public static let host = "codigo"

    /// El código del enlace, en su forma normal; `nil` si no es un enlace de código. No revisa que el código exista:
    /// eso lo dice la pantalla.
    public static func code(from url: URL) -> String? {
        guard url.scheme?.lowercased() == scheme,
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            components.host?.lowercased() == host
        else { return nil }
        let raw = components.path.split(separator: "/").first.map(String.init) ?? ""
        let code = EnteredCode.normalize(raw.removingPercentEncoding ?? raw)
        guard !code.isEmpty, code.count <= 12 else { return nil }
        return code
    }

    /// El enlace de un código, para compartirlo.
    public static func url(for code: String) -> URL? {
        URL(string: "\(scheme)://\(host)/\(EnteredCode.normalize(code))")
    }
}

extension Character {
    fileprivate var isASCIIDigitCharacter: Bool { ("0"..."9").contains(self) }
}
