import Foundation
import Testing

@testable import CruceCore

@Suite("Cuánto puso cada pagador")
struct ParchePayersDraftTests {
    private let joan = MockParches.joan
    private let jesus = MockParches.jesus
    private let ana = MockParches.ana
    private let carlos = MockParches.carlos
    private var order: [UUID] { [joan, jesus, ana, carlos] }

    @Test("Partes iguales con el mayor residuo: el peso que sobra va a quien va primero")
    func equalAmounts() {
        #expect(ParchePayersDraft.equalAmounts(total: 600_000, count: 2) == [300_000, 300_000])
        #expect(ParchePayersDraft.equalAmounts(total: 100_000, count: 3) == [33_334, 33_333, 33_333])
        #expect(ParchePayersDraft.equalAmounts(total: 2, count: 3) == [1, 1, 0])
        #expect(ParchePayersDraft.equalAmounts(total: 0, count: 2) == [0, 0])
        #expect(ParchePayersDraft.equalAmounts(total: 1_000, count: 0).isEmpty)
    }

    @Test("Con un solo pagador, pone todo el total y no hay nada que cuadrar")
    func singlePayerPaysTotal() {
        var draft = ParchePayersDraft(order: order, payerIDs: [joan], total: 45_000)
        #expect(!draft.hasSeveralPayers)
        #expect(draft.payers == [ParchePayer(participantID: joan, amount: 45_000)])
        #expect(draft.isBalanced)
        #expect(draft.mismatchMessage == nil)
        draft.setTotal(50_000)
        #expect(draft.payers == [ParchePayer(participantID: joan, amount: 50_000)])
    }

    @Test("Al agregar pagadores el total se reparte en partes iguales, en el orden del parche")
    func addingPayersSplitsEqually() {
        var draft = ParchePayersDraft(order: order, payerIDs: [jesus], total: 600_000)
        draft.toggle(joan)
        #expect(draft.hasSeveralPayers)
        #expect(draft.payerIDs == [joan, jesus])
        #expect(draft.amount(of: joan) == 300_000)
        #expect(draft.amount(of: jesus) == 300_000)
        #expect(draft.isBalanced)
        draft.toggle(ana)
        #expect(draft.payers.map(\.amount) == [200_000, 200_000, 200_000])
        draft.setTotal(100_000)
        #expect(draft.payers.map(\.amount) == [33_334, 33_333, 33_333])
        draft.toggle(ana)
        #expect(draft.payers.map(\.amount) == [50_000, 50_000])
    }

    @Test("No se puede quitar al último pagador")
    func lastPayerStays() {
        var draft = ParchePayersDraft(order: order, payerIDs: [joan], total: 10_000)
        draft.toggle(joan)
        #expect(draft.payerIDs == [joan])
    }

    @Test("Después de escribir un monto a mano ya no se reparte solo")
    func handEditStopsTheEqualSplit() {
        var draft = ParchePayersDraft(order: order, payerIDs: [jesus, joan], total: 600_000)
        draft.setAmount(400_000, for: jesus)
        #expect(draft.isEditedByHand)
        #expect(draft.amount(of: joan) == 300_000)
        #expect(draft.mismatchMessage == "Sobran $100.000")
        #expect(!draft.isBalanced)
        draft.setTotal(700_000)
        #expect(draft.amount(of: jesus) == 400_000, "El total cambió, pero el monto escrito a mano se queda")
        #expect(draft.mismatchMessage == nil)
        draft.toggle(ana)
        #expect(draft.amount(of: ana) == 0)
        #expect(draft.mismatchMessage == nil)
        draft.setTotal(800_000)
        #expect(draft.mismatchMessage == "Faltan $100.000")
    }

    @Test("Un pagador con $0 no deja guardar, aunque la suma dé el total")
    func payerWithoutAmountCannotSave() {
        var draft = ParchePayersDraft(order: order, payerIDs: [jesus, joan], total: 600_000)
        #expect(draft.canSave)
        #expect(draft.problemMessage == nil)
        draft.setAmount(600_000, for: jesus)
        draft.setAmount(0, for: joan)
        #expect(draft.isBalanced)
        #expect(!draft.canSave)
        #expect(draft.problemMessage == "Cada quien que pagó tiene que poner algo")

        // Un total menor que el número de pagadores: a alguien le tocan $0.
        let tiny = ParchePayersDraft(order: order, payerIDs: [joan, jesus, ana], total: 2)
        #expect(tiny.isBalanced)
        #expect(!tiny.canSave)
        #expect(tiny.problemMessage == "Cada quien que pagó tiene que poner algo")

        // Faltan o sobran va primero.
        draft.setAmount(500_000, for: jesus)
        #expect(draft.problemMessage == "Faltan $100.000")
    }

