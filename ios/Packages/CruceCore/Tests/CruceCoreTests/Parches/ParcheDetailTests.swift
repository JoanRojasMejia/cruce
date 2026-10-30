import Foundation
import Testing

@testable import CruceCore

@Suite("Detalle de un parche")
struct ParcheDetailTests {
    private let day = Date(timeIntervalSince1970: 1_800_000_000)

    private func detail(_ participants: [ParcheParticipant]) -> ParcheDetail {
        ParcheDetail(
            parche: Parche(name: "Prueba", code: "PCH-ABC234", createdAt: day), participants: participants)
    }

    // MARK: - Orden del parche

    @Test("Si entraron al mismo tiempo, el orden lo decide el id, igual que en la base")
    func orderBreaksTiesByIDLikePostgres() throws {
        // Postgres ordena los uuid por sus 16 bytes: 0f < 01… < 0a… < 90… < a0… < ff….
        let ids = try [
            "ffffffff-0000-0000-0000-000000000000", "a0000000-0000-0000-0000-000000000000",
            "0000000a-0000-0000-0000-000000000000", "90000000-0000-0000-0000-000000000000",
            "00000001-0000-0000-0000-000000000000", "00000000-0000-0000-0000-00000000000f",
        ].map { try #require(UUID(uuidString: $0)) }
        let tied = ids.map { ParcheParticipant(id: $0, displayName: "P", joinedAt: day) }
        let expected = [ids[5], ids[4], ids[2], ids[3], ids[1], ids[0]]
        #expect(detail(tied).order == expected)
        #expect(detail(tied.reversed()).order == expected, "No depende de la posición en la lista")
    }

    @Test("Primero entra quien llegó antes, aunque su id sea mayor")
    func orderUsesJoinedAtFirst() throws {
        let late = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
        let early = try #require(UUID(uuidString: "ffffffff-ffff-ffff-ffff-ffffffffffff"))
        let participants = [
            ParcheParticipant(id: late, displayName: "B", joinedAt: day.addingTimeInterval(1)),
            ParcheParticipant(id: early, displayName: "A", joinedAt: day),
        ]
        #expect(detail(participants).order == [early, late])
    }

    // MARK: - Todos en $0

    @Test("Con gastos y todos los saldos en $0, todos quedaron en $0")
    func everyoneAtZeroWithSettledBalances() throws {
        let cena = try #require(MockParches.parches().first { $0.id == MockParches.cenaID })
        #expect(cena.everyoneAtZero)
    }

    @Test("Si alguien debe, no todos están en $0")
    func everyoneAtZeroIsFalseWithDebts() throws {
        let santaMarta = try #require(MockParches.parches().first { $0.id == MockParches.santaMartaID })
        #expect(!santaMarta.everyoneAtZero)
    }

    @Test("Un parche sin gastos no cuenta como saldado")
    func everyoneAtZeroNeedsExpenses() {
        let empty = detail([ParcheParticipant(displayName: "A", joinedAt: day)])
        #expect(!empty.everyoneAtZero)
    }
}
