import Foundation
import Testing

@testable import CruceCore

/// Reloj compartido entre el backend en memoria y los stores; las pruebas lo adelantan a mano.
final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var current = Date(timeIntervalSince1970: 1_800_000_000)

    var now: Date { lock.withLock { current } }

    func advance(hours: Double) {
        lock.withLock { current = current.addingTimeInterval(hours * 3_600) }
    }
}

/// Un backend en memoria con varias personas, cada una con su propio `ParcheStore`.
@MainActor
struct ParcheWorld {
    let clock = TestClock()
    let backend: InMemoryParcheBackend
    let jesus = Member(name: "Jesús", avatarColor: .violet, tikeVariant: .verde)
    let ana = Member(name: "Ana", avatarColor: .yellow, tikeVariant: .rosa)
    let carlos = Member(name: "Carlos", avatarColor: .yellow, tikeVariant: .rosa)
    let joan = Member(name: "Joan", avatarColor: .yellow, tikeVariant: .rosa)

    init() {
        let clock = clock
        backend = InMemoryParcheBackend(now: { clock.now })
    }

    func store(_ member: Member, pending: any PendingStore = InMemoryPendingStore()) -> ParcheStore {
        let clock = clock
        return ParcheStore(
            session: SessionStore(phase: .main, me: member, partner: MockData.joan, userID: member.id),
            repository: InMemoryParcheRepository(backend: backend, userID: member.id),
            pendingStore: pending,
            now: { clock.now })
    }
}

@MainActor
@Suite("Estado de los parches")
struct ParcheStoreTests {
    /// Jesús crea "Santa Marta", Ana se une con el código y Jesús agrega a Carlos sin la app.
    private func santaMarta(_ world: ParcheWorld) async throws -> (
        jesus: ParcheStore, ana: ParcheStore, parche: ParcheDetail, carlos: ParcheParticipant
    ) {
        let jesus = world.store(world.jesus)
        let ana = world.store(world.ana)
        let created = try #require(await jesus.createParche(name: "Santa Marta"))
        _ = try #require(await ana.join(code: created.parche.code))
        let carlos = try #require(await jesus.addParticipant(name: "Carlos", to: created.id))
        await jesus.refresh(created.id)
        return (jesus, ana, try #require(jesus.parche(created.id)), carlos)
    }

    private func participant(_ detail: ParcheDetail, _ name: String) throws -> ParcheParticipant {
        try #require(detail.participants.first { $0.displayName == name })
    }

    // MARK: - Crear, unirse y personas sin la app

    @Test("Crear: el parche queda abierto, con quien lo crea y un código PCH-")
    func createParche() async throws {
        let world = ParcheWorld()
        let jesus = world.store(world.jesus)
        let detail = try #require(await jesus.createParche(name: "  Santa Marta "))
        #expect(detail.parche.name == "Santa Marta")
        #expect(detail.parche.status == .open)
        #expect(detail.participants.map(\.displayName) == ["Jesús"])
        #expect(detail.me?.userID == world.jesus.id)
        #expect(ParcheCode.kind(of: detail.parche.code) == .parche)
        #expect(detail.parche.code.count == 10)
        #expect(jesus.parches.map(\.id) == [detail.id])
    }

    @Test("El nombre del parche va de 1 a 60 caracteres")
    func parcheNameValidation() async {
        let world = ParcheWorld()
        let jesus = world.store(world.jesus)
        #expect(await jesus.createParche(name: "   ") == nil)
        #expect(jesus.error == .invalidParcheName)
        #expect(await jesus.createParche(name: String(repeating: "a", count: 61)) == nil)
        #expect(jesus.error?.message == "El nombre del parche debe tener entre 1 y 60 caracteres.")
    }

    @Test("Unirse: Ana queda como participante y ve los gastos; dos veces no la duplica")
    func joinParche() async throws {
        let world = ParcheWorld()
        let (jesus, ana, parche, _) = try await santaMarta(world)
        let me = try #require(parche.me)
        let lunch = try #require(
            jesus.validateExpense(
                in: parche.id, concept: "Almuerzo", base: 90_000, split: .equal(Set(parche.order)),
                payers: [ParchePayer(participantID: me.id, amount: 90_000)]))
        await jesus.save(lunch)
        await ana.load()
        #expect(ana.parche(parche.id)?.visibleExpenses.map(\.concept) == ["Almuerzo"])
        _ = await ana.join(code: parche.parche.code.lowercased())
        await jesus.refresh(parche.id)
        #expect(jesus.parche(parche.id)?.participants.filter { $0.displayName == "Ana" }.count == 1)
    }

