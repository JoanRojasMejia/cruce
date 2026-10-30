import Foundation

/// Una fila de la sección "Pagos" del parche, desde la vista de quien usa la app: "Le pagaste $90.000 a Ana" y
/// "Confirmado por Ana · 19 oct".
public struct ParchePaymentLine: Identifiable, Hashable, Sendable {
    /// El `id` del pago.
    public let id: UUID
    public let title: String
    public let detail: String
    public let amount: Int

    public init(id: UUID, title: String, detail: String, amount: Int) {
        self.id = id
        self.title = title
        self.detail = detail
        self.amount = amount
    }
}

/// La tarjeta "Tu saldo en el parche" y lo que se muestra debajo según los saldos: "Para saldar", "Saldos", "Anotar un
/// pago" y "Pagos". Todo desde la vista de quien usa la app (`myParticipantID`).
extension ParcheDetail {
    /// El saldo de quien usa la app; 0 si no está en el parche.
    public var myNet: Int {
        myParticipantID.map(balance(of:)) ?? 0
    }

    /// A quiénes les paga esa persona según el plan "Para saldar", en el orden del plan y sin repetir.
    public func creditors(of participantID: UUID) -> [UUID] {
        var seen: Set<UUID> = []
        return suggestedTransfers.filter { $0.fromID == participantID }.map(\.toID).filter { seen.insert($0).inserted }
    }

    /// "Te deben en el parche", "Debes en el parche", "Todos quedaron a paz y salvo" (todos en $0), "Ya están a paz y
    /// salvo" (cerrado sin gastos) o "Estás a paz y salvo" (tú en $0 y otros no).
    public var myBalancePhrase: String {
        let net = myNet
        if net > 0 { return "Te deben en el parche" }
        if net < 0 { return "Debes en el parche" }
        if everyoneAtZero { return "Todos quedaron a paz y salvo" }
        return isSettled ? "Ya están a paz y salvo" : "Estás a paz y salvo"
    }

    /// Lo que va debajo del monto: "a tu favor", "a favor de Jesús y Joan" (a quienes les pagas según "Para saldar")
    /// o, con todos en $0, "Nadie le debe nada a nadie."; `nil` si solo tú estás en $0.
    public var myBalanceNote: String? {
        let net = myNet
        if net > 0 { return "a tu favor" }
        if net < 0, let me = myParticipantID {
            let names = creditors(of: me).map { participant($0)?.displayName ?? "alguien" }
            return names.isEmpty ? nil : "a favor de \(ParcheTicket.list(names))"
        }
        return everyoneAtZero ? "Nadie le debe nada a nadie." : nil
    }

    /// "Para saldar" y "Saldos" se esconden cuando todos quedaron en $0: no hay nada que saldar.
    public var showsSettlementPlan: Bool { !everyoneAtZero }

    /// "Anotar un pago": siempre con el parche abierto; cerrado, solo mientras alguien deba algo.
    public var allowsRecordingPayment: Bool { parche.isOpen || !everyoneAtZero }

    /// La sección "Pagos" (los confirmados) aparece cuando todos quedaron en $0 y hubo pagos.
    public var showsPaymentHistory: Bool { everyoneAtZero && !confirmedPayments.isEmpty }

    /// "Le pagaste $87.500 a Jesús", "Carlos te pagó $87.500" o "Carlos le pagó $87.500 a Jesús".
    public func paymentPhrase(from: UUID?, to: UUID?, amount: Int) -> String {
        let value = Money.format(amount)
        let fromName = from.flatMap(participant)?.displayName ?? "Alguien"
        let toName = to.flatMap(participant)?.displayName ?? "alguien"
        if from != nil && from == myParticipantID { return "Le pagaste \(value) a \(toName)" }
        if to != nil && to == myParticipantID { return "\(fromName) te pagó \(value)" }
        return "\(fromName) le pagó \(value) a \(toName)"
    }

    /// Los pagos confirmados, del más reciente al más antiguo. Debajo de cada uno, quién lo confirmó y cuándo: quien
    /// recibe, si lo anotó o lo confirmó ("Confirmado por Ana · 19 oct"); si contó de una vez porque quien recibe no
    /// tenía la app, quien lo anotó ("Anotado por Jesús · 4 nov"). "ti" para quien usa la app.
    public func paymentLines(now: Date = .now, calendar: Calendar = .current) -> [ParchePaymentLine] {
        confirmedPayments
            .sorted { ($0.confirmedAt ?? $0.createdAt) > ($1.confirmedAt ?? $1.createdAt) }
            .map { payment in
                let date = payment.confirmedAt ?? payment.createdAt
                // Contó de una vez al anotarlo (`confirmed_at` igual a `created_at`) y no lo anotó quien recibe: quien
                // recibe no tenía la app y nadie lo confirmó.
                let autoConfirmed = payment.recordedBy != payment.toID && payment.confirmedAt == payment.createdAt
                let who =
                    autoConfirmed
                    ? "Anotado por \(personName(payment.recordedBy))" : "Confirmado por \(personName(payment.toID))"
                return ParchePaymentLine(
                    id: payment.id,
                    title: paymentPhrase(from: payment.fromID, to: payment.toID, amount: payment.amount),
                    detail: "\(who) · \(DateText.relative(date, now: now, calendar: calendar))", amount: payment.amount)
            }
    }

    /// "Ana" o "ti" para quien usa la app (para "Confirmado por ti").
    private func personName(_ participantID: UUID) -> String {
        participantID == myParticipantID ? "ti" : participant(participantID)?.displayName ?? "alguien"
    }
}
