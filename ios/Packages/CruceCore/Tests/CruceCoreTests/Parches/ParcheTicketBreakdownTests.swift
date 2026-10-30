import Foundation
import Testing

@testable import CruceCore

/// "Cómo se calcula" en el ticket personal, sobre "Finca" de `MockParches`: Yisus pagó el mercado de $516.000 y Nata el
/// Uber de $114.000, los dos entre los cuatro.
@Suite("ParcheTicket: cómo se calcula")
struct ParcheTicketBreakdownTests {
    let finca = MockParches.finca()
    let cut = Date(timeIntervalSince1970: 1_800_000_000)

    private func ticket(_ id: UUID, in detail: ParcheDetail? = nil) throws -> ParcheTicket {
        try #require(ParcheTicket.personal(for: id, in: detail ?? finca, at: cut))
    }

    private func rows(_ ticket: ParcheTicket) -> [String] {
        (ticket.breakdown?.rows ?? []).map { "\($0.label) \(Money.format($0.amount, showsSign: $0.amount < 0))" }
    }

    @Test("Los saldos de Finca son los de la conversación con Joan")
    func balances() {
        #expect(finca.balance(of: MockParches.fincaJoan) == -157_500)
        #expect(finca.balance(of: MockParches.fincaLaura) == -157_500)
        #expect(finca.balance(of: MockParches.fincaNata) == -43_500)
        #expect(finca.balance(of: MockParches.fincaYisus) == 358_500)
    }

    @Test("Nata: le tocó en total $157.500, puso −$114.000 y debe $43.500")
    func nataBreakdown() throws {
        let nata = try ticket(MockParches.fincaNata)
        #expect(rows(nata) == ["Le tocó en total $157.500", "Puso −$114.000"])
        #expect(nata.breakdown?.result == ParcheTicket.Breakdown.Row(label: "Debe", amount: 43_500))
    }

    @Test("Yisus: puso $516.000, le tocó −$157.500 y le deben $358.500")
    func yisusBreakdown() throws {
        let yisus = try ticket(MockParches.fincaYisus)
        #expect(rows(yisus) == ["Puso $516.000", "Le tocó −$157.500"])
        #expect(yisus.breakdown?.result == ParcheTicket.Breakdown.Row(label: "Le deben", amount: 358_500))
    }

    @Test("Laura no puso nada: solo lo que le tocó")
    func lauraBreakdown() throws {
        let laura = try ticket(MockParches.fincaLaura)
        #expect(rows(laura) == ["Le tocó en total $157.500"])
        #expect(laura.breakdown?.result == ParcheTicket.Breakdown.Row(label: "Debe", amount: 157_500))
    }

    @Test("En $0: lo que le tocó, lo que puso y a paz y salvo")
    func zeroBreakdown() throws {
        let santaMarta = MockParches.parches().first { $0.id == MockParches.santaMartaID }!
        let ana = try ticket(MockParches.ana, in: santaMarta)
        #expect(rows(ana) == ["Le tocó en total $220.000", "Puso −$220.000"])
        #expect(ana.breakdown?.result == ParcheTicket.Breakdown.Row(label: "Está a paz y salvo", amount: 0))
    }

    /// Finca con un pago confirmado de Nata a Yisus, uno por confirmar (no cuenta) y la deuda de Joan con Yisus que
    /// pasó a su cruce.
    private var fincaWithPayments: ParcheDetail {
        var detail = finca
        detail.payments = [
            ParchePayment(
                parcheID: MockParches.fincaID, fromID: MockParches.fincaNata, toID: MockParches.fincaYisus,
                amount: 20_000, recordedBy: MockParches.fincaYisus, createdAt: cut, confirmedAt: cut),
            ParchePayment(
                parcheID: MockParches.fincaID, fromID: MockParches.fincaLaura, toID: MockParches.fincaYisus,
                amount: 10_000, recordedBy: MockParches.fincaLaura, createdAt: cut),
        ]
        detail.transfers = [
            ParcheCruceTransfer(
                parcheID: MockParches.fincaID, fromID: MockParches.fincaJoan, toID: MockParches.fincaYisus,
                amount: 50_000, createdAt: cut)
        ]
        return detail
    }

