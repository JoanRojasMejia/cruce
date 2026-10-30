import Foundation

/// Estado guardado de un parche, igual que `parches.status`. "A paz y salvo" no se guarda: se calcula.
public enum ParcheStatus: String, Codable, Hashable, Sendable {
    case open
    case closed
}

/// Un grupo de varias personas con inicio y fin (un viaje, una cena). Aparte del cruce de dos.
public struct Parche: Identifiable, Codable, Hashable, Sendable {
    /// Largo máximo del nombre (igual que el `check` de `parches.name`).
    public static let maxNameLength = 60

    public let id: UUID
    public var name: String
    /// Código para unirse: `PCH-` y 6 caracteres.
    public var code: String
    public var status: ParcheStatus
    public var createdAt: Date
    public var closedAt: Date?
    /// El participante que creó el parche (`parches.created_by`): solo él lo cierra. `nil` en lo guardado antes.
    public var createdBy: UUID?

    public init(
        id: UUID = UUID(), name: String, code: String, status: ParcheStatus = .open, createdAt: Date,
        closedAt: Date? = nil, createdBy: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.code = code
        self.status = status
        self.createdAt = createdAt
        self.closedAt = closedAt
        self.createdBy = createdBy
    }

    public var isOpen: Bool { status == .open }
}

/// Una persona de un parche, con o sin la app. Las demás piezas del parche la nombran por este `id`.
public struct ParcheParticipant: Identifiable, Codable, Hashable, Sendable {
    /// Largo máximo del nombre (igual que el `check` de `parche_participants.display_name`).
    public static let maxNameLength = 40

    public let id: UUID
    /// La cuenta de quien tiene la app; `nil` si no la tiene.
    public var userID: UUID?
    public var displayName: String
    /// Código `SOY-` para quedarse con el lugar; solo mientras no tenga la app.
    public var claimCode: String?
    /// Momento en que entró al parche; define el orden del parche.
    public var joinedAt: Date
    /// Última vez que abrió el parche (para los avisos sin ver).
    public var lastSeenAt: Date?
    /// Su color: el de su perfil si tiene la app; si no, el siguiente color libre del parche al entrar.
    public var avatarColor: AvatarColor
    /// Su @usuario (`participant_username`), solo si tiene la app.
    public var username: String?
    /// Cuándo se borró la cuenta de quien tenía este lugar (`account_deleted_at`). El lugar se queda, con el nombre
    /// "Cuenta borrada", sus gastos y sus pagos; no tiene código `SOY-` y nadie lo reclama.
    public var accountDeletedAt: Date?

    public init(
        id: UUID = UUID(), userID: UUID? = nil, displayName: String, claimCode: String? = nil, joinedAt: Date,
        lastSeenAt: Date? = nil, avatarColor: AvatarColor = .yellow, username: String? = nil,
        accountDeletedAt: Date? = nil
    ) {
        self.id = id
        self.userID = userID
        self.displayName = displayName
        self.claimCode = claimCode
        self.joinedAt = joinedAt
        self.lastSeenAt = lastSeenAt
        self.avatarColor = avatarColor
        self.username = username
        self.accountDeletedAt = accountDeletedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, userID, displayName, claimCode, joinedAt, lastSeenAt, avatarColor, username, accountDeletedAt
    }

    /// Un participante guardado en el teléfono antes del color por persona no trae `avatarColor`: se lee amarillo.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        userID = try container.decodeIfPresent(UUID.self, forKey: .userID)
        displayName = try container.decode(String.self, forKey: .displayName)
        claimCode = try container.decodeIfPresent(String.self, forKey: .claimCode)
        joinedAt = try container.decode(Date.self, forKey: .joinedAt)
        lastSeenAt = try container.decodeIfPresent(Date.self, forKey: .lastSeenAt)
        avatarColor = try container.decodeIfPresent(AvatarColor.self, forKey: .avatarColor) ?? .yellow
        username = try container.decodeIfPresent(String.self, forKey: .username)
        accountDeletedAt = try container.decodeIfPresent(Date.self, forKey: .accountDeletedAt)
    }

    public var hasApp: Bool { userID != nil }

    /// Quien tenía este lugar borró su cuenta.
    public var isDeletedAccount: Bool { accountDeletedAt != nil }

    /// "Carlos (sin la app)" o solo el nombre ("Cuenta borrada" no dice "sin la app": tuvo la app y la borró).
    public var label: String {
        hasApp || isDeletedAccount ? displayName : "\(displayName) (sin la app)"
    }

    /// "@ana", solo para quien tiene la app.
    public var handle: String? {
        hasApp ? username.map(Username.display) : nil
    }

    /// Dos primeras letras del nombre.
    public var initials: String {
        String(displayName.trimmingCharacters(in: .whitespaces).prefix(2))
    }
}

