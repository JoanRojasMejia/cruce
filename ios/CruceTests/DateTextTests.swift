import XCTest
@testable import Cruce

final class DateTextTests: XCTestCase {
    private let friday = DateComponents(calendar: Calendar(identifier: .gregorian), year: 2026, month: 10, day: 23, hour: 20).date!

    func testDayHasNoRelativeWord() {
        // Aunque sea hoy, `day` no dice "Hoy": se usa después de "el" en el texto para compartir.
        XCTAssertEqual(DateText.day(friday), "vie 23 de oct")
    }

    func testLongKeepsRelativeWordForToday() {
        XCTAssertEqual(DateText.long(friday, now: friday), "Hoy, vie 23 de oct")
    }
}
