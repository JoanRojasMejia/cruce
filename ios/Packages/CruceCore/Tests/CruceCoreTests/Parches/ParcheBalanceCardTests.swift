import Foundation
import Testing

@testable import CruceCore

/// La tarjeta "Tu saldo en el parche", "Para saldar", "Saldos" y la sección "Pagos" según el saldo de quien usa la app
/// (A2-52 "Parche saldado" y A2-53 "Debes en el parche").
@Suite("ParcheDetail: tarjeta del saldo y pagos")
struct ParcheBalanceCardTests {
    /// 7 nov 2026 al mediodía (UTC): "Cena de Ana" se cerró el 19 oct.
    let reference = Date(timeIntervalSince1970: 1_794_052_800)

    private func santaMarta(viewer: UUID) -> ParcheDetail {
        var detail = MockParches.parches(reference: reference).first { $0.id == MockParches.santaMartaID }!
        detail.myParticipantID = viewer
        return detail
    }

    private func cena(viewer: UUID = MockParches.cenaJoan) -> ParcheDetail {
        var detail = MockParches.parches(reference: reference).first { $0.id == MockParches.cenaID }!
        detail.myParticipantID = viewer
        return detail
    }

    // MARK: - Debes en el parche (A2-53)

    @Test("Carlos debe $172.000 en Santa Marta: a favor de Jesús y Joan, en el orden del plan")
    func carlosOwes() {
        let detail = santaMarta(viewer: MockParches.carlos)
        #expect(detail.myNet == -172_000)
        #expect(detail.myBalancePhrase == "Debes en el parche")
        #expect(detail.creditors(of: MockParches.carlos) == [MockParches.jesus, MockParches.joan])
        #expect(detail.myBalanceNote == "a favor de Jesús y Joan")
        #expect(detail.showsSettlementPlan)
        #expect(detail.allowsRecordingPayment)
        #expect(!detail.showsPaymentHistory)
    }

    @Test("Con tres personas a quienes pagarles: a favor de Ana, Jesús y Joan")
    func threeCreditors() throws {
        let start = reference.addingTimeInterval(-86_400)
        let ids = (1...4).map { UUID(uuidString: "00000000-0000-0000-0000-00000000D00\($0)")! }
        let names = ["Carlos", "Ana", "Jesús", "Joan"]
        let participants = zip(ids, names).enumerated().map { index, pair in
            ParcheParticipant(
                id: pair.0, userID: UUID(), displayName: pair.1, joinedAt: start.addingTimeInterval(Double(index)))
        }
        let parche = Parche(name: "Finca", code: "PCH-F1NCA2", createdAt: start, createdBy: ids[0])
        let dinner = try ParcheExpense.resolve(
            parcheID: parche.id, concept: "Asado", base: 90_000, split: .equal([ids[0]]),
            payers: [
                ParchePayer(participantID: ids[1], amount: 50_000), ParchePayer(participantID: ids[2], amount: 30_000),
                ParchePayer(participantID: ids[3], amount: 10_000),
            ], order: ids, recordedBy: ids[1], at: start)
        let detail = ParcheDetail(
            parche: parche, participants: participants, expenses: [dinner], myParticipantID: ids[0])
        #expect(detail.myBalanceNote == "a favor de Ana, Jesús y Joan")
    }

    @Test("Te deben: a tu favor; tú en $0 y otros no: a paz y salvo sin nota y con el plan a la vista")
    func otherStates() {
        let joan = santaMarta(viewer: MockParches.joan)
        #expect(joan.myBalancePhrase == "Te deben en el parche")
        #expect(joan.myBalanceNote == "a tu favor")
        let ana = santaMarta(viewer: MockParches.ana)
        #expect(ana.myBalancePhrase == "Estás a paz y salvo")
        #expect(ana.myBalanceNote == nil)
        #expect(ana.showsSettlementPlan)
        #expect(!ana.showsPaymentHistory)
    }

    @Test("El ticket de Carlos dice a favor de quién con la misma lista")
    func ticketUsesSameList() throws {
        let detail = santaMarta(viewer: MockParches.joan)
        let ticket = try #require(ParcheTicket.personal(for: MockParches.carlos, in: detail, at: reference))
        #expect(ticket.favor == "a favor de Jesús y Joan")
    }

    // MARK: - Parche saldado (A2-52)

