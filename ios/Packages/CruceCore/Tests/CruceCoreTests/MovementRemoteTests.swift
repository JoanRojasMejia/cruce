import Foundation
import Testing

@testable import CruceCore

@Suite("JSON de los movimientos")
struct MovementRemoteTests {
    private let joan = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private let jesus = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    private let cruce = UUID(uuidString: "aaaaaaaa-0000-0000-0000-000000000001")!

    /// Una fila de `movements` como la devuelve PostgREST.
    private func row(
        id: String = "bbbbbbbb-0000-0000-0000-000000000001", kind: String = "expense", split: String = "equal",
        percent: Int = 50, method: String = "null", deleted: String = "null"
    ) -> String {
        """
        {"id": "\(id)", "kind": "\(kind)", "payer_id": "\(joan)", "amount": 60000, "concept": "Cena",
         "category": "comida", "split_type": "\(split)", "other_share_percent": \(percent),
         "payment_method": \(method), "occurred_at": "2026-10-27T20:15:00.123456+00:00",
         "created_by": "\(joan)", "deleted_at": \(deleted)}
        """
    }

    private func decode(_ rows: String...) throws -> [Movement] {
        try MovementRemote.movements(from: Data("[\(rows.joined(separator: ","))]".utf8))
    }

    @Test(
        "Cada reparto de la base se vuelve su SplitRule",
        arguments: [
            ("equal", 50, SplitRule.equal),
            ("percentage", 30, .percentage(otherShare: 30)),
            ("full_other", 100, .fullOther),
        ])
    func splits(type: String, percent: Int, expected: SplitRule) throws {
        let movement = try #require(try decode(row(split: type, percent: percent)).first)
        #expect(movement.split == expected)
    }

    @Test("Una fila completa trae todos los datos del movimiento")
    func fullRow() throws {
        let movement = try #require(try decode(row()).first)
        #expect(movement.id == UUID(uuidString: "bbbbbbbb-0000-0000-0000-000000000001"))
        #expect(movement.kind == .expense)
        #expect(movement.payerID == joan)
        #expect(movement.amount == 60_000)
        #expect(movement.concept == "Cena")
        #expect(movement.category == .comida)
        #expect(movement.createdBy == joan)
        #expect(movement.paymentMethod == nil)
        #expect(movement.deletedAt == nil)
        #expect(ParcheRemote.timestamp(movement.date) == "2026-10-27T20:15:00.123456Z")
    }

    @Test("Un pago para saldar trae su medio de pago")
    func settlement() throws {
        let movement = try #require(
            try decode(row(kind: "settlement", split: "full_other", percent: 100, method: "\"Nequi\"")).first)
        #expect(movement.kind == .settlement)
        #expect(movement.split == .fullOther)
        #expect(movement.paymentMethod == "Nequi")
    }

    @Test("Un movimiento eliminado conserva la fecha del borrado")
    func deleted() throws {
        let movement = try #require(try decode(row(deleted: "\"2026-10-28T08:00:00+00:00\"")).first)
        #expect(movement.isDeleted)
    }

    @Test(
        "Un reparto o un tipo que la app no conoce no se acepta",
        arguments: [("raro", "expense"), ("equal", "regalo")])
    func unknownValues(split: String, kind: String) {
        #expect(throws: (any Error).self) { try decode(row(kind: kind, split: split)) }
    }

    @Test("La fila para guardar lleva el cruce, el reparto y la fecha con microsegundos, sin columnas de la base")
    func rowForSave() throws {
        let date = try #require(ParcheRemote.parseTimestamp("2026-10-27T20:15:00.123456+00:00"))
        let movement = Movement(
            payerID: jesus, amount: 100_000, concept: "Mercado", category: .mercado,
            split: .percentage(otherShare: 30), date: date, createdBy: jesus)
        let data = try JSONEncoder().encode(MovementRemote.row(for: movement, cruce: cruce))
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["id"] as? String == movement.id.uuidString)
        #expect(json["ledger_id"] as? String == cruce.uuidString)
        #expect(json["kind"] as? String == "expense")
        #expect(json["payer_id"] as? String == jesus.uuidString)
        #expect(json["amount"] as? Int == 100_000)
        #expect(json["split_type"] as? String == "percentage")
        #expect(json["other_share_percent"] as? Int == 30)
        #expect(json["occurred_at"] as? String == "2026-10-27T20:15:00.123456Z")
        #expect(json["created_by"] as? String == jesus.uuidString)
        #expect(json["payment_method"] is NSNull)
        #expect(json["deleted_at"] is NSNull)
        #expect(json["owed_by_other"] == nil)
        #expect(json["created_at"] == nil)
        #expect(json["updated_at"] == nil)
    }

    @Test("Ida y vuelta: guardar y leer da el mismo movimiento")
    func roundTrip() throws {
        let original = Movement(
            kind: .settlement, payerID: joan, amount: 20_000, concept: "Saldar cuentas", category: .otro,
            split: .fullOther, date: try #require(ParcheRemote.parseTimestamp("2026-10-27T10:00:00.5+00:00")),
            createdBy: joan, paymentMethod: "Efectivo")
        let encoded = try JSONEncoder().encode([MovementRemote.row(for: original, cruce: cruce)])
        #expect(try MovementRemote.movements(from: encoded) == [original])
    }
}
