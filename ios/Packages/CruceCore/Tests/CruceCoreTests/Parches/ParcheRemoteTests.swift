import Foundation
import Testing

@testable import CruceCore

@Suite("Traducción de parches con Supabase")
struct ParcheRemoteTests {
    private let me = UUID(uuidString: "00000000-0000-0000-0000-0000000000a1")!
    private let friend = UUID(uuidString: "00000000-0000-0000-0000-0000000000a2")!
    private let parcheID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
    // Participantes: Jesús (yo), Ana (con la app) y Carlos (sin la app).
    private let jesus = UUID(uuidString: "20000000-0000-0000-0000-000000000001")!
    private let ana = UUID(uuidString: "20000000-0000-0000-0000-000000000002")!
    private let carlos = UUID(uuidString: "20000000-0000-0000-0000-000000000003")!
    private let expenseID = UUID(uuidString: "30000000-0000-0000-0000-000000000001")!
    private let itemsID = UUID(uuidString: "30000000-0000-0000-0000-000000000002")!

    /// Respuesta de `parches?select=detailSelect` como la devuelve PostgREST (participantes desordenados).
    private var sample: Data {
        Data(
            """
            [{
              "id": "\(parcheID)", "name": "Santa Marta", "code": "PCH-ABC234", "status": "closed",
              "created_at": "2026-10-20T10:00:00.123456+00:00", "closed_at": "2026-10-25T18:30:00+00:00",
              "parche_participants": [
                {"id": "\(carlos)", "parche_id": "\(parcheID)", "user_id": null, "display_name": "Carlos",
                 "claim_code": "SOY-XYZ789", "joined_at": "2026-10-20T10:05:00+00:00", "last_seen_at": null},
                {"id": "\(jesus)", "parche_id": "\(parcheID)", "user_id": "\(me)", "display_name": "Jesús",
                 "claim_code": null, "joined_at": "2026-10-20T10:00:00.123456+00:00",
                 "last_seen_at": "2026-10-24T09:00:00+00:00"},
                {"id": "\(ana)", "parche_id": "\(parcheID)", "user_id": "\(friend)", "display_name": "Ana",
                 "claim_code": null, "joined_at": "2026-10-20T10:01:00+00:00", "last_seen_at": null}
              ],
              "parche_expenses": [
                {"id": "\(expenseID)", "parche_id": "\(parcheID)", "concept": "Hotel", "base_amount": 90000,
                 "tip_percent": 0, "amount": 90000, "spent_on": "2026-10-21T00:00:00+00:00",
                 "split_method": "percentage", "recorded_by": "\(jesus)",
                 "created_at": "2026-10-21T08:00:00+00:00", "updated_at": "2026-10-21T08:00:00+00:00",
                 "updated_by": null, "deleted_at": null, "deleted_by": null,
                 "parche_expense_payers": [{"participant_id": "\(ana)", "amount": 40000},
                                           {"participant_id": "\(jesus)", "amount": 50000}],
                 "parche_expense_shares": [{"participant_id": "\(carlos)", "amount": 45000, "input": 50},
                                           {"participant_id": "\(jesus)", "amount": 45000, "input": 50}],
                 "parche_expense_items": []},
                {"id": "\(itemsID)", "parche_id": "\(parcheID)", "concept": "Cena", "base_amount": 30000,
                 "tip_percent": 10, "amount": 33000, "spent_on": "2026-10-22T00:00:00+00:00",
                 "split_method": "items", "recorded_by": "\(ana)",
                 "created_at": "2026-10-22T08:00:00+00:00", "updated_at": "2026-10-22T09:00:00+00:00",
                 "updated_by": "\(jesus)", "deleted_at": "2026-10-23T09:00:00+00:00", "deleted_by": "\(ana)",
                 "parche_expense_payers": [{"participant_id": "\(ana)", "amount": 33000}],
                 "parche_expense_shares": [{"participant_id": "\(ana)", "amount": 16500, "input": null},
                                           {"participant_id": "\(jesus)", "amount": 16500, "input": null}],
                 "parche_expense_items": [
                   {"id": "40000000-0000-0000-0000-000000000002", "position": 1, "amount": 10000,
                    "participant_ids": ["\(jesus)"]},
                   {"id": "40000000-0000-0000-0000-000000000001", "position": 0, "amount": 20000,
                    "participant_ids": ["\(jesus)", "\(ana)"]}]}
              ],
              "parche_payments": [
                {"id": "50000000-0000-0000-0000-000000000001", "parche_id": "\(parcheID)", "from_id": "\(carlos)",
                 "to_id": "\(jesus)", "amount": 10000, "recorded_by": "\(ana)",
                 "created_at": "2026-10-23T10:00:00+00:00", "confirmed_at": null}
              ],
              "parche_cruce_transfers": [
                {"id": "60000000-0000-0000-0000-000000000001", "parche_id": "\(parcheID)", "from_id": "\(ana)",
                 "to_id": "\(jesus)", "amount": 5000, "movement_id": "70000000-0000-0000-0000-000000000001",
                 "created_at": "2026-10-25T19:00:00+00:00"}
              ],
              "parche_activity": [
                {"id": "80000000-0000-0000-0000-000000000001", "parche_id": "\(parcheID)", "kind": "expenseCreated",
                 "actor_id": "\(ana)", "participant_id": null, "other_participant_id": null,
                 "recorded_by_id": "\(ana)", "expense_id": "\(itemsID)", "payment_id": null, "amount": 33000,
                 "concept": "Cena", "created_at": "2026-10-24T10:00:00+00:00"},
                {"id": "80000000-0000-0000-0000-000000000002", "parche_id": "\(parcheID)", "kind": "parcheCreated",
                 "actor_id": "\(jesus)", "participant_id": null, "other_participant_id": null,
                 "recorded_by_id": null, "expense_id": null, "payment_id": null, "amount": null,
                 "concept": null, "created_at": "2026-10-20T10:00:00+00:00"}
              ]
            }]
            """.utf8)
    }

