#if DEBUG
    import SwiftUI
    import CruceCore

    /// Abre la app directo en una pantalla con datos de ejemplo, para comparar con las capturas del diseño.
    /// Solo existe en Debug. Uso: `xcrun simctl launch <udid> com.joanrojas.cruce.dev -screen history`.
    enum DebugScreen: String, CaseIterable {
        case onboarding1, onboarding2, onboarding3
        case signUp, signUpCode, signUpName, invite, join, joinInvalid, connected
        case homeEmpty, homeTheyOwe, homeYouOwe, homeJesus, cruces, cruceAna
        case add, saved, history, detail, delete, settle, success, offline, settings
        case parches, parchesEmpty, parcheNew, parcheCode, parcheDetail, parcheDetailEnd, parcheExpense,
            parcheExpenseItems
        case parcheTicket, parcheTicketSettled, parcheTicketGroup
        case parcheDelete, parchePayment, parcheClose, parcheCruce, parcheClosed, parcheOffline

        /// Pantalla pedida con el argumento `-screen`, si la hay.
        static var current: DebugScreen? {
            UserDefaults.standard.string(forKey: "screen").flatMap(DebugScreen.init(rawValue:))
        }

        @MainActor
        func makeStores() -> AppStores {
            switch self {
            case .onboarding1, .onboarding2, .onboarding3: return .sample(phase: .onboarding)
            case .signUp: return .sample(phase: .signUp)
            case .signUpCode: return .sample(phase: .signUp, pendingEmail: "joan@correo.com")
            case .signUpName: return .sample(phase: .signUp, userID: MockData.joan.id)
            case .invite: return .sample(phase: .invite)
            case .join: return .sample(phase: .join, viewer: MockData.jesus, joinCode: "CRZ-4821")
            case .joinInvalid: return .sample(phase: .join, viewer: MockData.jesus, joinCode: "CRZ-0000")
            case .connected: return .sample(phase: .connected)
            case .homeEmpty: return .sample(movements: [])
            case .homeTheyOwe: return .sample()
            case .homeYouOwe:
                // Solo los gastos que pagó Jesús: Joan queda debiendo.
                return .sample(movements: MockData.movements().filter { $0.payerID == MockData.jesus.id })
            case .homeJesus: return .sample(viewer: MockData.jesus)
            case .cruces: return .sample(withAna: true)
            case .cruceAna:
                let stores = AppStores.sample(withAna: true)
                stores.router.push(.cruce(MockData.joanAnaCruceID))
                return stores
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
            case .parches: return stores(path: [.parches])
            case .parchesEmpty: return stores(path: [.parches], parcheBackend: InMemoryParcheBackend())
            case .parcheNew: return stores(path: [.newParche])
            case .parcheCode: return stores(path: [.enterCode])
            case .parcheDetail, .parcheDetailEnd, .parcheOffline:
                return stores(path: [.parche(MockParches.santaMartaID)])
            case .parcheExpense: return stores(path: [.addParcheExpense(parcheID: MockParches.santaMartaID)])
            case .parcheExpenseItems, .parcheDelete:
                return stores(path: [
                    .editParcheExpense(parcheID: MockParches.santaMartaID, expenseID: Self.lunchID)
                ])
            case .parcheTicket:
                return stores(path: [
                    .parche(MockParches.santaMartaID),
                    .parcheTicket(parcheID: MockParches.santaMartaID, participantID: MockParches.carlos),
                ])
            case .parcheTicketSettled:
                return stores(path: [
                    .parche(MockParches.santaMartaID),
                    .parcheTicket(parcheID: MockParches.santaMartaID, participantID: MockParches.ana),
                ])
            case .parcheTicketGroup:
                return stores(path: [
                    .parche(MockParches.santaMartaID),
                    .parcheTicket(parcheID: MockParches.santaMartaID, participantID: nil),
                ])
            case .parchePayment: return stores(path: [.parchePayment(parcheID: MockParches.santaMartaID)])
            case .parcheClose: return stores(path: [.closeParche(parcheID: MockParches.santaMartaID)])
            case .parcheCruce:
                return stores(path: [.closeParche(parcheID: MockParches.santaMartaID)], parcheBackend: closedBackend())
            case .parcheClosed:
                return stores(path: [.parche(MockParches.santaMartaID)], parcheBackend: closedBackend())
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
            case .parcheDetailEnd:
                NavigationStack {
                    ParcheDetailView(parcheID: MockParches.santaMartaID, startsAtBottom: true)
                        .toolbar(.hidden, for: .navigationBar)
                }
            case .parcheCruce:
                NavigationStack {
                    CloseParcheView(parcheID: MockParches.santaMartaID, closed: true)
                        .toolbar(.hidden, for: .navigationBar)
                }
            case .parcheDelete:
                NavigationStack {
                    ParcheExpenseView(
                        parcheID: MockParches.santaMartaID, editing: Self.lunchID, confirmingDelete: true
                    )
                    .toolbar(.hidden, for: .navigationBar)
                }
            case .parcheOffline:
                RootView()
                    .task {
                        // Se va la señal y un pago queda en la cola del teléfono.
                        await stores.parches.load()
                        await Self.offlineBackend.setOffline(true)
                        await stores.parches.recordPayment(
                            in: MockParches.santaMartaID, from: MockParches.carlos, to: MockParches.jesus,
                            amount: 20_000)
                    }
            default: RootView()
            }
        }

        /// El almuerzo de "Santa Marta" (reparto por consumo con propina).
        private static let lunchID = UUID(uuidString: "00000000-0000-0000-0000-00000000E001")!

        /// Backend que `parcheOffline` deja sin conexión después de cargar.
        private static let offlineBackend = MockParches.backend()

        @MainActor
        private func stores(path: [Route], parcheBackend: InMemoryParcheBackend? = nil) -> AppStores {
            let backend = parcheBackend ?? (self == .parcheOffline ? Self.offlineBackend : nil)
            let stores = AppStores.sample(parcheBackend: backend)
            stores.router.path = path
            return stores
        }

        /// "Santa Marta" ya cerrado: Joan y Jesús comparten un cruce y se deben algo, así que aparece la pregunta.
        private func closedBackend() -> InMemoryParcheBackend {
            let parches = MockParches.parches().map { detail in
                var detail = detail
                if detail.id == MockParches.santaMartaID {
                    detail.parche.status = .closed
                    detail.parche.closedAt = .now
                }
                return detail
            }
            return InMemoryParcheBackend(parches: parches, cruces: [[MockData.joan.id, MockData.jesus.id]])
        }
    }
#endif
