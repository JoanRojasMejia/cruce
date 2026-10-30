import Foundation

/// Variante de la ilustración del recibo ("Tike").
/// Quien crea la cuenta compartida ve el rosa; quien se une con código ve el verde.
public enum TikeVariant: String, Codable, Hashable, Sendable {
    case rosa
    case verde
}

/// Color fijo de cada persona: vive en su perfil (`profiles.avatar_color`) y se ve igual en cada cruce y en cada parche.
/// Quien está sin la app tiene el suyo dentro del parche (`parche_participants.avatar_color`).
/// Los `rawValue` son los del enum `person_color` de la base y los nombres de los tokens de `CruceColor`.
public enum AvatarColor: String, Codable, CaseIterable, Hashable, Sendable {
    case yellow
    case violet
    case green
    case peach
    case pink
    case lime

    /// La paleta en orden: amarillo, violeta, verde, durazno, rosado y lima.
    public static let palette: [AvatarColor] = allCases

    /// El color de quien entra a un parche sin la app: el primero de la paleta que nadie del parche usa. Si ya se usaron
    /// los 6, vuelve a empezar según cuántas personas hay (igual que `next_parche_color` en la base).
    public static func nextFree(after used: [AvatarColor]) -> AvatarColor {
        palette.first { !used.contains($0) } ?? palette[used.count % palette.count]
    }
}

/// Una de las dos personas de la cuenta compartida. El color es el de su perfil; el recibo, el de su papel en el cruce.
public struct Member: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var avatarColor: AvatarColor
    public var tikeVariant: TikeVariant

    public init(id: UUID = UUID(), name: String, avatarColor: AvatarColor, tikeVariant: TikeVariant) {
        self.id = id
        self.name = name
        self.avatarColor = avatarColor
        self.tikeVariant = tikeVariant
    }

    /// Dos primeras letras del nombre ("Jo", "Je").
    public var initials: String {
        String(name.trimmingCharacters(in: .whitespaces).prefix(2))
    }
}
