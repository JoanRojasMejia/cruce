import XCTest
@testable import Cruce

final class DateTextTests: XCTestCase {
    private let friday = DateComponents(calendar: Calendar(identifier: .gregorian), year: 2026, month: 10, day: 23, hour: 20).date!

    func testDayHasNoRelativeWord() {
        // Aunque sea hoy, `day` no dice "Hoy": se usa después de "el" en el texto para compartir.
        XCTAssertEqual(DateText.day(friday), "vie 23 oct")
    }

    func testLongKeepsRelativeWordForToday() {
        XCTAssertEqual(DateText.long(friday, now: friday), "Hoy, vie 23 oct")
    }

    func testShortDatesHaveNoDe() {
        // El diseño escribe "14 oct", no "14 de oct".
        let older = Calendar(identifier: .gregorian).date(byAdding: .day, value: -9, to: friday)!
        XCTAssertEqual(DateText.relative(older, now: friday), "14 oct")
        XCTAssertEqual(DateText.groupHeader(older, now: friday), "MIÉ 14 OCT")
    }
}
