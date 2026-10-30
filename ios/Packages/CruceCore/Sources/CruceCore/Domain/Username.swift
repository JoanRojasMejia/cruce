import Foundation

/// El @usuario de cada persona (`profiles.username`): de 3 a 20 caracteres (minúsculas, números, punto y guion bajo),
/// único sin importar mayúsculas. Las reglas son las de la base (`20261030100000_usuarios.sql`); la app las repite para
/// revisar el formato sin preguntarle a la base y para el doble en memoria. La app identifica a las personas por `id`,
/// nunca por el @usuario.
public enum Username {
    public static let minLength = 3
    public static let maxLength = 20
    private static let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789._")
    private static let accents: [Character: Character] = [
        "á": "a", "à": "a", "ä": "a", "â": "a", "ã": "a", "å": "a", "é": "e", "è": "e", "ë": "e", "ê": "e",
        "í": "i", "ì": "i", "ï": "i", "î": "i", "ó": "o", "ò": "o", "ö": "o", "ô": "o", "õ": "o", "ú": "u",
        "ù": "u", "ü": "u", "û": "u", "ñ": "n", "ç": "c",
    ]

    /// Lo escrito en la forma en que se guarda: sin espacios a los lados, sin la `@` inicial y en minúsculas
    /// (igual que `normalize_username`).
    public static func normalize(_ text: String) -> String {
        var trimmed = Substring(text.trimmingCharacters(in: .whitespacesAndNewlines))
        if trimmed.first == "@" { trimmed = trimmed.dropFirst() }
        return trimmed.lowercased()
    }

    /// Cumple el formato después de normalizarlo.
    public static func isValid(_ text: String) -> Bool {
        let username = normalize(text)
        return (minLength...maxLength).contains(username.count) && username.allSatisfy(allowed.contains)
    }

    /// "@joan".
    public static func display(_ username: String) -> String {
        "@" + username
    }

    /// La sugerencia para un nombre, igual que `username_suggestion` en la base: minúsculas sin tildes, espacios y
    /// guiones a punto, sin otros caracteres, sin puntos repetidos ni en los extremos y de máximo 20. Un nombre de 1 o 2
    /// caracteres se completa con ".cruce"; uno sin letras ni números queda "usuario". Si está ocupada, agrega 2, 3…
    /// recortando la base.
    public static func suggestion(from name: String, isTaken: (String) -> Bool = { _ in false }) -> String {
        let lowered = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var base = ""
        var lastWasSeparator = false
        for character in lowered {
            let plain = accents[character] ?? character
            if plain.isWhitespace || plain == "-" {
                if !lastWasSeparator { base.append(".") }
                lastWasSeparator = true
            } else if allowed.contains(plain) {
                // Varios puntos seguidos quedan en uno (como `\.{2,}` en la base).
                if plain == "." && base.last == "." { continue }
                base.append(plain)
                lastWasSeparator = plain == "."
            }
        }
        base = String(base.trimmingCharacters(in: CharacterSet(charactersIn: "._")))
        if base.isEmpty {
            base = "usuario"
        } else if base.count < minLength {
            base += ".cruce"
        }
        base = trimmedEnd(String(base.prefix(maxLength)))
        var candidate = base
        var number = 1
        while isTaken(candidate) {
            number += 1
            let suffix = String(number)
            candidate = trimmedEnd(String(base.prefix(maxLength - suffix.count))) + suffix
        }
        return candidate
    }

    /// Sin puntos ni guiones bajos al final (después de recortar).
    private static func trimmedEnd(_ text: String) -> String {
        var text = text
        while let last = text.last, last == "." || last == "_" { text.removeLast() }
        return text
    }
}

/// Por qué un @usuario no sirve. Es el campo `error` de `check_username` y `set_username`.
public enum UsernameRejection: String, Equatable, Sendable {
    /// No cumple el formato.
    case format
    /// Es de otra persona.
    case taken

    /// El mensaje de la base (igual que `username_error`). Lo usan el doble en memoria y la revisión del formato.
    public var defaultMessage: String {
        switch self {
        case .format: "Tu @usuario debe tener de 3 a 20 caracteres: minúsculas, números, punto o guion bajo."
        case .taken: "Ese @usuario ya está ocupado. Prueba con otro."
        }
    }
}

/// Resultado de revisar o guardar un @usuario: disponible (normalizado) o por qué no sirve, con el mensaje de la base.
public enum UsernameCheck: Equatable, Sendable {
    case available(String)
    case rejected(UsernameRejection, message: String)

    /// El rechazo de formato, sin preguntarle a la base.
    public static let invalidFormat = UsernameCheck.rejected(.format, message: UsernameRejection.format.defaultMessage)
}
