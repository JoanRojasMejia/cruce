import CruceCore
import SwiftUI

/// Decide qué flujo mostrar según la etapa de la sesión. Al arrancar con la sesión real
/// (`AppStores.live()`), primero la calcula con `session.refresh()`; los datos de ejemplo ya vienen listos.
/// También abre los enlaces `cruce://codigo/<CÓDIGO>`: "Tengo un código" con el campo lleno, en cuanto haya sesión.
struct RootView: View {
    @Environment(SessionStore.self) private var session
    @Environment(Router.self) private var router

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
        // Sin sesión, el código espera en `pendingCode` hasta que se llegue a invitar o al inicio.
        .onOpenURL { url in
            if session.receive(link: url) { openPendingCode() }
        }
        .onChange(of: session.phase) { openPendingCode() }
        .onChange(of: session.isReady) { openPendingCode() }
        .task {
            // Sin red, lo guardado abre el inicio al instante; `refresh()` después lo confirma con la base.
            if !session.isReady {
                await session.restore()
                await session.refresh()
            }
        }
    }

    private func openPendingCode() {
        if session.isReady && session.opensPendingCode { router.showEnterCode() }
    }

    @ViewBuilder
    private var phaseView: some View {
        Group {
            switch session.phase {
            case .onboarding: OnboardingView()
            case .signUp: SignUpView()
            case .invite: InviteFlow()
            case .connected: ConnectedView()
            case .main: MainView()
            }
        }
    }
}

/// Flujo principal con navegación por pila. La raíz es el inicio del cruce cuando hay uno solo y sigue abierto; si no,
/// "Tus cruces" (`SessionStore.showsCruceList`).
struct MainView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(SessionStore.self) private var session
    @Environment(LedgerStore.self) private var ledger
    @Environment(Router.self) private var router

    var body: some View {
        @Bindable var session = session
        @Bindable var ledger = ledger
        @Bindable var router = router
        NavigationStack(path: $router.path) {
            Group {
                if session.showsCruceList {
                    CruceListView()
                } else {
                    HomeView()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .swipeBackEnabled()
            .routeDestinations()
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
        // Alguien se unió al código o quien usa la app se unió a otro cruce, estando ya en el inicio.
        .fullScreenCover(item: $session.lastLinked) { _ in
            ConnectedView()
        }
        // Al arrancar, al cambiar los cruces y al volver a la app: se cargan los movimientos de cada cruce y se siguen
        // los cambios en tiempo real mientras la app esté activa. SwiftUI cancela la tarea anterior y cierra los canales.
        .task(id: FollowKey(cruces: session.cruces.map(\.id), isActive: scenePhase == .active)) {
            guard scenePhase == .active else { return }
            // Primero lo guardado en el teléfono (para abrir sin red), después la base y el tiempo real.
            await ledger.restore()
            await ledger.load()
            await ledger.follow()
        }
    }
}

/// Cuándo volver a cargar y a escuchar: cambian los cruces o la app vuelve al primer plano.
private struct FollowKey: Equatable {
    let cruces: [UUID]
    let isActive: Bool
}

/// Invitar con su propia pila: quien todavía no tiene cruce llega desde aquí a "Tengo un código" y a sus parches.
struct InviteFlow: View {
    @Environment(Router.self) private var router

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.path) {
            InviteView()
                .toolbar(.hidden, for: .navigationBar)
                .swipeBackEnabled()
                .routeDestinations()
        }
    }
}

/// Las pantallas de cada `Route`. Lo comparten el flujo principal e invitar.
struct RouteDestinations: ViewModifier {
    @Environment(SessionStore.self) private var session
    @Environment(LedgerStore.self) private var ledger

    func body(content: Content) -> some View {
        content.navigationDestination(for: Route.self) { route in
            destination(for: route)
                .toolbar(.hidden, for: .navigationBar)
                .swipeBackEnabled()
        }
    }

    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
        case .addMovement:
            AddMovementView(
                defaultSplit: SplitRule(
                    otherPercent: session.openCruce?.defaultOtherPercent ?? CruceLink.standardOtherPercent))
        case .editMovement(let id): AddMovementView(editing: ledger.movement(id))
        case .history: HistoryView()
        case .detail(let id): MovementDetailView(movementID: id)
        case .settle: SettleView()
        case .settings: SettingsView()
        case .cruceSettings: CruceSettingsView()
        case .profile: ProfileView()
        case .defaultSplit: DefaultSplitView()
        case .offline: OfflineView()
        case .cruce(let id): HomeView(showsBack: true).onAppear { session.open(id) }
        case .invite: InviteView()
        case .parches: ParcheListView()
        case .parche(let id): ParcheDetailView(parcheID: id)
        case .newParche: NewParcheView()
        case .addParcheExpense(let parcheID): ParcheExpenseView(parcheID: parcheID)
        case .editParcheExpense(let parcheID, let expenseID): ParcheExpenseView(parcheID: parcheID, editing: expenseID)
        case .parchePayment(let parcheID): ParchePaymentView(parcheID: parcheID)
        case .closeParche(let parcheID): CloseParcheView(parcheID: parcheID)
        case .parcheActivity(let parcheID): ParcheActivityView(parcheID: parcheID)
        case .parcheTicket(let parcheID, let participantID):
            ParcheTicketView(parcheID: parcheID, participantID: participantID)
        case .enterCode: EnterCodeView()
        case .parcheArrival(let parcheID, let kind): ParcheArrivalView(parcheID: parcheID, kind: kind)
        }
    }
}

extension View {
    /// Abre las pantallas de `Route` dentro de un `NavigationStack`.
    func routeDestinations() -> some View {
        modifier(RouteDestinations())
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
