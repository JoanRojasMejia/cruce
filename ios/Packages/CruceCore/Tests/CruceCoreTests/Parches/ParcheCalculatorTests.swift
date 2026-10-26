import Foundation
import Testing

@testable import CruceCore

@Suite("Saldos y transferencias de parches")
struct ParcheCalculatorTests {
    private let parcheID = UUID()
    private let ana = UUID()
    private let jesus = UUID()
    private let carlos = UUID()
    private let joan = UUID()
    private var order: [UUID] { [ana, jesus, carlos, joan] }
    private let day = Date(timeIntervalSince1970: 1_800_000_000)

    private func expense(
        payers: [UUID: Int], split: ParcheSplit, base: Int, tip: Int = 0, deleted: Bool = false
    ) throws -> ParcheExpense {
        var expense = try ParcheExpense.resolve(
            parcheID: parcheID, concept: "Prueba", base: base, tipPercent: tip, split: split,
            payers: order.compactMap { id in payers[id].map { ParchePayer(participantID: id, amount: $0) } },
            order: order, recordedBy: ana, at: day)
        if deleted { expense.deletedAt = day }
        return expense
    }

    private func payment(from: UUID, to: UUID, _ amount: Int, confirmed: Bool = true) -> ParchePayment {
        ParchePayment(
            parcheID: parcheID, fromID: from, toID: to, amount: amount, recordedBy: from, createdAt: day,
            confirmedAt: confirmed ? day : nil)
    }

    /// El almuerzo de la spec: Ana paga $220.000 repartidos en $110.000 (Jesús), $55.000 (Ana), $22.000 y $33.000.
    private func lunch() throws -> ParcheExpense {
        try expense(
            payers: [ana: 220_000],
            split: .items([
                ParcheSplitItem(amount: 50_000, participantIDs: [ana]),
                ParcheSplitItem(amount: 100_000, participantIDs: [jesus]),
                ParcheSplitItem(amount: 20_000, participantIDs: [carlos]),
                ParcheSplitItem(amount: 30_000, participantIDs: [joan]),
            ]), base: 200_000, tip: 10)
    }

    private func nets(_ balances: [ParcheBalance]) -> [UUID: Int] {
        Dictionary(uniqueKeysWithValues: balances.map { ($0.participantID, $0.net) })
    }

    // MARK: - Gasto

    @Test("Resolver un gasto guarda el total con propina, los pagadores y las partes")
    func resolveExpense() throws {
        let lunch = try lunch()
        #expect(lunch.amount == 220_000)
        #expect(lunch.baseAmount == 200_000)
        #expect(lunch.share(of: jesus) == 110_000)
        #expect(lunch.paid(by: ana) == 220_000)
        #expect(lunch.mainPayerID == ana)
        #expect(lunch.recordedBy == ana)
    }

    @Test("Dos tarjetas: Ana paga $120.000 y Jesús $100.000 de $220.000")
    func twoPayers() throws {
        let bill = try expense(payers: [ana: 120_000, jesus: 100_000], split: .equal(Set(order)), base: 220_000)
        #expect(bill.payers.count == 2)
        #expect(bill.mainPayerID == ana)
        let balances = nets(ParcheCalculator.balances(order: order, expenses: [bill]))
        #expect(balances == [ana: 65_000, jesus: 45_000, carlos: -55_000, joan: -55_000])
    }

