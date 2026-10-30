import Foundation
import Testing

@testable import CruceCore

/// Color fijo por persona (corrección 3): el color sale del perfil y no del rol en cada cruce; quien está sin la app
/// recibe el siguiente color libre del parche; el recibo rosa o verde sigue siendo por cruce.
@MainActor
@Suite("Color fijo por persona")
struct PersonColorTests {
    private let joanID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private let jesusID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    private let anaID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!

    /// Joan es verde, Jesús rosado y Ana durazno: ninguno coincide con el color que antes daba el rol.
    private func makeDirectory() -> InMemoryAccountDirectory {
        InMemoryAccountDirectory(profiles: [
            Profile(id: joanID, displayName: "Joan", avatarColor: .green),
            Profile(id: jesusID, displayName: "Jesús", avatarColor: .pink),
            Profile(id: anaID, displayName: "Ana", avatarColor: .peach),
        ])
    }

    private func session(_ user: UUID, _ directory: InMemoryAccountDirectory) async -> SessionStore {
        let session = SessionStore(
            phase: .onboarding, me: Member(name: "Tú", avatarColor: .yellow, tikeVariant: .rosa),
            partner: Member(name: "Tu amigo", avatarColor: .violet, tikeVariant: .verde),
            auth: InMemoryAuthService(signedIn: user), directory: directory, isReady: false)
        await session.refresh()
        return session
    }

    private func data(_ text: String) -> Data { Data(text.utf8) }

    // MARK: - Paleta

