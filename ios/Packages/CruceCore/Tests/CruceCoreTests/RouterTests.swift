import Foundation
import Testing

@testable import CruceCore

@MainActor
@Suite("Navegación del flujo principal")
struct RouterTests {
    @Test("Abrir apila las pantallas en orden")
    func pushAppendsRoutes() {
        let router = Router()
        let id = UUID()
        router.push(.history)
        router.push(.detail(id))
        #expect(router.path == [.history, .detail(id)])
    }

    @Test("Volver quita la última pantalla")
    func popRemovesLastRoute() {
        let router = Router(path: [.history, .settle])
        router.pop()
        #expect(router.path == [.history])
    }

    @Test("Volver con la pila vacía no falla")
    func popOnEmptyPathDoesNothing() {
        let router = Router()
        router.pop()
        #expect(router.path.isEmpty)
    }

    @Test("Volver al inicio vacía la pila")
    func popToRootClearsPath() {
        let router = Router(path: [.history, .addMovement, .settings])
        router.popToRoot()
        #expect(router.path.isEmpty)
    }

    @Test("El engrane de \"Tus cruces\" abre los Ajustes de la cuenta")
    func gearInCruceListOpensAccountSettings() {
        #expect(Route.gear(inCruce: false) == .settings)
    }

    @Test("El engrane de un cruce abre los Ajustes del cruce")
    func gearInCruceOpensCruceSettings() {
        let router = Router(path: [.cruce(UUID())])
        router.push(Route.gear(inCruce: true))
        #expect(router.path.last == .cruceSettings)
    }

    @Test("\"Tu cuenta\" en los Ajustes del cruce abre los Ajustes encima")
    func accountRowStacksAccountSettings() {
        let router = Router(path: [.cruceSettings])
        router.push(.settings)
        #expect(router.path == [.cruceSettings, .settings])
        router.pop()
        #expect(router.path == [.cruceSettings])
    }

    @Test("La actividad del parche se abre encima de su detalle y vuelve a él")
    func parcheActivityStacksOnDetail() {
        let id = UUID()
        let router = Router(path: [.parche(id)])
        router.push(.parcheActivity(parcheID: id))
        #expect(router.path == [.parche(id), .parcheActivity(parcheID: id)])
        router.pop()
        #expect(router.path == [.parche(id)])
    }
}
