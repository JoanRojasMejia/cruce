import Testing
@testable import CruceCore

// Prueba provisional: confirma que la lógica vive en el paquete. Se quita al migrar MoneyTests.
@Test("El paquete expone el formato de pesos")
func moneyLivesInPackage() {
    #expect(Money.format(30_000) == "$30.000")
}
