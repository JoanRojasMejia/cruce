#if DEBUG
    import CruceCore
    import Foundation

    extension AppStores {
        /// Datos de ejemplo del canvas (solo Debug): por defecto los ve Joan y "Jesús te debe $20.000".
        /// En el inicio hay un cruce con Jesús; con `withAna`, Joan tiene también uno con Ana (el más reciente, abierto
        /// al arrancar) donde le debe $15.000, y el inicio muestra "Tus cruces".
        /// Lo usan la app en Debug, `DebugScreen` y las vistas previas.
        @MainActor
        static func sample(
            phase: SessionStore.Phase = .main,
            viewer: Member = MockData.joan,
            movements: [Movement] = MockData.movements(),
            userID: UUID? = nil,
            pendingEmail: String? = nil,
            joinCode: String? = nil,
            withAna: Bool = false,
            parcheBackend: InMemoryParcheBackend? = nil
        ) -> AppStores {
            let other = viewer.id == MockData.joan.id ? MockData.jesus : MockData.joan
            // Con `joinCode`, la pantalla de unirse arranca con ese código y lo revisa contra una base en memoria donde
            // `other` ya invitó con `CRZ-4821`; por eso hace falta una sesión abierta.
            let directory =
                joinCode == nil
                ? InMemoryAccountDirectory()
                : InMemoryAccountDirectory(
                    profiles: [
                        Profile(id: viewer.id, displayName: viewer.name),
                        Profile(id: other.id, displayName: other.name),
                    ],
                    invitesFrom: [other.id])
            // Los cruces solo en el inicio; antes (invitar, unirse) todavía no hay.
            var cruces: [CruceLink] = []
            var byCruce: [UUID: [Movement]] = [:]
            if phase == .main {
                cruces = [MockData.joanJesusCruce(viewer: viewer)]
                byCruce[MockData.joanJesusCruceID] = movements
                if withAna {
                    cruces.insert(MockData.joanAnaCruce, at: 0)
                    byCruce[MockData.joanAnaCruceID] = MockData.anaMovements()
                }
            }
            // Sesión con dobles en memoria: cualquier correo recibe el código 123456, sin red.
            let session = SessionStore(
                phase: phase, me: viewer, partner: other, inviteCode: "CRZ-4821", cruces: cruces,
                auth: InMemoryAuthService(code: "123456"), directory: directory,
                userID: joinCode == nil ? userID : (userID ?? viewer.id), pendingEmail: pendingEmail
            )
            session.pendingJoinCode = joinCode
            // La lista se fija al construir, para no depender de la tarea `load()`.
            let ledger = LedgerStore(
                session: session,
                repository: InMemoryLedgerRepository(movements: byCruce),
                movements: session.openCruceID.flatMap { byCruce[$0] } ?? movements,
                movementsByCruce: byCruce
            )
            // Los parches de `MockParches` vistos por quien usa la app; se leen con `parches.load()` al arrancar.
            let parches = ParcheStore(
                session: session,
                repository: InMemoryParcheRepository(backend: parcheBackend ?? MockParches.backend(), userID: viewer.id)
            )
            return AppStores(session: session, ledger: ledger, router: Router(), parches: parches)
        }
    }
#endif
