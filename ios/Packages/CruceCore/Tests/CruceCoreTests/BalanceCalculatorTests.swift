import Foundation
import Testing

@testable import CruceCore

@Suite("Saldo neto entre los dos")
struct BalanceCalculatorTests {
    private let joan = MockData.joan.id
    private let jesus = MockData.jesus.id

    private func expense(_ payer: UUID, _ amount: Int, _ split: SplitRule = .equal) -> Movement {
        Movement(payerID: payer, amount: amount, concept: "Prueba", category: .otro, split: split, createdBy: payer)
    }

    /// Ejemplo del brief: Joan paga cena $60.000 a medias y Jesús mercado $100.000 a medias.
    @Test("El ejemplo del brief deja a Joan debiendo $20.000")
    func briefExampleNetsToJoanOwingTwentyThousand() {
        let movements = [expense(joan, 60_000), expense(jesus, 100_000)]
        #expect(BalanceCalculator.net(of: movements, for: joan) == -20_000)
        #expect(BalanceCalculator.net(of: movements, for: jesus) == 20_000)
        #expect(BalanceCalculator.state(of: movements, for: joan) == .youOwe(20_000))
        #expect(BalanceCalculator.state(of: movements, for: jesus) == .theyOweYou(20_000))
    }

    @Test("El saldo es simétrico entre los dos")
    func netIsSymmetricBetweenBothMembers() {
        let movements = MockData.movements()
        #expect(BalanceCalculator.net(of: movements, for: joan) == -BalanceCalculator.net(of: movements, for: jesus))
    }

    /// Los datos de ejemplo coinciden con el canvas: "Jesús te debe $20.000".
    @Test("Los datos de ejemplo coinciden con el diseño")
    func mockDataMatchesDesign() {
        #expect(BalanceCalculator.state(of: MockData.movements(), for: joan) == .theyOweYou(20_000))
    }

    @Test("Un préstamo cuenta completo para el otro")
    func loanCountsFullyForTheOther() {
        let movements = [expense(joan, 40_000, .fullOther)]
        #expect(BalanceCalculator.net(of: movements, for: joan) == 40_000)
    }

    @Test("Reparto por porcentaje")
    func percentageSplit() {
        // Joan paga $60.000 y a Jesús le toca el 60 %.
        let movement = expense(joan, 60_000, .percentage(otherShare: 60))
        #expect(movement.owedByOther == 36_000)
        #expect(movement.payerShare == 24_000)
    }

    @Test(
        "Los montos impares se redondean al peso más cercano",
        arguments: [
            (25_001, SplitRule.equal, 12_501),
            (25_003, SplitRule.percentage(otherShare: 30), 7_501),
        ])
    func oddAmountsRoundToNearestPeso(amount: Int, split: SplitRule, owedByOther: Int) {
        #expect(expense(joan, amount, split).owedByOther == owedByOther)
    }

    @Test("Saldar deja el saldo en $0")
    func settlementLeavesBalanceAtZero() throws {
        var movements = MockData.movements()
        let payment = try #require(
            BalanceCalculator.settlement(
                movements: movements, me: joan, other: jesus, createdBy: joan, paymentMethod: "Nequi")
        )
        #expect(payment.payerID == jesus, "Quien debe es quien paga")
        #expect(payment.amount == 20_000)
        movements.append(payment)
        #expect(BalanceCalculator.state(of: movements, for: joan) == .settled)
    }

    @Test("No hay pago para saldar si ya están a paz y salvo")
    func settlementIsNilWhenAlreadySettled() {
        #expect(
            BalanceCalculator.settlement(movements: [], me: joan, other: jesus, createdBy: joan, paymentMethod: nil)
                == nil)
    }

    @Test("Movimientos desde el último pago para saldar")
    func movementsSinceLastSettlement() {
        #expect(BalanceCalculator.movementsSinceLastSettlement(MockData.movements()).count == 7)
    }

    // MARK: - Borrado suave

    /// Movimiento con fecha fija, para ordenar sin depender de la hora del reloj.
    private func movement(
        _ payer: UUID, _ amount: Int, day: Int, kind: Movement.Kind = .expense, deleted: Bool = false
    ) -> Movement {
        let date = Date(timeIntervalSince1970: TimeInterval(day) * 86_400)
        return Movement(
            kind: kind, payerID: payer, amount: amount, concept: "Prueba", category: .otro,
            split: kind == .settlement ? .fullOther : .equal, date: date, createdBy: payer,
            deletedAt: deleted ? date.addingTimeInterval(60) : nil)
    }

    @Test("Un gasto eliminado no cuenta en el saldo")
    func deletedExpenseDoesNotCountInNet() {
        let movements = [expense(joan, 60_000), expense(jesus, 100_000), movement(joan, 40_000, day: 1, deleted: true)]
        #expect(BalanceCalculator.net(of: movements, for: joan) == -20_000)
    }

    @Test("Un gasto eliminado no cambia el pago para saldar")
    func deletedExpenseDoesNotChangeSettlement() throws {
        let movements = [expense(joan, 60_000), expense(jesus, 100_000), movement(joan, 40_000, day: 1, deleted: true)]
        let payment = try #require(
            BalanceCalculator.settlement(
                movements: movements, me: joan, other: jesus, createdBy: joan, paymentMethod: "Nequi")
        )
        #expect(payment.amount == 20_000)
        #expect(payment.payerID == joan)
    }

    @Test("Un gasto eliminado después de saldar no cuenta como movimiento nuevo")
    func deletedExpenseDoesNotCountSinceLastSettlement() {
        let movements = [
            movement(joan, 10_000, day: 1),
            movement(jesus, 5_000, day: 2, kind: .settlement),
            movement(joan, 20_000, day: 3),
            movement(jesus, 30_000, day: 4, deleted: true),
        ]
        let since = BalanceCalculator.movementsSinceLastSettlement(movements)
        #expect(since.map(\.amount) == [20_000])
    }

    @Test("Un pago para saldar eliminado no es el último pago")
    func deletedSettlementIsNotTheLastOne() {
        let movements = [
            movement(joan, 10_000, day: 1),
            movement(jesus, 5_000, day: 2, kind: .settlement, deleted: true),
            movement(joan, 20_000, day: 3),
        ]
        let since = BalanceCalculator.movementsSinceLastSettlement(movements)
        #expect(since.map(\.amount) == [10_000, 20_000])
    }

    @Test("Un movimiento guardado sin la clave deletedAt se lee como vigente")
    func decodesMovementWithoutDeletedAt() throws {
        let original = movement(joan, 10_000, day: 1)
        let data = try JSONEncoder().encode(original)
        var object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        object["deletedAt"] = nil
        let legacy = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(Movement.self, from: legacy)
        #expect(decoded.deletedAt == nil)
        #expect(!decoded.isDeleted)
        #expect(decoded.amount == 10_000)
    }
}
