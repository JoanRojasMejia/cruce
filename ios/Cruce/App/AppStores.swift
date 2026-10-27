import CruceCore
import Supabase
import SwiftUI

/// Los stores de la app, juntos solo para llevarlos de la raíz a las vistas. No tiene lógica.
struct AppStores {
    let session: SessionStore
    let ledger: LedgerStore
    let router: Router
    let parches: ParcheStore
    /// Solo en el arranque real; los datos de ejemplo no escuchan la red.
    var network: NetworkMonitor?

    /// Arranque real: la sesión con Supabase Auth (local en Debug, la nube en Release), un solo `SupabaseClient`
    /// para la autenticación y los datos, con los movimientos de cada cruce en Supabase. La etapa sale de `session.refresh()`.
    @MainActor
    static func live() -> AppStores {
        let config = SupabaseConfig.load()
        let client = SupabaseClient(
            supabaseURL: config.url,
            supabaseKey: config.anonKey,
            // Emite la sesión guardada al arrancar aunque haya vencido; `currentUserID()` la renueva.
            options: SupabaseClientOptions(auth: .init(emitLocalSessionAsInitialSession: true))
        )
        // `me` y `partner` son marcadores hasta `refresh()`: el nombre, el color y el recibo salen del perfil y del cruce
        // más reciente (`my_cruces`). Sin cruces, ninguna pantalla muestra `partner`.
        let session = SessionStore(
            phase: .onboarding,
            me: Member(name: "Tú", avatarColor: .yellow, tikeVariant: .rosa),
            partner: Member(name: "Tu amigo", avatarColor: .violet, tikeVariant: .verde),
            auth: SupabaseAuthService(client: client),
            directory: SupabaseAccountDirectory(client: client),
            // Lo último que supo la sesión, para abrir la app sin red (`Application Support/Cruce/sesion.json`).
            cache: FileSessionCache.standard(),
            isReady: false
        )
        let ledger = LedgerStore(
            session: session, repository: SupabaseLedgerRepository(client: client),
            feed: SupabaseMovementFeed(client: client),
            // Los movimientos y la cola sin conexión se guardan en `Application Support/Cruce/movimientos.json`.
            localStore: FileLedgerLocalStore.standard())
        // Los parches van con Supabase; la cola sin conexión y las respuestas a "¿Lo pasas a tu cruce?" se guardan
        // en `Application Support/Cruce/parches.json` para que sobrevivan a cerrar la app.
        let parches = ParcheStore(
            session: session,
            repository: SupabaseParcheRepository(client: client),
            pendingStore: FilePendingStore.standard())
        // Al volver la red se envía lo pendiente y se recarga.
        let network = NetworkMonitor()
        network.start(updating: ledger)
        return AppStores(session: session, ledger: ledger, router: Router(), parches: parches, network: network)
    }
}

extension View {
    /// Inyecta los stores en el `Environment`. Toda raíz (la app, `DebugScreen` y las vistas previas)
    /// usa este modificador, así ninguna se queda sin uno.
    func cruceStores(_ stores: AppStores) -> some View {
        environment(stores.session)
            .environment(stores.ledger)
            .environment(stores.router)
            .environment(stores.parches)
    }
}
