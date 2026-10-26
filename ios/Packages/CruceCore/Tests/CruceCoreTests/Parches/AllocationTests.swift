import Foundation
import Testing

@testable import CruceCore

@Suite("Reparto de gastos de parches")
struct AllocationTests {
    // Orden del parche: Jesús, Ana, Carlos, Joan, Sofía.
    private let jesus = UUID()
    private let ana = UUID()
    private let carlos = UUID()
    private let joan = UUID()
    private let sofia = UUID()
    private var order: [UUID] { [jesus, ana, carlos, joan, sofia] }
    private var four: [UUID] { [jesus, ana, carlos, joan] }

    private func amounts(_ allocation: ParcheAllocation) -> [UUID: Int] {
        Dictionary(uniqueKeysWithValues: allocation.shares.map { ($0.participantID, $0.amount) })
    }

    // MARK: - Mayor residuo

    @Test("Un monto exacto se reparte sin residuo")
    func exactSplit() throws {
        #expect(try Allocation.split(total: 100_000, weights: [1, 1, 1, 1]) == [25_000, 25_000, 25_000, 25_000])
    }

    @Test("$100.000 entre 3: el peso que sobra va al primero del parche")
    func remainderGoesToFirstOnTie() throws {
        #expect(try Allocation.split(total: 100_000, weights: [1, 1, 1]) == [33_334, 33_333, 33_333])
    }

    @Test("Los pesos que sobran van a los residuos más grandes")
    func remainderGoesToLargestRemainders() throws {
        // 10 en pesos 1, 2, 3: 1,666 / 3,333 / 5 → residuos 4/6, 2/6, 0.
        #expect(try Allocation.split(total: 10, weights: [1, 2, 3]) == [2, 3, 5])
        // 7 en pesos 3, 3, 1: 3/7·7=3, 3, 1; exacto.
        #expect(try Allocation.split(total: 7, weights: [3, 3, 1]) == [3, 3, 1])
        // 5 en pesos 2, 2, 2: 1,666 cada uno; los dos primeros se llevan el sobrante.
        #expect(try Allocation.split(total: 5, weights: [2, 2, 2]) == [2, 2, 1])
    }

    @Test("Un peso en cero no recibe nada")
    func zeroWeightGetsNothing() throws {
        #expect(try Allocation.split(total: 30_000, weights: [1, 0, 1, 0, 1]) == [10_000, 0, 10_000, 0, 10_000])
    }

    @Test("Todos los pesos en cero dan error")
    func allZeroWeightsThrow() {
        #expect(throws: ParcheSplitError.noWeights) { try Allocation.split(total: 100, weights: [0, 0]) }
        #expect(throws: ParcheSplitError.noWeights) { try Allocation.split(total: 100, weights: []) }
    }

    @Test("Pesos negativos o total negativo dan error")
    func negativeInputsThrow() {
        #expect(throws: ParcheSplitError.negativeWeight) { try Allocation.split(total: 100, weights: [1, -1]) }
        #expect(throws: ParcheSplitError.negativeAmount) { try Allocation.split(total: -1, weights: [1]) }
    }

    @Test("No se desborda con montos y pesos grandes")
    func largeValuesDoNotOverflow() throws {
        let total = 999_999_999_999
        let result = try Allocation.split(total: total, weights: [999_999_999_999, 1, 333_333_333_333])
        #expect(result.reduce(0, +) == total)
    }

