import Foundation
import Observation

/// Quién usa la app, con quién comparte la cuenta y en qué etapa del flujo de entrada va.
@MainActor
@Observable
public final class SessionStore {
    /// Etapas del flujo de entrada.
    public enum Phase: Equatable, Sendable {
        case onboarding
        case signUp
        case invite
        case join
        case connected
        case main
    }

    public var phase: Phase
    public var me: Member
    public var partner: Member
    /// Código para invitar al otro. `nil` mientras no exista (lo trae el CP4).
    public var inviteCode: String?

    public init(phase: Phase, me: Member, partner: Member, inviteCode: String? = nil) {
        self.phase = phase
        self.me = me
        self.partner = partner
        self.inviteCode = inviteCode
    }

    /// El miembro con ese `id`: quien usa la app o el otro.
    public func member(_ id: UUID) -> Member {
        id == me.id ? me : partner
    }

    /// Vuelve al onboarding. La navegación la limpia quien llama (`Router.popToRoot()`).
    public func signOut() {
        phase = .onboarding
    }
}
