import Foundation
import Testing

@testable import CruceCore

@Suite("Fechas en español")
struct DateTextTests {
    /// Gregoriano y en la zona horaria del sistema, la misma que usan los formateadores de `DateText`.
    /// Así las pruebas dan lo mismo en cualquier zona (se comprueba con `TZ=America/Bogota` y `TZ=Asia/Tokyo`).
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }()

    private var friday: Date {
        DateComponents(calendar: calendar, year: 2026, month: 10, day: 23, hour: 20).date!
    }

    @Test("`day` no dice Hoy ni Ayer")
    func dayHasNoRelativeWord() {
        // Aunque sea hoy, `day` no dice "Hoy": se usa después de "el" en el texto para compartir.
        #expect(DateText.day(friday) == "vie 23 oct")
    }

    @Test("`long` conserva Hoy cuando es el mismo día")
    func longKeepsRelativeWordForToday() {
        #expect(DateText.long(friday, now: friday) == "Hoy, vie 23 oct")
    }

    @Test("`moment` dice la hora con su artículo")
    func momentSaysHourWithArticle() throws {
        let oneOClock = try #require(calendar.date(bySettingHour: 13, minute: 16, second: 0, of: friday))
        #expect(DateText.moment(oneOClock, now: friday, calendar: calendar) == "hoy a la 1:16 p. m.")
        let yesterday = try #require(calendar.date(byAdding: .day, value: -1, to: friday))
        #expect(DateText.moment(yesterday, now: friday, calendar: calendar) == "ayer a las 8:00 p. m.")
        let older = try #require(calendar.date(byAdding: .day, value: -2, to: friday))
        #expect(DateText.moment(older, now: friday, calendar: calendar) == "el 21 oct a las 8:00 p. m.")
    }

    @Test("Las fechas cortas no llevan \"de\"")
    func shortDatesHaveNoDe() throws {
        // El diseño escribe "14 oct", no "14 de oct".
        let older = try #require(calendar.date(byAdding: .day, value: -9, to: friday))
        #expect(DateText.relative(older, now: friday, calendar: calendar) == "14 oct")
        #expect(DateText.groupHeader(older, now: friday, calendar: calendar) == "MIÉ 14 OCT")
    }
}
