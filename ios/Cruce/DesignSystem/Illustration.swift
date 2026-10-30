import CruceCore
import SwiftUI

/// Ilustraciones de la app. Los estados "te deben" y "debes" del cruce tienen dos versiones:
/// el recibo rosa lo ve quien creó la cuenta (Joan) y el verde lo ve quien se unió (Jesús).
/// Los parches y los tickets usan ilustraciones neutrales (sin rosa ni verde).
///
/// Todas tienen su imagen en el catálogo. Si alguna llegara a faltar, se dibuja `fallback`
/// (la que esa pantalla usaba antes) o nada.
enum Illustration: Equatable {
    case welcome
    case empty
    case saved
    case theyOweYou(TikeVariant)
    case youOwe(TikeVariant)
    case settle
    case allClear
    case offline
    /// Escribe el código del correo.
    case checkEmail
    case newParche
    case parchesEmpty
    /// Llegada con un código `PCH-`.
    case parcheArrival
    /// Llegada con un código `SOY-`; la mini va en el bloque del código del ticket.
    case placeClaimed
    case placeClaimedMini
    case closeParche
    /// Esquina del ticket pendiente (individual y de grupo).
    case ticketPending
    case cruceTransfer
    case cruceClosed
    /// Tarjeta del saldo del parche cuando todos quedan en $0.
    case parcheSettled
    case groupTheyOweYou
    case groupYouOwe
    case paymentPending
    case invalidCode

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
        case .checkEmail: return "il-09-revisa-correo"
        case .newParche: return "il-10-nuevo-parche"
        case .parchesEmpty: return "il-11-parches-vacio"
        case .parcheArrival: return "il-12-llegaste-parche"
        case .placeClaimed: return "il-13-lugar-tuyo"
        case .placeClaimedMini: return "il-13-lugar-tuyo-mini"
        case .closeParche: return "il-14-cerrar-parche"
        case .ticketPending: return "il-15-ticket-pendiente"
        case .cruceTransfer: return "il-16-pasar-cruce"
        case .cruceClosed: return "il-17-cruce-cerrado"
        case .parcheSettled: return "il-18-parche-saldado"
        case .groupTheyOweYou: return "il-19a-grupo-te-deben"
        case .groupYouOwe: return "il-19b-grupo-debes"
        case .paymentPending: return "il-20-pago-por-confirmar"
        case .invalidCode: return "il-21-codigo-invalido"
        }
    }

    /// La ilustración que esa pantalla usaba antes de tener la suya; `nil` si no tenía ninguna.
    /// La tarjeta del saldo del parche y la del cruce cerrado pasan la suya a `IllustrationView`,
    /// porque depende del recibo de quien usa la app.
    var fallback: Illustration? {
        switch self {
        case .newParche, .parcheArrival, .placeClaimed: return .welcome
        case .parchesEmpty: return .empty
        case .closeParche, .ticketPending: return .settle
        case .parcheSettled: return .allClear
        case .checkEmail, .placeClaimedMini, .cruceTransfer, .cruceClosed, .groupTheyOweYou, .groupYouOwe,
            .paymentPending, .invalidCode:
            return nil
        case .welcome, .empty, .saved, .theyOweYou, .youOwe, .settle, .allClear, .offline:
            return nil
        }
    }

    /// La imagen ya está en el catálogo. Un espacio vacío no se compila, así que `UIImage` no la encuentra.
    var isAvailable: Bool { UIImage(named: assetName) != nil }

    /// Lo que se dibuja: esta si su imagen existe; si no, el respaldo (si existe) o nada.
    func resolved(fallback: Illustration?, isAvailable: (Illustration) -> Bool = \.isAvailable) -> Illustration? {
        if isAvailable(self) { return self }
        guard let fallback, isAvailable(fallback) else { return nil }
        return fallback
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
        case .checkEmail: return "La mascota de Cruce abre un sobre del que sale un código de seis casillas"
        case .newParche: return "La mascota de Cruce levanta una maleta rodeada de cuatro recibos listos para el paseo"
        case .parchesEmpty: return "La mascota de Cruce espera sentada en una maleta, rodeada de siluetas punteadas"
        case .parcheArrival: return "La mascota de Cruce y el parche reciben a un recibo que llega corriendo"
        case .placeClaimed, .placeClaimedMini: return "Un recibo punteado cobra vida y salta feliz"
        case .closeParche:
            return "La mascota de Cruce se sienta sobre una maleta llena de recibos para cerrarla con candado"
        case .ticketPending: return "La mascota de Cruce señala un recibo largo con una moneda"
        case .cruceTransfer: return "Una moneda salta del parche hacia la mascota de Cruce y un recibo"
        case .cruceClosed: return "Dos recibos se despiden mientras la mascota de Cruce guarda el historial en una caja"
        case .parcheSettled: return "La mascota de Cruce y el parche celebran con confeti: todos quedaron en cero pesos"
        case .groupTheyOweYou: return "Varios recibos le entregan monedas a la mascota de Cruce, sentada sobre monedas"
        case .groupYouOwe: return "La mascota de Cruce, preocupada, le reparte monedas a una fila de recibos"
        case .paymentPending: return "Un recibo sostiene un billete junto a un reloj de arena"
        case .invalidCode: return "La mascota de Cruce intenta abrir un candado con una llave que no entra"
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

/// Dibuja la ilustración, o su respaldo mientras la imagen no esté en el catálogo.
/// Si no hay ninguna de las dos, no ocupa espacio.
struct IllustrationView: View {
    let illustration: Illustration
    var height: CGFloat
    /// Si se pasa, la ilustración puede encogerse hasta este alto cuando falta espacio,
    /// antes que cortar el texto de la pantalla.
    var minHeight: CGFloat?
    /// Respaldo propio de la pantalla; si es `nil`, se usa `illustration.fallback`.
    var fallback: Illustration?

    init(illustration: Illustration, height: CGFloat, minHeight: CGFloat? = nil, fallback: Illustration? = nil) {
        self.illustration = illustration
        self.height = height
        self.minHeight = minHeight
        self.fallback = fallback
    }

    var body: some View {
        if let shown = illustration.resolved(fallback: fallback ?? illustration.fallback) {
            Image(shown.assetName)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(minHeight: minHeight ?? height, maxHeight: height)
                .layoutPriority(minHeight == nil ? 0 : -1)
                .accessibilityLabel(shown.accessibilityLabel)
        }
    }
}
