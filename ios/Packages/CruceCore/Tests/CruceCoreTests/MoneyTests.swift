import Testing
@testable import CruceCore

@Suite("Formato y lectura de pesos")
struct MoneyTests {
    @Test("El formato agrupa los miles con puntos", arguments: [
        (0, "$0"),
        (999, "$999"),
        (30_000, "$30.000"),
        (1_800_000, "$1.800.000"),
    ])
    func formatGroupsThousandsWithDots(value: Int, expected: String) {
        #expect(Money.format(value) == expected)
    }

    @Test("Con signo usa el menos tipográfico", arguments: [
        (18_000, "+$18.000"),
        (-50_000, "\u{2212}$50.000"),
        (0, "$0"),
    ])
    func formatWithSignUsesTypographicMinus(value: Int, expected: String) {
        #expect(Money.format(value, showsSign: true) == expected)
    }

    @Test("Lee los dígitos que se escriben en el teclado", arguments: [
        ("60000", 60_000),
        ("", 0),
        ("$60.000", 60_000),
    ])
    func parseDigits(digits: String, expected: Int) {
        #expect(Money.parse(digits: digits) == expected)
    }
}
