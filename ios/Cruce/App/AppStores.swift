import CruceCore
import SwiftUI

/// Los tres stores de la app, juntos solo para llevarlos de la raíz a las vistas. No tiene lógica.
struct AppStores {
    let session: SessionStore
    let ledger: LedgerStore
    let router: Router

    /// Arranque de Release: onboarding, sin movimientos y con miembros provisionales neutros.
    /// Lo reemplazan la sesión y el código reales del CP3/CP4; Release todavía no se distribuye.
    @MainActor
    static func live() -> AppStores {
        let session = SessionStore(
            phase: .onboarding,
            me: Member(name: "Tú", avatarColor: .yellow, tikeVariant: .rosa),
            partner: Member(name: "Tu amigo", avatarColor: .violet, tikeVariant: .verde)
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
