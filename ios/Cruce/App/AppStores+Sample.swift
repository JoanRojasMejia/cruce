#if DEBUG
    import CruceCore
    import Foundation

    extension AppStores {
        /// Datos de ejemplo del canvas (solo Debug): por defecto los ve Joan y "Jesús te debe $20.000".
        /// Lo usan la app en Debug, `DebugScreen` y las vistas previas.
        @MainActor
        static func sample(
            phase: SessionStore.Phase = .main,
            viewer: Member = MockData.joan,
            movements: [Movement] = MockData.movements(),
            userID: UUID? = nil,
            pendingEmail: String? = nil
        ) -> AppStores {
            let other = viewer.id == MockData.joan.id ? MockData.jesus : MockData.joan
            // Sesión con dobles en memoria: cualquier correo recibe el código 123456, sin red.
            let session = SessionStore(
                phase: phase, me: viewer, partner: other, inviteCode: "CRZ-4821",
                auth: InMemoryAuthService(code: "123456"), directory: InMemoryAccountDirectory(),
                userID: userID, pendingEmail: pendingEmail
            )
            // La lista se fija al construir, para no depender de la tarea `load()`.
            let ledger = LedgerStore(
                session: session,
                repository: InMemoryLedgerRepository(movements: movements),
                movements: movements
            )
            return AppStores(session: session, ledger: ledger, router: Router())
        }
    }
#endif