/// Cuánto pagó una persona de un gasto.
public struct ParchePayer: Codable, Hashable, Sendable {
    public var participantID: UUID
    public var amount: Int

    public init(participantID: UUID, amount: Int) {
        self.participantID = participantID
        self.amount = amount
    }
}

/// Por qué no se puede guardar un gasto, con su mensaje para la pantalla.
public enum ParcheExpenseError: Error, Equatable, Sendable {
    case invalidConcept
    case invalidAmount
    case noPayers
    case payersDoNotMatch(paid: Int, total: Int)
    case split(ParcheSplitError)

    public var message: String {
        switch self {
        case .invalidConcept: "El concepto debe tener entre 1 y 80 caracteres."
        case .invalidAmount: "El monto debe ser mayor que $0."
        case .noPayers: "Elige quién pagó."
        case .payersDoNotMatch(let paid, let total):
            paid < total
                ? "Faltan \(Money.format(total - paid)): quienes pagaron suman \(Money.format(paid)) de \(Money.format(total))."
                : "Sobran \(Money.format(paid - total)): quienes pagaron suman \(Money.format(paid)) y el total es \(Money.format(total))."
        case .split(let error): error.message
        }
    }
}

/// Un gasto de un parche: el dato de entrada del reparto y las partes ya resueltas en pesos.
/// Guardar lo resuelto hace que el saldo no cambie si mañana cambia el algoritmo.
public struct ParcheExpense: Identifiable, Codable, Hashable, Sendable {
    /// Largo máximo del concepto (igual que el `check` de `parche_expenses.concept`).
    public static let maxConceptLength = 80

    /// Generado en el cliente para que los reintentos sin conexión sean idempotentes.
    public let id: UUID
    public let parcheID: UUID
    public var concept: String
    /// Monto antes de la propina.
    public var baseAmount: Int
    public var tipPercent: Int
    /// Total con propina; es lo que suman los pagadores y las partes.
    public var amount: Int
    public var spentOn: Date
    public var split: ParcheSplit
    public var payers: [ParchePayer]
    public var shares: [ParcheShare]
    /// Participante que lo anotó.
    public var recordedBy: UUID
    public var createdAt: Date
    public var updatedAt: Date
    /// Participante que lo editó por última vez.
    public var updatedBy: UUID?
    public var deletedAt: Date?
    public var deletedBy: UUID?

    public init(
        id: UUID = UUID(), parcheID: UUID, concept: String, baseAmount: Int, tipPercent: Int, amount: Int,
        spentOn: Date, split: ParcheSplit, payers: [ParchePayer], shares: [ParcheShare], recordedBy: UUID,
        createdAt: Date, updatedAt: Date? = nil, updatedBy: UUID? = nil, deletedAt: Date? = nil, deletedBy: UUID? = nil
    ) {
        self.id = id
        self.parcheID = parcheID
        self.concept = concept
        self.baseAmount = baseAmount
        self.tipPercent = tipPercent
        self.amount = amount
        self.spentOn = spentOn
        self.split = split
        self.payers = payers
        self.shares = shares
        self.recordedBy = recordedBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.updatedBy = updatedBy
        self.deletedAt = deletedAt
        self.deletedBy = deletedBy
    }

    /// Valida y resuelve un gasto: concepto de 1 a 80, monto > 0, el reparto con propina y pagadores que suman el total.
    public static func resolve(
        id: UUID = UUID(), parcheID: UUID, concept: String, base: Int, tipPercent: Int = 0, split: ParcheSplit,
        payers: [ParchePayer], order: [UUID], recordedBy: UUID, at date: Date, spentOn: Date? = nil
    ) throws(ParcheExpenseError) -> ParcheExpense {
        let trimmed = concept.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...maxConceptLength).contains(trimmed.count) else { throw .invalidConcept }
        guard base > 0 else { throw .invalidAmount }
        let payers = payers.filter { $0.amount != 0 }
        guard !payers.isEmpty, payers.allSatisfy({ $0.amount > 0 }) else { throw .noPayers }
        let allocation: ParcheAllocation
        do {
            allocation = try Allocation.allocate(base: base, split: split, tipPercent: tipPercent, order: order)
        } catch {
            throw .split(error)
        }
        let paid = payers.map(\.amount).reduce(0, +)
        guard paid == allocation.total else { throw .payersDoNotMatch(paid: paid, total: allocation.total) }
        return ParcheExpense(
            id: id, parcheID: parcheID, concept: trimmed, baseAmount: base, tipPercent: tipPercent,
            amount: allocation.total, spentOn: spentOn ?? date, split: split, payers: payers, shares: allocation.shares,
            recordedBy: recordedBy, createdAt: date)
    }

    public var isDeleted: Bool { deletedAt != nil }

    /// Lo que le toca a esa persona.
    public func share(of participantID: UUID) -> Int {
        shares.filter { $0.participantID == participantID }.map(\.amount).reduce(0, +)
    }

    /// Lo que pagó esa persona.
    public func paid(by participantID: UUID) -> Int {
        payers.filter { $0.participantID == participantID }.map(\.amount).reduce(0, +)
    }

    /// Quien más pagó (en empate, el primero de la lista). Lo usa el aviso de duplicado.
    public var mainPayerID: UUID? {
        payers.enumerated().max { lhs, rhs in
            lhs.element.amount != rhs.element.amount ? lhs.element.amount < rhs.element.amount : lhs.offset > rhs.offset
        }?.element.participantID
    }
}

