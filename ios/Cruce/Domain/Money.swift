import Foundation

/// Utilidades para pesos colombianos enteros. Nunca se usan decimales.
enum Money {
    /// Signo menos tipográfico (U+2212), no el guion.
    static let minusSign = "\u{2212}"

    /// Parte de un monto según un porcentaje, redondeando al peso más cercano (.5 hacia arriba).
    static func share(of amount: Int, percent: Int) -> Int {
        precondition(amount >= 0, "Los montos siempre son positivos")
        return (amount * percent + 50) / 100
    }

    /// Formato de la app: `$30.000`, `$1.800.000`, `+$18.000`, `−$50.000`.
    static func format(_ value: Int, showsSign: Bool = false) -> String {
        let digits = String(value.magnitude)
        var groups: [String] = []
        var end = digits.endIndex
        while end > digits.startIndex {
            let start = digits.index(end, offsetBy: -3, limitedBy: digits.startIndex) ?? digits.startIndex
            groups.insert(String(digits[start..<end]), at: 0)
            end = start
        }
        let body = "$" + groups.joined(separator: ".")
        guard showsSign, value != 0 else { return body }
        return (value > 0 ? "+" : minusSign) + body
    }

    /// Convierte lo que se escribe en el teclado ("60000") a pesos. Máximo 12 dígitos.
    static func parse(digits: String) -> Int {
        Int(digits.filter(\.isNumber).prefix(12)) ?? 0
    }
}