    @Test("Código inválido: \"Ese código no existe\" y no cambia nada")
    func invalidCode() async throws {
        let world = ParcheWorld()
        let (_, ana, _, _) = try await santaMarta(world)
        let before = ana.parches
        #expect(await ana.join(code: "PCH-ZZZZZZ") == nil)
        #expect(ana.error?.message == "Ese código no existe")
        #expect(ana.parches == before)
    }

    @Test("Agregar a Carlos: aparece como Carlos (sin la app) con un código SOY-")
    func addParticipantWithoutApp() async throws {
        let world = ParcheWorld()
        let (jesus, _, parche, carlos) = try await santaMarta(world)
        #expect(carlos.label == "Carlos (sin la app)")
        #expect(ParcheCode.kind(of: try #require(carlos.claimCode)) == .place)
        #expect(parche.participants.map(\.displayName) == ["Jesús", "Ana", "Carlos"], "Orden de unión")
        #expect(await jesus.addParticipant(name: "", to: parche.id) == nil)
        #expect(jesus.error == .invalidPersonName)
    }

    @Test("Carlos instala la app: se queda con su lugar, sus gastos y lo que debe")
    func claimPlace() async throws {
        let world = ParcheWorld()
        let (jesus, _, parche, carlos) = try await santaMarta(world)
        let me = try #require(parche.me)
        let taxi = try #require(
            jesus.validateExpense(
                in: parche.id, concept: "Taxi", base: 30_000, split: .equal(Set(parche.order)),
                payers: [ParchePayer(participantID: me.id, amount: 30_000)]))
        await jesus.save(taxi)

        let carlosStore = world.store(world.carlos)
        let claimCode = try #require(carlos.claimCode)
        let claimed = try #require(await carlosStore.enter(code: claimCode))
        #expect(claimed.me?.id == carlos.id, "El mismo lugar, sin crear una persona nueva")
        #expect(claimed.participants.count == 3)
        #expect(claimed.me?.claimCode == nil)
        #expect(claimed.balances.first { $0.participantID == carlos.id }?.net == -10_000)

