import Foundation

/// "Cómo se calcula" del ticket personal: las cuentas de la persona que dan su saldo. Las frases van en tercera persona,
/// como el resto del ticket.
extension ParcheTicket {
    /// Las cuentas que dan el saldo: lo que le tocó, lo que puso, los pagos confirmados y lo que pasó a un cruce.
    public struct Breakdown: Hashable, Sendable {
        /// Una fila: "Puso" y "−$114.000". El monto va con signo, tal como se lee: si debe, lo que suma a su deuda;
        /// si le deben, lo que suma a su favor. Las filas siempre suman `result`.
        public struct Row: Hashable, Sendable {
            public let label: String
            public let amount: Int

            public init(label: String, amount: Int) {
                self.label = label
                self.amount = amount
            }
        }

        public let rows: [Row]
        /// "Debe $43.500", "Le deben $358.500" o "Está a paz y salvo" ($0).
        public let result: Row

        /// "le tocó en total $157.500 · puso −$114.000 · debe $43.500", para el texto que se comparte.
        public var sentence: String {
            let parts = rows.map { "\(lowercasedFirst($0.label)) \(Money.format($0.amount, showsSign: $0.amount < 0))" }
            let total =
                result.amount == 0
                ? lowercasedFirst(result.label) : "\(lowercasedFirst(result.label)) \(Money.format(result.amount))"
            return (parts + [total]).joined(separator: " · ")
        }

        private func lowercasedFirst(_ text: String) -> String {
            text.prefix(1).lowercased() + text.dropFirst()
        }
    }

    /// Las cuentas de una persona; `nil` si no tiene gastos, pagos ni deudas que pasaron al cruce.
    static func breakdown(for id: UUID, in detail: ParcheDetail) -> Breakdown? {
        let ledger = Ledger(detail)
        let net = detail.balance(of: id)
        let favorable = net > 0
        // Cada fila con lo que aporta al saldo (positivo: a su favor), en el orden en que se lee.
        let share = (favorable ? "Le tocó" : "Le tocó en total", -ledger.share(of: id))
        let paid = ("Puso", ledger.paid(by: id))
        let made = ("Ya pagó", detail.confirmedPayments.filter { $0.fromID == id }.map(\.amount).reduce(0, +))
        let received = ("Ya le pagaron", -detail.confirmedPayments.filter { $0.toID == id }.map(\.amount).reduce(0, +))
        var entries = favorable ? [paid, share, received, made] : [share, paid, made, received]
        for transfer in detail.transfers where transfer.isAccepted && (transfer.fromID == id || transfer.toID == id) {
            let other = transfer.fromID == id ? transfer.toID : transfer.fromID
            entries.append(
                (
                    "Pasó a su cruce con \(displayName(other, in: detail))",
                    transfer.fromID == id ? transfer.amount : -transfer.amount
                ))
        }
        let rows = entries.filter { $0.1 != 0 }.map { Breakdown.Row(label: $0.0, amount: favorable ? $0.1 : -$0.1) }
        guard !rows.isEmpty else { return nil }
        let result: Breakdown.Row
        if net < 0 {
            result = Breakdown.Row(label: "Debe", amount: -net)
        } else if net > 0 {
            result = Breakdown.Row(label: "Le deben", amount: net)
        } else {
            result = Breakdown.Row(label: "Está a paz y salvo", amount: 0)
        }
        return Breakdown(rows: rows, result: result)
    }
}

/// Las cuentas de los gastos vigentes de un parche, sin cruzar: lo que pagó y lo que le tocó a cada quien.
private struct Ledger {
    let expenses: [ParcheExpense]

    init(_ detail: ParcheDetail) {
        expenses = detail.visibleExpenses
    }

    func share(of id: UUID) -> Int { expenses.map { $0.share(of: id) }.reduce(0, +) }
    func paid(by id: UUID) -> Int { expenses.map { $0.paid(by: id) }.reduce(0, +) }
}
