import CruceCore
import SwiftUI

/// Ilustraciones de la app. Los estados "te deben" y "debes" tienen dos versiones:
/// el recibo rosa lo ve quien creó la cuenta (Joan) y el verde lo ve quien se unió (Jesús).
enum Illustration {
    case welcome
    case empty
    case saved
    case theyOweYou(TikeVariant)
    case youOwe(TikeVariant)
    case settle
    case allClear
    case offline

    var assetName: String {
        switch self {
        case .welcome: return "il-01-bienvenida"
        case .empty: return "il-02-sin-movimientos"
        case .saved: return "il-03-gasto-guardado"
        case .theyOweYou(let v): return "il-04-te-deben-\(v.rawValue)"
        case .youOwe(let v): return "il-05-debes-\(v.rawValue)"
        case .settle: return "il-06-saldar"
        case .allClear: return "il-07-paz-y-salvo"
        case .offline: return "il-08-sin-conexion"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .welcome: return "La mascota de Cruce celebra con dos recibos que chocan las manos"
        case .empty: return "La mascota de Cruce se asoma a una caja vacía"
        case .saved: return "La mascota de Cruce levanta el pulgar junto a un recibo aprobado"
        case .theyOweYou: return "Un recibo le entrega una moneda a la mascota de Cruce"
        case .youOwe: return "La mascota de Cruce, preocupada, ve cómo un recibo se lleva una moneda"
        case .settle: return "Dos recibos intercambian un billete"
        case .allClear: return "La mascota de Cruce celebra sobre un letrero de cero pesos"
        case .offline: return "La mascota de Cruce mira un celular sin señal"
        }
    }
}

extension Illustration {
    /// Ilustración del saldo según el estado y la variante del recibo de quien usa la app
    /// (regla rosa o verde, `Member.tikeVariant`). En $0 es "a paz y salvo".
    static func balance(_ state: BalanceState, variant: TikeVariant) -> Illustration {
        switch state {
        case .theyOweYou: return .theyOweYou(variant)
        case .youOwe: return .youOwe(variant)
        case .settled: return .allClear
        }
    }
}

struct IllustrationView: View {
    let illustration: Illustration
    var height: CGFloat
    /// Si se pasa, la ilustración puede encogerse hasta este alto cuando falta espacio,
    /// antes que cortar el texto de la pantalla.
    var minHeight: CGFloat?

    var body: some View {
        Image(illustration.assetName)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity)
            .frame(minHeight: minHeight ?? height, maxHeight: height)
            .layoutPriority(minHeight == nil ? 0 : -1)
            .accessibilityLabel(illustration.accessibilityLabel)
    }
}