    @Test("Faltan o sobran: el mensaje dice cuánto, en pesos")
    func mismatchMessage() {
        var draft = ParchePayersDraft(order: order, payerIDs: [jesus, joan], total: 600_000)
        draft.setAmount(250_000, for: jesus)
        #expect(draft.difference == 50_000)
        #expect(draft.mismatchMessage == "Faltan $50.000")
        draft.setAmount(350_000, for: joan)
        #expect(draft.difference == 0)
        #expect(draft.mismatchMessage == nil)
        #expect(draft.isBalanced)
        draft.setAmount(1_350_000, for: joan)
        #expect(draft.mismatchMessage == "Sobran $1.000.000")
    }

    @Test("Al volver a un solo pagador, ese pone el total y vuelve a repartirse solo")
    func backToOnePayerResets() {
        var draft = ParchePayersDraft(order: order, payerIDs: [jesus, joan], total: 600_000)
        draft.setAmount(100_000, for: jesus)
        draft.toggle(jesus)
        #expect(draft.payers == [ParchePayer(participantID: joan, amount: 600_000)])
        #expect(!draft.isEditedByHand)
        draft.toggle(ana)
        #expect(draft.payers.map(\.amount) == [300_000, 300_000])
    }

    @Test("Editar un gasto conserva lo que puso cada uno")
    func editingKeepsAmounts() {
        let draft = ParchePayersDraft(
            order: order,
            editing: [
                ParchePayer(participantID: jesus, amount: 400_000), ParchePayer(participantID: joan, amount: 200_000),
            ],
            total: 600_000)
        #expect(draft.payerIDs == [joan, jesus])
        #expect(draft.isEditedByHand)
        #expect(draft.isBalanced)
        let even = ParchePayersDraft(
            order: order,
            editing: [
                ParchePayer(participantID: jesus, amount: 300_000), ParchePayer(participantID: joan, amount: 300_000),
            ],
            total: 600_000)
        #expect(!even.isEditedByHand, "Si estaba en partes iguales, sigue repartiéndose solo")
    }

    @Test("El Hospedaje de Santa Marta: Jesús $400.000 y Joan $200.000 dan +47.000, +125.000, 0 y −172.000")
    func santaMartaLodging() throws {
        let santaMarta = try #require(MockParches.parches().first { $0.id == MockParches.santaMartaID })
        let lodgingID = try #require(santaMarta.expenses.first { $0.concept == "Hospedaje" }?.id)
        // Se anota con la pantalla: Jesús pagó y se agrega a Joan; Jesús escribe que puso $400.000.
        var draft = ParchePayersDraft(order: santaMarta.order, payerIDs: [jesus], total: 600_000)
        draft.toggle(joan)
        #expect(draft.amount(of: joan) == 300_000)
        draft.setAmount(400_000, for: jesus)
        #expect(draft.mismatchMessage == "Sobran $100.000")
        draft.setAmount(200_000, for: joan)
        #expect(draft.isBalanced)
        let lodging = try ParcheExpense.resolve(
            id: lodgingID, parcheID: santaMarta.id, concept: "Hospedaje", base: 600_000,
            split: .shares([joan: 1, jesus: 1, ana: 1, carlos: 1]), payers: draft.payers, order: santaMarta.order,
            recordedBy: jesus, at: santaMarta.parche.createdAt)
        #expect(lodging.paid(by: jesus) == 400_000)
        #expect(lodging.paid(by: joan) == 200_000)
        var detail = santaMarta
        detail.expenses = santaMarta.expenses.map { $0.id == lodgingID ? lodging : $0 }
        let nets = Dictionary(uniqueKeysWithValues: detail.balances.map { ($0.participantID, $0.net) })
        #expect(nets == [joan: 47_000, jesus: 125_000, ana: 0, carlos: -172_000])
    }
}
