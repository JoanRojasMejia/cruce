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

    @Test("Los montos impares se redondean al peso más cercano", arguments: [
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
            BalanceCalculator.settlement(movements: movements, me: joan, other: jesus, createdBy: joan, paymentMethod: "Nequi")
        )
        #expect(payment.payerID == jesus, "Quien debe es quien paga")
        #expect(payment.amount == 20_000)
        movements.append(payment)
        #expect(BalanceCalculator.state(of: movements, for: joan) == .settled)
    }

    @Test("No hay pago para saldar si ya están a paz y salvo")
    func settlementIsNilWhenAlreadySettled() {
        #expect(BalanceCalculator.settlement(movements: [], me: joan, other: jesus, createdBy: joan, paymentMethod: nil) == nil)
    }

    @Test("Movimientos desde el último pago para saldar")
    func movementsSinceLastSettlement() {
        #expect(BalanceCalculator.movementsSinceLastSettlement(MockData.movements()).count == 7)
    }
}