    @Test("Siempre suma exactamente el total", arguments: 0..<300)
    func alwaysSumsToTotal(seed: Int) throws {
        var generator = SeededGenerator(seed: UInt64(seed))
        let count = Int.random(in: 1...8, using: &generator)
        var weights = (0..<count).map { _ in Int.random(in: 0...1_000, using: &generator) }
        if weights.allSatisfy({ $0 == 0 }) { weights[0] = 1 }
        let total = Int.random(in: 0...50_000_000, using: &generator)
        let result = try Allocation.split(total: total, weights: weights)
        #expect(result.reduce(0, +) == total)
        #expect(result.count == weights.count)
        for (amount, weight) in zip(result, weights) {
            // Nadie se aleja más de un peso de su parte exacta, y peso cero es cero.
            let exact = Double(total) * Double(weight) / Double(weights.reduce(0, +))
            #expect(abs(Double(amount) - exact) < 1)
            if weight == 0 { #expect(amount == 0) }
        }
    }

    // MARK: - Iguales

    @Test("Iguales entre todos: $100.000 entre 4")
    func equalAmongAll() throws {
        let allocation = try Allocation.allocate(base: 100_000, split: .equal(Set(four)), order: four)
        #expect(allocation.total == 100_000)
        #expect(amounts(allocation) == [jesus: 25_000, ana: 25_000, carlos: 25_000, joan: 25_000])
    }

    @Test("Iguales entre algunos: taxi de $30.000 entre 3 de 5")
    func equalAmongSome() throws {
        let allocation = try Allocation.allocate(base: 30_000, split: .equal([ana, carlos, sofia]), order: order)
        #expect(amounts(allocation) == [ana: 10_000, carlos: 10_000, sofia: 10_000])
        #expect(allocation.shares.map(\.participantID) == [ana, carlos, sofia], "En el orden del parche")
    }

    @Test("Iguales sin nadie elegido da error")
    func equalWithoutParticipantsThrows() {
        #expect(throws: ParcheSplitError.noParticipants) {
            try Allocation.allocate(base: 30_000, split: .equal([]), order: order)
        }
    }

    @Test("$100.000 entre 3 en el orden del parche")
    func equalRoundingFollowsParcheOrder() throws {
        let allocation = try Allocation.allocate(base: 100_000, split: .equal([carlos, jesus, ana]), order: order)
        #expect(allocation.shares.map(\.amount) == [33_334, 33_333, 33_333])
        #expect(allocation.shares.map(\.participantID) == [jesus, ana, carlos])
    }

    // MARK: - Por consumo

    @Test("Por consumo: cada uno su plato")
    func itemsEachOwnDish() throws {
        let split = ParcheSplit.items([
            ParcheSplitItem(amount: 100_000, participantIDs: [jesus]),
            ParcheSplitItem(amount: 50_000, participantIDs: [ana]),
            ParcheSplitItem(amount: 20_000, participantIDs: [carlos]),
            ParcheSplitItem(amount: 30_000, participantIDs: [joan]),
        ])
        let allocation = try Allocation.allocate(base: 200_000, split: split, order: four)
        #expect(amounts(allocation) == [jesus: 100_000, ana: 50_000, carlos: 20_000, joan: 30_000])
    }

    @Test("Por consumo: cuenta mixta con una entrada para los 4")
    func itemsMixedBill() throws {
        let split = ParcheSplit.items([
            ParcheSplitItem(amount: 40_000, participantIDs: Set(four)),
            ParcheSplitItem(amount: 30_000, participantIDs: [jesus]),
            ParcheSplitItem(amount: 20_000, participantIDs: [ana]),
        ])
        let allocation = try Allocation.allocate(base: 90_000, split: split, order: four)
        #expect(amounts(allocation) == [jesus: 40_000, ana: 30_000, carlos: 10_000, joan: 10_000])
    }

