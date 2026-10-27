import Foundation

/// Traducción entre las filas de `movements` (PostgREST) y `Movement`. No depende de supabase-swift:
/// `SupabaseLedgerRepository` hace las peticiones y aquí se decodifican y se arman las filas, para probarlo con
/// `swift test`. Las fechas usan las mismas funciones que los parches (`ParcheRemote`), que conservan los microsegundos.
public enum MovementRemote {
    /// Columnas que se leen de `movements`: todo lo que usa `Movement` (sin `owed_by_other`, que la app calcula).
    public static let select =
        "id, kind, payer_id, amount, concept, category, split_type, other_share_percent, payment_method, "
        + "occurred_at, created_by, deleted_at"

    private struct ReadRow: Decodable {
        let id: UUID
        let kind: Movement.Kind
        let payerId: UUID
        let amount: Int
        let concept: String
        let category: MovementCategory
        let splitType: String
        let otherSharePercent: Int
        let paymentMethod: String?
        let occurredAt: Date
        let createdBy: UUID
        let deletedAt: Date?

        enum CodingKeys: String, CodingKey {
            case id, kind, amount, concept, category
            case payerId = "payer_id"
            case splitType = "split_type"
            case otherSharePercent = "other_share_percent"
            case paymentMethod = "payment_method"
            case occurredAt = "occurred_at"
            case createdBy = "created_by"
            case deletedAt = "deleted_at"
        }
    }

    /// Las filas de `movements` como movimientos, en el mismo orden. Un reparto o un tipo desconocido es un error.
    public static func movements(from data: Data) throws -> [Movement] {
        try ParcheRemote.decoder().decode([ReadRow].self, from: data).map { row in
            Movement(
                id: row.id, kind: row.kind, payerID: row.payerId, amount: row.amount, concept: row.concept,
                category: row.category, split: try split(type: row.splitType, percent: row.otherSharePercent),
                date: row.occurredAt, createdBy: row.createdBy, paymentMethod: row.paymentMethod,
                deletedAt: row.deletedAt)
        }
    }

    /// `split_type` y `other_share_percent` de la base como `SplitRule`.
    static func split(type: String, percent: Int) throws -> SplitRule {
        switch type {
        case "equal": return .equal
        case "full_other": return .fullOther
        case "percentage": return .percentage(otherShare: percent)
        default:
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Reparto desconocido: \(type)"))
        }
    }

    /// La fila que se envía para crear o editar un movimiento (`upsert` por `id`). No lleva `owed_by_other` (columna
    /// generada) ni `created_at` y `updated_at` (los pone la base). `payment_method` y `deleted_at` van aunque sean
    /// `nil`, para que la fila quede igual al movimiento.
    public struct Row: Encodable, Sendable {
        let id: UUID
        let ledgerId: UUID
        let kind: String
        let payerId: UUID
        let amount: Int
        let concept: String
        let category: String
        let splitType: String
        let otherSharePercent: Int
        let paymentMethod: String?
        let occurredAt: String
        let createdBy: UUID
        let deletedAt: String?

        enum CodingKeys: String, CodingKey {
            case id, kind, amount, concept, category
            case ledgerId = "ledger_id"
            case payerId = "payer_id"
            case splitType = "split_type"
            case otherSharePercent = "other_share_percent"
            case paymentMethod = "payment_method"
            case occurredAt = "occurred_at"
            case createdBy = "created_by"
            case deletedAt = "deleted_at"
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(ledgerId, forKey: .ledgerId)
            try container.encode(kind, forKey: .kind)
            try container.encode(payerId, forKey: .payerId)
            try container.encode(amount, forKey: .amount)
            try container.encode(concept, forKey: .concept)
            try container.encode(category, forKey: .category)
            try container.encode(splitType, forKey: .splitType)
            try container.encode(otherSharePercent, forKey: .otherSharePercent)
            try container.encode(paymentMethod, forKey: .paymentMethod)
            try container.encode(occurredAt, forKey: .occurredAt)
            try container.encode(createdBy, forKey: .createdBy)
            try container.encode(deletedAt, forKey: .deletedAt)
        }
    }

    /// El movimiento como fila de ese cruce.
    public static func row(for movement: Movement, cruce: UUID) -> Row {
        let splitType: String =
            switch movement.split {
            case .equal: "equal"
            case .percentage: "percentage"
            case .fullOther: "full_other"
            }
        return Row(
            id: movement.id, ledgerId: cruce, kind: movement.kind.rawValue, payerId: movement.payerID,
            amount: movement.amount, concept: movement.concept, category: movement.category.rawValue,
            splitType: splitType, otherSharePercent: movement.split.otherSharePercent,
            paymentMethod: movement.paymentMethod, occurredAt: ParcheRemote.timestamp(movement.date),
            createdBy: movement.createdBy, deletedAt: movement.deletedAt.map(ParcheRemote.timestamp))
    }
}
