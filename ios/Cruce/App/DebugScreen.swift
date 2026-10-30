#if DEBUG
    import SwiftUI
    import CruceCore

    /// Abre la app directo en una pantalla con datos de ejemplo, para comparar con las capturas del diseño.
    /// Solo existe en Debug. Uso: `xcrun simctl launch <udid> com.joanrojas.cruce.dev -screen history`.
    enum DebugScreen: String, CaseIterable {
        case onboarding1, onboarding2, onboarding3
        case signUp, signUpCode, signUpName, invite, join, joinInvalid, connected
        /// "Tengo un código": de un parche y de un lugar (con la base en memoria) y cada error.
        case codeParche, codePlace, codeExpired, codeUsed, codeOwn, codeUnknown
        case homeEmpty, homeTheyOwe, homeYouOwe, homeJesus, cruces, cruceAna
        /// La entrada "Choque" sobre el inicio de ejemplo (las demás pantallas abren sin ella).
        case splash
        case add, saved, history, detail, delete, settle, success, offline, settings
        case cruceSettings, profile, defaultSplit, settleAmount, successPartial, unlink, unlinkSettled, crucesClosed,
            cruceClosed
        case parches, parchesEmpty, parcheNew, parcheCode, parcheArrival, parcheArrivalPlace, parcheDetail,
            parcheDetailEnd, parcheShare, parcheActivity,
            parcheExpense,
            parcheExpenseItems
        case parcheTicket, parcheTicketSettled, parcheTicketGroup
        /// "Finca" (`MockParches.finca`): el detalle y los tickets de Nata y Yisus, con "Cómo se calcula".
        case parcheFinca, parcheTicketNata, parcheTicketYisus
        case parcheDelete, parchePayment, parchePaymentOver, parcheClose, parcheNotCreator, parcheCloseNotCreator,
            parcheCruce, parcheCrucePending, parcheClosed,
            parcheOffline, parcheUndo
        /// "Cena de Ana" cerrado con todos en $0 (A2-52) y "Santa Marta" visto por Carlos, que debe (A2-53).
        case parcheSettledAll, parcheYouOwe
        /// "Editar movimiento": al editar no arranca ningún teclado (se abre al tocar la tarjeta del monto).
        case editMovement

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
            // Quien todavía no tiene cruce escribe el código de Joan en "Tengo un código", desde invitar.
            case .join, .joinInvalid:
                let stores = AppStores.sample(
                    phase: .invite, viewer: MockData.jesus, pendingCode: self == .join ? "CRZ-4821" : "CRZ-0000")
                stores.router.path = [.enterCode]
                return stores
            case .codeParche, .codePlace:
                // Ana (de `MockData`) no está en "Santa Marta": el código lleva al parche o al lugar de Carlos.
                let stores = AppStores.sample(
                    viewer: MockData.ana, pendingCode: self == .codeParche ? "PCH-SM4R7A" : "SOY-K7QX2M")
                stores.router.path = [.enterCode]
                return stores
            case .codeExpired, .codeUsed, .codeOwn, .codeUnknown: return .sample()
            case .connected: return .sample(phase: .connected)
            case .homeEmpty: return .sample(movements: [])
            case .homeTheyOwe, .splash: return .sample()
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
            case .editMovement:
                let stores = AppStores.sample()
                stores.router.path = [.editMovement(stores.ledger.visibleMovements[0].id)]
                return stores
            case .history: return stores(path: [.history])
            case .detail, .delete: return .sample()
            case .settle: return stores(path: [.settle])
            case .offline:
                let stores = stores(path: [.offline])
                stores.ledger.isOffline = true
                stores.ledger.pendingSyncCount = 1
                return stores
            case .settings:
                // Ajustes de la cuenta: desde el engrane de "Tus cruces".
                let stores = AppStores.sample(withAna: true)
                stores.router.path = [.settings]
                return stores
            case .cruceSettings, .unlink: return stores(path: [.cruceSettings])
            case .unlinkSettled:
                // A paz y salvo: el diálogo no ofrece "Saldar primero".
                let stores = AppStores.sample(movements: [])
                stores.router.path = [.cruceSettings]
                return stores
            case .profile: return stores(path: [.settings, .profile])
            case .defaultSplit: return stores(path: [.cruceSettings, .defaultSplit])
            case .settleAmount: return .sample()
            case .successPartial:
                let stores = AppStores.sample()
                stores.ledger.lastSettlement = BalanceCalculator.settlement(
                    movements: stores.ledger.visibleMovements, me: MockData.joan.id, other: MockData.jesus.id,
                    createdBy: MockData.joan.id, paymentMethod: "Nequi", amount: 5_000
                )
                return stores
            case .crucesClosed: return .sample(withAna: true, closedJesus: true)
            case .cruceClosed:
                let stores = AppStores.sample(closedJesus: true)
                stores.router.push(.cruce(MockData.joanJesusCruceID))
                return stores
            case .parches: return stores(path: [.parches])
            case .parchesEmpty: return stores(path: [.parches], parcheBackend: InMemoryParcheBackend())
            case .parcheNew: return stores(path: [.newParche])
            case .parcheCode: return stores(path: [.enterCode])
            case .parcheArrival, .parcheArrivalPlace:
                // Ana (de `MockData`) no está en "Santa Marta": entra con el código en `rootOverride`.
                return .sample(viewer: MockData.ana)
            case .parcheDetail, .parcheDetailEnd, .parcheOffline, .parcheUndo:
                return stores(path: [.parche(MockParches.santaMartaID)])
            case .parcheShare: return .sample()
            case .parcheActivity:
                return stores(path: [
                    .parche(MockParches.santaMartaID), .parcheActivity(parcheID: MockParches.santaMartaID),
                ])
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
            case .parcheFinca: return stores(path: [.parche(MockParches.fincaID)], parcheBackend: Self.fincaBackend())
            case .parcheTicketNata, .parcheTicketYisus:
                return stores(
                    path: [
                        .parche(MockParches.fincaID),
                        .parcheTicket(
                            parcheID: MockParches.fincaID,
                            participantID: self == .parcheTicketNata ? MockParches.fincaNata : MockParches.fincaYisus),
                    ], parcheBackend: Self.fincaBackend())
            case .parchePayment, .parchePaymentOver:
                return stores(path: [.parchePayment(parcheID: MockParches.santaMartaID)])
            case .parcheClose: return stores(path: [.closeParche(parcheID: MockParches.santaMartaID)])
            case .parcheNotCreator, .parcheCloseNotCreator:
                // Jesús ve "Santa Marta", que creó Joan: no lo puede cerrar.
                return AppStores.sample(viewer: MockData.jesus)
            case .parcheCruce:
                return stores(
                    path: [.closeParche(parcheID: MockParches.santaMartaID)],
                    parcheBackend: closedBackend(carlosHasApp: true))
            case .parcheCrucePending:
                return stores(
                    path: [.parche(MockParches.santaMartaID)],
                    parcheBackend: closedBackend(carlosHasApp: true, carlosProposed: true))
            case .parcheClosed:
                return stores(path: [.parche(MockParches.santaMartaID)], parcheBackend: closedBackend())
            case .parcheSettledAll: return stores(path: [.parche(MockParches.cenaID)])
            case .parcheYouOwe:
                // Carlos ya tiene la app y lo ve él: debe $172.000 a favor de Jesús y Joan.
                let stores = AppStores.sample(
                    viewer: Self.carlos, parcheBackend: closedBackend(carlosHasApp: true, closed: false))
                stores.router.path = [.parche(MockParches.santaMartaID)]
                return stores
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
            case .settleAmount:
                ChangeAmountSheet(total: stores.ledger.balance.amount, initial: 5_000) { _ in }
                    .screenBackground()
            case .unlink, .unlinkSettled:
                NavigationStack {
                    CruceSettingsView(confirmingUnlink: true).toolbar(.hidden, for: .navigationBar)
                }
            case .detail, .delete:
                NavigationStack {
                    MovementDetailView(
                        movementID: stores.ledger.visibleMovements[0].id, confirmingDelete: self == .delete
                    )
                    .toolbar(.hidden, for: .navigationBar)
                }
            case .codeExpired, .codeUsed, .codeOwn, .codeUnknown:
                NavigationStack {
                    Group {
                        switch self {
                        case .codeExpired:
                            EnterCodeView(
                                code: "CRZ-4821",
                                preview: .rejected(.expired, message: CodeRejection.expired.defaultMessage))
                        case .codeUsed:
                            EnterCodeView(
                                code: "SOY-K7QX2M",
                                preview: .rejected(.used, message: CodeRejection.used.defaultMessage))
                        case .codeOwn:
                            EnterCodeView(
                                code: "CRZ-4821", preview: .rejected(.own, message: CodeRejection.own.defaultMessage))
                        default:
                            EnterCodeView(code: "HOLA-1234")
                        }
                    }
                    .toolbar(.hidden, for: .navigationBar)
                }
            case .parcheDetailEnd:
                NavigationStack {
                    ParcheDetailView(parcheID: MockParches.santaMartaID, startsAtBottom: true)
                        .toolbar(.hidden, for: .navigationBar)
                }
            case .parcheArrival, .parcheArrivalPlace:
                RootView()
                    .task {
                        // Entra de verdad (en memoria) y abre la llegada, como desde "Tengo un código".
                        await stores.parches.load()
                        let code = self == .parcheArrival ? "PCH-SM4R7A" : "SOY-K7QX2M"
                        if let arrival = await stores.parches.enter(code: code) {
                            stores.router.path = [
                                .parcheArrival(parcheID: arrival.detail.id, kind: arrival.kind)
                            ]
                        }
                    }
            case .parcheShare:
                NavigationStack {
                    ParcheDetailView(parcheID: MockParches.santaMartaID, sharing: true)
                        .toolbar(.hidden, for: .navigationBar)
                }
            case .parcheNotCreator:
                NavigationStack {
                    ParcheDetailView(parcheID: MockParches.santaMartaID, startsAtBottom: true)
                        .toolbar(.hidden, for: .navigationBar)
                }
            case .parcheCloseNotCreator:
                NavigationStack {
                    CloseParcheView(parcheID: MockParches.santaMartaID).toolbar(.hidden, for: .navigationBar)
                }
            case .parchePaymentOver:
                NavigationStack {
                    ParchePaymentView(
                        parcheID: MockParches.santaMartaID,
                        overpayment: "Carlos te debe $47.000 en el parche. Anotaste $50.000."
                    )
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
                        // Se va la señal y un pago y un gasto quedan en la cola del teléfono ("Sin enviar").
                        await stores.parches.load()
                        await Self.offlineBackend.setOffline(true)
                        await stores.parches.recordPayment(
                            in: MockParches.santaMartaID, from: MockParches.carlos, to: MockParches.jesus,
                            amount: 20_000)
                        let people: Set = [MockParches.joan, MockParches.jesus, MockParches.ana, MockParches.carlos]
                        if let expense = stores.parches.validateExpense(
                            in: MockParches.santaMartaID, concept: "Hielo", base: 12_000, split: .equal(people),
                            payers: [ParchePayer(participantID: MockParches.joan, amount: 12_000)])
                        {
                            await stores.parches.save(expense)
                        }
                    }
            case .signUpCode:
                // Recién enviado el código: "Pedir otro código" muestra la cuenta regresiva de 30 s.
                RootView().task { await stores.session.resendCode() }
            case .parcheUndo:
                RootView()
                    .task {
                        // Recién borrado el almuerzo: el aviso con "Deshacer" dura 5 segundos.
                        await stores.parches.load()
                        await stores.parches.deleteExpense(Self.lunchID, in: MockParches.santaMartaID)
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

        /// Los parches de ejemplo y "Finca", que no está en `MockParches.parches()` para no cambiar las pruebas.
        private static func fincaBackend() -> InMemoryParcheBackend {
            InMemoryParcheBackend(
                parches: MockParches.parches() + [MockParches.finca()],
                cruces: [[MockData.joan.id, MockData.jesus.id]], colors: MockParches.colors)
        }

        /// La cuenta de Carlos cuando se queda con su lugar (solo para estas pantallas).
        private static let carlosUserID = UUID(uuidString: "00000000-0000-0000-0000-0000000000A4")!

        /// Carlos como quien usa la app (`parcheYouOwe`).
        private static let carlos = Member(id: carlosUserID, name: "Carlos", avatarColor: .peach, tikeVariant: .verde)

        /// "Santa Marta" ya cerrado. Joan y Jesús comparten un cruce, pero en "Para saldar" no hay un pago entre ellos.
        /// Con `carlosHasApp`, Carlos se quedó con su lugar y comparte un cruce con Joan: aparece la pregunta por los
        /// $47.000 que le paga a Joan. Con `carlosProposed`, Carlos ya lo propuso y Joan lo acepta o lo rechaza. Con
        /// `closed: false`, "Santa Marta" sigue abierto.
        private func closedBackend(
            carlosHasApp: Bool = false, carlosProposed: Bool = false, closed: Bool = true
        ) -> InMemoryParcheBackend {
            let parches = MockParches.parches().map { detail in
                var detail = detail
                guard detail.id == MockParches.santaMartaID else { return detail }
                if closed {
                    detail.parche.status = .closed
                    detail.parche.closedAt = .now
                }
                if carlosHasApp, let index = detail.participants.firstIndex(where: { $0.id == MockParches.carlos }) {
                    detail.participants[index].userID = Self.carlosUserID
                    detail.participants[index].claimCode = nil
                }
                if carlosProposed {
                    detail.transfers.append(
                        ParcheCruceTransfer(
                            parcheID: detail.id, fromID: MockParches.carlos, toID: MockParches.joan, amount: 47_000,
                            createdAt: .now, status: .pending, proposedBy: MockParches.carlos))
                }
                return detail
            }
            var cruces: [Set<UUID>] = [[MockData.joan.id, MockData.jesus.id]]
            if carlosHasApp { cruces.append([MockData.joan.id, Self.carlosUserID]) }
            return InMemoryParcheBackend(parches: parches, cruces: cruces)
        }
    }
#endif
