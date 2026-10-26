import CruceCore
import SwiftUI

/// Decide qué flujo mostrar según la etapa de la sesión. Al arrancar con la sesión real
/// (`AppStores.live()`), primero la calcula con `session.refresh()`; los datos de ejemplo ya vienen listos.
struct RootView: View {
    @Environment(SessionStore.self) private var session

    var body: some View {
        Group {
            if !session.isReady {
                // Mientras se lee la sesión guardada: el mismo fondo del arranque, sin parpadear el onboarding.
                CruceColor.cream.ignoresSafeArea()
            } else {
                phaseView
            }
        }
        .animation(.easeInOut(duration: 0.25), value: session.phase)
        .task {
            if !session.isReady { await session.refresh() }
        }
    }

    @ViewBuilder
    private var phaseView: some View {
        Group {
            switch session.phase {
            case .onboarding: OnboardingView()
            case .signUp: SignUpView()
            case .invite: InviteView()
            case .join: JoinView()
            case .connected: ConnectedView()
            case .main: MainView()
            }
        }
    }
}

/// Flujo principal con navegación por pila.
struct MainView: View {
    @Environment(LedgerStore.self) private var ledger
    @Environment(Router.self) private var router

    var body: some View {
        @Bindable var ledger = ledger
        @Bindable var router = router
        NavigationStack(path: $router.path) {
            HomeView()
                .toolbar(.hidden, for: .navigationBar)
                .swipeBackEnabled()
                .navigationDestination(for: Route.self) { route in
                    destination(for: route)
                        .toolbar(.hidden, for: .navigationBar)
                        .swipeBackEnabled()
                }
        }
        // Oscurece el inicio detrás de "Gasto guardado" más que la atenuación del sistema.
        .overlay {
            if ledger.lastSaved != nil {
                CruceColor.scrim.ignoresSafeArea().transition(.opacity).allowsHitTesting(false)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: ledger.lastSaved != nil)
        .sheet(item: $ledger.lastSaved) { movement in
            MovementSavedSheet(movement: movement)
                .presentationDetents([.height(520), .large])
                .presentationCornerRadius(Radius.sheet)
                .presentationBackground { SheetBackground() }
                .presentationDragIndicator(.hidden)
        }
        .fullScreenCover(item: $ledger.lastSettlement) { payment in
            SettleSuccessView(payment: payment)
        }
    }

    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
        case .addMovement: AddMovementView()
        case .editMovement(let id): AddMovementView(editing: ledger.movement(id))
        case .history: HistoryView()
        case .detail(let id): MovementDetailView(movementID: id)
        case .settle: SettleView()
        case .settings: SettingsView()
        case .offline: OfflineView()
        }
    }
}

#if DEBUG
    #Preview("Inicio") {
        RootView().cruceStores(.sample())
    }

    #Preview("Onboarding") {
        RootView().cruceStores(.sample(phase: .onboarding))
    }
#endif
