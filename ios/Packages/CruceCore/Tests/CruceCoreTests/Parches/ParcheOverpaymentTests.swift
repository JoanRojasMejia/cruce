import Foundation
import Testing

@testable import CruceCore

/// Santa Marta (`MockParches`): el plan "Para saldar" dice que Carlos le paga $125.000 a Jesús y $47.000 a Joan, y
/// hay un pago por confirmar de Carlos a Joan por $50.000 anotado por Ana.
@MainActor
@Suite("Aviso de pago de más en un parche")
struct ParcheOverpaymentTests {
    private let joan = MockParches.joan
    private let jesus = MockParches.jesus
    private let ana = MockParches.ana
    private let carlos = MockParches.carlos

    private func store(_ member: Member) -> ParcheStore {
        ParcheStore(
            session: SessionStore(phase: .main, me: member, partner: MockData.jesus, userID: member.id),
            repository: InMemoryParcheRepository(backend: MockParches.backend(), userID: member.id))
    }

    private func santaMarta(as member: Member) async throws -> (ParcheStore, ParcheDetail) {
        let store = store(member)
        await store.load()
        return (store, try #require(store.parche(MockParches.santaMartaID)))
    }

    private var anaMember: Member {
        Member(id: MockParches.anaUserID, name: "Ana", avatarColor: .green, tikeVariant: .rosa)
    }

    @Test("El plan cuenta solo pagos confirmados: el de $50.000 por confirmar no cambia los $47.000")
    func plannedAmountIgnoresPendingPayments() async throws {
        let (_, detail) = try await santaMarta(as: MockData.joan)
        #expect(detail.pendingPayments.contains { $0.fromID == carlos && $0.toID == joan && $0.amount == 50_000 })
        #expect(detail.plannedAmount(from: carlos, to: joan) == 47_000)
        #expect(detail.plannedAmount(from: carlos, to: jesus) == 125_000)
        #expect(detail.plannedAmount(from: joan, to: carlos) == 0, "Solo en el sentido del plan")
        #expect(detail.plannedAmount(from: carlos, to: ana) == 0)
    }

    @Test("Un pago mayor que el plan da aviso; igual o menor, no")
    func overpaymentRule() async throws {
        let (_, detail) = try await santaMarta(as: MockData.joan)
        #expect(
            detail.overpayment(from: carlos, to: joan, amount: 50_000)
                == ParcheOverpayment(fromID: carlos, toID: joan, planned: 47_000, amount: 50_000))
        #expect(detail.overpayment(from: carlos, to: joan, amount: 47_000) == nil)
        #expect(detail.overpayment(from: carlos, to: joan, amount: 20_000) == nil)
        #expect(
            detail.overpayment(from: carlos, to: ana, amount: 1)
                == ParcheOverpayment(fromID: carlos, toID: ana, planned: 0, amount: 1))
    }

    @Test("Al anotar: \"Carlos te debe $47.000 en el parche. Anotaste $50.000.\"")
    func recordingWarningForReceiver() async throws {
        let (store, detail) = try await santaMarta(as: MockData.joan)
        #expect(
            store.overpaymentWarning(from: carlos, to: joan, amount: 50_000, in: detail)
                == "Carlos te debe $47.000 en el parche. Anotaste $50.000.")
        #expect(store.overpaymentWarning(from: carlos, to: joan, amount: 47_000, in: detail) == nil)
        #expect(
            store.overpaymentWarning(from: carlos, to: jesus, amount: 130_000, in: detail)
                == "Carlos le debe $125.000 a Jesús en el parche. Anotaste $130.000.")
        #expect(
            store.overpaymentWarning(from: joan, to: carlos, amount: 10_000, in: detail)
                == "No le debes nada a Carlos en el parche. Anotaste $10.000.")
    }

    @Test("Desde otra vista el aviso nombra a los dos, y sin transferencia dice que no le debe nada")
    func recordingWarningOtherViewpoints() async throws {
        let (jesusStore, jesusView) = try await santaMarta(as: MockData.jesus)
        #expect(
            jesusStore.overpaymentWarning(from: carlos, to: joan, amount: 50_000, in: jesusView)
                == "Carlos le debe $47.000 a Joan en el parche. Anotaste $50.000.")
        #expect(
            jesusStore.overpaymentWarning(from: carlos, to: jesus, amount: 130_000, in: jesusView)
                == "Carlos te debe $125.000 en el parche. Anotaste $130.000.")
        let (anaStore, anaView) = try await santaMarta(as: anaMember)
        #expect(
            anaStore.overpaymentWarning(from: joan, to: ana, amount: 5_000, in: anaView)
                == "Joan no te debe nada en el parche. Anotaste $5.000.")
        #expect(
            anaStore.overpaymentWarning(from: ana, to: joan, amount: 5_000, in: anaView)
                == "No le debes nada a Joan en el parche. Anotaste $5.000.")
        #expect(
            anaStore.overpaymentWarning(from: carlos, to: ana, amount: 5_000, in: anaView)
                == "Carlos no te debe nada en el parche. Anotaste $5.000.")
        #expect(
            jesusStore.overpaymentWarning(from: carlos, to: ana, amount: 5_000, in: jesusView)
                == "Carlos no le debe nada a Ana en el parche. Anotaste $5.000.")
    }

    @Test("Al confirmar el pago que anotó Ana: el aviso dice quién lo anotó")
    func confirmingWarning() async throws {
        let (store, detail) = try await santaMarta(as: MockData.joan)
        let payment = try #require(store.pendingConfirmations(in: detail).first)
        #expect(payment.amount == 50_000)
        #expect(
            store.overpaymentWarning(for: payment, in: detail)
                == "Carlos te debe $47.000 en el parche. Ana anotó $50.000.")
        var mine = payment
        mine.recordedBy = joan
        #expect(
            store.overpaymentWarning(for: mine, in: detail)
                == "Carlos te debe $47.000 en el parche. Anotaste $50.000.")
        mine.amount = 47_000
        #expect(store.overpaymentWarning(for: mine, in: detail) == nil)
    }

    @Test("Para confirmar, el plan no cuenta el pago mismo aunque ya figure como confirmado en el teléfono")
    func confirmingExcludesThePaymentItself() async throws {
        let (store, detail) = try await santaMarta(as: MockData.joan)
        var payment = try #require(store.pendingConfirmations(in: detail).first)
        var confirmed = detail
        payment.confirmedAt = detail.parche.createdAt
        confirmed.payments = [payment]
        #expect(confirmed.plannedAmount(from: carlos, to: joan) == 0, "Con el pago contado ya no hay plan")
        #expect(confirmed.plannedAmount(from: carlos, to: joan, excluding: payment.id) == 47_000)
        #expect(
            store.overpaymentWarning(for: payment, in: confirmed)
                == "Carlos te debe $47.000 en el parche. Ana anotó $50.000.")
    }
}
