import Foundation

/// Categorías de gasto. Deben coincidir con el enum `category` de Supabase.
public enum MovementCategory: String, Codable, CaseIterable, Identifiable, Hashable {
    case comida
    case mercado
    case transporte
    case hogar
    case ocio
    case prestamo
    case otro

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .comida: return "Comida"
        case .mercado: return "Mercado"
        case .transporte: return "Transporte"
        case .hogar: return "Hogar"
        case .ocio: return "Ocio"
        case .prestamo: return "Préstamo"
        case .otro: return "Otro"
        }
    }

    /// SF Symbol equivalente al ícono del diseño.
    public var symbol: String {
        switch self {
        case .comida: return "fork.knife"
        case .mercado: return "cart"
        case .transporte: return "car"
        case .hogar: return "house"
        case .ocio: return "film"
        case .prestamo: return "banknote"
        case .otro: return "square.grid.2x2"
        }
    }
}

/// Cómo se reparte un gasto entre los dos.
public enum SplitRule: Codable, Hashable {
    /// 50/50.
    case equal
    /// Porcentaje que le corresponde a quien NO pagó (0–100).
    case percentage(otherShare: Int)
    /// Todo le corresponde al otro (préstamos, pagos para saldar).
    case fullOther

    /// Porcentaje del monto que le toca a quien no pagó.
    var otherSharePercent: Int {
        switch self {
        case .equal: return 50
        case .percentage(let share): return min(max(share, 0), 100)
        case .fullOther: return 100
        }
    }

    public var title: String {
        switch self {
        case .equal: return "50/50"
        case .percentage(let share): return "\(100 - share)/\(share)"
        case .fullOther: return "Todo es del otro"
        }
    }
}

/// Un gasto o un pago para saldar.
public struct Movement: Identifiable, Codable, Hashable {
    public enum Kind: String, Codable, Hashable {
        case expense
        case settlement
    }

    public let id: UUID
    public var kind: Kind
    /// Quién puso la plata.
    public var payerID: UUID
    /// Monto en pesos colombianos enteros.
    public var amount: Int
    public var concept: String
    public var category: MovementCategory
    public var split: SplitRule
    public var date: Date
    public var createdBy: UUID
    public var paymentMethod: String?

    public init(
        id: UUID = UUID(),
        kind: Kind = .expense,
        payerID: UUID,
        amount: Int,
        concept: String,
        category: MovementCategory,
        split: SplitRule = .equal,
        date: Date = .now,
        createdBy: UUID,
        paymentMethod: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.payerID = payerID
        self.amount = amount
        self.concept = concept
        self.category = category
        self.split = split
        self.date = date
        self.createdBy = createdBy
        self.paymentMethod = paymentMethod
    }

    /// Lo que quien no pagó le debe a quien pagó por este movimiento.
    public var owedByOther: Int {
        Money.share(of: amount, percent: split.otherSharePercent)
    }

    /// Lo que le corresponde pagar a quien pagó (su propia parte).
    public var payerShare: Int {
        amount - owedByOther
    }
}
