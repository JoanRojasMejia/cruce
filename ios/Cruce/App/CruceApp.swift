import SwiftUI

/// Raíz de composición: arma los stores y los inyecta en el `Environment`.
@main
struct CruceApp: App {
    @State private var stores: AppStores

    init() {
        #if DEBUG
            // En Debug la app arranca con Supabase local, o con los datos de ejemplo de la pantalla
            // pedida con `-screen`.
            _stores = State(initialValue: DebugScreen.current?.makeStores() ?? .live())
        #else
            _stores = State(initialValue: .live())
        #endif
    }

    var body: some Scene {
        WindowGroup {
            root
                .cruceStores(stores)
                .preferredColorScheme(.light)
                // El texto crece con el sistema hasta accessibility1; más allá rompe el diseño.
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                .task {
                    await stores.ledger.load()
                    await stores.parches.load()
                }
        }
    }

    @ViewBuilder
    private var root: some View {
        #if DEBUG
            if let screen = DebugScreen.current {
                screen.rootOverride(for: stores)
            } else {
                RootView()
            }
        #else
            RootView()
        #endif
    }
}
