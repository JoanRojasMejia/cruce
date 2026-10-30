import Foundation

/// Los códigos que se escriben en "Tengo un código": `CRZ-` (cruce), `PCH-` (parche) y `SOY-` (lugar en un parche).
public enum ParcheCode {
    public enum Kind: String, Hashable, Sendable {
        case cruce = "CRZ-"
        case parche = "PCH-"
        case place = "SOY-"
    }

    /// Alfabeto sin caracteres ambiguos (sin 0/O, 1/I/L), igual que en la base de datos.
    public static let alphabet = Array("ABCDEFGHJKMNPQRSTUVWXYZ23456789")
    /// Caracteres después del prefijo.
    public static let length = 6

    /// Mayúsculas y sin espacios a los lados.
    public static func normalize(_ code: String) -> String {
        code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    /// El tipo de código según su prefijo, o `nil` si no es ninguno.
    public static func kind(of code: String) -> Kind? {
        let normalized = normalize(code)
        return [Kind.cruce, .parche, .place].first { normalized.hasPrefix($0.rawValue) }
    }

    /// Un código nuevo; en la app los genera la base de datos y este solo lo usan los dobles en memoria.
    public static func generate(_ kind: Kind) -> String {
        var generator = SystemRandomNumberGenerator()
        return generate(kind, using: &generator)
    }

    public static func generate(_ kind: Kind, using generator: inout some RandomNumberGenerator) -> String {
        kind.rawValue + String((0..<length).map { _ in alphabet.randomElement(using: &generator)! })
    }
}

/// Qué pasó en un parche. En la base lo escriben triggers en `parche_activity`.
public enum ParcheActivityKind: String, Codable, Hashable, Sendable {
    case parcheCreated
    case expenseCreated
    case expenseEdited
    case expenseDeleted
    case paymentRecorded
    case paymentConfirmed
    case participantAdded
    case participantJoined
    case placeClaimed
    case parcheClosed
    /// Alguien propuso pasar a su cruce una transferencia del plan; queda por confirmar.
    case debtProposedToCruce
    /// La otra persona aceptó: la deuda pasó al cruce.
    case debtMovedToCruce
    /// La otra persona no aceptó: la deuda sigue en el parche.
    case debtRejectedForCruce
}

/// Un aviso dentro de la app. No hay notificaciones push.
public struct ParcheActivity: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let parcheID: UUID
    public var kind: ParcheActivityKind
    /// Participante que hizo la acción.
    public var actorID: UUID?
    /// La persona de la que se trata: la que se agregó, se unió o se quedó con su lugar; quien pagó o quien debía.
    public var participantID: UUID?
    /// La otra persona: quien recibió el pago o a quien le debían.
    public var otherParticipantID: UUID?
    /// Quien anotó el gasto o el pago (para "editó un gasto que anotaste").
    public var recordedByID: UUID?
    public var amount: Int?
    public var concept: String?
    public var createdAt: Date

    public init(
        id: UUID = UUID(), parcheID: UUID, kind: ParcheActivityKind, actorID: UUID?, participantID: UUID? = nil,
        otherParticipantID: UUID? = nil, recordedByID: UUID? = nil, amount: Int? = nil, concept: String? = nil,
        createdAt: Date
    ) {
        self.id = id
        self.parcheID = parcheID
        self.kind = kind
        self.actorID = actorID
        self.participantID = participantID
        self.otherParticipantID = otherParticipantID
        self.recordedByID = recordedByID
        self.amount = amount
        self.concept = concept
        self.createdAt = createdAt
    }
}

/// Un pago del parche mayor que lo que el plan "Para saldar" dice entre esas dos personas. Se puede anotar o
/// confirmar igual; la pantalla avisa antes.
public struct ParcheOverpayment: Hashable, Sendable {
    public let fromID: UUID
    public let toID: UUID
    /// Lo que dice el plan (0 si no hay transferencia entre los dos en ese sentido).
    public let planned: Int
    public let amount: Int

    public init(fromID: UUID, toID: UUID, planned: Int, amount: Int) {
        self.fromID = fromID
        self.toID = toID
        self.planned = planned
        self.amount = amount
    }
}

/// Todo lo de un parche visto por quien usa la app. Los saldos se calculan, nunca se guardan.
public struct ParcheDetail: Identifiable, Codable, Hashable, Sendable {
    public var parche: Parche
    public var participants: [ParcheParticipant]
    /// Todos los gastos, también los borrados (borrado suave).
    public var expenses: [ParcheExpense]
    public var payments: [ParchePayment]
    public var transfers: [ParcheCruceTransfer]
    public var activity: [ParcheActivity]
    /// El participante de quien usa la app.
    public var myParticipantID: UUID?
    /// Participantes con los que quien usa la app comparte un cruce.
    public var crucePartnerIDs: Set<UUID>

    public init(
        parche: Parche, participants: [ParcheParticipant], expenses: [ParcheExpense] = [],
        payments: [ParchePayment] = [], transfers: [ParcheCruceTransfer] = [], activity: [ParcheActivity] = [],
        myParticipantID: UUID? = nil, crucePartnerIDs: Set<UUID> = []
    ) {
        self.parche = parche
        self.participants = participants
        self.expenses = expenses
        self.payments = payments
        self.transfers = transfers
        self.activity = activity
        self.myParticipantID = myParticipantID
        self.crucePartnerIDs = crucePartnerIDs
    }

