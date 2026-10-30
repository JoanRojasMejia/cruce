/// Una tecla del teclado de Cruce, con el que se escribe el monto principal.
public enum AmountKey: Hashable, Sendable {
    case digit(Int)
    case tripleZero
    case delete

    /// Las teclas en el orden del diseño: 1 a 9, `000`, `0` y borrar.
    public static let layout: [AmountKey] = (1...9).map(AmountKey.digit) + [.tripleZero, .digit(0), .delete]

    /// Lo que se ve en la tecla (borrar se dibuja con un ícono).
    public var title: String {
        switch self {
        case .digit(let value): return String(value)
        case .tripleZero: return "000"
        case .delete: return "⌫"
        }
    }

    /// Lo que dice VoiceOver al llegar a la tecla.
    public var accessibilityLabel: String {
        switch self {
        case .digit(let value): return String(value)
        case .tripleZero: return "Tres ceros"
        case .delete: return "Borrar"
        }
    }
}

/// Cómo cambia el monto principal al tocar una tecla, y cómo se lee con VoiceOver.
public enum AmountEntry {
    /// El mismo límite que `Money.parse`.
    public static let maxDigits = 12

    /// El monto después de tocar `key`: los dígitos se agregan a la derecha, los ceros a la izquierda no cuentan y una
    /// tecla que pasaría de `maxDigits` no hace nada.
    public static func press(_ key: AmountKey, on amount: Int) -> Int {
        let next: Int
        switch key {
        case .delete: return amount / 10
        case .digit(let value): next = amount * 10 + value
        case .tripleZero: next = amount * 1_000
        }
        return String(next).count <= maxDigits ? next : amount
    }

    /// El monto para VoiceOver: los dígitos sin puntos ("60000 pesos"), que en español se oye "sesenta mil pesos".
    public static func spokenValue(_ amount: Int) -> String {
        amount == 1 ? "1 peso" : "\(amount) pesos"
    }

    /// Lo que se anuncia después de cada tecla: "Monto: 60000 pesos".
    public static func announcement(_ amount: Int) -> String {
        "Monto: \(spokenValue(amount))"
    }
}

/// Qué teclado está abierto en una pantalla con un monto principal: el de Cruce (`amount`), el del sistema para otro
/// campo (`field`) o ninguno. Nunca los dos a la vez.
public enum AmountEntryFocus: Hashable, Sendable {
    case amount
    case field
    case none

    /// Al anotar algo nuevo arranca el monto; al editar no arranca nada.
    public static func initial(isEditing: Bool) -> AmountEntryFocus {
        isEditing ? .none : .amount
    }

    public var showsKeypad: Bool { self == .amount }

    /// Se abrió el teclado del sistema (se tocó otro campo): se cierra el de Cruce.
    public var afterSystemKeyboardShows: AmountEntryFocus { .field }

    /// Se cerró el teclado del sistema. Si fue por tocar la tarjeta, el de Cruce sigue abierto.
    public var afterSystemKeyboardHides: AmountEntryFocus { self == .field ? .none : self }
}