    @Test("Cena de Ana cerrada y todos en $0: la frase, la nota, sin plan ni saldos ni anotar un pago")
    func settledClosed() {
        let detail = cena()
        #expect(detail.everyoneAtZero)
        #expect(detail.myBalancePhrase == "Todos quedaron a paz y salvo")
        #expect(detail.myBalanceNote == "Nadie le debe nada a nadie.")
        #expect(!detail.showsSettlementPlan)
        #expect(!detail.allowsRecordingPayment)
        #expect(detail.showsPaymentHistory)
    }

    @Test("Abierto y todos en $0: igual la frase y sin plan, pero se puede seguir anotando")
    func settledOpen() {
        var detail = cena()
        detail.parche.status = .open
        detail.parche.closedAt = nil
        #expect(detail.myBalancePhrase == "Todos quedaron a paz y salvo")
        #expect(!detail.showsSettlementPlan)
        #expect(detail.allowsRecordingPayment)
        #expect(detail.showsPaymentHistory)
    }

    @Test("Cerrado y todos en $0 sin pagos (cada quien pagó lo suyo): no hay sección de pagos")
    func settledWithoutPayments() throws {
        var detail = cena()
        let ana = MockParches.cenaAna
        detail.payments = []
        detail.expenses = [
            try ParcheExpense.resolve(
                parcheID: detail.id, concept: "Postre", base: 20_000, split: .equal([ana]),
                payers: [ParchePayer(participantID: ana, amount: 20_000)], order: detail.order, recordedBy: ana,
                at: reference)
        ]
        #expect(detail.everyoneAtZero)
        #expect(!detail.showsPaymentHistory)
        #expect(detail.paymentLines(now: reference).isEmpty)
    }

    @Test("La fila del pago de Joan a Ana, que Ana anotó: confirmado por Ana el 19 oct")
    func cenaPaymentLine() {
        let lines = cena().paymentLines(now: reference)
        #expect(lines.map(\.title) == ["Le pagaste $60.000 a Ana"])
        #expect(lines.map(\.detail) == ["Confirmado por Ana · 19 oct"])
        #expect(lines.map(\.amount) == [60_000])
        // Desde la vista de Ana.
        let ana = cena(viewer: MockParches.cenaAna).paymentLines(now: reference)
        #expect(ana.map(\.title) == ["Joan te pagó $60.000"])
        #expect(ana.map(\.detail) == ["Confirmado por ti · 19 oct"])
    }

    @Test(
        "Pagos confirmados del más reciente al más antiguo; quien no tiene la app no confirma: anotado por quien lo anotó"
    )
    func paymentLinesPerspective() {
        var detail = santaMarta(viewer: MockParches.joan)
        func daysAgo(_ days: Double) -> Date { reference.addingTimeInterval(-days * 86_400) }
        detail.payments += [
            // Quien recibe (Carlos) no tiene la app: cuenta de una vez.
            ParchePayment(
                parcheID: detail.id, fromID: MockParches.jesus, toID: MockParches.carlos, amount: 10_000,
                recordedBy: MockParches.jesus, createdAt: daysAgo(3), confirmedAt: daysAgo(3)),
            // Ana lo anotó y Joan lo confirmó después.
            ParchePayment(
                parcheID: detail.id, fromID: MockParches.ana, toID: MockParches.joan, amount: 20_000,
                recordedBy: MockParches.ana, createdAt: daysAgo(6), confirmedAt: daysAgo(2)),
            // Lo anotó quien recibe (Jesús).
            ParchePayment(
                parcheID: detail.id, fromID: MockParches.carlos, toID: MockParches.jesus, amount: 30_000,
                recordedBy: MockParches.jesus, createdAt: daysAgo(5), confirmedAt: daysAgo(5)),
            // Joan anotó un pago a Carlos (sin la app).
            ParchePayment(
                parcheID: detail.id, fromID: MockParches.joan, toID: MockParches.carlos, amount: 5_000,
                recordedBy: MockParches.joan, createdAt: daysAgo(4), confirmedAt: daysAgo(4)),
        ]
        let lines = detail.paymentLines(now: reference)
        // El pago pendiente de `MockParches` (Carlos a Joan, sin confirmar) no aparece.
        #expect(
            lines.map(\.title) == [
                "Ana te pagó $20.000", "Jesús le pagó $10.000 a Carlos", "Le pagaste $5.000 a Carlos",
                "Carlos le pagó $30.000 a Jesús",
            ])
        #expect(
            lines.map(\.detail) == [
                "Confirmado por ti · 5 nov", "Anotado por Jesús · 4 nov", "Anotado por ti · 3 nov",
                "Confirmado por Jesús · 2 nov",
            ])
    }
}