    private func decodeSample() throws -> ParcheDetail {
        let details = try ParcheRemote.details(from: sample, userID: me, crucePartners: [friend])
        #expect(details.count == 1)
        return try #require(details.first)
    }

    // MARK: - Lecturas

    @Test("El parche, sus participantes en orden de unión y quién soy yo")
    func parcheAndParticipants() throws {
        let detail = try decodeSample()
        #expect(detail.parche.name == "Santa Marta")
        #expect(detail.parche.code == "PCH-ABC234")
        #expect(detail.parche.status == .closed)
        #expect(detail.parche.closedAt != nil)
        #expect(detail.participants.map(\.id) == [jesus, ana, carlos])
        #expect(detail.myParticipantID == jesus)
        #expect(detail.crucePartnerIDs == [ana])
        #expect(detail.participant(carlos)?.claimCode == "SOY-XYZ789")
        #expect(detail.participant(carlos)?.hasApp == false)
    }

    @Test("Las fechas de Postgres conservan los microsegundos")
    func microseconds() throws {
        let date = try #require(ParcheRemote.parseTimestamp("2026-10-20T10:00:00.123456+00:00"))
        let whole = try #require(ParcheRemote.parseTimestamp("2026-10-20T10:00:00+00:00"))
        #expect(abs(date.timeIntervalSince(whole) - 0.123456) < 0.000_001)
        #expect(ParcheRemote.parseTimestamp("2026-10-20T05:00:00-05:00") == whole)
        #expect(ParcheRemote.parseTimestamp("ayer") == nil)
    }

    @Test("Una fecha enviada se vuelve a leer igual (reintentos idempotentes)")
    func timestampRoundTrip() throws {
        let text = ParcheRemote.timestamp(try #require(ParcheRemote.parseTimestamp("2026-10-20T10:00:00.123456Z")))
        #expect(text == "2026-10-20T10:00:00.123456Z")
        #expect(ParcheRemote.timestamp(Date(timeIntervalSince1970: 0)) == "1970-01-01T00:00:00.000000Z")
        let now = Date()
        #expect(
            ParcheRemote.timestamp(try #require(ParcheRemote.parseTimestamp(ParcheRemote.timestamp(now))))
                == ParcheRemote.timestamp(now))
    }

    @Test("Un gasto por porcentaje con varios pagadores, ordenados como el parche")
    func percentageExpense() throws {
        let expense = try #require(try decodeSample().expenses.first { $0.id == expenseID })
        #expect(expense.split == .percentage([jesus: 50, carlos: 50]))
        #expect(
            expense.payers == [
                ParchePayer(participantID: jesus, amount: 50000), .init(participantID: ana, amount: 40000),
            ])
        #expect(expense.shares.map(\.participantID) == [jesus, carlos])
        #expect(expense.recordedBy == jesus)
        #expect(!expense.isDeleted)
    }

