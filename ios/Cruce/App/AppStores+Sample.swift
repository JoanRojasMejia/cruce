#if DEBUG
    import CruceCore

    extension AppStores {
        /// Datos de ejemplo del canvas (solo Debug): por defecto los ve Joan y "Jesús te debe $20.000".
        /// Lo usan la app en Debug, `DebugScreen` y las vistas previas.
        @MainActor
        static func sample(
            phase: SessionStore.Phase = .main,
            viewer: Member = MockData.joan,
            movements: [Movement] = MockData.movements()
        ) -> AppStores {
            let other = viewer.id == MockData.joan.id ? MockData.jesus : MockData.joan
            let session = SessionStore(phase: phase, me: viewer, partner: other, inviteCode: "CRZ-4821")
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