    @Test("Los pagos confirmados y lo que pasó al cruce también son filas")
    func paymentsAndTransfers() throws {
        let detail = fincaWithPayments
        let nata = try ticket(MockParches.fincaNata, in: detail)
        #expect(rows(nata) == ["Le tocó en total $157.500", "Puso −$114.000", "Ya pagó −$20.000"])
        #expect(nata.breakdown?.result == ParcheTicket.Breakdown.Row(label: "Debe", amount: 23_500))
        let yisus = try ticket(MockParches.fincaYisus, in: detail)
        #expect(
            rows(yisus) == [
                "Puso $516.000", "Le tocó −$157.500", "Ya le pagaron −$20.000", "Pasó a su cruce con Joan −$50.000",
            ])
        #expect(yisus.breakdown?.result == ParcheTicket.Breakdown.Row(label: "Le deben", amount: 288_500))
        let joan = try ticket(MockParches.fincaJoan, in: detail)
        #expect(rows(joan) == ["Le tocó en total $157.500", "Pasó a su cruce con Yisus −$50.000"])
        #expect(joan.breakdown?.result == ParcheTicket.Breakdown.Row(label: "Debe", amount: 107_500))
    }

    @Test(
        "Las filas siempre suman el saldo que muestra el ticket",
        arguments: [
            MockParches.finca(), MockParches.parches()[0], MockParches.parches()[1],
        ])
    func rowsAddUp(detail: ParcheDetail) throws {
        var withPayments = detail
        if detail.id == MockParches.fincaID { withPayments = fincaWithPayments }
        for candidate in [detail, withPayments] {
            for person in candidate.participants {
                let ticket = try ticket(person.id, in: candidate)
                let breakdown = try #require(ticket.breakdown)
                let net = candidate.balance(of: person.id)
                #expect(breakdown.rows.map(\.amount).reduce(0, +) == breakdown.result.amount)
                #expect(breakdown.result.amount == abs(net))
            }
        }
    }

    @Test("Una cena simple: quien no pagó debe la mitad")
    func simpleDinner() throws {
        let a = UUID()
        let b = UUID()
        let parcheID = UUID()
        let expense = try ParcheExpense.resolve(
            parcheID: parcheID, concept: "Cena", base: 100_000, split: .equal([a, b]),
            payers: [ParchePayer(participantID: a, amount: 100_000)], order: [a, b], recordedBy: a, at: cut)
        let detail = ParcheDetail(
            parche: Parche(id: parcheID, name: "Cena", code: "PCH-CENA22", createdAt: cut),
            participants: [
                ParcheParticipant(id: a, displayName: "Ana", joinedAt: cut),
                ParcheParticipant(id: b, displayName: "Beto", joinedAt: cut.addingTimeInterval(1)),
            ],
            expenses: [expense])
        #expect(
            try ticket(b, in: detail).breakdown?.result == ParcheTicket.Breakdown.Row(label: "Debe", amount: 50_000))
    }

    @Test("El texto para compartir lleva cómo se calcula, sin explicar por qué le paga a quien le paga")
    func shareText() throws {
        let text = try ticket(MockParches.fincaNata).shareText(scheme: "cruce")
        #expect(
            text == """
                Cruce · Parche Finca: Nata debe $43.500.
                Cómo se calcula: le tocó en total $157.500 · puso −$114.000 · debe $43.500.
                ¿Ya tienes Cruce? Entra con el código SOY-N4T4QZ y tus cuentas te siguen. Ábrelo en Cruce: \
                cruce://codigo/SOY-N4T4QZ
                """)
        let yisus = try ticket(MockParches.fincaYisus).shareText(scheme: "cruce")
        #expect(yisus.contains("Cómo se calcula: puso $516.000 · le tocó −$157.500 · le deben $358.500."))
        for person in finca.participants {
            #expect(!(try ticket(person.id).shareText(scheme: "cruce").contains("¿Por qué")))
        }
        let ana = try ticket(
            MockParches.ana, in: MockParches.parches()[0]
        ).shareText(scheme: "cruce")
        #expect(ana.contains("Cómo se calcula: le tocó en total $220.000 · puso −$220.000 · está a paz y salvo."))
    }

    @Test("El ticket del parche no lleva cómo se calcula")
    func groupTicket() {
        let group = ParcheTicket.parche(finca, at: cut)
        #expect(group.breakdown == nil)
        #expect(!group.shareText(scheme: "cruce").contains("¿Por qué"))
    }
}
