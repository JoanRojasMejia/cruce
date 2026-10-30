import Foundation

/// "Cómo se calcula" y "¿Por qué le paga todo a…?" del ticket personal. En un parche, "Para saldar" junta las deudas
/// para que haya menos pagos y por eso a veces alguien le paga a quien no pagó sus gastos; el ticket lo explica con
/// las cuentas de la persona. Las frases van en tercera persona, como el resto del ticket.
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

    /// "¿Por qué le paga todo a Yisus?" y la explicación con los montos.
    public struct Explanation: Hashable, Sendable {
        public let title: String
        public let body: String

        public init(title: String, body: String) {
            self.title = title
            self.body = body
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

    /// Por qué "Para saldar" no coincide con quién pagó qué; `nil` si coincide (no hay nada que explicar).
    static func explanation(for id: UUID, in detail: ParcheDetail) -> Explanation? {
        guard let person = detail.participant(id) else { return nil }
        let ledger = Ledger(detail)
        let name = person.displayName
        let net = detail.balance(of: id)
        // Lo que los demás le deben por lo que pagó y lo que debe por lo que pagaron otros, sin cruzar.
        let receive = ledger.paid(by: id) - ledger.selfCovered(id)
        let pay = ledger.share(of: id) - ledger.selfCovered(id)
        if net < 0 {
            return debtorExplanation(id, name: name, receive: receive, pay: pay, ledger: ledger, in: detail)
        }
        if net > 0 { return creditorExplanation(id, name: name, net: net, ledger: ledger, in: detail) }
        let settledOutside =
            detail.confirmedPayments.contains { $0.fromID == id || $0.toID == id }
            || detail.transfers.contains { $0.isAccepted && ($0.fromID == id || $0.toID == id) }
        guard receive > 0, pay > 0, !settledOutside else { return nil }
        return Explanation(
            title: "¿Por qué está a paz y salvo?",
            body: "Lo que pagó \(name) (\(list(ledger.conceptsPaid(by: id)))) cubre justo lo que le tocaba, así que "
                + "Cruce cruza las cuentas: en vez de recibir \(Money.format(receive)) y pagar \(Money.format(pay)), "
                + "no le paga nada a nadie ni nadie le paga.")
    }

    private static func debtorExplanation(
        _ id: UUID, name: String, receive: Int, pay: Int, ledger: Ledger, in detail: ParcheDetail
    ) -> Explanation? {
        let creditors = detail.creditors(of: id)
        guard !creditors.isEmpty else { return nil }
        let creditorNames = list(creditors.map { displayName($0, in: detail) })
        let title =
            creditors.count == 1 ? "¿Por qué le paga todo a \(creditorNames)?" : "¿Por qué le paga a \(creditorNames)?"
        // Puso plata y aun así paga: lo que le deben se descuenta de lo que debe.
        if receive > 0, pay > 0 {
            return Explanation(
                title: title,
                body: "Lo que pagó \(name) (\(list(ledger.conceptsPaid(by: id)))) ya cubre parte de lo que le tocaba, "
                    + "así que Cruce cruza las cuentas: en vez de recibir \(Money.format(receive)) y pagar "
                    + "\(Money.format(pay)), le paga solo la diferencia a \(creditorNames). Así hay menos pagos.")
        }
        // Parte de lo suyo lo pagó alguien a quien no le paga.
        let payers = ledger.payers(ofSharesOf: id)
        let others = payers.filter { !creditors.contains($0) }
        if !others.isEmpty {
            let partial = payers.contains { creditors.contains($0) }
            let concepts = others.flatMap { ledger.concepts(paidBy: $0, sharedBy: id) }
            return Explanation(
                title: title,
                body:
                    "\(partial ? "Parte de lo que" : "Lo que") le toca \(others.count == 1 ? "lo pagó" : "lo pagaron") "
                    + "\(list(others.map { displayName($0, in: detail) })) (\(list(unique(concepts)))), pero Cruce "
                    + "cruza las cuentas para que haya menos pagos: por eso le paga todo a \(creditorNames).")
        }
        // Les paga a quienes pagaron, pero no lo mismo que le tocaba con cada uno.
        let mismatch = detail.order.contains {
            $0 != id && detail.plannedAmount(from: id, to: $0) != ledger.owed(from: id, to: $0)
        }
        guard mismatch else { return nil }
        return Explanation(
            title: title,
            body: "Cruce cruza las cuentas para que haya menos pagos: por eso no le paga a cada quien lo mismo que le "
                + "tocaba en sus gastos.")
    }

    private static func creditorExplanation(
        _ id: UUID, name: String, net: Int, ledger: Ledger, in detail: ParcheDetail
    ) -> Explanation? {
        var sentences: [String] = []
        for other in detail.order where other != id {
            let planned = detail.plannedAmount(from: other, to: id)
            let owed = ledger.owed(from: other, to: id)
            guard planned != owed, planned > 0 || owed > 0 else { continue }
            let otherName = displayName(other, in: detail)
            let paysNote = "\(otherName) le paga \(Money.format(planned)) y no \(Money.format(owed))"
            // Lo que los demás le deben a esa persona por lo que pagó.
            let receivable = ledger.paid(by: other) - ledger.selfCovered(other)
            // Lo que esa persona les debe a otros (ni a quien es el ticket ni a sí misma).
            let elsewhere = detail.order.filter { $0 != id && $0 != other && ledger.owed(from: other, to: $0) > 0 }
            let extra = elsewhere.map { ledger.owed(from: other, to: $0) }.reduce(0, +)
            if receivable > 0, planned == owed - receivable {
                sentences.append(
                    "\(paysNote) porque se le descuentan \(Money.format(receivable)) que le debían por lo que pagó "
                        + "(\(list(ledger.conceptsPaid(by: other)))).")
            } else if extra > 0, planned == owed + extra {
                let concepts = elsewhere.flatMap { ledger.concepts(paidBy: $0, sharedBy: other) }
                sentences.append(
                    "\(paysNote) porque se le suman \(Money.format(extra)) que le debía a "
                        + "\(list(elsewhere.map { displayName($0, in: detail) })) (\(list(unique(concepts)))).")
            } else if planned == 0 {
                sentences.append(
                    "\(otherName) no le paga: lo que le debía (\(Money.format(owed))) se cruzó con otras cuentas.")
            } else if owed <= 0 {
                sentences.append(
                    "\(otherName) le paga \(Money.format(planned)) aunque no le debía nada por sus gastos: se cruzó "
                        + "con otras cuentas.")
            } else {
                sentences.append("\(paysNote) porque se cruzó con otras cuentas.")
            }
        }
        guard !sentences.isEmpty else { return nil }
        sentences.append(
            "Cruce cruza las cuentas para que haya menos pagos: en total le llegan \(Money.format(net)).")
        return Explanation(title: "¿Por qué le pagan así?", body: sentences.joined(separator: " "))
    }

    private static func unique(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        return values.filter { seen.insert($0).inserted }
    }
}

/// Las cuentas de los gastos vigentes de un parche, sin cruzar: quién pagó qué y a quién le tocó.
private struct Ledger {
    let detail: ParcheDetail
    /// Del más antiguo al más reciente, como se lee una lista de conceptos.
    let expenses: [ParcheExpense]

    init(_ detail: ParcheDetail) {
        self.detail = detail
        expenses = detail.visibleExpenses.reversed()
    }

    func share(of id: UUID) -> Int { expenses.map { $0.share(of: id) }.reduce(0, +) }
    func paid(by id: UUID) -> Int { expenses.map { $0.paid(by: id) }.reduce(0, +) }

    /// Lo que le tocó a esa persona en lo que ella misma pagó: ni se lo debe nadie ni lo debe.
    func selfCovered(_ id: UUID) -> Int {
        expenses.map { fraction($0.share(of: id), times: $0.paid(by: id), over: $0.amount) }.reduce(0, +)
    }

    /// Lo que `from` le debe a `to` por los gastos que pagó `to` (sin restar lo que `to` le debe a `from`), menos los
    /// pagos confirmados y las deudas que pasaron al cruce entre los dos.
    func owed(from: UUID, to: UUID) -> Int {
        var owed = expenses.map { fraction($0.share(of: from), times: $0.paid(by: to), over: $0.amount) }.reduce(0, +)
        for payment in detail.confirmedPayments {
            if payment.fromID == from && payment.toID == to { owed -= payment.amount }
            if payment.fromID == to && payment.toID == from { owed += payment.amount }
        }
        for transfer in detail.transfers where transfer.isAccepted {
            if transfer.fromID == from && transfer.toID == to { owed -= transfer.amount }
            if transfer.fromID == to && transfer.toID == from { owed += transfer.amount }
        }
        return owed
    }

    /// Los gastos que pagó esa persona y en los que a otros también les tocó algo.
    func conceptsPaid(by id: UUID) -> [String] {
        expenses.filter { $0.paid(by: id) > 0 && $0.share(of: id) < $0.amount }.map(\.concept)
    }

    /// Los gastos que pagó `payer` y en los que le tocó algo a `person`.
    func concepts(paidBy payer: UUID, sharedBy person: UUID) -> [String] {
        expenses.filter { $0.paid(by: payer) > 0 && $0.share(of: person) > 0 }.map(\.concept)
    }

    /// Quienes pagaron gastos en los que le tocó algo a esa persona (sin ella), en el orden del parche.
    func payers(ofSharesOf id: UUID) -> [UUID] {
        detail.order.filter { payer in
            payer != id && expenses.contains { $0.share(of: id) > 0 && $0.paid(by: payer) > 0 }
        }
    }

    /// `value * numerator / denominator` en enteros, sin desbordar con montos grandes.
    private func fraction(_ value: Int, times numerator: Int, over denominator: Int) -> Int {
        guard denominator > 0 else { return 0 }
        return denominator.dividingFullWidth(value.multipliedFullWidth(by: numerator)).quotient
    }
}