/// Un pago entre dos personas del parche. Solo cuenta en el saldo cuando está confirmado.
public struct ParchePayment: Identifiable, Codable, Hashable, Sendable {
    /// Generado en el cliente para que los reintentos sin conexión sean idempotentes.
    public let id: UUID
    public let parcheID: UUID
    /// Quien pagó.
    public var fromID: UUID
    /// Quien recibió.
    public var toID: UUID
    public var amount: Int
    /// Participante que lo anotó.
    public var recordedBy: UUID
    public var createdAt: Date
    public var confirmedAt: Date?

    public init(
        id: UUID = UUID(), parcheID: UUID, fromID: UUID, toID: UUID, amount: Int, recordedBy: UUID, createdAt: Date,
        confirmedAt: Date? = nil
    ) {
        self.id = id
        self.parcheID = parcheID
        self.fromID = fromID
        self.toID = toID
        self.amount = amount
        self.recordedBy = recordedBy
        self.createdAt = createdAt
        self.confirmedAt = confirmedAt
    }

    public var isConfirmed: Bool { confirmedAt != nil }
}

/// Una transferencia del plan "Para saldar" que uno de los dos propuso pasar a su cruce. Solo cuando la otra persona
/// la acepta se crea el movimiento en el cruce y, en el parche, cuenta como un pago confirmado de `fromID` a `toID`.
public struct ParcheCruceTransfer: Identifiable, Codable, Hashable, Sendable {
    /// Igual que `parche_cruce_transfers.status`.
    public enum Status: String, Codable, Hashable, Sendable {
        /// Por confirmar: la otra persona todavía no responde.
        case pending
        /// Pasó al cruce.
        case accepted
        /// La otra persona no aceptó: la deuda sigue en el parche.
        case rejected
    }

    public let id: UUID
    public let parcheID: UUID
    /// Quien debía.
    public var fromID: UUID
    /// A quien le debían.
    public var toID: UUID
    public var amount: Int
    /// El movimiento que se creó en el cruce (al aceptarla).
    public var movementID: UUID?
    public var createdAt: Date
    public var status: Status
    /// Participante que la propuso (`nil` en las que pasaron al cruce antes de que hubiera que aceptarlas).
    public var proposedBy: UUID?
    /// Cuándo la otra persona la aceptó o la rechazó.
    public var respondedAt: Date?

    public init(
        id: UUID = UUID(), parcheID: UUID, fromID: UUID, toID: UUID, amount: Int, movementID: UUID? = nil,
        createdAt: Date, status: Status = .accepted, proposedBy: UUID? = nil, respondedAt: Date? = nil
    ) {
        self.id = id
        self.parcheID = parcheID
        self.fromID = fromID
        self.toID = toID
        self.amount = amount
        self.movementID = movementID
        self.createdAt = createdAt
        self.status = status
        self.proposedBy = proposedBy
        self.respondedAt = respondedAt
    }

    enum CodingKeys: String, CodingKey {
        case id, parcheID, fromID, toID, amount, movementID, createdAt, status, proposedBy, respondedAt
    }

    /// Lo guardado antes de que hubiera que aceptarlas no trae `status`: ya había pasado al cruce.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        parcheID = try container.decode(UUID.self, forKey: .parcheID)
        fromID = try container.decode(UUID.self, forKey: .fromID)
        toID = try container.decode(UUID.self, forKey: .toID)
        amount = try container.decode(Int.self, forKey: .amount)
        movementID = try container.decodeIfPresent(UUID.self, forKey: .movementID)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        status = try container.decodeIfPresent(Status.self, forKey: .status) ?? .accepted
        proposedBy = try container.decodeIfPresent(UUID.self, forKey: .proposedBy)
        respondedAt = try container.decodeIfPresent(Date.self, forKey: .respondedAt)
    }

    public var isAccepted: Bool { status == .accepted }
    public var isPending: Bool { status == .pending }

    /// Es entre esas dos personas, sin importar quién le debía a quién.
    public func isBetween(_ a: UUID, _ b: UUID) -> Bool {
        (fromID == a && toID == b) || (fromID == b && toID == a)
    }
}
