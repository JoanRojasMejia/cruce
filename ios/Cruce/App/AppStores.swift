import CruceCore
import Supabase
import SwiftUI

/// Los tres stores de la app, juntos solo para llevarlos de la raíz a las vistas. No tiene lógica.
struct AppStores {
    let session: SessionStore
    let ledger: LedgerStore
    let router: Router

    /// Arranque real: la sesión con Supabase Auth (local en Debug, la nube en Release), un solo `SupabaseClient`
    /// para la autenticación y los datos, y sin movimientos hasta el CP5. La etapa sale de `session.refresh()`.
    @MainActor
    static func live() -> AppStores {
        let config = SupabaseConfig.load()
        let client = SupabaseClient(
            supabaseURL: config.url,
            supabaseKey: config.anonKey,
            // Emite la sesión guardada al arrancar aunque haya vencido; `currentUserID()` la renueva.
            options: SupabaseClientOptions(auth: .init(emitLocalSessionAsInitialSession: true))
        )
        let session = SessionStore(
            phase: .onboarding,
            me: Member(name: "Tú", avatarColor: .yellow, tikeVariant: .rosa),
            partner: Member(name: "Tu amigo", avatarColor: .violet, tikeVariant: .verde),
            auth: SupabaseAuthService(client: client),
            directory: SupabaseAccountDirectory(client: client),
            isReady: false
        )
        let ledger = LedgerStore(session: session, repository: InMemoryLedgerRepository())
        return AppStores(session: session, ledger: ledger, router: Router())
    }
}

extension View {
    /// Inyecta los tres stores en el `Environment`. Toda raíz (la app, `DebugScreen` y las vistas previas)
    /// usa este modificador, así ninguna se queda sin uno.
    func cruceStores(_ stores: AppStores) -> some View {
        environment(stores.session)
            .environment(stores.ledger)
            .environment(stores.router)
    }
}
