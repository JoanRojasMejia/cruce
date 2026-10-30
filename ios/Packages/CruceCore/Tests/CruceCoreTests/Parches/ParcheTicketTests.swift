import Foundation
import Testing

@testable import CruceCore

/// Tickets de `ticket-parche` sobre "Santa Marta" de `MockParches`: Joan +$47.000, Jesús +$125.000, Ana $0 y
/// Carlos (sin la app) −$172.000.
@Suite("ParcheTicket")
struct ParcheTicketTests {
    let detail = MockParches.parches().first { $0.id == MockParches.santaMartaID }!
    let cut = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("El ticket de Carlos dice cuánto debe, a quién, por qué gastos, pendiente y con su código")
    func carlos() throws {
        let ticket = try #require(ParcheTicket.personal(for: MockParches.carlos, in: detail, at: cut))
        #expect(ticket.headline == "Carlos debe $172.000")
        #expect(ticket.amount == -172_000)
        #expect(ticket.favor == "a favor de Jesús y Joan" || ticket.favor == "a favor de Joan y Jesús")
        #expect(
            Set(ticket.transfers) == ["Carlos le paga $125.000 a Jesús", "Carlos le paga $47.000 a Joan"])
        #expect(ticket.lines.map(\.concept) == ["Almuerzo en Taganga", "Hospedaje"])
        #expect(ticket.lines.map(\.share) == [22_000, 150_000])
        // Del almuerzo por consumo, el ticket dice qué consumió Carlos (los ítems con nombre).
        #expect(ticket.lines.map(\.items) == [["Mojarra"], []])
        #expect(ticket.stamp == .pending)
        #expect(ticket.cutAt == cut)
        #expect(ticket.claimCode == "SOY-K7QX2M")
        #expect(ticket.claimPhrase == "¿Ya tienes Cruce? Entra con el código SOY-K7QX2M y tus cuentas te siguen")
    }

    @Test(
        "El texto para compartir el ticket de Carlos lleva el enlace de su código SOY con el esquema de la app",
        arguments: ["cruce", "cruce-test", "cruce-dev"])
    func carlosShareText(scheme: String) throws {
        let ticket = try #require(ParcheTicket.personal(for: MockParches.carlos, in: detail, at: cut))
        #expect(ticket.claimLink(scheme: scheme) == "\(scheme)://codigo/SOY-K7QX2M")
        let text = ticket.shareText(scheme: scheme)
        #expect(text.hasPrefix("Cruce · Parche Santa Marta: Carlos debe $172.000."))
        #expect(text.contains("¿Ya tienes Cruce? Entra con el código SOY-K7QX2M y tus cuentas te siguen."))
        #expect(text.hasSuffix("Ábrelo en Cruce: \(scheme)://codigo/SOY-K7QX2M"))
    }

    @Test("Sin código SOY (con la app o el del parche) el texto no lleva enlace")
    func shareTextWithoutLink() throws {
        let ana = try #require(ParcheTicket.personal(for: MockParches.ana, in: detail, at: cut))
        #expect(ana.claimLink(scheme: "cruce") == nil)
        #expect(!ana.shareText(scheme: "cruce").contains("://"))
        let group = ParcheTicket.parche(detail, at: cut)
        #expect(group.shareText(scheme: "cruce") == "Cruce · Parche Santa Marta: Total gastado $865.000")
    }

    @Test("Ana tiene la app y está en cero: a paz y salvo y sin código")
    func ana() throws {
        let ticket = try #require(ParcheTicket.personal(for: MockParches.ana, in: detail, at: cut))
        #expect(ticket.headline == "Ana está a paz y salvo")
        #expect(ticket.stamp == .settled)
        #expect(ticket.favor == nil)
        #expect(ticket.transfers.isEmpty)
        #expect(ticket.claimCode == nil)
        #expect(ticket.claimPhrase == nil)
    }

    @Test("A quien le deben, el ticket lo dice con su nombre y lo que pagó")
    func jesus() throws {
        let ticket = try #require(ParcheTicket.personal(for: MockParches.jesus, in: detail, at: cut))
        #expect(ticket.headline == "A Jesús le deben $125.000")
        #expect(ticket.favor == "a favor de Jesús")
        #expect(ticket.lines.first { $0.concept == "Hospedaje" }?.paid == 400_000)
    }

    @Test("El ticket del parche lleva el total y las transferencias, sin saldos individuales")
    func parche() {
        let ticket = ParcheTicket.parche(detail, at: cut)
        #expect(ticket.parcheName == "Santa Marta")
        #expect(ticket.personName == nil)
        #expect(ticket.headline == "Total gastado")
        #expect(ticket.amount == 865_000)
        #expect(ticket.transfers.count == 2)
        #expect(ticket.transfers.allSatisfy { $0.hasPrefix("Carlos le paga") })
        #expect(ticket.lines.isEmpty)
        #expect(ticket.expenseCount == 3)
        #expect(ticket.stamp == .pending)
        #expect(ticket.claimCode == nil)
    }

    @Test("Un parche en cero lleva el sello a paz y salvo")
    func settledParche() {
        let cena = MockParches.parches().first { $0.id == MockParches.cenaID }!
        #expect(ParcheTicket.parche(cena, at: cut).stamp == .settled)
    }

    @Test("Lista de nombres en español")
    func names() {
        #expect(ParcheTicket.list(["Ana"]) == "Ana")
        #expect(ParcheTicket.list(["Ana", "Jesús"]) == "Ana y Jesús")
        #expect(ParcheTicket.list(["Ana", "Jesús", "Joan"]) == "Ana, Jesús y Joan")
    }

    @Test("Una persona que no está en el parche no tiene ticket")
    func unknown() {
        #expect(ParcheTicket.personal(for: UUID(), in: detail, at: cut) == nil)
    }
}
