import SwiftUI

@main
struct CruceApp: App {
    @State private var app: AppState

    init() {
        // Por ahora la app arranca con datos de ejemplo vistos por Joan.
        // En el punto 2 esto se reemplaza por la sesión real de Supabase.
        _app = State(initialValue: AppState.preview(phase: .onboarding))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
                .preferredColorScheme(.light)
                .task { await app.load() }
        }
    }
}
