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
}
