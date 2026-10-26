#if DEBUG
    import SwiftUI
    import CruceCore

    /// Abre la app directo en una pantalla con datos de ejemplo, para comparar con las capturas del diseño.
    /// Solo existe en Debug. Uso: `xcrun simctl launch <udid> com.joanrojas.cruce -screen history`.
    enum DebugScreen: String, CaseIterable {
        case onboarding1, onboarding2, onboarding3
        case signUp, invite, join, connected
        case homeEmpty, homeTheyOwe, homeYouOwe, homeJesus
        case add, saved, history, detail, delete, settle, success, offline, settings

        /// Pantalla pedida con el argumento `-screen`, si la hay.
        static var current: DebugScreen? {
            UserDefaults.standard.string(forKey: "screen").flatMap(DebugScreen.init(rawValue:))
        }

        @MainActor
        func makeStores() -> AppStores {
            switch self {
            case .onboarding1, .onboarding2, .onboarding3: return .sample(phase: .onboarding)
            case .signUp: return .sample(phase: .signUp)
            case .invite: return .sample(phase: .invite)
            case .join: return .sample(phase: .join, viewer: MockData.jesus)
            case .connected: return .sample(phase: .connected)
            case .homeEmpty: return .sample(movements: [])
            case .homeTheyOwe: return .sample()
            case .homeYouOwe:
                // Solo los gastos que pagó Jesús: Joan queda debiendo.
                return .sample(movements: MockData.movements().filter { $0.payerID == MockData.jesus.id })
            case .homeJesus: return .sample(viewer: MockData.jesus)
            case .add: return stores(path: [.addMovement])
            case .history: return stores(path: [.history])
            case .detail, .delete: return .sample()
            case .settle: return stores(path: [.settle])
            case .offline:
                let stores = stores(path: [.offline])
                stores.ledger.isOffline = true
                stores.ledger.pendingSyncCount = 1
                return stores
            case .settings: return stores(path: [.settings])
            case .saved:
                let stores = AppStores.sample()
                stores.ledger.lastSaved = stores.ledger.visibleMovements.first
                return stores
            case .success:
                let stores = AppStores.sample()
                stores.ledger.lastSettlement = BalanceCalculator.settlement(
                    movements: stores.ledger.visibleMovements, me: MockData.joan.id, other: MockData.jesus.id,
                    createdBy: MockData.joan.id, paymentMethod: "Nequi"
                )
                return stores
            }
        }

        /// Vista raíz: las pantallas que dependen de estado interno de la vista se arman aquí; el resto usa `RootView`.
        @MainActor @ViewBuilder
        func rootOverride(for stores: AppStores) -> some View {
            switch self {
            case .onboarding2: OnboardingView(page: 1)
            case .onboarding3: OnboardingView(page: 2)
            case .detail, .delete:
                NavigationStack {
                    MovementDetailView(
                        movementID: stores.ledger.visibleMovements[0].id, confirmingDelete: self == .delete
                    )
                    .toolbar(.hidden, for: .navigationBar)
                }
            default: RootView()
            }
        }

        @MainActor
        private func stores(path: [Route]) -> AppStores {
            let stores = AppStores.sample()
            stores.router.path = path
            return stores
        }
    }
#endif
