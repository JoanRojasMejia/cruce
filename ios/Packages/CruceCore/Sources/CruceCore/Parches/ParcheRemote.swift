import Foundation

/// Traducción entre el JSON de Supabase (PostgREST) y los modelos de parches. No depende de supabase-swift:
/// `SupabaseParcheRepository` hace las peticiones y aquí se decodifican las filas, se arman los parámetros de las
/// funciones y se traducen los errores. Así todo esto se prueba con `swift test`.
public enum ParcheRemote {
    /// Lo que se pide de `parches` en una sola consulta: cada parche con todo lo suyo embebido (RLS solo deja ver
    /// los parches de quien pregunta).
    public static let detailSelect = """
        id, name, code, status, created_at, closed_at, created_by, parche_participants(*, participant_username), \
        parche_expenses(*, parche_expense_payers(participant_id, amount), \
        parche_expense_shares(participant_id, amount, input), \
        parche_expense_items(id, position, amount, participant_ids, name)), \
        parche_payments(*), parche_cruce_transfers(*), parche_activity(*)
        """

    // MARK: - Fechas

    /// `timestamptz` de PostgREST (`2026-10-26T10:00:00.123456+00:00`, con o sin fracción) a `Date`, sin perder
    /// los microsegundos.
    /// También acepta el formato de Supabase Realtime (`2026-10-26 10:00:00.123456+00`): espacio en vez de `T` y zona
    /// sin minutos.
    public static func parseTimestamp(_ text: String) -> Date? {
        var text = text.replacingOccurrences(of: " ", with: "T")
        if let sign = text.lastIndex(where: { $0 == "+" || $0 == "-" }), sign > (text.firstIndex(of: "T") ?? sign),
            text[text.index(after: sign)...].count == 2
        {
            text += ":00"
        }
        var base = text
        var fraction = 0.0
        if let dot = text.firstIndex(of: "."), let tIndex = text.firstIndex(of: "T"), dot > tIndex {
            let afterDot = text.index(after: dot)
            let end = text[afterDot...].firstIndex { !$0.isNumber } ?? text.endIndex
            let digits = text[afterDot..<end]
            if let value = Double("0." + digits) { fraction = value }
            base = String(text[..<dot]) + String(text[end...])
        }
        guard let date = try? Date.ISO8601FormatStyle().parse(base) else { return nil }
        return date.addingTimeInterval(fraction)
    }

    /// `Date` a texto ISO 8601 en UTC con microsegundos, la misma precisión que guarda Postgres. Reenviar la misma
    /// fecha da siempre el mismo texto (y la base reconoce el reintento como el mismo gasto).
    public static func timestamp(_ date: Date) -> String {
        let micros = Int64((date.timeIntervalSince1970 * 1_000_000).rounded())
        let seconds = micros >= 0 ? micros / 1_000_000 : (micros - 999_999) / 1_000_000
        let fraction = micros - seconds * 1_000_000
        let whole = Date(timeIntervalSince1970: TimeInterval(seconds))
        let text = whole.formatted(Date.ISO8601FormatStyle())  // 2026-10-26T10:00:00Z
        let padded = String(fraction)
        return String(text.dropLast()) + "." + String(repeating: "0", count: 6 - padded.count) + padded + "Z"
    }

