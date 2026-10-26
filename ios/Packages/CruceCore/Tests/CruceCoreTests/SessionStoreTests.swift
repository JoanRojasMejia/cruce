import Foundation
import Testing

@testable import CruceCore

@MainActor
@Suite("Sesión")
struct SessionStoreTests {
    @Test("Cerrar sesión vuelve al onboarding")
    func signOutReturnsToOnboarding() {
        let session = SessionStore(phase: .main, me: MockData.joan, partner: MockData.jesus)
        session.signOut()
        #expect(session.phase == .onboarding)
    }

    @Test("Busca a cada miembro por su id")
    func memberLooksUpById() {
        let session = SessionStore(phase: .main, me: MockData.joan, partner: MockData.jesus)
        #expect(session.member(MockData.jesus.id) == MockData.jesus)
        #expect(session.member(MockData.joan.id) == MockData.joan)
    }

    @Test("El código de invitación empieza vacío")
    func inviteCodeDefaultsToNil() {
        let session = SessionStore(phase: .invite, me: MockData.joan, partner: MockData.jesus)
        #expect(session.inviteCode == nil)
    }
}
