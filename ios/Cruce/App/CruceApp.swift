import SwiftUI

@main
struct CruceApp: App {
    @State private var app: AppState

    init() {
        // Por ahora la app arranca con datos de ejemplo vistos por Joan.
        // En el punto 2 esto se reemplaza por la sesión real de Supabase.
        var initial = AppState.preview(phase: .onboarding)
        #if DEBUG
        if let screen = DebugScreen.current { initial = screen.makeState() }
        #endif
        _app = State(initialValue: initial)
    }

    var body: some Scene {
        WindowGroup {
            root
                .environment(app)
                .preferredColorScheme(.light)
                // El texto crece con el sistema hasta accessibility1; más allá rompe el diseño.
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                .task { await app.load() }
        }
    }

    @ViewBuilder
    private var root: some View {
        #if DEBUG
        if let screen = DebugScreen.current {
            screen.rootOverride(for: app)
        } else {
            RootView()
        }
        #else
        RootView()
        #endif
    }
}
