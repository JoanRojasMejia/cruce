import Foundation
import Testing

@testable import CruceCore

/// "Cómo se calcula" y "¿Por qué le paga todo a…?" en el ticket personal, sobre "Finca" de `MockParches`: Yisus pagó
/// el mercado de $516.000 y Nata el Uber de $114.000, los dos entre los cuatro.
@Suite("ParcheTicket: cómo se calcula y por qué")
struct ParcheTicketExplanationTests {
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

    @Test("Nata puso plata y aun así paga: el ticket explica el cruce con los montos")
    func nataExplanation() throws {
        let nata = try ticket(MockParches.fincaNata)
        #expect(nata.explanation?.title == "¿Por qué le paga todo a Yisus?")
        #expect(
            nata.explanation?.body
                == "Lo que pagó Nata (Uber) ya cubre parte de lo que le tocaba, así que Cruce cruza las cuentas: "
                + "en vez de recibir $85.500 y pagar $129.000, le paga solo la diferencia a Yisus. Así hay menos pagos."
        )
    }

    @Test("Laura no puso nada y parte de lo suyo lo pagó Nata: el ticket dice por qué le paga todo a Yisus")
    func lauraExplanation() throws {
        let laura = try ticket(MockParches.fincaLaura)
        #expect(laura.explanation?.title == "¿Por qué le paga todo a Yisus?")
        #expect(
            laura.explanation?.body
                == "Parte de lo que le toca lo pagó Nata (Uber), pero Cruce cruza las cuentas para que haya menos "
                + "pagos: por eso le paga todo a Yisus.")
        let joan = try ticket(MockParches.fincaJoan)
        #expect(joan.explanation == laura.explanation)
    }

    @Test("A Yisus le pagan distinto de lo que le tocaba a cada quien en el mercado: el ticket dice por qué")
    func yisusExplanation() throws {
        let yisus = try ticket(MockParches.fincaYisus)
        #expect(yisus.explanation?.title == "¿Por qué le pagan así?")
        #expect(
            yisus.explanation?.body
                == "Joan le paga $157.500 y no $129.000 porque se le suman $28.500 que le debía a Nata (Uber). "
                + "Laura le paga $157.500 y no $129.000 porque se le suman $28.500 que le debía a Nata (Uber). "
                + "Nata le paga $43.500 y no $129.000 porque se le descuentan $85.500 que le debían por lo que "
                + "pagó (Uber). Cruce cruza las cuentas para que haya menos pagos: en total le llegan $358.500.")
    }

    @Test("Varias personas que pagaron lo de alguien y varias a quienes les paga")
    func severalPayers() throws {
        let santaMarta = MockParches.parches().first { $0.id == MockParches.santaMartaID }!
        let carlos = try ticket(MockParches.carlos, in: santaMarta)
        #expect(carlos.explanation?.title == "¿Por qué le paga a Jesús y Joan?")
        #expect(
            carlos.explanation?.body
                == "Parte de lo que le toca lo pagó Ana (Almuerzo en Taganga), pero Cruce cruza las cuentas para que "
                + "haya menos pagos: por eso le paga todo a Jesús y Joan.")
    }

    @Test("Sin cruce de cuentas no hay explicación: el que debe le paga a quien pagó, lo mismo que le tocaba")
    func noCrossing() throws {
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
        #expect(try ticket(a, in: detail).explanation == nil)
        #expect(try ticket(b, in: detail).explanation == nil)
        #expect(
            try ticket(b, in: detail).breakdown?.result == ParcheTicket.Breakdown.Row(label: "Debe", amount: 50_000))
        // En "Cena de Ana" Joan ya pagó: tampoco hay nada que explicar.
        let cena = MockParches.parches()[1]
        #expect(try ticket(MockParches.cenaAna, in: cena).explanation == nil)
        #expect(try ticket(MockParches.cenaJoan, in: cena).explanation == nil)
    }

    @Test("Quien pagó justo lo que le tocaba queda a paz y salvo sin recibir ni pagar")
    func zeroExplanation() throws {
        let santaMarta = MockParches.parches().first { $0.id == MockParches.santaMartaID }!
        let ana = try ticket(MockParches.ana, in: santaMarta)
        #expect(ana.explanation?.title == "¿Por qué está a paz y salvo?")
        #expect(
            ana.explanation?.body
                == "Lo que pagó Ana (Almuerzo en Taganga) cubre justo lo que le tocaba, así que Cruce cruza las "
                + "cuentas: en vez de recibir $165.000 y pagar $165.000, no le paga nada a nadie ni nadie le paga.")
    }

    @Test("El texto para compartir lleva cómo se calcula y por qué, en pocas líneas")
    func shareText() throws {
        let text = try ticket(MockParches.fincaNata).shareText(scheme: "cruce")
        #expect(
            text == """
                Cruce · Parche Finca: Nata debe $43.500.
                Cómo se calcula: le tocó en total $157.500 · puso −$114.000 · debe $43.500.
                ¿Por qué le paga todo a Yisus? Lo que pagó Nata (Uber) ya cubre parte de lo que le tocaba, así que \
                Cruce cruza las cuentas: en vez de recibir $85.500 y pagar $129.000, le paga solo la diferencia a \
                Yisus. Así hay menos pagos.
                ¿Ya tienes Cruce? Entra con el código SOY-N4T4QZ y tus cuentas te siguen. Ábrelo en Cruce: \
                cruce://codigo/SOY-N4T4QZ
                """)
        let yisus = try ticket(MockParches.fincaYisus).shareText(scheme: "cruce")
        #expect(yisus.contains("Cómo se calcula: puso $516.000 · le tocó −$157.500 · le deben $358.500."))
        let ana = try ticket(
            MockParches.ana, in: MockParches.parches()[0]
        ).shareText(scheme: "cruce")
        #expect(ana.contains("Cómo se calcula: le tocó en total $220.000 · puso −$220.000 · está a paz y salvo."))
    }

    @Test("El ticket del parche no lleva cómo se calcula ni por qué")
    func groupTicket() {
        let group = ParcheTicket.parche(finca, at: cut)
        #expect(group.breakdown == nil)
        #expect(group.explanation == nil)
    }
}
