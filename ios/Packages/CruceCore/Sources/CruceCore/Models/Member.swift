import Foundation

/// Variante de la ilustración del recibo ("Tike").
/// Quien crea la cuenta compartida ve el rosa; quien se une con código ve el verde.
public enum TikeVariant: String, Codable, Hashable, Sendable {
    case rosa
    case verde
}

/// Color del avatar de cada persona.
public enum AvatarColor: String, Codable, Hashable, Sendable {
    case yellow
    case violet
}

/// Una de las dos personas de la cuenta compartida.
public struct Member: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var avatarColor: AvatarColor
    public var tikeVariant: TikeVariant

    /// Dos primeras letras del nombre ("Jo", "Je").
    public var initials: String {
        String(name.trimmingCharacters(in: .whitespaces).prefix(2))
    }
}
