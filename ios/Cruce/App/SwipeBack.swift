import SwiftUI
import UIKit

extension View {
    /// Reactiva deslizar desde el borde izquierdo para volver, que iOS desactiva al ocultar la barra de navegación.
    /// Se aplica en la raíz del `NavigationStack` y en cada destino: si la app abre con pantallas ya apiladas,
    /// la raíz no llega a dibujarse.
    func swipeBackEnabled() -> some View {
        background(SwipeBackEnabler())
    }
}

/// UIKit es inevitable aquí: SwiftUI no expone el gesto de volver del `UINavigationController`.
private struct SwipeBackEnabler: UIViewRepresentable {
    func makeUIView(context: Context) -> Probe { Probe() }
    func updateUIView(_ view: Probe, context: Context) {}

    /// Vista invisible que, al entrar en la ventana, busca el `UINavigationController` en la cadena de respondedores.
    final class Probe: UIView {
        // El gesto guarda a su delegado como referencia débil; la vista lo mantiene vivo.
        private let popDelegate = PopDelegate()

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window != nil else { return }
            var responder: UIResponder? = self
            while let current = responder, !(current is UINavigationController) {
                responder = current.next
            }
            popDelegate.navigationController = responder as? UINavigationController
            popDelegate.navigationController?.interactivePopGestureRecognizer?.delegate = popDelegate
        }
    }

    final class PopDelegate: NSObject, UIGestureRecognizerDelegate {
        weak var navigationController: UINavigationController?

        // Solo cuando hay una pantalla a la cual volver; en la raíz el gesto dejaría la pila trabada.
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            (navigationController?.viewControllers.count ?? 0) > 1
        }
    }
}
