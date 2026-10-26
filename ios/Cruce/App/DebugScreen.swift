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
    func makeState() -> AppState {
        switch self {
        case .onboarding1, .onboarding2, .onboarding3: return .preview(phase: .onboarding)
        case .signUp: return .preview(phase: .signUp)
        case .invite: return .preview(phase: .invite)
        case .join: return .preview(phase: .join, viewer: MockData.jesus)
        case .connected: return .preview(phase: .connected)
        case .homeEmpty: return .preview(movements: [])
        case .homeTheyOwe: return .preview()
        case .homeYouOwe:
            // Solo los gastos que pagó Jesús: Joan queda debiendo.
            return .preview(movements: MockData.movements().filter { $0.payerID == MockData.jesus.id })
        case .homeJesus: return .preview(viewer: MockData.jesus)
        case .add: return state(path: [.addMovement])
        case .history: return state(path: [.history])
        case .detail, .delete: return .preview()
        case .settle: return state(path: [.settle])
        case .offline:
            let state = state(path: [.offline])
            state.isOffline = true
            state.pendingSyncCount = 1
            return state
        case .settings: return state(path: [.settings])
        case .saved:
            let state = AppState.preview()
            state.lastSaved = state.sortedMovements.first
            return state
        case .success:
            let state = AppState.preview()
            state.lastSettlement = BalanceCalculator.settlement(
                movements: state.sortedMovements, me: MockData.joan.id, other: MockData.jesus.id,
                createdBy: MockData.joan.id, paymentMethod: "Nequi"
            )
            return state
        }
    }

    /// Vista raíz: las pantallas que dependen de estado interno de la vista se arman aquí; el resto usa `RootView`.
    @MainActor @ViewBuilder
    func rootOverride(for state: AppState) -> some View {
        switch self {
        case .onboarding2: OnboardingView(page: 1)
        case .onboarding3: OnboardingView(page: 2)
        case .detail, .delete:
            NavigationStack {
                MovementDetailView(movementID: state.sortedMovements[0].id, confirmingDelete: self == .delete)
                    .toolbar(.hidden, for: .navigationBar)
            }
        default: RootView()
        }
    }

    @MainActor
    private func state(path: [Route]) -> AppState {
        let state = AppState.preview()
        state.path = path
        return state
    }
}
#endif