        await jesus.refresh(parche.id)
        let detail = try #require(jesus.parche(parche.id))
        let phrases = detail.activity.map { jesus.phrase(for: $0, in: detail) }
        #expect(phrases.contains("Carlos ahora tiene la app"))
        // El código ya no sirve.
        #expect(await world.store(world.joan).enter(code: try #require(carlos.claimCode)) == nil)
    }

    @Test("Ya estaba en el parche: no puede quedarse con el lugar de Carlos")
    func claimPlaceWhenAlreadyParticipant() async throws {
        let world = ParcheWorld()
        let (jesus, ana, parche, carlos) = try await santaMarta(world)
        #expect(await ana.enter(code: try #require(carlos.claimCode)) == nil)
        #expect(ana.error == .alreadyInParche)
        #expect(ana.error?.message == "Ya estás en este parche, así que no puedes quedarte con ese lugar.")
        await jesus.refresh(parche.id)
        #expect(try participant(try #require(jesus.parche(parche.id)), "Carlos").hasApp == false)
    }

    @Test("El campo \"Tengo un código\" decide por el prefijo")
    func codeKinds() {
        #expect(ParcheStore.codeKind(" crz-4821 ") == .cruce)
        #expect(ParcheStore.codeKind("pch-abc234") == .parche)
        #expect(ParcheStore.codeKind("SOY-ABC234") == .place)
        #expect(ParcheStore.codeKind("HOLA") == nil)
        let code = ParcheCode.generate(.parche)
        #expect(code.hasPrefix("PCH-"))
        #expect(code.dropFirst(4).allSatisfy { ParcheCode.alphabet.contains($0) })
    }

    // MARK: - Gastos

    @Test("Ana edita un gasto de Jesús: los saldos cambian y Jesús ve el aviso")
    func editingSomeoneElsesExpense() async throws {
        let world = ParcheWorld()
        let (jesus, ana, parche, _) = try await santaMarta(world)
        let me = try #require(parche.me)
        let dinner = try #require(
            jesus.validateExpense(
                in: parche.id, concept: "Cena", base: 90_000, split: .equal(Set(parche.order)),
                payers: [ParchePayer(participantID: me.id, amount: 90_000)]))
        await jesus.save(dinner)
        await ana.load()

        let edited = try #require(
            ana.validateExpense(
                in: parche.id, editing: dinner.id, concept: "Cena", base: 120_000, split: .equal(Set(parche.order)),
                payers: [ParchePayer(participantID: me.id, amount: 120_000)]))
        #expect(edited.recordedBy == me.id, "Sigue anotado por Jesús")
        await ana.save(edited)

        await jesus.refresh(parche.id)
        let detail = try #require(jesus.parche(parche.id))
        #expect(detail.balances.first { $0.participantID == me.id }?.net == 80_000)
        #expect(detail.activity.map { jesus.phrase(for: $0, in: detail) }.contains("Ana editó un gasto que anotaste"))

    }

    @Test("Borrar es suave: el gasto se queda marcado y deja de contar")
    func deleteIsSoft() async throws {
        let world = ParcheWorld()
        let (jesus, _, parche, _) = try await santaMarta(world)
        let me = try #require(parche.me)
        let taxi = try #require(
            jesus.validateExpense(
                in: parche.id, concept: "Taxi", base: 30_000, split: .equal(Set(parche.order)),
                payers: [ParchePayer(participantID: me.id, amount: 30_000)]))
        await jesus.save(taxi)
        await jesus.deleteExpense(taxi.id, in: parche.id)
        let detail = try #require(jesus.parche(parche.id))
        #expect(detail.expenses.first { $0.id == taxi.id }?.isDeleted == true)
        #expect(detail.visibleExpenses.isEmpty)
        #expect(detail.balances.allSatisfy { $0.net == 0 })
    }

    @Test("Los pagadores que no suman el total no dejan guardar y explican cuánto falta")
    func payersMismatch() async throws {
        let world = ParcheWorld()
        let (jesus, _, parche, _) = try await santaMarta(world)
        let me = try #require(parche.me)
        #expect(
            jesus.validateExpense(
                in: parche.id, concept: "Cuenta", base: 220_000, split: .equal(Set(parche.order)),
                payers: [ParchePayer(participantID: me.id, amount: 200_000)]) == nil)
        #expect(jesus.error?.message == "Faltan $20.000: quienes pagaron suman $200.000 de $220.000.")
    }

    @Test("Ana y Jesús anotan el mismo almuerzo: aviso de posible duplicado")
    func duplicateWarning() async throws {
        let world = ParcheWorld()
        let (jesus, ana, parche, _) = try await santaMarta(world)
        let anaID = try participant(parche, "Ana").id
        await ana.load()
        let byAna = try #require(
            ana.validateExpense(
                in: parche.id, concept: "Almuerzo", base: 220_000, split: .equal(Set(parche.order)),
                payers: [ParchePayer(participantID: anaID, amount: 220_000)]))
        await ana.save(byAna)

        world.clock.advance(hours: 1)
        await jesus.refresh(parche.id)
        let byJesus = try #require(
            jesus.validateExpense(
                in: parche.id, concept: "Almuerzo playa", base: 220_000, split: .equal(Set(parche.order)),
                payers: [ParchePayer(participantID: anaID, amount: 220_000)]))
        #expect(jesus.duplicateWarning(for: byJesus) == "Parece que Ana ya anotó este gasto")

        // Otro monto u otro pagador no avisan; se puede guardar igual.
        let other = try #require(
            jesus.validateExpense(
                in: parche.id, concept: "Almuerzo", base: 210_000, split: .equal(Set(parche.order)),
                payers: [ParchePayer(participantID: anaID, amount: 210_000)]))
        #expect(jesus.duplicateWarning(for: other) == nil)
        await jesus.save(byJesus)
        #expect(jesus.parche(parche.id)?.visibleExpenses.count == 2)

        // Pasadas 3 horas ya no avisa.
        world.clock.advance(hours: 3.5)
        #expect(jesus.duplicateWarning(for: byJesus.with(id: UUID())) == nil)
    }

    @Test("El gasto borrado no cuenta como duplicado")
    func deletedExpenseIsNotDuplicate() async throws {
        let world = ParcheWorld()
        let (jesus, _, parche, _) = try await santaMarta(world)
        let me = try #require(parche.me)
        let first = try #require(
            jesus.validateExpense(
                in: parche.id, concept: "Taxi", base: 30_000, split: .equal(Set(parche.order)),
                payers: [ParchePayer(participantID: me.id, amount: 30_000)]))
        await jesus.save(first)
        #expect(jesus.duplicateWarning(for: first.with(id: UUID())) == "Parece que ya anotaste este gasto")
        await jesus.deleteExpense(first.id, in: parche.id)
        #expect(jesus.duplicateWarning(for: first.with(id: UUID())) == nil)
    }

    // MARK: - Pagos

    @Test("Ana anota que Carlos le pagó a Jesús: queda pendiente hasta que Jesús confirma")
    func paymentNeedsConfirmation() async throws {
        let world = ParcheWorld()
        let (jesus, ana, parche, carlos) = try await santaMarta(world)
        let me = try #require(parche.me)
        let rent = try #require(
            jesus.validateExpense(
                in: parche.id, concept: "Hospedaje", base: 262_500, split: .equal(Set(parche.order)),
                payers: [ParchePayer(participantID: me.id, amount: 262_500)]))
        await jesus.save(rent)
        await ana.load()

        let payment = try #require(await ana.recordPayment(in: parche.id, from: carlos.id, to: me.id, amount: 87_500))
        #expect(!payment.isConfirmed)

        await jesus.refresh(parche.id)
        var detail = try #require(jesus.parche(parche.id))
        let pending = jesus.pendingConfirmations(in: detail)
        #expect(pending.map(\.id) == [payment.id])
        #expect(jesus.confirmationPrompt(for: payment, in: detail) == "Carlos te pagó $87.500, ¿confirmas?")
        #expect(detail.balances.first { $0.participantID == carlos.id }?.net == -87_500)

        await jesus.confirmPayment(payment.id, in: parche.id)
        detail = try #require(jesus.parche(parche.id))
        #expect(detail.balances.first { $0.participantID == carlos.id }?.net == 0)
        #expect(jesus.pendingConfirmations(in: detail).isEmpty)
    }

    @Test("Lo anota quien recibió: cuenta de una vez")
    func paymentByReceiverCountsNow() async throws {
        let world = ParcheWorld()
        let (jesus, _, parche, carlos) = try await santaMarta(world)
        let me = try #require(parche.me)
        let payment = try #require(await jesus.recordPayment(in: parche.id, from: carlos.id, to: me.id, amount: 87_500))
        #expect(payment.isConfirmed)
        #expect(jesus.parche(parche.id)?.balances.first { $0.participantID == carlos.id }?.net == 87_500)
    }

    @Test("Un pago necesita monto y dos personas distintas")
    func invalidPayment() async throws {
        let world = ParcheWorld()
        let (jesus, _, parche, _) = try await santaMarta(world)
        let me = try #require(parche.me)
        #expect(await jesus.recordPayment(in: parche.id, from: me.id, to: me.id, amount: 1_000) == nil)
        #expect(jesus.error == .invalidPayment)
    }

    // MARK: - Cerrar

    @Test("Cerrar: ya no se anotan gastos, pero sí pagos, y no se reabre")
    func closeParche() async throws {
        let world = ParcheWorld()
        let (jesus, ana, parche, carlos) = try await santaMarta(world)
        let me = try #require(parche.me)
        #expect(await ana.close(parche.id))
        await jesus.refresh(parche.id)
        #expect(jesus.parche(parche.id)?.parche.status == .closed)
        #expect(
            jesus.validateExpense(
                in: parche.id, concept: "Tarde", base: 10_000, split: .equal([me.id]),
                payers: [ParchePayer(participantID: me.id, amount: 10_000)]) == nil)
        #expect(jesus.error == .parcheClosed)
        #expect(await jesus.recordPayment(in: parche.id, from: carlos.id, to: me.id, amount: 5_000) != nil)
        let detail = try #require(jesus.parche(parche.id))
        #expect(detail.activity.map { jesus.phrase(for: $0, in: detail) }.contains("Ana cerró el parche"))
    }

    @Test("Queda a paz y salvo cuando se confirma el último pago de un parche cerrado")
    func becomesSettled() async throws {
        let world = ParcheWorld()
        let (jesus, ana, parche, _) = try await santaMarta(world)
        let me = try #require(parche.me)
        let anaID = try participant(parche, "Ana").id
        let carlosID = try participant(parche, "Carlos").id
        let bill = try #require(
            jesus.validateExpense(
                in: parche.id, concept: "Lancha", base: 60_000, split: .equal([me.id, anaID]),
                payers: [ParchePayer(participantID: me.id, amount: 60_000)]))
        await jesus.save(bill)
        #expect(await jesus.close(parche.id))
        #expect(jesus.statusLabel(for: try #require(jesus.parche(parche.id))) == "Parche cerrado")

        await ana.load()
        let payment = try #require(await ana.recordPayment(in: parche.id, from: anaID, to: me.id, amount: 30_000))
        #expect(!payment.isConfirmed)
        await jesus.load()
        await jesus.confirmPayment(payment.id, in: parche.id)
        let detail = try #require(jesus.parche(parche.id))
        #expect(detail.isSettled)
        #expect(jesus.statusLabel(for: detail) == "A paz y salvo")
        #expect(carlosID != me.id)
    }

    // MARK: - Pasar al cruce

    /// Jesús paga $256.000 entre los 4 y cierra; Joan y Jesús comparten un cruce.
    private func lodgingWithJoan(_ world: ParcheWorld) async throws -> (ParcheStore, ParcheStore, ParcheDetail) {
        let (jesus, _, parche, _) = try await santaMarta(world)
        let joan = world.store(world.joan)
        _ = try #require(await joan.join(code: parche.parche.code))
        await world.backend.addCruce(world.jesus.id, world.joan.id)
        await jesus.refresh(parche.id)
        let detail = try #require(jesus.parche(parche.id))
        let me = try #require(detail.me)
        let lodging = try #require(
            jesus.validateExpense(
                in: parche.id, concept: "Hospedaje", base: 256_000, split: .equal(Set(detail.order)),
                payers: [ParchePayer(participantID: me.id, amount: 256_000)]))
        await jesus.save(lodging)
        return (jesus, joan, try #require(jesus.parche(parche.id)))
    }

    @Test("Joan y Jesús pasan su deuda al cruce y en el parche ya no hay transferencia entre ellos")
    func moveDebtToCruce() async throws {
        let world = ParcheWorld()
        let (jesus, joan, detail) = try await lodgingWithJoan(world)
        let joanID = try participant(detail, "Joan").id
        // Con el parche abierto no se pregunta.
        #expect(jesus.cruceCandidates(in: detail).isEmpty)
        #expect(await jesus.close(detail.id))

        let open = try #require(jesus.parche(detail.id))
        let candidates = jesus.cruceCandidates(in: open)
        #expect(candidates == [ParcheCruceCandidate(other: try participant(open, "Joan"), amountYouAreOwed: 64_000)])
        #expect(jesus.crucePrompt(for: candidates[0]) == "Joan te debe $64.000. ¿Lo pasas a tu cruce con Joan?")

        #expect(await jesus.moveDebtToCruce(in: detail.id, with: joanID))
        let after = try #require(jesus.parche(detail.id))
        #expect(after.transfers.map(\.amount) == [64_000])
        #expect(!after.suggestedTransfers.contains { Set([$0.fromID, $0.toID]) == Set([joanID, after.me!.id]) })
        #expect(jesus.cruceCandidates(in: after).isEmpty)

        // Una sola vez por par, aunque lo intente el otro.
        await joan.load()
        #expect(await joan.moveDebtToCruce(in: detail.id, with: try #require(after.me).id) == false)
        #expect(joan.error == .alreadyMoved)
    }

    @Test("No quieren pasarla: la deuda se salda en el parche y no se vuelve a preguntar")
    func declineCruce() async throws {
        let world = ParcheWorld()
        let pending = InMemoryPendingStore()
        let (jesus, _, detail) = try await lodgingWithJoan(world)
        #expect(await jesus.close(detail.id))
        let joanID = try participant(detail, "Joan").id
        let store = world.store(world.jesus, pending: pending)
        await store.load()
        await store.declineCruce(in: detail.id, with: joanID)
        let closed = try #require(store.parche(detail.id))
        #expect(store.cruceCandidates(in: closed).isEmpty)
        #expect(closed.suggestedTransfers.contains { $0.fromID == joanID && $0.amount == 64_000 })
        // Se guarda en el dispositivo.
        let again = world.store(world.jesus, pending: pending)
        await again.load()
        #expect(again.cruceCandidates(in: try #require(again.parche(detail.id))).isEmpty)
    }

    @Test("Sin un cruce compartido no se puede pasar la deuda")
    func moveDebtNeedsSharedCruce() async throws {
        let world = ParcheWorld()
        let (jesus, _, parche, _) = try await santaMarta(world)
        let anaID = try participant(parche, "Ana").id
        #expect(await jesus.close(parche.id))
        #expect(await jesus.moveDebtToCruce(in: parche.id, with: anaID) == false)
        #expect(jesus.error == .noSharedCruce)
    }

    // MARK: - Avisos

    @Test("Contador: Ana anota dos gastos, Jesús ve 2 sin ver y al abrir vuelve a cero")
    func unseenCounter() async throws {
        let world = ParcheWorld()
        let (jesus, ana, parche, _) = try await santaMarta(world)
        await jesus.open(parche.id)
        #expect(jesus.parche(parche.id)?.unseenCount == 0)

        world.clock.advance(hours: 1)
        await ana.load()
        let anaID = try participant(parche, "Ana").id
        for concept in ["Mercado", "Gasolina"] {
            let expense = try #require(
                ana.validateExpense(
                    in: parche.id, concept: concept, base: 40_000, split: .equal(Set(parche.order)),
                    payers: [ParchePayer(participantID: anaID, amount: 40_000)]))
            await ana.save(expense)
        }
        world.clock.advance(hours: 1)
        await jesus.load()
        #expect(jesus.parche(parche.id)?.unseenCount == 2)
        #expect(jesus.unseenTotal == 2)
        await jesus.open(parche.id)
        #expect(jesus.parche(parche.id)?.unseenCount == 0)
        await jesus.load()
        #expect(jesus.parche(parche.id)?.unseenCount == 0, "Quedó guardado en el repositorio")
    }

    @Test("Frases de la actividad y de los saldos con tú")
    func phrases() async throws {
        let world = ParcheWorld()
        let (jesus, ana, parche, _) = try await santaMarta(world)
        let detail = try #require(jesus.parche(parche.id))
        let phrases = detail.activity.map { jesus.phrase(for: $0, in: detail) }
        #expect(phrases.contains("Ana se unió al parche"))
        #expect(phrases.contains("Agregaste a Carlos (sin la app)"))
        #expect(phrases.contains("Creaste el parche"))
        await ana.load()
        let anaView = try #require(ana.parche(parche.id))
        #expect(
            anaView.activity.map { ana.phrase(for: $0, in: anaView) }.contains("Jesús agregó a Carlos (sin la app)"))

        let me = try #require(detail.me)
        let anaID = try participant(detail, "Ana").id
        #expect(jesus.balanceText(net: 165_000, for: anaID, in: detail) == "Le deben $165.000")
        #expect(jesus.balanceText(net: -110_000, for: anaID, in: detail) == "Debe $110.000")
        #expect(jesus.balanceText(net: -110_000, for: me.id, in: detail) == "Debes $110.000")
        #expect(jesus.balanceText(net: 5_000, for: me.id, in: detail) == "Te deben $5.000")
        #expect(jesus.balanceText(net: 0, for: anaID, in: detail) == "A paz y salvo")
        #expect(
            jesus.phrase(for: ParcheTransfer(fromID: anaID, toID: me.id, amount: 45_000), in: detail)
                == "Ana te paga $45.000")
        #expect(
            jesus.phrase(for: ParcheTransfer(fromID: me.id, toID: anaID, amount: 45_000), in: detail)
                == "Le pagas $45.000 a Ana")
        let carlosID = try participant(detail, "Carlos").id
        #expect(
            jesus.phrase(for: ParcheTransfer(fromID: carlosID, toID: anaID, amount: 45_000), in: detail)
                == "Carlos le paga $45.000 a Ana")
    }

    // MARK: - Sin conexión

    @Test("Sin señal: el gasto se guarda en el teléfono y al volver se envía una sola vez")
    func offlineExpenseIsSentOnce() async throws {
        let world = ParcheWorld()
        let pending = InMemoryPendingStore()
        let (_, _, parche, _) = try await santaMarta(world)
        let ana = world.store(world.ana, pending: pending)
        await ana.load()
        let anaID = try participant(parche, "Ana").id

        await world.backend.setOffline(true)
        let expense = try #require(
            ana.validateExpense(
                in: parche.id, concept: "Arepas", base: 24_000, split: .equal(Set(parche.order)),
                payers: [ParchePayer(participantID: anaID, amount: 24_000)]))
        await ana.save(expense)
        #expect(ana.pendingSyncCount == 1)
        #expect(ana.isOffline)
        #expect(ana.parche(parche.id)?.visibleExpenses.map(\.concept) == ["Arepas"], "Se ve en el teléfono")
        await ana.retryPending()
        #expect(ana.pendingSyncCount == 1, "Sigue sin conexión")

        // Ana cierra la app y la abre con conexión.
        await world.backend.setOffline(false)
        let reopened = world.store(world.ana, pending: pending)
        await reopened.load()
        #expect(reopened.pendingSyncCount == 0)
        #expect(!reopened.isOffline)
        await reopened.retryPending()
        let jesus = world.store(world.jesus)
        await jesus.load()
        let detail = try #require(jesus.parche(parche.id))
        #expect(detail.expenses.filter { $0.concept == "Arepas" }.count == 1)
        #expect(detail.activity.filter { $0.kind == .expenseCreated }.count == 1)
        #expect(try await pending.load().pending.isEmpty)
    }

    @Test("Si la respuesta se pierde, el reintento no duplica el gasto ni el pago")
    func retryIsIdempotent() async throws {
        let world = ParcheWorld()
        let (jesus, _, parche, carlos) = try await santaMarta(world)
        let me = try #require(parche.me)
        await world.backend.setDropsResponses(true)
        let expense = try #require(
            jesus.validateExpense(
                in: parche.id, concept: "Lancha", base: 60_000, split: .equal(Set(parche.order)),
                payers: [ParchePayer(participantID: me.id, amount: 60_000)]))
        await jesus.save(expense)
        _ = await jesus.recordPayment(in: parche.id, from: carlos.id, to: me.id, amount: 10_000)
        #expect(jesus.pendingSyncCount == 2)

        await world.backend.setDropsResponses(false)
        await jesus.retryPending()
        #expect(jesus.pendingSyncCount == 0)
        let detail = try #require(jesus.parche(parche.id))
        #expect(detail.expenses.count == 1)
        #expect(detail.payments.count == 1)
        #expect(detail.activity.filter { $0.kind == .expenseCreated }.count == 1)
        #expect(detail.activity.filter { $0.kind == .paymentRecorded }.count == 1)
    }

    @Test("Varias ediciones sin conexión quedan como una sola en la cola, en orden")
    func offlineQueueCoalescesEdits() async throws {
        let world = ParcheWorld()
        let (jesus, _, parche, _) = try await santaMarta(world)
        let me = try #require(parche.me)
        await world.backend.setOffline(true)
        let expense = try #require(
            jesus.validateExpense(
                in: parche.id, concept: "Pan", base: 8_000, split: .equal([me.id]),
                payers: [ParchePayer(participantID: me.id, amount: 8_000)]))
        await jesus.save(expense)
        let edited = try #require(
            jesus.validateExpense(
                in: parche.id, editing: expense.id, concept: "Pan y café", base: 12_000, split: .equal([me.id]),
                payers: [ParchePayer(participantID: me.id, amount: 12_000)]))
        await jesus.save(edited)
        await jesus.deleteExpense(expense.id, in: parche.id)
        #expect(jesus.pendingSyncCount == 2)

        await world.backend.setOffline(false)
        await jesus.retryPending()
        let detail = try #require(jesus.parche(parche.id))
        let stored = try #require(detail.expenses.first { $0.id == expense.id })
        #expect(stored.concept == "Pan y café")
        #expect(stored.isDeleted)
    }

    @Test("Un error que no es de conexión no se reintenta y se muestra")
    func nonConnectivityErrorIsDropped() async throws {
        let world = ParcheWorld()
        let (jesus, ana, parche, _) = try await santaMarta(world)
        let me = try #require(parche.me)
        // Jesús todavía cree que el parche está abierto, pero Ana ya lo cerró.
        #expect(await ana.close(parche.id))
        let expense = try #require(
            jesus.validateExpense(
                in: parche.id, concept: "Tarde", base: 10_000, split: .equal([me.id]),
                payers: [ParchePayer(participantID: me.id, amount: 10_000)]))
        await jesus.save(expense)
        #expect(jesus.pendingSyncCount == 0)
        #expect(jesus.error == .parcheClosed)
        #expect(jesus.parche(parche.id)?.visibleExpenses.isEmpty == true, "Se recarga lo que hay en el servidor")
    }

    @Test("Sin conexión no se puede crear un parche")
    func createNeedsConnection() async {
        let world = ParcheWorld()
        await world.backend.setOffline(true)
        let jesus = world.store(world.jesus)
        #expect(await jesus.createParche(name: "Santa Marta") == nil)
        #expect(jesus.error == .network)
        #expect(jesus.error?.message == "No pudimos conectarnos. Revisa tu conexión y vuelve a intentarlo.")
    }

    // MARK: - Datos de ejemplo

    @Test("Los datos de ejemplo cargan con saldos que suman cero")
    func mockParches() async throws {
        let store = ParcheStore(
            session: SessionStore(phase: .main, me: MockData.joan, partner: MockData.jesus, userID: MockData.joan.id),
            repository: InMemoryParcheRepository(backend: MockParches.backend(), userID: MockData.joan.id))
        await store.load()
        #expect(store.parches.count == 2)
        let santaMarta = try #require(store.parches.first { $0.parche.name == "Santa Marta" })
        #expect(santaMarta.parche.isOpen)
        #expect(santaMarta.participants.contains { !$0.hasApp })
        #expect(santaMarta.balances.map(\.net).reduce(0, +) == 0)
        #expect(santaMarta.unseenCount > 0)
        let closed = try #require(store.parches.first { !$0.parche.isOpen })
        #expect(closed.isSettled)
        #expect(store.parches.first?.parche.isOpen == true, "Los abiertos van primero")
    }
}

