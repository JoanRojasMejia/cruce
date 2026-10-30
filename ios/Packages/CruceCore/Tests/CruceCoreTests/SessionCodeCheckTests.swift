import Foundation
import Testing

@testable import CruceCore

/// Revisar un código `CRZ-` mientras se escribe o llega por un enlace: un chequeo cancelado o viejo no deja un
/// "No pudimos conectarnos" falso ni pisa la respuesta del código más nuevo.
@MainActor
@Suite("Revisar un código de cruce")
struct SessionCodeCheckTests {
    private let jesusID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!

    private func session(_ directory: ScriptedDirectory) async -> SessionStore {
        let session = SessionStore(
            phase: .onboarding, me: Member(name: "Tú", avatarColor: .yellow, tikeVariant: .rosa),
            partner: Member(name: "Tu amigo", avatarColor: .violet, tikeVariant: .verde),
            auth: InMemoryAuthService(signedIn: jesusID), directory: directory, isReady: false)
        await session.refresh()
        return session
    }

    /// Espera a que el chequeo de ese código quede detenido en la base de mentiras.
    private func waitUntilWaiting(_ code: String, in directory: ScriptedDirectory) async {
        while await !directory.isWaiting(code) { await Task.yield() }
    }

    @Test(
        "Un chequeo cancelado no deja un problema",
        arguments: [CancellationError() as any Error, URLError(.cancelled) as any Error])
    func cancelledCheckSetsNoProblem(cancellation: any Error) async {
        let directory = ScriptedDirectory(jesusID)
        await directory.script("CRZ-1111", .failure(cancellation))
        let jesus = await session(directory)
        await jesus.checkCode("CRZ-1111")
        #expect(jesus.error == nil)
        #expect(jesus.invitePreview == nil)
    }

    @Test("Un chequeo que falla por la red sí deja el problema")
    func networkFailureSetsProblem() async {
        let directory = ScriptedDirectory(jesusID)
        await directory.script("CRZ-1111", .failure(URLError(.notConnectedToInternet)))
        let jesus = await session(directory)
        await jesus.checkCode("CRZ-1111")
        #expect(jesus.error == .network)
    }

    @Test("Un error del código viejo no pisa la respuesta del código nuevo")
    func staleFailureIsIgnored() async {
        let directory = ScriptedDirectory(jesusID)
        await directory.script("CRZ-1111", .failure(URLError(.notConnectedToInternet)), waits: true)
        await directory.script("CRZ-2222", .success(.valid(inviterName: "Joan")))
        let jesus = await session(directory)
        let old = Task { await jesus.checkCode("CRZ-1111") }
        await waitUntilWaiting("CRZ-1111", in: directory)
        await jesus.checkCode("CRZ-2222")
        await directory.release("CRZ-1111")
        await old.value
        #expect(jesus.invitePreview == .valid(inviterName: "Joan"))
        #expect(jesus.error == nil)
    }

    @Test("La respuesta del código viejo no pisa la del código nuevo")
    func staleAnswerIsIgnored() async {
        let directory = ScriptedDirectory(jesusID)
        await directory.script("CRZ-1111", .success(.valid(inviterName: "Ana")), waits: true)
        await directory.script(
            "CRZ-2222", .success(.rejected(.expired, message: CodeRejection.expired.defaultMessage)))
        let jesus = await session(directory)
        let old = Task { await jesus.checkCode("CRZ-1111") }
        await waitUntilWaiting("CRZ-1111", in: directory)
        await jesus.checkCode("CRZ-2222")
        await directory.release("CRZ-1111")
        await old.value
        #expect(jesus.invitePreview == .rejected(.expired, message: CodeRejection.expired.defaultMessage))
    }
}

/// `AccountDirectory` con un perfil y respuestas escritas para `previewInvite`; una respuesta puede esperar a
/// `release(_:)` para simular una consulta lenta.
actor ScriptedDirectory: AccountDirectory {
    private let base: InMemoryAccountDirectory
    private var answers: [String: Result<InviteCheck, any Error>] = [:]
    private var gated: Set<String> = []
    private var waiting: [String: CheckedContinuation<Void, Never>] = [:]

    init(_ userID: UUID) {
        base = InMemoryAccountDirectory(profiles: [Profile(id: userID, displayName: "Jesús", avatarColor: .violet)])
    }

    func script(_ code: String, _ answer: Result<InviteCheck, any Error>, waits: Bool = false) {
        answers[code] = answer
        if waits { gated.insert(code) }
    }

    func isWaiting(_ code: String) -> Bool { waiting[code] != nil }

    func release(_ code: String) { waiting.removeValue(forKey: code)?.resume() }

    func previewInvite(_ code: String, for userID: UUID) async throws -> InviteCheck {
        if gated.contains(code) {
            await withCheckedContinuation { waiting[code] = $0 }
        }
        guard let answer = answers[code] else { return try await base.previewInvite(code, for: userID) }
        return try answer.get()
    }

    func profile(for userID: UUID) async throws -> Profile? { try await base.profile(for: userID) }
    func createProfile(_ profile: Profile) async throws { try await base.createProfile(profile) }
    func updateDisplayName(_ name: String, for userID: UUID) async throws {
        try await base.updateDisplayName(name, for: userID)
    }
    func updateAvatarColor(_ color: AvatarColor, for userID: UUID) async throws {
        try await base.updateAvatarColor(color, for: userID)
    }
    func cruces(for userID: UUID) async throws -> [CruceLink] { try await base.cruces(for: userID) }
    func inviteCode(for userID: UUID) async throws -> String { try await base.inviteCode(for: userID) }
    func redeemInvite(_ code: String, for userID: UUID) async throws -> InviteCheck {
        try await base.redeemInvite(code, for: userID)
    }
    func setDefaultOtherPercent(_ percent: Int, in cruceID: UUID, for userID: UUID) async throws {
        try await base.setDefaultOtherPercent(percent, in: cruceID, for: userID)
    }
    func closeCruce(_ cruceID: UUID, for userID: UUID) async throws -> Date {
        try await base.closeCruce(cruceID, for: userID)
    }
}