    @Test("La paleta tiene 6 colores, en orden, con los nombres de la base")
    func palette() throws {
        #expect(AvatarColor.palette == [.yellow, .violet, .green, .peach, .pink, .lime])
        let decoded = try JSONDecoder().decode(
            [AvatarColor].self, from: data(#"["yellow","violet","green","peach","pink","lime"]"#))
        #expect(decoded == AvatarColor.palette)
    }

    @Test("Quien está sin la app recibe el siguiente color libre; con los 6 usados, vuelve a empezar")
    func nextFree() {
        #expect(AvatarColor.nextFree(after: []) == .yellow)
        #expect(AvatarColor.nextFree(after: [.green, .yellow]) == .violet)
        #expect(AvatarColor.nextFree(after: [.yellow, .violet, .green, .peach, .pink]) == .lime)
        #expect(AvatarColor.nextFree(after: AvatarColor.palette) == .yellow)
        #expect(AvatarColor.nextFree(after: AvatarColor.palette + [.lime]) == .violet)
    }

    // MARK: - La misma persona, del mismo color en todas partes

    @Test("La misma persona se ve del mismo color en Tus cruces, en un cruce, en un parche y en los tickets")
    func sameColorEverywhere() async throws {
        let directory = makeDirectory()
        // Joan creó el cruce con Jesús y se unió al de Ana: antes era amarillo en uno y violeta en el otro.
        await directory.link(joanID, jesusID)
        await directory.link(anaID, joanID)

        // Tus cruces (Joan) y cada cruce abierto: Joan sigue verde; solo cambia el recibo.
        let joan = await session(joanID, directory)
        #expect(joan.cruces.map(\.partner.avatarColor) == [.peach, .pink])
        for cruce in joan.cruces {
            joan.open(cruce.id)
            #expect(joan.me.avatarColor == .green)
        }
        joan.open(joan.cruces.first { $0.partner.id == jesusID }!.id)
        #expect(joan.me.tikeVariant == .rosa)
        joan.open(joan.cruces.first { $0.partner.id == anaID }!.id)
        #expect(joan.me.tikeVariant == .verde)

        // Jesús y Ana ven a Joan verde en su cruce.
        let jesus = await session(jesusID, directory)
        #expect(jesus.partner.avatarColor == .green)
        #expect(jesus.me.avatarColor == .pink)
        let ana = await session(anaID, directory)
        #expect(ana.partner.avatarColor == .green)

        // En un parche: Joan lo crea, Jesús se une y Carlos va sin la app.
        let backend = InMemoryParcheBackend(colors: [joanID: .green, jesusID: .pink])
        let joanParches = InMemoryParcheRepository(backend: backend, userID: joanID)
        let jesusParches = InMemoryParcheRepository(backend: backend, userID: jesusID)
        let created = try await joanParches.createParche(id: UUID(), name: "Santa Marta", displayName: "Joan")
        _ = try await jesusParches.joinParche(code: created.parche.code, displayName: "Jesús")
        let carlos = try await joanParches.addParticipant(id: UUID(), parcheID: created.id, displayName: "Carlos")
        let detail = try await jesusParches.loadParche(id: created.id)
        let joanInParche = try #require(detail.participants.first { $0.userID == joanID })
        #expect(joanInParche.avatarColor == .green)
        #expect(detail.participants.first { $0.userID == jesusID }?.avatarColor == .pink)
        // Carlos: verde y rosado ya están, así que recibe el primero libre de la paleta.
        #expect(carlos.avatarColor == .yellow)

        // En el ticket de Joan, el mismo color.
        let ticket = try #require(ParcheTicket.personal(for: joanInParche.id, in: detail, at: .now))
        #expect(ticket.person?.avatarColor == .green)
        #expect(ParcheTicket.personal(for: carlos.id, in: detail, at: .now)?.person?.avatarColor == .yellow)
    }

    @Test("Quien se queda con un lugar pasa a tener el color de su perfil")
    func claimTakesProfileColor() async throws {
        let backend = InMemoryParcheBackend(colors: [joanID: .green, anaID: .peach])
        let joanParches = InMemoryParcheRepository(backend: backend, userID: joanID)
        let created = try await joanParches.createParche(id: UUID(), name: "Cena", displayName: "Joan")
        let carlos = try await joanParches.addParticipant(id: UUID(), parcheID: created.id, displayName: "Carlos")
        #expect(carlos.avatarColor == .yellow)
        let code = try #require(carlos.claimCode)
        let claimed = try await InMemoryParcheRepository(backend: backend, userID: anaID).claimPlace(code: code)
        #expect(claimed.participant(carlos.id)?.avatarColor == .peach)
    }

    // MARK: - Cambiar el color

    @Test("Cambiar el color en Tu perfil se guarda, se ve en el cruce del otro y en los parches")
    func updateColor() async throws {
        let directory = makeDirectory()
        await directory.link(joanID, jesusID)
        let joan = await session(joanID, directory)
        #expect(await joan.updateColor(.lime))
        #expect(joan.me.avatarColor == .lime)
        #expect(await directory.storedProfile(for: joanID)?.avatarColor == .lime)
        let jesus = await session(jesusID, directory)
        #expect(jesus.partner.avatarColor == .lime)

        let backend = InMemoryParcheBackend(colors: [joanID: .green])
        let repository = InMemoryParcheRepository(backend: backend, userID: joanID)
        let created = try await repository.createParche(id: UUID(), name: "Cena", displayName: "Joan")
        await backend.setColor(.lime, for: joanID)
        let detail = try await repository.loadParche(id: created.id)
        #expect(detail.participants.first?.avatarColor == .lime)
    }

    @Test("Sin red el color sigue siendo el anterior")
    func updateColorOffline() async {
        let directory = makeDirectory()
        let joan = await session(joanID, directory)
        await directory.setFailing(true)
        #expect(await !joan.updateColor(.lime))
        #expect(joan.error == .network)
        #expect(joan.me.avatarColor == .green)
    }

    @Test("Un perfil nuevo recibe un color de la paleta")
    func newProfileColor() async {
        let user = UUID()
        let directory = InMemoryAccountDirectory()
        let session = SessionStore(
            phase: .onboarding, me: Member(name: "Tú", avatarColor: .yellow, tikeVariant: .rosa),
            partner: Member(name: "Tu amigo", avatarColor: .violet, tikeVariant: .verde),
            auth: InMemoryAuthService(signedIn: user), directory: directory, isReady: false)
        await session.refresh()
        #expect(await session.createProfile(name: "Joan"))
        let stored = await directory.storedProfile(for: user)
        #expect(stored.map { AvatarColor.palette.contains($0.avatarColor) } == true)
        #expect(session.me.avatarColor == stored?.avatarColor)
    }

    // MARK: - JSON de la base

    @Test("my_cruces trae el color del perfil del otro, también los colores nuevos")
    func remoteCruceColor() throws {
        let json = """
            [{"ledger_id": "aaaaaaaa-0000-0000-0000-000000000001", "partner_id": "\(jesusID)",
              "partner_name": "Jesús", "my_tike": "rosa", "my_avatar": "green", "partner_tike": "verde",
              "partner_avatar": "peach", "linked_at": "2026-10-27T10:00:00+00:00"}]
            """
        let links = try CruceRemote.cruceLinks(from: data(json))
        #expect(links[0].partner.avatarColor == .peach)
        #expect(links[0].myTikeVariant == .rosa)
    }

    @Test("Cada participante del parche trae su color; sin la columna (base vieja) queda amarillo")
    func remoteParticipantColor() throws {
        let withColor = try ParcheRemote.participant(
            from: data(
                """
                {"id": "\(UUID())", "user_id": null, "display_name": "Carlos", "claim_code": "SOY-ABC234",
                 "joined_at": "2026-10-20T10:00:00+00:00", "last_seen_at": null, "avatar_color": "lime"}
                """))
        #expect(withColor.avatarColor == .lime)
        let without = try ParcheRemote.participant(
            from: data(
                """
                {"id": "\(UUID())", "user_id": null, "display_name": "Carlos", "claim_code": "SOY-ABC234",
                 "joined_at": "2026-10-20T10:00:00+00:00", "last_seen_at": null}
                """))
        #expect(without.avatarColor == .yellow)
    }

    @Test("Un participante guardado sin color (antes de esta versión) se lee amarillo")
    func oldParticipantSnapshot() throws {
        let json = """
            {"id": "\(UUID())", "displayName": "Carlos", "joinedAt": 0}
            """
        let participant = try JSONDecoder().decode(ParcheParticipant.self, from: data(json))
        #expect(participant.avatarColor == .yellow)
    }
}
