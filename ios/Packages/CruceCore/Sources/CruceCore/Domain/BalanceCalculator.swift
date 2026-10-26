import Foundation

/// Saldo neto visto desde una persona.
public enum BalanceState: Equatable {
    /// El otro te debe este monto.
    case theyOweYou(Int)
    /// Tú le debes este monto al otro.
    case youOwe(Int)
    /// Están a paz y salvo.
    case settled

    public init(net: Int) {
        if net > 0 {
            self = .theyOweYou(net)
        } else if net < 0 {
            self = .youOwe(-net)
        } else {
            self = .settled
        }
    }

    public var amount: Int {
        switch self {
        case .theyOweYou(let v), .youOwe(let v): return v
        case .settled: return 0
        }
    }
}

/// Lógica pura del saldo. El saldo nunca se guarda: siempre se calcula sumando los movimientos.
public enum BalanceCalculator {
    /// Efecto de un movimiento en el saldo de `memberID`.
    /// Positivo: a tu favor (el otro te debe más). Negativo: a favor del otro.
    public static func impact(of movement: Movement, for memberID: UUID) -> Int {
        movement.payerID == memberID ? movement.owedByOther : -movement.owedByOther
    }

    /// Saldo neto de `memberID`. Positivo: el otro le debe.
    public static func net(of movements: [Movement], for memberID: UUID) -> Int {
        movements.reduce(0) { $0 + impact(of: $1, for: memberID) }
    }

    static func state(of movements: [Movement], for memberID: UUID) -> BalanceState {
        BalanceState(net: net(of: movements, for: memberID))
    }

    /// Movimiento que deja el saldo en $0, o `nil` si ya están a paz y salvo.
    /// Quien debe le paga todo al otro: es un pago con reparto "todo es del otro".
    public static func settlement(
        movements: [Movement],
        me: UUID,
        other: UUID,
        createdBy: UUID,
        paymentMethod: String?,
        date: Date = .now
    ) -> Movement? {
        let net = net(of: movements, for: me)
        guard net != 0 else { return nil }
        return Movement(
            kind: .settlement,
            payerID: net > 0 ? other : me,
            amount: abs(net),
            concept: "Saldar cuentas",
            category: .otro,
            split: .fullOther,
            date: date,
            createdBy: createdBy,
            paymentMethod: paymentMethod
        )
    }

    /// Movimientos registrados después del último pago para saldar.
    public static func movementsSinceLastSettlement(_ movements: [Movement]) -> [Movement] {
        let sorted = movements.sorted { $0.date < $1.date }
        guard let lastIndex = sorted.lastIndex(where: { $0.kind == .settlement }) else { return sorted }
        return Array(sorted[(lastIndex + 1)...])
    }
}
