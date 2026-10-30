import Testing

@testable import CruceCore

@Suite("Teclado de montos")
struct AmountEntryTests {
    /// Toca las teclas en orden desde un monto vacío.
    private func type(_ keys: [AmountKey], from amount: Int = 0) -> Int {
        keys.reduce(amount) { AmountEntry.press($1, on: $0) }
    }

    @Test("Seis y tres ceros dan $6.000, como al escribir \"6000\"")
    func sixAndTripleZero() {
        let amount = type([.digit(6), .tripleZero])
        #expect(amount == 6_000)
        #expect(Money.format(amount) == "$6.000")
        #expect(amount == Money.parse(digits: "6000"))
    }

    @Test("Los dígitos se agregan a la derecha")
    func digitsAppend() {
        #expect(type([.digit(6), .digit(0), .digit(0), .digit(0), .digit(0)]) == 60_000)
    }

    @Test("Los ceros a la izquierda no cuentan")
    func leadingZerosAreIgnored() {
        #expect(type([.digit(0), .digit(0)]) == 0)
        #expect(type([.tripleZero]) == 0)
        #expect(type([.digit(0), .digit(5)]) == 5)
    }

    @Test("Borrar quita el último dígito y en cero no hace nada")
    func deleteRemovesLastDigit() {
        #expect(AmountEntry.press(.delete, on: 6_000) == 600)
        #expect(AmountEntry.press(.delete, on: 7) == 0)
        #expect(AmountEntry.press(.delete, on: 0) == 0)
    }

    @Test("Acepta hasta 12 dígitos, el mismo límite que la lectura de montos")
    func capsAtTwelveDigits() {
        let twelve = 999_999_999_999
        #expect(AmountEntry.maxDigits == 12)
        #expect(AmountEntry.press(.digit(9), on: 99_999_999_999) == twelve)
        #expect(AmountEntry.press(.digit(5), on: twelve) == twelve)
        // "000" no entra si pasaría de 12 dígitos: el monto queda igual.
        #expect(AmountEntry.press(.tripleZero, on: 1_234_567_890) == 1_234_567_890)
        #expect(AmountEntry.press(.tripleZero, on: 123_456_789) == 123_456_789_000)
        #expect(Money.parse(digits: "1234567890123") == 123_456_789_012)
    }

    @Test("Las teclas van en el orden del diseño")
    func layout() {
        let titles = AmountKey.layout.map(\.title)
        #expect(titles == ["1", "2", "3", "4", "5", "6", "7", "8", "9", "000", "0", "⌫"])
    }

    @Test("Cada tecla tiene su etiqueta para VoiceOver")
    func accessibilityLabels() {
        #expect(AmountKey.delete.accessibilityLabel == "Borrar")
        #expect(AmountKey.tripleZero.accessibilityLabel == "Tres ceros")
        #expect(AmountKey.digit(3).accessibilityLabel == "3")
        #expect(AmountKey.digit(0).accessibilityLabel == "0")
    }

    @Test(
        "El monto hablado usa los dígitos sin puntos y dice pesos",
        arguments: [
            (60_000, "60000 pesos"),
            (1, "1 peso"),
            (0, "0 pesos"),
        ])
    func spokenValue(amount: Int, expected: String) {
        #expect(AmountEntry.spokenValue(amount) == expected)
    }

    @Test("Al tocar una tecla se anuncia \"Monto: …\"")
    func announcement() {
        #expect(AmountEntry.announcement(60_000) == "Monto: 60000 pesos")
    }

    @Test("Al anotar algo nuevo arranca el monto; al editar, nada")
    func initialFocus() {
        #expect(AmountEntryFocus.initial(isEditing: false) == .amount)
        #expect(AmountEntryFocus.initial(isEditing: true) == .none)
        #expect(AmountEntryFocus.amount.showsKeypad)
        #expect(!AmountEntryFocus.field.showsKeypad)
        #expect(!AmountEntryFocus.none.showsKeypad)
    }

    @Test("El teclado del sistema cierra el de Cruce; al cerrarse no abre ninguno")
    func systemKeyboardTransitions() {
        #expect(AmountEntryFocus.amount.afterSystemKeyboardShows == .field)
        #expect(AmountEntryFocus.none.afterSystemKeyboardShows == .field)
        #expect(AmountEntryFocus.field.afterSystemKeyboardHides == .none)
        // Tocar la tarjeta baja el teclado del sistema: el de Cruce queda abierto.
        #expect(AmountEntryFocus.amount.afterSystemKeyboardHides == .amount)
        #expect(AmountEntryFocus.none.afterSystemKeyboardHides == .none)
    }
}
