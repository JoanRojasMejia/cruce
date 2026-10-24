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

    func testMomentSaysHourWithArticle() {
        let calendar = Calendar(identifier: .gregorian)
        let oneOClock = calendar.date(bySettingHour: 13, minute: 16, second: 0, of: friday)!
        XCTAssertEqual(DateText.moment(oneOClock, now: friday), "hoy a la 1:16 p. m.")
        let yesterday = calendar.date(byAdding: .day, value: -1, to: friday)!
        XCTAssertEqual(DateText.moment(yesterday, now: friday), "ayer a las 8:00 p. m.")
        let older = calendar.date(byAdding: .day, value: -2, to: friday)!
        XCTAssertEqual(DateText.moment(older, now: friday), "el 21 oct a las 8:00 p. m.")
    }

    func testShortDatesHaveNoDe() {
        // El diseño escribe "14 oct", no "14 de oct".
        let older = Calendar(identifier: .gregorian).date(byAdding: .day, value: -9, to: friday)!
        XCTAssertEqual(DateText.relative(older, now: friday), "14 oct")
        XCTAssertEqual(DateText.groupHeader(older, now: friday), "MIÉ 14 OCT")
    }
}
