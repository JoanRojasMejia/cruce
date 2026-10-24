import SwiftUI

extension Color {
    /// Crea un color a partir de un hex de 24 bits, por ejemplo `0xFFD12E`.
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

/// Paleta de la propuesta A (neobrutalista juguetona).
/// Fuente: "Guía de estilo · Cruce" en el canvas de diseño.
enum CruceColor {
    /// Acción principal, marca, avatar de Joan.
    static let yellow = Color(hex: 0xFFD12E)
    /// Avatar de Jesús, invitación, ocio.
    static let violet = Color(hex: 0x8B6CFF)
    /// Saldo a favor, éxito, mercado.
    static let green = Color(hex: 0x3DCB4A)
    /// Saldo en contra, error, eliminar, comida.
    static let pink = Color(hex: 0xFF5C8A)
    /// Vista previa del saldo, estado "después".
    static let lime = Color(hex: 0xB5E33B)
    /// Transporte, pendientes, avisos suaves.
    static let peach = Color(hex: 0xFFE19A)
    /// Texto, bordes, sombras, selección.
    static let ink = Color(hex: 0x111111)
    /// Fondo de todas las pantallas.
    static let cream = Color(hex: 0xFBF6EA)
    /// Tarjetas, inputs, botones secundarios.
    static let surface = Color.white
    /// Texto secundario.
    static let textSecondary = Color(hex: 0x4A4A4A)
    /// Texto de párrafos.
    static let textBody = Color(hex: 0x3A3A3A)
    /// Separadores dentro de tarjetas.
    static let line = Color(hex: 0xE2DBCB)
    /// Pestaña del saldo en $0, estados inactivos.
    static let neutral = Color(hex: 0xD9D4C7)
    /// Fondo oscurecido detrás de hojas y diálogos.
    static let scrim = Color(hex: 0x111111, opacity: 0.55)
}