    @Test("Los pagadores deben sumar el total y se explica cuánto falta")
    func payersMustSumTotal() {
        #expect(throws: ParcheExpenseError.payersDoNotMatch(paid: 200_000, total: 220_000)) {
            try expense(payers: [ana: 200_000], split: .equal(Set(order)), base: 220_000)
        }
        #expect(
            ParcheExpenseError.payersDoNotMatch(paid: 200_000, total: 220_000).message
                == "Faltan $20.000: quienes pagaron suman $200.000 de $220.000.")
        #expect(
            ParcheExpenseError.payersDoNotMatch(paid: 225_000, total: 220_000).message
                == "Sobran $5.000: quienes pagaron suman $225.000 y el total es $220.000.")
    }

    @Test("Un gasto necesita concepto, monto y pagadores")
    func expenseValidation() {
        #expect(throws: ParcheExpenseError.invalidConcept) {
            try ParcheExpense.resolve(
                parcheID: parcheID, concept: "  ", base: 10_000, split: .equal([ana]),
                payers: [ParchePayer(participantID: ana, amount: 10_000)], order: order, recordedBy: ana, at: day)
        }
        #expect(throws: ParcheExpenseError.invalidAmount) {
            try expense(payers: [ana: 0], split: .equal([ana]), base: 0)
        }
        #expect(throws: ParcheExpenseError.split(.noParticipants)) {
            try expense(payers: [ana: 10_000], split: .equal([]), base: 10_000)
        }
        #expect(throws: ParcheExpenseError.noPayers) {
            try expense(payers: [:], split: .equal([ana]), base: 10_000)
        }
    }

    // MARK: - Saldos

    @Test("Un almuerzo: a Ana le deben $165.000 y los demás deben")
    func lunchBalances() throws {
        let balances = ParcheCalculator.balances(order: order, expenses: [try lunch()])
        #expect(nets(balances) == [ana: 165_000, jesus: -110_000, carlos: -22_000, joan: -33_000])
        #expect(balances.map(\.participantID) == order, "En el orden del parche")
        #expect(balances.map(\.net).reduce(0, +) == 0)
    }

    @Test("Los gastos borrados no cuentan")
    func deletedExpensesDoNotCount() throws {
        let deleted = try expense(payers: [jesus: 40_000], split: .equal(Set(order)), base: 40_000, deleted: true)
        let balances = nets(ParcheCalculator.balances(order: order, expenses: [try lunch(), deleted]))
        #expect(balances[jesus] == -110_000)
    }

    @Test("Los pagos confirmados cuentan y los pendientes no")
    func paymentsCountOnlyWhenConfirmed() throws {
        let pending = payment(from: jesus, to: ana, 110_000, confirmed: false)
        let before = nets(ParcheCalculator.balances(order: order, expenses: [try lunch()], payments: [pending]))
        #expect(before[jesus] == -110_000)

        let confirmed = payment(from: jesus, to: ana, 110_000)
        let after = nets(ParcheCalculator.balances(order: order, expenses: [try lunch()], payments: [confirmed]))
        #expect(after[jesus] == 0)
        #expect(after[ana] == 55_000)
    }

    @Test("Una deuda que pasó al cruce cuenta como un pago")
    func cruceTransferCountsAsPayment() throws {
        let transfer = ParcheCruceTransfer(parcheID: parcheID, fromID: joan, toID: ana, amount: 33_000, createdAt: day)
        let balances = nets(ParcheCalculator.balances(order: order, expenses: [try lunch()], transfers: [transfer]))
        #expect(balances[joan] == 0)
        #expect(balances[ana] == 132_000)
    }

    @Test("Los saldos siempre suman cero", arguments: 0..<100)
    func balancesSumToZero(seed: Int) throws {
        var generator = SeededGenerator(seed: UInt64(seed) &+ 77)
        var expenses: [ParcheExpense] = []
        for _ in 0..<Int.random(in: 1...6, using: &generator) {
            let base = Int.random(in: 1...900_000, using: &generator)
            let payer = order.randomElement(using: &generator)!
            let people = Set(order.filter { _ in Bool.random(using: &generator) })
            let tip = Int.random(in: 0...20, using: &generator)
            let total = base + base * tip / 100
            expenses.append(
                try expense(
                    payers: [payer: total], split: .equal(people.isEmpty ? [payer] : people), base: base, tip: tip))
        }
        let payments = [payment(from: carlos, to: jesus, Int.random(in: 1...50_000, using: &generator))]
        let balances = ParcheCalculator.balances(order: order, expenses: expenses, payments: payments)
        #expect(balances.map(\.net).reduce(0, +) == 0)

        // Las transferencias mínimas dejan a todos en cero y son a lo sumo n − 1.
        let transfers = ParcheCalculator.minimumTransfers(balances)
        let nonZero = balances.filter { $0.net != 0 }.count
        #expect(transfers.count <= max(nonZero - 1, 0))
        var settled = nets(balances)
        for transfer in transfers {
            #expect(transfer.amount > 0)
            settled[transfer.fromID, default: 0] += transfer.amount
            settled[transfer.toID, default: 0] -= transfer.amount
        }
        #expect(settled.values.allSatisfy { $0 == 0 })
        #expect(ParcheCalculator.minimumTransfers(balances) == transfers, "Determinista")
    }

    // MARK: - A paz y salvo

    @Test("A paz y salvo solo con el parche cerrado y todos en cero")
    func settledNeedsClosedAndZero() throws {
        let zero = ParcheCalculator.balances(
            order: order, expenses: [try lunch()],
            payments: [
                payment(from: jesus, to: ana, 110_000), payment(from: carlos, to: ana, 22_000),
                payment(from: joan, to: ana, 33_000),
            ])
        #expect(ParcheCalculator.isSettled(status: .closed, balances: zero))
        #expect(!ParcheCalculator.isSettled(status: .open, balances: zero))
        let owing = ParcheCalculator.balances(order: order, expenses: [try lunch()])
        #expect(!ParcheCalculator.isSettled(status: .closed, balances: owing))
    }

    // MARK: - Mínimo de transferencias

    @Test("Cuatro personas: tres transferencias a Ana, de la deuda más grande a la más pequeña")
    func minimumTransfersFourPeople() {
        let balances = [
            ParcheBalance(participantID: ana, net: 165_000), ParcheBalance(participantID: jesus, net: -110_000),
            ParcheBalance(participantID: carlos, net: -22_000), ParcheBalance(participantID: joan, net: -33_000),
        ]
        #expect(
            ParcheCalculator.minimumTransfers(balances) == [
                ParcheTransfer(fromID: jesus, toID: ana, amount: 110_000),
                ParcheTransfer(fromID: joan, toID: ana, amount: 33_000),
                ParcheTransfer(fromID: carlos, toID: ana, amount: 22_000),
            ])
    }

    @Test("Los empates los gana quien va primero en el parche")
    func minimumTransfersTieBreak() {
        let balances = [
            ParcheBalance(participantID: ana, net: 10_000), ParcheBalance(participantID: jesus, net: 10_000),
            ParcheBalance(participantID: carlos, net: -10_000), ParcheBalance(participantID: joan, net: -10_000),
        ]
        #expect(
            ParcheCalculator.minimumTransfers(balances) == [
                ParcheTransfer(fromID: carlos, toID: ana, amount: 10_000),
                ParcheTransfer(fromID: joan, toID: jesus, amount: 10_000),
            ])
    }

    @Test("Sin saldos no hay transferencias")
    func noTransfersWhenSettled() {
        #expect(ParcheCalculator.minimumTransfers([ParcheBalance(participantID: ana, net: 0)]).isEmpty)
    }

    // MARK: - Pagos con confirmación

    @Test("Carlos le pagó a Jesús: si lo anota Ana queda pendiente")
    func paymentRecordedByOtherIsPending() {
        let participants = [
            ParcheParticipant(id: jesus, userID: UUID(), displayName: "Jesús", joinedAt: day),
            ParcheParticipant(id: carlos, displayName: "Carlos", claimCode: "SOY-ABC234", joinedAt: day),
        ]
        #expect(!ParcheCalculator.confirmsImmediately(recordedBy: ana, toID: jesus, participants: participants))
        #expect(ParcheCalculator.confirmsImmediately(recordedBy: jesus, toID: jesus, participants: participants))
        // Si quien recibe no tiene la app, cuenta de una vez.
        #expect(ParcheCalculator.confirmsImmediately(recordedBy: ana, toID: carlos, participants: participants))
    }

    @Test("Quien no tiene la app se muestra como sin la app")
    func participantLabel() {
        let carlos = ParcheParticipant(displayName: "Carlos", claimCode: "SOY-ABC234", joinedAt: day)
        #expect(!carlos.hasApp)
        #expect(carlos.label == "Carlos (sin la app)")
        let ana = ParcheParticipant(userID: UUID(), displayName: "Ana", joinedAt: day)
        #expect(ana.hasApp)
        #expect(ana.label == "Ana")
    }

    // MARK: - Deuda directa entre dos

    /// Jesús paga $256.000 entre los 4: cada uno le debe $64.000.
    private func lodging() throws -> ParcheExpense {
        try expense(payers: [jesus: 256_000], split: .equal(Set(order)), base: 256_000)
    }

    @Test("Joan le debe directamente $64.000 a Jesús")
    func directDebt() throws {
        let expenses = [try lodging()]
        #expect(ParcheCalculator.directDebt(from: joan, to: jesus, expenses: expenses) == 64_000)
        #expect(ParcheCalculator.directDebt(from: jesus, to: joan, expenses: expenses) == -64_000)
    }

    @Test("La deuda directa se calcula antes de simplificar las del grupo")
    func directDebtIgnoresSimplification() throws {
        // Además, Ana paga $80.000 entre Ana y Joan.
        let extra = try expense(payers: [ana: 80_000], split: .equal([ana, joan]), base: 80_000)
        let expenses = [try lodging(), extra]
        #expect(ParcheCalculator.directDebt(from: joan, to: jesus, expenses: expenses) == 64_000)
        #expect(ParcheCalculator.directDebt(from: joan, to: ana, expenses: expenses) == 40_000)
        // Ana le debe $64.000 a Jesús y Joan le debe $40.000 a Ana.
        #expect(ParcheCalculator.directDebt(from: ana, to: jesus, expenses: expenses) == 64_000)
    }

    @Test("Con varios pagadores, la deuda directa es proporcional a lo que pagó cada uno")
    func directDebtWithSeveralPayers() throws {
        let bill = try expense(payers: [ana: 120_000, jesus: 100_000], split: .equal(Set(order)), base: 220_000)
        #expect(ParcheCalculator.directDebt(from: carlos, to: ana, expenses: [bill]) == 30_000)
        #expect(ParcheCalculator.directDebt(from: carlos, to: jesus, expenses: [bill]) == 25_000)
        #expect(ParcheCalculator.directDebt(from: jesus, to: ana, expenses: [bill]) == 5_000)
    }

    @Test("Los pagos confirmados entre los dos y los gastos borrados ajustan la deuda directa")
    func directDebtIncludesPayments() throws {
        let deleted = try expense(payers: [jesus: 40_000], split: .equal([joan]), base: 40_000, deleted: true)
        let expenses = [try lodging(), deleted]
        let payments = [
            payment(from: joan, to: jesus, 4_000), payment(from: jesus, to: joan, 1_000),
            payment(from: joan, to: jesus, 50_000, confirmed: false),
        ]
        #expect(ParcheCalculator.directDebt(from: joan, to: jesus, expenses: expenses, payments: payments) == 61_000)
    }

    @Test("Joan y Jesús pasan su deuda al cruce: ya no hay transferencia entre ellos")
    func movingDebtToCruceRemovesTheirTransfer() throws {
        let expenses = [try lodging()]
        let amount = ParcheCalculator.directDebt(from: joan, to: jesus, expenses: expenses)
        let transfer = ParcheCruceTransfer(
            parcheID: parcheID, fromID: joan, toID: jesus, amount: amount, createdAt: day)
        #expect(
            ParcheCalculator.directDebt(from: joan, to: jesus, expenses: expenses, transfers: [transfer]) == 0)
        let balances = ParcheCalculator.balances(order: order, expenses: expenses, transfers: [transfer])
        #expect(balances.map(\.net).reduce(0, +) == 0)
        let suggestions = ParcheCalculator.minimumTransfers(balances)
        #expect(!suggestions.contains { Set([$0.fromID, $0.toID]) == Set([joan, jesus]) })
        #expect(suggestions.count == 2)
    }

    @Test("No quieren pasarla: la deuda se salda en el parche")
    func notMovingDebtKeepsTransferInParche() throws {
        let suggestions = ParcheCalculator.minimumTransfers(
            ParcheCalculator.balances(order: order, expenses: [try lodging()]))
        #expect(suggestions.contains(ParcheTransfer(fromID: joan, toID: jesus, amount: 64_000)))
    }
}