@Suite("Cola sin conexión guardada en disco")
struct FilePendingStoreTests {
    @Test("Guarda y lee la cola y las respuestas del cruce")
    func roundTrip() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = FilePendingStore(url: directory.appendingPathComponent("parches.json"))
        #expect(try await store.load() == ParcheLocalState())

        let parcheID = UUID()
        let payment = ParchePayment(
            parcheID: parcheID, fromID: UUID(), toID: UUID(), amount: 5_000, recordedBy: UUID(),
            createdAt: Date(timeIntervalSince1970: 1_800_000_000))
        let state = ParcheLocalState(
            pending: [.recordPayment(payment), .deleteExpense(id: UUID(), parcheID: parcheID, at: payment.createdAt)],
            declinedCruce: [ParcheDeclinedCruce(parcheID: parcheID, otherID: UUID())])
        try await store.save(state)
        #expect(try await FilePendingStore(url: directory.appendingPathComponent("parches.json")).load() == state)
        try? FileManager.default.removeItem(at: directory)
    }
}

extension ParcheExpense {
    /// El mismo gasto con otro `id`, como si alguien lo anotara de nuevo.
    fileprivate func with(id: UUID) -> ParcheExpense {
        ParcheExpense(
            id: id, parcheID: parcheID, concept: concept, baseAmount: baseAmount, tipPercent: tipPercent,
            amount: amount,
            spentOn: spentOn, split: split, payers: payers, shares: shares, recordedBy: recordedBy, createdAt: createdAt
        )
    }
}

