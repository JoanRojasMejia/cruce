import Foundation

/// Lo que dice un ticket para compartir (personal o del parche). Las frases van en tercera persona porque la imagen
/// se manda a otras personas: "Carlos debe $87.500", "Jesús le paga $110.000 a Ana".
public struct ParcheTicket: Hashable, Sendable {
    /// El sello del ticket.
    public enum Stamp: String, Hashable, Sendable {
        case pending = "Pendiente"
        case settled = "A paz y salvo"
    }

    /// Un gasto en el ticket personal: lo que le tocó a la persona, lo que pagó y, en uno por consumo, los ítems con
    /// nombre que consumió ("Mojarra").
    public struct Line: Hashable, Sendable {
        public let concept: String
        public let share: Int
        public let paid: Int
        public let items: [String]

        public init(concept: String, share: Int, paid: Int, items: [String] = []) {
            self.concept = concept
            self.share = share
            self.paid = paid
            self.items = items
        }
    }

    public let parcheName: String
    /// "Carlos" en el personal; `nil` en el del parche.
    public let personName: String?
    /// La persona del ticket personal (para su avatar, con su color); `nil` en el del parche.
    public let person: ParcheParticipant?
    /// "Carlos debe $87.500", "A Ana le deben $165.000", "Carlos está a paz y salvo" o "Total gastado".
    public let headline: String
    /// El saldo con signo en el personal; el total gastado en el del parche.
    public let amount: Int
    /// "a favor de Jesús" o "a favor de Ana"; `nil` si no hay saldo o en el del parche.
    public let favor: String?
    /// "Jesús le paga $110.000 a Ana".
    public let transfers: [String]
    public let lines: [Line]
    /// Cantidad de gastos vigentes del parche.
    public let expenseCount: Int
    /// Fecha y hora del corte.
    public let cutAt: Date
    public let stamp: Stamp
    /// El código `SOY-` de quien no tiene la app.
    public let claimCode: String?

    /// "¿Ya tienes Cruce? Entra con el código SOY-K7QX2M y tus cuentas te siguen".
    public var claimPhrase: String? {
        claimCode.map { "¿Ya tienes Cruce? Entra con el código \($0) y tus cuentas te siguen" }
    }

    /// El ticket de una persona: su frase, sus transferencias, sus gastos y, si no tiene la app, su código `SOY-`.
    public static func personal(for participantID: UUID, in detail: ParcheDetail, at date: Date) -> ParcheTicket? {
        guard let person = detail.participant(participantID) else { return nil }
        let net = detail.balance(of: participantID)
        let name = person.displayName
        let amount = Money.format(abs(net))
        let transfers = detail.suggestedTransfers.filter { $0.fromID == participantID || $0.toID == participantID }
        let headline: String
        let favor: String?
        if net < 0 {
            headline = "\(name) debe \(amount)"
            let creditors = transfers.filter { $0.fromID == participantID }.map { displayName($0.toID, in: detail) }
            favor = creditors.isEmpty ? nil : "a favor de \(list(creditors))"
        } else if net > 0 {
            headline = "A \(name) le deben \(amount)"
            favor = "a favor de \(name)"
        } else {
            headline = "\(name) está a paz y salvo"
            favor = nil
        }
        let lines = detail.visibleExpenses.compactMap { expense -> Line? in
            let share = expense.share(of: participantID)
            let paid = expense.paid(by: participantID)
            guard share > 0 || paid > 0 else { return nil }
            var items: [String] = []
            if case .items(let list) = expense.split {
                items = list.filter { $0.participantIDs.contains(participantID) }.compactMap(\.name)
            }
            return Line(concept: expense.concept, share: share, paid: paid, items: items)
        }
        return ParcheTicket(
            parcheName: detail.parche.name, personName: name, person: person, headline: headline, amount: net,
            favor: favor,
            transfers: transfers.map { phrase(for: $0, in: detail) }, lines: lines,
            expenseCount: detail.visibleExpenses.count, cutAt: date, stamp: net == 0 ? .settled : .pending,
            claimCode: person.hasApp ? nil : person.claimCode)
    }

    /// El ticket del parche: total gastado y transferencias para saldar, sin los saldos de cada persona.
    public static func parche(_ detail: ParcheDetail, at date: Date) -> ParcheTicket {
        let settled = detail.balances.allSatisfy { $0.net == 0 }
        return ParcheTicket(
            parcheName: detail.parche.name, personName: nil, person: nil, headline: "Total gastado",
            amount: detail.totalSpent,
            favor: nil, transfers: detail.suggestedTransfers.map { phrase(for: $0, in: detail) }, lines: [],
            expenseCount: detail.visibleExpenses.count, cutAt: date, stamp: settled ? .settled : .pending,
            claimCode: nil)
    }

    /// "Jesús le paga $110.000 a Ana".
    public static func phrase(for transfer: ParcheTransfer, in detail: ParcheDetail) -> String {
        "\(displayName(transfer.fromID, in: detail)) le paga \(Money.format(transfer.amount)) a \(displayName(transfer.toID, in: detail))"
    }

    /// "Ana", "Ana y Jesús" o "Ana, Jesús y Joan".
    static func list(_ names: [String]) -> String {
        guard let last = names.last else { return "" }
        guard names.count > 1 else { return last }
        return names.dropLast().joined(separator: ", ") + " y " + last
    }

    private static func displayName(_ id: UUID, in detail: ParcheDetail) -> String {
        detail.participant(id)?.displayName ?? "Alguien"
    }
}