    /// Decodificador para las filas: fechas de Postgres y `bigint` como `Int`.
    public static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            guard let date = parseTimestamp(text) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Fecha inválida: \(text)")
            }
            return date
        }
        return decoder
    }

    // MARK: - Filas

    public struct ParticipantRow: Decodable, Sendable {
        let id: UUID
        let userID: UUID?
        let displayName: String
        let claimCode: String?
        let joinedAt: Date
        let lastSeenAt: Date?
        /// Opcional para seguir leyendo una base sin la migración de colores (queda amarillo).
        let avatarColor: AvatarColor?
        /// El campo calculado `participant_username` (solo en `detailSelect`) y `account_deleted_at`.
        let username: String?
        let accountDeletedAt: Date?

        enum CodingKeys: String, CodingKey {
            case id
            case userID = "user_id"
            case displayName = "display_name"
            case claimCode = "claim_code"
            case joinedAt = "joined_at"
            case lastSeenAt = "last_seen_at"
            case avatarColor = "avatar_color"
            case username = "participant_username"
            case accountDeletedAt = "account_deleted_at"
        }

        var model: ParcheParticipant {
            ParcheParticipant(
                id: id, userID: userID, displayName: displayName, claimCode: claimCode, joinedAt: joinedAt,
                lastSeenAt: lastSeenAt, avatarColor: avatarColor ?? .yellow, username: username,
                accountDeletedAt: accountDeletedAt)
        }
    }

    struct PayerRow: Decodable {
        let participantID: UUID
        let amount: Int

        enum CodingKeys: String, CodingKey {
            case participantID = "participant_id"
            case amount
        }
    }

    struct ShareRow: Decodable {
        let participantID: UUID
        let amount: Int
        let input: Int?

        enum CodingKeys: String, CodingKey {
            case participantID = "participant_id"
            case amount, input
        }
    }

    struct ItemRow: Decodable {
        let id: UUID
        let position: Int
        let amount: Int
        let participantIDs: [UUID]
        /// Opcional: sin la columna (antes de `items_con_nombre`) llega `nil`.
        let name: String?

        enum CodingKeys: String, CodingKey {
            case id, position, amount, name
            case participantIDs = "participant_ids"
        }
    }

    struct ExpenseRow: Decodable {
        let id: UUID
        let parcheID: UUID
        let concept: String
        let baseAmount: Int
        let tipPercent: Int
        let amount: Int
        let spentOn: Date
        let splitMethod: String
        let recordedBy: UUID
        let createdAt: Date
        let updatedAt: Date
        let updatedBy: UUID?
        let deletedAt: Date?
        let deletedBy: UUID?
        let payers: [PayerRow]?
        let shares: [ShareRow]?
        let items: [ItemRow]?

        enum CodingKeys: String, CodingKey {
            case id, concept, amount
            case parcheID = "parche_id"
            case baseAmount = "base_amount"
            case tipPercent = "tip_percent"
            case spentOn = "spent_on"
            case splitMethod = "split_method"
            case recordedBy = "recorded_by"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
            case updatedBy = "updated_by"
            case deletedAt = "deleted_at"
            case deletedBy = "deleted_by"
            case payers = "parche_expense_payers"
            case shares = "parche_expense_shares"
            case items = "parche_expense_items"
        }

        /// El gasto con pagadores y partes en el orden del parche. El reparto se reconstruye del dato de entrada
        /// de cada parte (`input`) o de los ítems.
        func model(order: [UUID]) throws -> ParcheExpense {
            let rank = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($1, $0) })
            let position = { (id: UUID) in rank[id] ?? Int.max }
            let shares = (shares ?? []).sorted { position($0.participantID) < position($1.participantID) }
            let payers = (payers ?? []).sorted { position($0.participantID) < position($1.participantID) }
            let split: ParcheSplit
            switch splitMethod {
            case "equal": split = .equal(Set(shares.map(\.participantID)))
            case "shares":
                split = .shares(Dictionary(uniqueKeysWithValues: shares.map { ($0.participantID, $0.input ?? 0) }))
            case "percentage":
                split = .percentage(
                    Dictionary(uniqueKeysWithValues: shares.map { ($0.participantID, $0.input ?? 0) }))
            case "items":
                split = .items(
                    (items ?? []).sorted { $0.position < $1.position }.map {
                        ParcheSplitItem(
                            id: $0.id, amount: $0.amount, participantIDs: Set($0.participantIDs), name: $0.name)
                    })
            default:
                throw DecodingError.dataCorrupted(
                    .init(codingPath: [CodingKeys.splitMethod], debugDescription: "Reparto desconocido: \(splitMethod)")
                )
            }
            return ParcheExpense(
                id: id, parcheID: parcheID, concept: concept, baseAmount: baseAmount, tipPercent: tipPercent,
                amount: amount, spentOn: spentOn, split: split,
                payers: payers.map { ParchePayer(participantID: $0.participantID, amount: $0.amount) },
                shares: shares.map { ParcheShare(participantID: $0.participantID, amount: $0.amount) },
                recordedBy: recordedBy, createdAt: createdAt, updatedAt: updatedAt, updatedBy: updatedBy,
                deletedAt: deletedAt, deletedBy: deletedBy)
        }
    }

    public struct PaymentRow: Decodable, Sendable {
        let id: UUID
        let parcheID: UUID
        let fromID: UUID
        let toID: UUID
        let amount: Int
        let recordedBy: UUID
        let createdAt: Date
        let confirmedAt: Date?

        enum CodingKeys: String, CodingKey {
            case id, amount
            case parcheID = "parche_id"
            case fromID = "from_id"
            case toID = "to_id"
            case recordedBy = "recorded_by"
            case createdAt = "created_at"
            case confirmedAt = "confirmed_at"
        }

        var model: ParchePayment {
            ParchePayment(
                id: id, parcheID: parcheID, fromID: fromID, toID: toID, amount: amount, recordedBy: recordedBy,
                createdAt: createdAt, confirmedAt: confirmedAt)
        }
    }

    public struct TransferRow: Decodable, Sendable {
        let id: UUID
        let parcheID: UUID
        let fromID: UUID
        let toID: UUID
        let amount: Int
        let movementID: UUID?
        let createdAt: Date
        /// `nil` en respuestas de antes de que hubiera que aceptarlas: ya habían pasado al cruce.
        let status: ParcheCruceTransfer.Status?
        let proposedBy: UUID?
        let respondedAt: Date?

        enum CodingKeys: String, CodingKey {
            case id, amount, status
            case parcheID = "parche_id"
            case fromID = "from_id"
            case toID = "to_id"
            case movementID = "movement_id"
            case createdAt = "created_at"
            case proposedBy = "proposed_by"
            case respondedAt = "responded_at"
        }

        var model: ParcheCruceTransfer {
            ParcheCruceTransfer(
                id: id, parcheID: parcheID, fromID: fromID, toID: toID, amount: amount, movementID: movementID,
                createdAt: createdAt, status: status ?? .accepted, proposedBy: proposedBy, respondedAt: respondedAt)
        }
    }

    public struct ActivityRow: Decodable, Sendable {
        let id: UUID
        let parcheID: UUID
        let kind: ParcheActivityKind
        let actorID: UUID?
        let participantID: UUID?
        let otherParticipantID: UUID?
        let recordedByID: UUID?
        let amount: Int?
        let concept: String?
        let createdAt: Date

        enum CodingKeys: String, CodingKey {
            case id, kind, amount, concept
            case parcheID = "parche_id"
            case actorID = "actor_id"
            case participantID = "participant_id"
            case otherParticipantID = "other_participant_id"
            case recordedByID = "recorded_by_id"
            case createdAt = "created_at"
        }

        var model: ParcheActivity {
            ParcheActivity(
                id: id, parcheID: parcheID, kind: kind, actorID: actorID, participantID: participantID,
                otherParticipantID: otherParticipantID, recordedByID: recordedByID, amount: amount, concept: concept,
                createdAt: createdAt)
        }
    }

    struct ParcheRow: Decodable {
        let id: UUID
        let name: String
        let code: String
        let status: ParcheStatus
        let createdAt: Date
        let closedAt: Date?
        let createdBy: UUID?
        let participants: [ParticipantRow]?
        let expenses: [ExpenseRow]?
        let payments: [PaymentRow]?
        let transfers: [TransferRow]?
        let activity: [ActivityRow]?

        enum CodingKeys: String, CodingKey {
            case id, name, code, status
            case createdAt = "created_at"
            case closedAt = "closed_at"
            case createdBy = "created_by"
            case participants = "parche_participants"
            case expenses = "parche_expenses"
            case payments = "parche_payments"
            case transfers = "parche_cruce_transfers"
            case activity = "parche_activity"
        }
    }

    /// Columnas de `ledger_members` que se leen para saber con quién comparte un cruce abierto.
    public static let memberSelect = "ledger_id, user_id, ledgers(closed_at)"

    /// Una fila de `ledger_members` (solo lo que hace falta para saber con quién comparte un cruce abierto).
    public struct LedgerMemberRow: Decodable, Hashable, Sendable {
        public let ledgerID: UUID
        public let userID: UUID
        /// Cuándo se cerró el cruce (`ledgers.closed_at`); `nil` si sigue abierto.
        public let closedAt: Date?

        public init(ledgerID: UUID, userID: UUID, closedAt: Date? = nil) {
            self.ledgerID = ledgerID
            self.userID = userID
            self.closedAt = closedAt
        }

        enum CodingKeys: String, CodingKey {
            case ledgerID = "ledger_id"
            case userID = "user_id"
            case ledger = "ledgers"
        }

        private struct Ledger: Decodable {
            let closedAt: Date?

            enum CodingKeys: String, CodingKey {
                case closedAt = "closed_at"
            }
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            ledgerID = try container.decode(UUID.self, forKey: .ledgerID)
            userID = try container.decode(UUID.self, forKey: .userID)
            closedAt = try container.decodeIfPresent(Ledger.self, forKey: .ledger)?.closedAt
        }
    }

    // MARK: - Armar los modelos

    /// Las cuentas con las que `userID` comparte un cruce abierto, según las filas de `ledger_members` que deja ver
    /// RLS. Un cruce cerrado (desvinculado) no cuenta.
    public static func crucePartners(of userID: UUID, members: [LedgerMemberRow]) -> Set<UUID> {
        let myLedgers = Set(members.filter { $0.userID == userID && $0.closedAt == nil }.map(\.ledgerID))
        return Set(members.filter { myLedgers.contains($0.ledgerID) && $0.userID != userID }.map(\.userID))
    }

    /// Los parches de la respuesta de `parches?select=detailSelect`, vistos por `userID`.
    public static func details(from data: Data, userID: UUID, crucePartners: Set<UUID>) throws -> [ParcheDetail] {
        try decoder().decode([ParcheRow].self, from: data).map { row in
            let participants = (row.participants ?? []).map(\.model)
            var detail = ParcheDetail(
                parche: Parche(
                    id: row.id, name: row.name, code: row.code, status: row.status, createdAt: row.createdAt,
                    closedAt: row.closedAt, createdBy: row.createdBy),
                participants: participants)
            let order = detail.order
            detail.participants = order.compactMap { id in participants.first { $0.id == id } }
            detail.expenses = try (row.expenses ?? []).map { try $0.model(order: order) }
            detail.payments = (row.payments ?? []).map(\.model)
            detail.transfers = (row.transfers ?? []).map(\.model)
            detail.activity = (row.activity ?? []).map(\.model)
            detail.myParticipantID = participants.first { $0.userID == userID }?.id
            detail.crucePartnerIDs = Set(
                participants.filter { $0.userID.map(crucePartners.contains) ?? false }.map(\.id))
            return detail
        }
    }

    public static func members(from data: Data) throws -> [LedgerMemberRow] {
        try decoder().decode([LedgerMemberRow].self, from: data)
    }

    public static func activity(from data: Data) throws -> [ParcheActivity] {
        try decoder().decode([ActivityRow].self, from: data).map(\.model)
    }

    /// La fila que devuelve `add_parche_participant`.
    public static func participant(from data: Data) throws -> ParcheParticipant {
        try decoder().decode(ParticipantRow.self, from: data).model
    }

    /// La fila que devuelven `propose_parche_debt_to_cruce`, `accept_parche_cruce_transfer` y
    /// `reject_parche_cruce_transfer`.
    public static func transfer(from data: Data) throws -> ParcheCruceTransfer {
        try decoder().decode(TransferRow.self, from: data).model
    }

    private struct CodePreviewResponse: Decodable {
        let ok: Bool
        let kind: String?
        let parcheName: String?
        let personName: String?
        let alreadyMember: Bool?
        let error: String?
        let message: String?

        enum CodingKeys: String, CodingKey {
            case ok, kind, error, message
            case parcheName = "parche_name"
            case personName = "person_name"
            case alreadyMember = "already_member"
        }
    }

    /// Lo que devuelve `preview_parche_code`: `{"ok": true, "kind": "parche", "parche_name", "already_member"}`,
    /// `{"ok": true, "kind": "place", "parche_name", "person_name"}` o `{"ok": false, "error", "message"}`. Un `error`
    /// que la app no conoce se trata como código que no existe, con el mensaje de la base.
    public static func codePreview(from data: Data) throws -> CodePreview {
        let response = try decoder().decode(CodePreviewResponse.self, from: data)
        guard response.ok else {
            let rejection = response.error.flatMap(CodeRejection.init(rawValue:)) ?? .invalid
            return .rejected(rejection, message: response.message ?? rejection.defaultMessage)
        }
        switch (response.kind, response.parcheName, response.personName) {
        case ("parche"?, let name?, _): return .parche(name: name, alreadyMember: response.alreadyMember ?? false)
        case ("place"?, let parche?, let person?): return .place(parcheName: parche, personName: person)
        default:
            throw DecodingError.dataCorrupted(
                .init(codingPath: [], debugDescription: "Vista previa de código sin tipo o sin nombre"))
        }
    }

    /// El `uuid` que devuelven `create_parche`, `join_parche` y `claim_parche_place`.
    public static func uuid(from data: Data) throws -> UUID {
        try decoder().decode(UUID.self, from: data)
    }

    /// Lo que devuelven `join_parche` y `claim_parche_place`: el id del parche, o `null` si el código no sirve (la base
    /// no lanza el error para no deshacer el intento fallido que registró).
    public static func joinedParcheID(from data: Data) throws -> UUID {
        guard let id = try decoder().decode(UUID?.self, from: data) else { throw ParcheRepositoryError.invalidCode }
        return id
    }

    // MARK: - Parámetros de las funciones

    public struct CreateParams: Encodable, Sendable {
        let pName: String
        let pDisplayName: String
        let pID: UUID

        public init(id: UUID, name: String, displayName: String) {
            pName = name
            pDisplayName = displayName
            pID = id
        }

        enum CodingKeys: String, CodingKey {
            case pName = "p_name"
            case pDisplayName = "p_display_name"
            case pID = "p_id"
        }
    }

    public struct JoinParams: Encodable, Sendable {
        let pCode: String
        let pDisplayName: String

        public init(code: String, displayName: String) {
            pCode = code
            pDisplayName = displayName
        }

        enum CodingKeys: String, CodingKey {
            case pCode = "p_code"
            case pDisplayName = "p_display_name"
        }
    }

    public struct AddParticipantParams: Encodable, Sendable {
        let pParche: UUID
        let pDisplayName: String
        let pID: UUID

        public init(id: UUID, parcheID: UUID, displayName: String) {
            pParche = parcheID
            pDisplayName = displayName
            pID = id
        }

        enum CodingKeys: String, CodingKey {
            case pParche = "p_parche"
            case pDisplayName = "p_display_name"
            case pID = "p_id"
        }
    }

    public struct CodeParams: Encodable, Sendable {
        let pCode: String

        public init(code: String) {
            pCode = code
        }

        enum CodingKeys: String, CodingKey {
            case pCode = "p_code"
        }
    }

    /// Para las funciones que solo reciben `p_id`.
    public struct IDParams: Encodable, Sendable {
        let pID: UUID

        public init(id: UUID) {
            pID = id
        }

        enum CodingKeys: String, CodingKey {
            case pID = "p_id"
        }
    }

    public struct SaveExpenseParams: Encodable, Sendable {
        struct Payer: Encodable, Sendable {
            let participantID: UUID
            let amount: Int

            enum CodingKeys: String, CodingKey {
                case participantID = "participant_id"
                case amount
            }
        }

        struct Share: Encodable, Sendable {
            let participantID: UUID
            let amount: Int
            let input: Int?

            enum CodingKeys: String, CodingKey {
                case participantID = "participant_id"
                case amount, input
            }

            // `input` va siempre, también como `null` (por consumo), igual que lo guarda la base.
            func encode(to encoder: any Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(participantID, forKey: .participantID)
                try container.encode(amount, forKey: .amount)
                try container.encode(input, forKey: .input)
            }
        }

        struct Item: Encodable, Sendable {
            let amount: Int
            let participantIDs: [UUID]
            /// Sin nombre no se manda la clave (la base lo guarda como null).
            let name: String?

            enum CodingKeys: String, CodingKey {
                case amount, name
                case participantIDs = "participant_ids"
            }
        }

        let pID: UUID
        let pParcheID: UUID
        let pConcept: String
        let pBaseAmount: Int
        let pTipPercent: Int
        let pAmount: Int
        let pSpentOn: String
        let pSplitMethod: String
        let pPayers: [Payer]
        let pShares: [Share]
        let pItems: [Item]

        public init(_ expense: ParcheExpense) {
            pID = expense.id
            pParcheID = expense.parcheID
            pConcept = expense.concept
            pBaseAmount = expense.baseAmount
            pTipPercent = expense.tipPercent
            pAmount = expense.amount
            pSpentOn = ParcheRemote.timestamp(expense.spentOn)
            pSplitMethod = expense.split.method
            pPayers = expense.payers.map { Payer(participantID: $0.participantID, amount: $0.amount) }
            pShares = expense.shares.map {
                Share(
                    participantID: $0.participantID, amount: $0.amount,
                    input: expense.split.input(for: $0.participantID))
            }
            if case .items(let items) = expense.split {
                pItems = items.map {
                    Item(
                        amount: $0.amount, participantIDs: $0.participantIDs.sorted { $0.uuidString < $1.uuidString },
                        name: $0.name)
                }
            } else {
                pItems = []
            }
        }

        enum CodingKeys: String, CodingKey {
            case pID = "p_id"
            case pParcheID = "p_parche_id"
            case pConcept = "p_concept"
            case pBaseAmount = "p_base_amount"
            case pTipPercent = "p_tip_percent"
            case pAmount = "p_amount"
            case pSpentOn = "p_spent_on"
            case pSplitMethod = "p_split_method"
            case pPayers = "p_payers"
            case pShares = "p_shares"
            case pItems = "p_items"
        }
    }

    public struct RecordPaymentParams: Encodable, Sendable {
        let pID: UUID
        let pParcheID: UUID
        let pFromID: UUID
        let pToID: UUID
        let pAmount: Int

        public init(_ payment: ParchePayment) {
            pID = payment.id
            pParcheID = payment.parcheID
            pFromID = payment.fromID
            pToID = payment.toID
            pAmount = payment.amount
        }

        enum CodingKeys: String, CodingKey {
            case pID = "p_id"
            case pParcheID = "p_parche_id"
            case pFromID = "p_from_id"
            case pToID = "p_to_id"
            case pAmount = "p_amount"
        }
    }

    /// Para `propose_parche_debt_to_cruce`.
    public struct ProposeCruceParams: Encodable, Sendable {
        let pParche: UUID
        let pOther: UUID

        public init(parcheID: UUID, otherParticipantID: UUID) {
            pParche = parcheID
            pOther = otherParticipantID
        }

        enum CodingKeys: String, CodingKey {
            case pParche = "p_parche"
            case pOther = "p_other"
        }
    }
}

extension ParcheRepositoryError {
    /// Traduce un error de la base: `P0001` con la pista (`hint`) que nombra el caso, `23514` (sumas y checks) como
    /// datos inválidos y `42501` (sin permiso, por ejemplo sin sesión) como no permitido. `nil` si no es de parches.
    public init?(databaseCode code: String?, hint: String?) {
        switch (code, hint) {
        case ("P0001", "invalidCode"?): self = .invalidCode
        case ("P0001", "alreadyParticipant"?): self = .alreadyParticipant
        case ("P0001", "notFound"?): self = .notFound
        case ("P0001", "notAllowed"?), ("P0001", "notAuthenticated"?), ("42501", _): self = .notAllowed
        case ("P0001", "parcheClosed"?): self = .parcheClosed
        case ("P0001", "parcheOpen"?): self = .parcheOpen
        case ("P0001", "invalidData"?), ("23514", _): self = .invalidData
        case ("P0001", "noSharedCruce"?): self = .noSharedCruce
        case ("P0001", "alreadyMoved"?): self = .alreadyMoved
        case ("P0001", "nothingToMove"?): self = .nothingToMove
        case ("P0001", "tooManyAttempts"?): self = .tooManyAttempts
        default: return nil
        }
    }
}
