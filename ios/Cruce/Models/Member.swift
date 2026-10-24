import Foundation

/// Variante de la ilustración del recibo ("Tike").
/// Quien crea la cuenta compartida ve el rosa; quien se une con código ve el verde.
enum TikeVariant: String, Codable, Hashable {
    case rosa
    case verde
}

/// Color del avatar de cada persona.
enum AvatarColor: String, Codable, Hashable {
    case yellow
    case violet
}

/// Una de las dos personas de la cuenta compartida.
struct Member: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var avatarColor: AvatarColor
    var tikeVariant: TikeVariant

    /// Dos primeras letras del nombre ("Jo", "Je").
    var initials: String {
        String(name.trimmingCharacters(in: .whitespaces).prefix(2))
    }
}
