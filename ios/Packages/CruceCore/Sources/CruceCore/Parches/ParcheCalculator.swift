import Foundation

/// Saldo de una persona del parche. Positivo: le deben; negativo: debe. Nunca se guarda.
public struct ParcheBalance: Hashable, Sendable {
    public let participantID: UUID
    public let net: Int

    public init(participantID: UUID, net: Int) {
        self.participantID = participantID
        self.net = net
    }
}

/// Una transferencia sugerida para saldar: `fromID` le paga `amount` a `toID`.
public struct ParcheTransfer: Hashable, Sendable {
    public let fromID: UUID
    public let toID: UUID
    public let amount: Int

    public init(fromID: UUID, toID: UUID, amount: Int) {
        self.fromID = fromID
        self.toID = toID
        self.amount = amount
    }
}

/// Cálculos de un parche: saldos, a paz y salvo, mínimo de transferencias y deuda directa entre dos.
public enum ParcheCalculator {
    /// Saldo de cada persona, en el orden del parche: lo que pagó en gastos vigentes − lo que le toca en ellos
    /// + pagos confirmados que hizo − pagos confirmados que recibió + deudas pasadas al cruce como quien debía
    /// − como a quien le debían. Siempre suma cero.
    public static func balances(
        order: [UUID], expenses: [ParcheExpense], payments: [ParchePayment] = [],
        transfers: [ParcheCruceTransfer] = []
    ) -> [ParcheBalance] {
        var net: [UUID: Int] = [:]
        for expense in expenses where !expense.isDeleted {
            for payer in expense.payers { net[payer.participantID, default: 0] += payer.amount }
            for share in expense.shares { net[share.participantID, default: 0] -= share.amount }
        }
        for payment in payments where payment.isConfirmed {
            net[payment.fromID, default: 0] += payment.amount
            net[payment.toID, default: 0] -= payment.amount
        }
        for transfer in transfers {
            net[transfer.fromID, default: 0] += transfer.amount
            net[transfer.toID, default: 0] -= transfer.amount
        }
        return order.map { ParcheBalance(participantID: $0, net: net[$0] ?? 0) }
    }

    /// A paz y salvo: el parche está cerrado y todos los saldos están en cero.
    public static func isSettled(status: ParcheStatus, balances: [ParcheBalance]) -> Bool {
        status == .closed && balances.allSatisfy { $0.net == 0 }
    }

    /// Voraz: el que más debe le paga al que más le deben el menor de los dos montos, y se repite.
    /// Da a lo sumo n − 1 transferencias; los empates los gana quien va primero en `balances` (orden del parche).
    public static func minimumTransfers(_ balances: [ParcheBalance]) -> [ParcheTransfer] {
        var remaining = balances.map(\.net)
        var transfers: [ParcheTransfer] = []
        while true {
            // Con comparaciones estrictas, en empate se queda el índice más bajo.
            var debtor: Int?
            var creditor: Int?
            for index in remaining.indices {
                if remaining[index] < 0, debtor.map({ remaining[index] < remaining[$0] }) ?? true { debtor = index }
                if remaining[index] > 0, creditor.map({ remaining[index] > remaining[$0] }) ?? true { creditor = index }
            }
            guard let debtor, let creditor else { break }
            let amount = min(-remaining[debtor], remaining[creditor])
            remaining[debtor] += amount
            remaining[creditor] -= amount
            transfers.append(
                ParcheTransfer(
                    fromID: balances[debtor].participantID, toID: balances[creditor].participantID, amount: amount))
        }
        return transfers
    }

    /// Lo que `a` le debe directamente a `b` (negativo si `b` le debe a `a`), antes de simplificar las del grupo.
    /// Por cada gasto vigente: lo que le toca a `a` por la fracción que pagó `b` (`share_a * paid_b / total`, entero)
    /// menos lo recíproco; luego los pagos confirmados y las deudas pasadas al cruce entre los dos.
    public static func directDebt(
        from a: UUID, to b: UUID, expenses: [ParcheExpense], payments: [ParchePayment] = [],
        transfers: [ParcheCruceTransfer] = []
    ) -> Int {
        var debt = 0
        for expense in expenses where !expense.isDeleted && expense.amount > 0 {
            debt += fraction(expense.share(of: a), times: expense.paid(by: b), over: expense.amount)
            debt -= fraction(expense.share(of: b), times: expense.paid(by: a), over: expense.amount)
        }
        for payment in payments where payment.isConfirmed {
            if payment.fromID == a && payment.toID == b { debt -= payment.amount }
            if payment.fromID == b && payment.toID == a { debt += payment.amount }
        }
        for transfer in transfers {
            if transfer.fromID == a && transfer.toID == b { debt -= transfer.amount }
            if transfer.fromID == b && transfer.toID == a { debt += transfer.amount }
        }
        return debt
    }

    /// Un pago cuenta de una vez si lo anota quien recibe o si quien recibe no tiene la app.
    public static func confirmsImmediately(
        recordedBy: UUID, toID: UUID, participants: [ParcheParticipant]
    ) -> Bool {
        if recordedBy == toID { return true }
        let receiver = participants.first { $0.id == toID }
        return receiver?.hasApp == false
    }

    /// `value * numerator / denominator` en enteros, sin desbordar con montos grandes.
    private static func fraction(_ value: Int, times numerator: Int, over denominator: Int) -> Int {
        denominator.dividingFullWidth(value.multipliedFullWidth(by: numerator)).quotient
    }
}
