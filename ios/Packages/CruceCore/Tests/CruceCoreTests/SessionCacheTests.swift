import Foundation
import Testing

@testable import CruceCore

/// Abrir la app sin red (CP7): la sesión guarda lo último que supo (quién entró, sus cruces y el abierto) y arranca con
/// eso aunque la base no responda.
@MainActor
@Suite("Sesión sin conexión")
struct SessionCacheTests {
    private let joanID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private let jesusID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!

    private func directory() async -> InMemoryAccountDirectory {
        let directory = InMemoryAccountDirectory(profiles: [
            Profile(id: joanID, displayName: "Joan"), Profile(id: jesusID, displayName: "Jesús"),
        ])
        await directory.link(joanID, jesusID)
        return directory
    }

    private func session(_ directory: InMemoryAccountDirectory, cache: InMemorySessionCache) -> SessionStore {
        SessionStore(
            phase: .onboarding, me: Member(name: "Tú", avatarColor: .yellow, tikeVariant: .rosa),
            partner: Member(name: "Tu amigo", avatarColor: .violet, tikeVariant: .verde),
            auth: InMemoryAuthService(signedIn: joanID), directory: directory, cache: cache, isReady: false)
    }

    @Test("Con red, la sesión guarda quién entró y sus cruces")
    func refreshSavesSnapshot() async throws {
        let cache = InMemorySessionCache()
        await session(await directory(), cache: cache).refresh()
        let saved = try #require(try await cache.load())
        #expect(saved.me.name == "Joan")
        #expect(saved.cruces.map(\.partner.name) == ["Jesús"])
    }

    @Test("Sin red, la app abre en el inicio con lo guardado")
    func restoreOffline() async {
        let cache = InMemorySessionCache()
        let online = await directory()
        await session(online, cache: cache).refresh()

        let offline = await directory()
        await offline.setFailing(true)
        let reopened = session(offline, cache: cache)
        await reopened.restore()
        #expect(reopened.isReady)
        #expect(reopened.phase == .main)
        #expect(reopened.partner.name == "Jesús")
        await reopened.refresh()
        #expect(reopened.phase == .main)
        #expect(reopened.error == .network)
    }

    @Test("Sin nada guardado, restaurar no cambia la etapa")
    func restoreEmpty() async {
        let reopened = session(await directory(), cache: InMemorySessionCache())
        await reopened.restore()
        #expect(!reopened.isReady)
        #expect(reopened.phase == .onboarding)
    }

    @Test("Cerrar sesión borra lo guardado")
    func signOutClears() async throws {
        let cache = InMemorySessionCache()
        let joan = session(await directory(), cache: cache)
        await joan.refresh()
        await joan.signOut()
        #expect(try await cache.load() == nil)
    }
}