/// Un repositorio cuya tarea se canceló (por ejemplo, la carga que reemplaza otra al cambiar la sesión).
private struct CancelledParcheRepository: ParcheRepository {
    func loadParches() async throws -> [ParcheDetail] { throw CancellationError() }
    func loadParche(id: UUID) async throws -> ParcheDetail { throw CancellationError() }
    func loadActivity(parcheID: UUID) async throws -> [ParcheActivity] { throw CancellationError() }
    func createParche(id: UUID, name: String, displayName: String) async throws -> ParcheDetail {
        throw CancellationError()
    }
    func joinParche(code: String, displayName: String) async throws -> ParcheDetail { throw CancellationError() }
    func addParticipant(id: UUID, parcheID: UUID, displayName: String) async throws -> ParcheParticipant {
        throw CancellationError()
    }
    func claimPlace(code: String) async throws -> ParcheDetail { throw CancellationError() }
    func saveExpense(_ expense: ParcheExpense) async throws { throw CancellationError() }
    func deleteExpense(id: UUID, parcheID: UUID, at date: Date) async throws { throw CancellationError() }
    func recordPayment(_ payment: ParchePayment) async throws { throw CancellationError() }
    func confirmPayment(id: UUID, parcheID: UUID) async throws { throw CancellationError() }
    func closeParche(id: UUID) async throws { throw CancellationError() }
    func moveDebtToCruce(parcheID: UUID, otherParticipantID: UUID) async throws -> ParcheCruceTransfer {
        throw CancellationError()
    }
    func markSeen(parcheID: UUID) async throws { throw CancellationError() }
}

@MainActor
@Suite("Cargas canceladas de parches")
struct ParcheStoreCancellationTests {
    @Test("Una carga cancelada no muestra \"sin conexión\" ni un error")
    func cancelledLoadIsSilent() async {
        let store = ParcheStore(
            session: SessionStore(phase: .main, me: MockData.joan, partner: MockData.jesus, userID: MockData.joan.id),
            repository: CancelledParcheRepository())
        await store.load()
        #expect(store.error == nil)
        #expect(!store.isOffline)
    }
}
