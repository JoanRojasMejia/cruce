import XCTest
@testable import Cruce

final class BalanceCalculatorTests: XCTestCase {
    private let joan = MockData.joan.id
    private let jesus = MockData.jesus.id

    private func expense(_ payer: UUID, _ amount: Int, _ split: SplitRule = .equal) -> Movement {
        Movement(payerID: payer, amount: amount, concept: "Prueba", category: .otro, split: split, createdBy: payer)
    }

    /// Ejemplo del brief: Joan paga cena $60.000 a medias y Jesús mercado $100.000 a medias.
    func testBriefExampleNetsToJoanOwingTwentyThousand() {
        let movements = [expense(joan, 60_000), expense(jesus, 100_000)]
        XCTAssertEqual(BalanceCalculator.net(of: movements, for: joan), -20_000)
        XCTAssertEqual(BalanceCalculator.net(of: movements, for: jesus), 20_000)
        XCTAssertEqual(BalanceCalculator.state(of: movements, for: joan), .youOwe(20_000))
        XCTAssertEqual(BalanceCalculator.state(of: movements, for: jesus), .theyOweYou(20_000))
    }

    func testNetIsSymmetricBetweenBothMembers() {
        let movements = MockData.movements()
        XCTAssertEqual(
            BalanceCalculator.net(of: movements, for: joan),
            -BalanceCalculator.net(of: movements, for: jesus)
        )
    }

    /// Los datos de ejemplo coinciden con el canvas: "Jesús te debe $20.000".
    func testMockDataMatchesDesign() {
        XCTAssertEqual(BalanceCalculator.state(of: MockData.movements(), for: joan), .theyOweYou(20_000))
    }

    func testLoanCountsFullyForTheOther() {
        let movements = [expense(joan, 40_000, .fullOther)]
        XCTAssertEqual(BalanceCalculator.net(of: movements, for: joan), 40_000)
    }

    func testPercentageSplit() {
        // Joan paga $60.000 y a Jesús le toca el 60 %.
        let movement = expense(joan, 60_000, .percentage(otherShare: 60))
        XCTAssertEqual(movement.owedByOther, 36_000)
        XCTAssertEqual(movement.payerShare, 24_000)
    }

    func testOddAmountsRoundToNearestPeso() {
        XCTAssertEqual(expense(joan, 25_001).owedByOther, 12_501)
        XCTAssertEqual(expense(joan, 25_003, .percentage(otherShare: 30)).owedByOther, 7_501)
    }

    func testSettlementLeavesBalanceAtZero() throws {
        var movements = MockData.movements()
        let payment = try XCTUnwrap(
            BalanceCalculator.settlement(movements: movements, me: joan, other: jesus, createdBy: joan, paymentMethod: "Nequi")
        )
        XCTAssertEqual(payment.payerID, jesus, "Quien debe es quien paga")
        XCTAssertEqual(payment.amount, 20_000)
        movements.append(payment)
        XCTAssertEqual(BalanceCalculator.state(of: movements, for: joan), .settled)
    }

    func testSettlementIsNilWhenAlreadySettled() {
        XCTAssertNil(BalanceCalculator.settlement(movements: [], me: joan, other: jesus, createdBy: joan, paymentMethod: nil))
    }

    func testMovementsSinceLastSettlement() {
        XCTAssertEqual(BalanceCalculator.movementsSinceLastSettlement(MockData.movements()).count, 7)
    }
}