    public var id: UUID { parche.id }

    /// Orden del parche (orden de unión); decide los empates del redondeo y de las transferencias.
    /// Igual que en la base (`order by joined_at, id`): si dos entraron al mismo tiempo, va primero el `id` menor.
    public var order: [UUID] {
        participants
            .sorted {
                $0.joinedAt != $1.joinedAt ? $0.joinedAt < $1.joinedAt : Self.precedes($0.id, $1.id)
            }
            .map(\.id)
    }

    /// Postgres compara los `uuid` byte a byte (sus 16 bytes, como `memcmp`).
    static func precedes(_ lhs: UUID, _ rhs: UUID) -> Bool {
        withUnsafeBytes(of: lhs.uuid) { left in
            withUnsafeBytes(of: rhs.uuid) { right in
                left.lexicographicallyPrecedes(right)
            }
        }
    }

    public var me: ParcheParticipant? {
        myParticipantID.flatMap(participant)
    }

    public func participant(_ id: UUID) -> ParcheParticipant? {
        participants.first { $0.id == id }
    }

    /// Quien creó el parche, si se sabe.
    public var creator: ParcheParticipant? {
        parche.createdBy.flatMap(participant)
    }

    /// Esa persona puede cerrar el parche: solo quien lo creó. Igual que `close_parche`: si quien lo creó ya no tiene
    /// la app (o no se sabe quién fue), lo cierra cualquiera del parche con la app.
    public func mayClose(_ participantID: UUID?) -> Bool {
        guard let participantID, let person = participant(participantID), person.hasApp else { return false }
        guard let creator, creator.hasApp else { return true }
        return creator.id == participantID
    }

    /// Gastos vigentes, del más reciente al más antiguo.
    public var visibleExpenses: [ParcheExpense] {
        expenses.filter { !$0.isDeleted }.sorted {
            $0.spentOn != $1.spentOn ? $0.spentOn > $1.spentOn : $0.createdAt > $1.createdAt
        }
    }

    /// Total gastado en gastos vigentes, con propina.
    public var totalSpent: Int {
        expenses.filter { !$0.isDeleted }.map(\.amount).reduce(0, +)
    }

    public var confirmedPayments: [ParchePayment] { payments.filter(\.isConfirmed) }
    public var pendingPayments: [ParchePayment] { payments.filter { !$0.isConfirmed } }

    public var balances: [ParcheBalance] {
        ParcheCalculator.balances(order: order, expenses: expenses, payments: payments, transfers: transfers)
    }

    public func balance(of participantID: UUID) -> Int {
        balances.first { $0.participantID == participantID }?.net ?? 0
    }

    /// Cerrado y con todos los saldos en cero.
    public var isSettled: Bool {
        ParcheCalculator.isSettled(status: parche.status, balances: balances)
    }

    /// Cómo saldar con el menor número de transferencias.
    public var suggestedTransfers: [ParcheTransfer] {
        ParcheCalculator.minimumTransfers(balances)
    }

    /// Lo que el plan "Para saldar" dice que `from` le paga a `to` (0 si el plan no tiene esa transferencia).
    /// Los pagos por confirmar ya no cuentan en los saldos; con `excluding` tampoco cuenta ese pago aunque esté
    /// confirmado, para comparar un pago contra el plan de antes de él.
    public func plannedAmount(from: UUID, to: UUID, excluding paymentID: UUID? = nil) -> Int {
        let plan =
            paymentID.map { id in
                ParcheCalculator.minimumTransfers(
                    ParcheCalculator.balances(
                        order: order, expenses: expenses, payments: payments.filter { $0.id != id },
                        transfers: transfers))
            } ?? suggestedTransfers
        return plan.filter { $0.fromID == from && $0.toID == to }.map(\.amount).reduce(0, +)
    }

    /// Un pago de `from` a `to` mayor que lo que dice el plan entre los dos; `nil` si no se pasa.
    public func overpayment(from: UUID, to: UUID, amount: Int, excluding paymentID: UUID? = nil) -> ParcheOverpayment? {
        let planned = plannedAmount(from: from, to: to, excluding: paymentID)
        guard amount > planned else { return nil }
        return ParcheOverpayment(fromID: from, toID: to, planned: planned, amount: amount)
    }

    /// La transferencia al cruce entre esas dos personas que sigue viva (por confirmar o aceptada), si la hay.
    /// Las rechazadas no cuentan: el par puede volver a proponerla.
    public func liveCruceTransfer(between a: UUID, and b: UUID) -> ParcheCruceTransfer? {
        transfers.first { $0.status != .rejected && $0.isBetween(a, b) }
    }

    /// Lo que `a` le debe directamente a `b`.
    public func directDebt(from a: UUID, to b: UUID) -> Int {
        ParcheCalculator.directDebt(from: a, to: b, expenses: expenses, payments: payments, transfers: transfers)
    }

    /// Avisos más recientes primero.
    public var sortedActivity: [ParcheActivity] {
        activity.sorted { $0.createdAt > $1.createdAt }
    }

    /// Avisos de otras personas desde la última vez que quien usa la app abrió el parche.
    public var unseenCount: Int {
        guard let me else { return 0 }
        let lastSeen = me.lastSeenAt ?? .distantPast
        return activity.filter { $0.actorID != me.id && $0.createdAt > lastSeen }.count
    }
}