    @Test("Un gasto por consumo con propina y borrado suave")
    func itemsExpense() throws {
        let expense = try #require(try decodeSample().expenses.first { $0.id == itemsID })
        guard case .items(let items) = expense.split else {
            Issue.record("Se esperaba un reparto por consumo")
            return
        }
        #expect(items.map(\.amount) == [20000, 10000])
        #expect(items.first?.participantIDs == [jesus, ana])
        #expect(expense.tipPercent == 10)
        #expect(expense.amount == 33000)
        #expect(expense.isDeleted)
        #expect(expense.deletedBy == ana)
        #expect(expense.updatedBy == jesus)
    }

    @Test("Pagos pendientes, deudas pasadas al cruce y avisos sin ver")
    func paymentsTransfersActivity() throws {
        let detail = try decodeSample()
        #expect(detail.pendingPayments.count == 1)
        #expect(detail.transfers.first?.amount == 5000)
        #expect(detail.transfers.first?.movementID != nil)
        #expect(detail.activity.count == 2)
        // Solo el gasto de Ana es posterior a mi `last_seen_at`; el aviso de crear el parche es mío.
        #expect(detail.unseenCount == 1)
    }

    @Test("Equal y shares se reconstruyen del dato de entrada de cada parte")
    func equalAndShares() throws {
        func expense(method: String, inputs: [Int?]) -> Data {
            let shares = zip([jesus, ana], inputs).map { id, input in
                "{\"participant_id\": \"\(id)\", \"amount\": 500, \"input\": \(input.map(String.init) ?? "null")}"
            }
            return Data(
                """
                [{"id": "\(parcheID)", "name": "Cena", "code": "PCH-ABC234", "status": "open",
                  "created_at": "2026-10-20T10:00:00Z", "closed_at": null,
                  "parche_participants": [], "parche_payments": [], "parche_cruce_transfers": [], "parche_activity": [],
                  "parche_expenses": [{"id": "\(expenseID)", "parche_id": "\(parcheID)", "concept": "Taxi",
                    "base_amount": 1000, "tip_percent": 0, "amount": 1000, "spent_on": "2026-10-21T00:00:00Z",
                    "split_method": "\(method)", "recorded_by": "\(jesus)", "created_at": "2026-10-21T00:00:00Z",
                    "updated_at": "2026-10-21T00:00:00Z", "updated_by": null, "deleted_at": null, "deleted_by": null,
                    "parche_expense_payers": [{"participant_id": "\(jesus)", "amount": 1000}],
                    "parche_expense_shares": [\(shares.joined(separator: ","))], "parche_expense_items": []}]}]
                """.utf8)
        }
        let equal = try ParcheRemote.details(
            from: expense(method: "equal", inputs: [1, 1]), userID: me, crucePartners: [])
        #expect(equal.first?.expenses.first?.split == .equal([jesus, ana]))
        #expect(equal.first?.myParticipantID == nil)
        let shares = try ParcheRemote.details(
            from: expense(method: "shares", inputs: [2, 3]), userID: me, crucePartners: [])
        #expect(shares.first?.expenses.first?.split == .shares([jesus: 2, ana: 3]))
        #expect(throws: DecodingError.self) {
            try ParcheRemote.details(from: expense(method: "magia", inputs: [1, 1]), userID: me, crucePartners: [])
        }
    }

    @Test("Con quién comparto un cruce sale de ledger_members")
    func crucePartners() throws {
        let ledger = UUID()
        let other = UUID()
        let members = try ParcheRemote.members(
            from: Data(
                """
                [{"ledger_id": "\(ledger)", "user_id": "\(me)"}, {"ledger_id": "\(ledger)", "user_id": "\(friend)"},
                 {"ledger_id": "\(other)", "user_id": "\(UUID())"}]
                """.utf8))
        #expect(ParcheRemote.crucePartners(of: me, members: members) == [friend])
        #expect(ParcheRemote.crucePartners(of: UUID(), members: members).isEmpty)
    }

    @Test("Un cruce cerrado no cuenta para pasar la deuda de un parche")
    func closedCruceIsNotAPartner() throws {
        let open = UUID()
        let closed = UUID()
        let gone = UUID()
        let members = try ParcheRemote.members(
            from: Data(
                """
                [{"ledger_id": "\(open)", "user_id": "\(me)", "ledgers": {"closed_at": null}},
                 {"ledger_id": "\(open)", "user_id": "\(friend)", "ledgers": {"closed_at": null}},
                 {"ledger_id": "\(closed)", "user_id": "\(me)", "ledgers": {"closed_at": "2026-10-27T10:00:00+00:00"}},
                 {"ledger_id": "\(closed)", "user_id": "\(gone)", "ledgers": {"closed_at": "2026-10-27T10:00:00+00:00"}}]
                """.utf8))
        #expect(ParcheRemote.crucePartners(of: me, members: members) == [friend])
    }

    @Test("Una transferencia al cruce por confirmar, aceptada o de antes (sin estado)")
    func transferStatus() throws {
        let pending = try ParcheRemote.transfer(
            from: Data(
                """
                {"id": "60000000-0000-0000-0000-000000000002", "parche_id": "\(parcheID)", "from_id": "\(carlos)",
                 "to_id": "\(jesus)", "amount": 125000, "movement_id": null, "status": "pending",
                 "proposed_by": "\(carlos)", "responded_at": null, "created_at": "2026-10-28T10:00:00+00:00"}
                """.utf8))
        #expect(pending.status == .pending)
        #expect(pending.proposedBy == carlos)
        #expect(pending.respondedAt == nil)
        #expect(pending.movementID == nil)

        let accepted = try ParcheRemote.transfer(
            from: Data(
                """
                {"id": "60000000-0000-0000-0000-000000000002", "parche_id": "\(parcheID)", "from_id": "\(carlos)",
                 "to_id": "\(jesus)", "amount": 125000, "movement_id": "70000000-0000-0000-0000-000000000002",
                 "status": "accepted", "proposed_by": "\(carlos)", "responded_at": "2026-10-28T11:00:00+00:00",
                 "created_at": "2026-10-28T10:00:00+00:00"}
                """.utf8))
        #expect(accepted.status == .accepted)
        #expect(accepted.respondedAt != nil)

        // Las que pasaron al cruce antes de esta versión no traen estado: ya están aceptadas.
        let detail = try decodeSample()
        #expect(detail.transfers.first?.status == .accepted)
        #expect(detail.transfers.first?.proposedBy == nil)
    }

    @Test("Las filas que devuelven las funciones")
    func functionResults() throws {
        let participant = try ParcheRemote.participant(
            from: Data(
                """
                {"id": "\(carlos)", "parche_id": "\(parcheID)", "user_id": null, "display_name": "Carlos",
                 "claim_code": "SOY-XYZ789", "joined_at": "2026-10-20T10:05:00.5+00:00", "last_seen_at": null}
                """.utf8))
        #expect(participant.id == carlos)
        #expect(participant.claimCode == "SOY-XYZ789")
        let transfer = try ParcheRemote.transfer(
            from: Data(
                """
                {"id": "\(UUID())", "parche_id": "\(parcheID)", "from_id": "\(ana)", "to_id": "\(jesus)",
                 "amount": 5000, "movement_id": null, "created_at": "2026-10-25T19:00:00+00:00"}
                """.utf8))
        #expect(transfer.fromID == ana)
        #expect(transfer.amount == 5000)
        #expect(try ParcheRemote.uuid(from: Data("\"\(parcheID)\"".utf8)) == parcheID)
    }

    // MARK: - Parámetros

    private func json(_ value: some Encodable) throws -> [String: Any] {
        try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any])
    }

    @Test("save_parche_expense recibe pagadores, partes con su dato de entrada e ítems")
    func saveExpenseParams() throws {
        let order = [jesus, ana, carlos]
        let items = ParcheSplit.items([
            ParcheSplitItem(amount: 20000, participantIDs: [ana, jesus]),
            ParcheSplitItem(amount: 10000, participantIDs: [carlos]),
        ])
        let expense = try ParcheExpense.resolve(
            id: expenseID, parcheID: parcheID, concept: " Cena ", base: 30000, tipPercent: 10, split: items,
            payers: [ParchePayer(participantID: ana, amount: 33000)], order: order, recordedBy: ana,
            at: Date(timeIntervalSince1970: 1_800_000_000))
        let params = try json(ParcheRemote.SaveExpenseParams(expense))
        #expect(params["p_id"] as? String == expenseID.uuidString)
        #expect(params["p_parche_id"] as? String == parcheID.uuidString)
        #expect(params["p_concept"] as? String == "Cena")
        #expect(params["p_base_amount"] as? Int == 30000)
        #expect(params["p_tip_percent"] as? Int == 10)
        #expect(params["p_amount"] as? Int == 33000)
        #expect(params["p_spent_on"] as? String == "2027-01-15T08:00:00.000000Z")
        #expect(params["p_split_method"] as? String == "items")
        let payers = try #require(params["p_payers"] as? [[String: Any]])
        #expect(payers.count == 1)
        #expect(payers.first?["amount"] as? Int == 33000)
        let shares = try #require(params["p_shares"] as? [[String: Any]])
        #expect(shares.map { $0["amount"] as? Int } == [11000, 11000, 11000])
        // Por consumo no hay dato de entrada: `input` va como null.
        #expect(shares.allSatisfy { $0["input"] is NSNull })
        let sentItems = try #require(params["p_items"] as? [[String: Any]])
        #expect(sentItems.map { $0["amount"] as? Int } == [20000, 10000])
        #expect((sentItems.first?["participant_ids"] as? [String])?.count == 2)
    }

    @Test("Por porcentaje cada parte lleva su porcentaje y no hay ítems")
    func percentageParams() throws {
        let expense = try ParcheExpense.resolve(
            parcheID: parcheID, concept: "Hotel", base: 90000, split: .percentage([jesus: 50, carlos: 50]),
            payers: [ParchePayer(participantID: jesus, amount: 90000)], order: [jesus, ana, carlos], recordedBy: jesus,
            at: .now)
        let params = try json(ParcheRemote.SaveExpenseParams(expense))
        let shares = try #require(params["p_shares"] as? [[String: Any]])
        #expect(shares.map { $0["input"] as? Int } == [50, 50])
        #expect((params["p_items"] as? [Any])?.isEmpty == true)
    }

    @Test("Los parámetros de las demás funciones usan los nombres de la base")
    func otherParams() throws {
        let payment = ParchePayment(
            parcheID: parcheID, fromID: carlos, toID: jesus, amount: 10000, recordedBy: ana, createdAt: .now)
        #expect(
            Set(try json(ParcheRemote.RecordPaymentParams(payment)).keys)
                == ["p_id", "p_parche_id", "p_from_id", "p_to_id", "p_amount"])
        #expect(
            Set(try json(ParcheRemote.CreateParams(id: parcheID, name: "Cena", displayName: "Jesús")).keys)
                == ["p_id", "p_name", "p_display_name"])
        #expect(
            Set(try json(ParcheRemote.JoinParams(code: "PCH-ABC234", displayName: "Ana")).keys) == [
                "p_code", "p_display_name",
            ])
        #expect(
            Set(try json(ParcheRemote.AddParticipantParams(id: carlos, parcheID: parcheID, displayName: "Carlos")).keys)
                == ["p_id", "p_parche", "p_display_name"])
        #expect(Set(try json(ParcheRemote.CodeParams(code: "SOY-XYZ789")).keys) == ["p_code"])
        #expect(Set(try json(ParcheRemote.IDParams(id: parcheID)).keys) == ["p_id"])
        #expect(
            Set(try json(ParcheRemote.ProposeCruceParams(parcheID: parcheID, otherParticipantID: ana)).keys)
                == ["p_parche", "p_other"])
    }

    // MARK: - Errores

    @Test(
        "Las pistas de la base se traducen a ParcheRepositoryError",
        arguments: [
            ("P0001", "invalidCode", ParcheRepositoryError.invalidCode),
            ("P0001", "alreadyParticipant", .alreadyParticipant),
            ("P0001", "notFound", .notFound),
            ("P0001", "notAllowed", .notAllowed),
            ("P0001", "notAuthenticated", .notAllowed),
            ("P0001", "parcheClosed", .parcheClosed),
            ("P0001", "parcheOpen", .parcheOpen),
            ("P0001", "invalidData", .invalidData),
            ("P0001", "noSharedCruce", .noSharedCruce),
            ("P0001", "alreadyMoved", .alreadyMoved),
            ("P0001", "nothingToMove", .nothingToMove),
            ("23514", "invalidData", .invalidData),
            ("23514", nil, .invalidData),
            ("42501", nil, .notAllowed),
        ] as [(String, String?, ParcheRepositoryError)])
    func errorHints(code: String, hint: String?, expected: ParcheRepositoryError) {
        #expect(ParcheRepositoryError(databaseCode: code, hint: hint) == expected)
    }

    @Test("Los errores que no son de parches no se traducen")
    func unknownErrors() {
        #expect(ParcheRepositoryError(databaseCode: "P0001", hint: "otraCosa") == nil)
        #expect(ParcheRepositoryError(databaseCode: "PGRST116", hint: nil) == nil)
        #expect(ParcheRepositoryError(databaseCode: nil, hint: "notFound") == nil)
    }
}
