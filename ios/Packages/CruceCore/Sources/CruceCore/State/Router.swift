import Observation

/// Pila de navegación del flujo principal. `MainView` la enlaza con `NavigationStack(path:)`.
@MainActor
@Observable
public final class Router {
    public var path: [Route]

    public init(path: [Route] = []) {
        self.path = path
    }

    /// Abre una pantalla encima de la actual.
    public func push(_ route: Route) {
        path.append(route)
    }

    /// Vuelve a la pantalla anterior. Con la pila vacía no hace nada.
    public func pop() {
        if !path.isEmpty { path.removeLast() }
    }

    /// Abre "Tengo un código" encima de lo que haya (al abrir un enlace), salvo que ya sea la pantalla de arriba: ahí
    /// la pantalla toma el código nuevo.
    public func showEnterCode() {
        if path.last != .enterCode { path.append(.enterCode) }
    }

    /// Vuelve al inicio.
    public func popToRoot() {
        path.removeAll()
    }
}
