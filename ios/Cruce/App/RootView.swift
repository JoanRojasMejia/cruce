import SwiftUI

/// Decide qué flujo mostrar según la etapa de la sesión.
struct RootView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        Group {
            switch app.phase {
            case .onboarding: OnboardingView()
            case .signUp: SignUpView()
            case .invite: InviteView()
            case .join: JoinView()
            case .connected: ConnectedView()
            case .main: MainView()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: app.phase)
    }
}

/// Flujo principal con navegación por pila.
struct MainView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        @Bindable var app = app
        NavigationStack(path: $app.path) {
            HomeView()
                .toolbar(.hidden, for: .navigationBar)
                .swipeBackEnabled()
                .navigationDestination(for: Route.self) { route in
                    destination(for: route)
                        .toolbar(.hidden, for: .navigationBar)
                        .swipeBackEnabled()
                }
        }
        .sheet(item: $app.lastSaved) { movement in
            MovementSavedSheet(movement: movement)
                .presentationDetents([.height(620), .large])
                .presentationCornerRadius(Radius.sheet)
                .presentationBackground(CruceColor.cream)
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(item: $app.lastSettlement) { payment in
            SettleSuccessView(payment: payment)
        }
    }

    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
        case .addMovement: AddMovementView()
        case .editMovement(let id): AddMovementView(editing: app.movement(id))
        case .history: HistoryView()
        case .detail(let id): MovementDetailView(movementID: id)
        case .settle: SettleView()
        case .settings: SettingsView()
        case .offline: OfflineView()
        }
    }
}

#Preview("Inicio") {
    RootView().environment(AppState.preview())
}

#Preview("Onboarding") {
    RootView().environment(AppState.preview(phase: .onboarding))
}
