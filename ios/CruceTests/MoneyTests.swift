import XCTest
@testable import Cruce

final class MoneyTests: XCTestCase {
    func testFormatGroupsThousandsWithDots() {
        XCTAssertEqual(Money.format(0), "$0")
        XCTAssertEqual(Money.format(999), "$999")
        XCTAssertEqual(Money.format(30_000), "$30.000")
        XCTAssertEqual(Money.format(1_800_000), "$1.800.000")
    }

    func testFormatWithSignUsesTypographicMinus() {
        XCTAssertEqual(Money.format(18_000, showsSign: true), "+$18.000")
        XCTAssertEqual(Money.format(-50_000, showsSign: true), "\u{2212}$50.000")
        XCTAssertEqual(Money.format(0, showsSign: true), "$0")
    }

    func testParseDigits() {
        XCTAssertEqual(Money.parse(digits: "60000"), 60_000)
        XCTAssertEqual(Money.parse(digits: ""), 0)
        XCTAssertEqual(Money.parse(digits: "$60.000"), 60_000)
    }
}