    @Test("Por consumo: los ítems deben sumar el monto")
    func itemsMustMatchBase() {
        let split = ParcheSplit.items([ParcheSplitItem(amount: 40_000, participantIDs: [jesus])])
        #expect(throws: ParcheSplitError.itemsDoNotMatch(difference: 10_000)) {
            try Allocation.allocate(base: 50_000, split: split, order: four)
        }
    }

    @Test("Por consumo: un ítem sin personas o en cero da error")
    func itemsNeedPeopleAndAmount() {
        #expect(throws: ParcheSplitError.noParticipants) {
            try Allocation.allocate(
                base: 10_000, split: .items([ParcheSplitItem(amount: 10_000, participantIDs: [])]), order: four)
        }
        #expect(throws: ParcheSplitError.invalidItemAmount) {
            try Allocation.allocate(
                base: 0, split: .items([ParcheSplitItem(amount: 0, participantIDs: [ana])]), order: four)
        }
    }

    // MARK: - Por partes y por porcentaje

    @Test("Por partes: una pareja cuenta doble")
    func sharesCoupleCountsDouble() throws {
        let allocation = try Allocation.allocate(
            base: 300_000, split: .shares([jesus: 2, ana: 1, carlos: 1]), order: order)
        #expect(amounts(allocation) == [jesus: 150_000, ana: 75_000, carlos: 75_000])
    }

    @Test("Por partes: negativas o todas en cero dan error")
    func sharesValidation() {
        #expect(throws: ParcheSplitError.negativeWeight) {
            try Allocation.allocate(base: 300_000, split: .shares([jesus: 2, ana: -1]), order: order)
        }
        #expect(throws: ParcheSplitError.noWeights) {
            try Allocation.allocate(base: 300_000, split: .shares([jesus: 0, ana: 0]), order: order)
        }
    }

    @Test("Por porcentaje: 50 %, 30 % y 20 %")
    func percentages() throws {
        let allocation = try Allocation.allocate(
            base: 200_000, split: .percentage([jesus: 50, ana: 30, carlos: 20]), order: order)
        #expect(amounts(allocation) == [jesus: 100_000, ana: 60_000, carlos: 40_000])
    }

    @Test("Por porcentaje: deben sumar 100")
    func percentagesMustSumToHundred() {
        #expect(throws: ParcheSplitError.percentagesDoNotSum(total: 90)) {
            try Allocation.allocate(base: 200_000, split: .percentage([jesus: 50, ana: 40]), order: order)
        }
    }

    @Test("Una persona que no es del parche da error")
    func unknownParticipantThrows() {
        #expect(throws: ParcheSplitError.unknownParticipant) {
            try Allocation.allocate(base: 10_000, split: .equal([UUID()]), order: order)
        }
    }

    // MARK: - Propina

    @Test("Propina del 10 % sobre el almuerzo por consumo")
    func tipIsProportional() throws {
        let split = ParcheSplit.items([
            ParcheSplitItem(amount: 100_000, participantIDs: [jesus]),
            ParcheSplitItem(amount: 50_000, participantIDs: [ana]),
            ParcheSplitItem(amount: 20_000, participantIDs: [carlos]),
            ParcheSplitItem(amount: 30_000, participantIDs: [joan]),
        ])
        let allocation = try Allocation.allocate(base: 200_000, split: split, tipPercent: 10, order: four)
        #expect(allocation.total == 220_000)
        #expect(allocation.tip == 20_000)
        #expect(amounts(allocation) == [jesus: 110_000, ana: 55_000, carlos: 22_000, joan: 33_000])
    }

    @Test("La propina se redondea hacia abajo")
    func tipRoundsDown() throws {
        let allocation = try Allocation.allocate(base: 10_005, split: .equal([jesus]), tipPercent: 10, order: order)
        #expect(allocation.tip == 1_000)
        #expect(allocation.total == 11_005)
    }

    @Test("La propina va de 0 a 100 %")
    func tipRange() {
        #expect(throws: ParcheSplitError.invalidTip) {
            try Allocation.allocate(base: 10_000, split: .equal([jesus]), tipPercent: 101, order: order)
        }
        #expect(throws: ParcheSplitError.invalidTip) {
            try Allocation.allocate(base: 10_000, split: .equal([jesus]), tipPercent: -1, order: order)
        }
    }

    @Test("Con cualquier reparto y propina, las partes suman el total", arguments: 0..<200)
    func allocationsAlwaysSumToTotal(seed: Int) throws {
        var generator = SeededGenerator(seed: UInt64(seed) &+ 10_000)
        let base = Int.random(in: 1...5_000_000, using: &generator)
        let tip = Int.random(in: 0...100, using: &generator)
        let chosen = order.filter { _ in Bool.random(using: &generator) }
        let people = chosen.isEmpty ? [ana] : chosen
        let split: ParcheSplit
        switch seed % 3 {
        case 0: split = .equal(Set(people))
        case 1:
            split = .shares(
                Dictionary(uniqueKeysWithValues: people.map { ($0, Int.random(in: 1...5, using: &generator)) }))
        default:
            // Ítems al azar cuyo total es `base`.
            let first = Int.random(in: 0...base, using: &generator)
            split = .items(
                [
                    ParcheSplitItem(amount: max(first, 1), participantIDs: Set(people)),
                    ParcheSplitItem(amount: base - max(first, 1), participantIDs: [people[0]]),
                ].filter { $0.amount > 0 })
        }
        let allocation = try Allocation.allocate(base: base, split: split, tipPercent: tip, order: order)
        #expect(allocation.total == base + base * tip / 100)
        #expect(allocation.shares.map(\.amount).reduce(0, +) == allocation.total)
    }
}

/// Generador determinista (SplitMix64) para las pruebas de propiedades.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
