import SwiftUI

/// Pesos de Archivo incluidos en `Resources/Fonts` (nombres PostScript).
enum ArchivoWeight: String {
    case medium = "Archivo-Medium"       // 500
    case semibold = "Archivo-SemiBold"   // 600
    case bold = "Archivo-Bold"           // 700
    case extraBold = "Archivo-ExtraBold" // 800
    case black = "Archivo-Black"         // 900
}

extension Font {
    static func archivo(_ size: CGFloat, _ weight: ArchivoWeight, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(weight.rawValue, size: size, relativeTo: style)
    }
}

/// Escala tipográfica de la guía de estilo.
enum TextStyleToken {
    /// $20.000 en la tarjeta del saldo · 60 / 900 / −2,5
    case amount
    /// Montos medianos (detalle, recibos) · 52 / 900 / −2
    case amountMedium
    /// Títulos grandes de pantallas de estado · 40 / 900 / −1,6
    case title1
    /// Títulos de formularios y onboarding · 36 / 900 / −1,4
    case title1Compact
    /// Encabezado de pantalla · 24 / 900 / −0,6
    case title2
    /// "Jesús te debe" · 22 / 800 / −0,4
    case balancePhrase
    /// Encabezados de sección · 18 / 800
    case sectionTitle
    /// Texto de botones principales · 17 / 900
    case button
    /// Botones secundarios · 16 / 800
    case buttonSecondary
    /// Título de una fila de movimiento · 15 / 800
    case rowTitle
    /// Párrafos · 15 / 600
    case body
    /// Párrafos de onboarding · 16 / 600
    case bodyLarge
    /// Etiquetas de campos · 13 / 800
    case fieldLabel
    /// Texto secundario · 12 / 600
    case secondary
    /// Etiquetas en mayúsculas ("SALDO NETO") · 11 / 800 / +1,2
    case label

    var font: Font {
        switch self {
        case .amount: return .archivo(60, .black, relativeTo: .largeTitle)
        case .amountMedium: return .archivo(52, .black, relativeTo: .largeTitle)
        case .title1: return .archivo(40, .black, relativeTo: .largeTitle)
        case .title1Compact: return .archivo(36, .black, relativeTo: .largeTitle)
        case .title2: return .archivo(24, .black, relativeTo: .title)
        case .balancePhrase: return .archivo(22, .extraBold, relativeTo: .title2)
        case .sectionTitle: return .archivo(18, .extraBold, relativeTo: .headline)
        case .button: return .archivo(17, .black, relativeTo: .headline)
        case .buttonSecondary: return .archivo(16, .extraBold, relativeTo: .headline)
        case .rowTitle: return .archivo(15, .extraBold, relativeTo: .subheadline)
        case .body: return .archivo(15, .semibold, relativeTo: .body)
        case .bodyLarge: return .archivo(16, .semibold, relativeTo: .body)
        case .fieldLabel: return .archivo(13, .extraBold, relativeTo: .footnote)
        case .secondary: return .archivo(12, .semibold, relativeTo: .caption)
        case .label: return .archivo(11, .extraBold, relativeTo: .caption2)
        }
    }

    var tracking: CGFloat {
        switch self {
        case .amount: return -2.5
        case .amountMedium: return -2
        case .title1: return -1.6
        case .title1Compact: return -1.4
        case .title2: return -0.6
        case .balancePhrase: return -0.4
        case .label: return 1.2
        default: return 0
        }
    }
}

extension View {
    /// Aplica fuente y tracking de un estilo de la guía.
    func textStyle(_ style: TextStyleToken) -> some View {
        font(style.font).tracking(style.tracking)
    }
}
