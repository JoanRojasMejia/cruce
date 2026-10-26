import Foundation

/// Un ítem de una cuenta repartida por consumo: su monto y quiénes lo consumieron.
public struct ParcheSplitItem: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var amount: Int
    public var participantIDs: Set<UUID>

    public init(id: UUID = UUID(), amount: Int, participantIDs: Set<UUID>) {
        self.id = id
        self.amount = amount
        self.participantIDs = participantIDs
    }
}

/// Cómo se reparte un gasto de un parche. Cada tipo solo produce pesos para `Allocation.split`.
public enum ParcheSplit: Codable, Hashable, Sendable {
    /// Partes iguales entre los elegidos (todos o algunos).
    case equal(Set<UUID>)
    /// Por consumo: cada ítem en partes iguales entre quienes lo consumieron.
    case items([ParcheSplitItem])
    /// Por partes: enteros ≥ 0, al menos uno > 0.
    case shares([UUID: Int])
    /// Por porcentaje: enteros que suman 100.
    case percentage([UUID: Int])

    /// Nombre del método, igual que `parche_expenses.split_method`.
    public var method: String {
        switch self {
        case .equal: "equal"
        case .items: "items"
        case .shares: "shares"
        case .percentage: "percentage"
        }
    }

    /// El dato de entrada de cada persona (1, sus partes, su porcentaje o su subtotal por consumo).
    public func input(for participantID: UUID) -> Int? {
        switch self {
        case .equal(let ids): ids.contains(participantID) ? 1 : nil
        case .shares(let values), .percentage(let values): values[participantID]
        case .items: nil
        }
    }
}

/// Lo que le toca a una persona de un gasto, en pesos ya resueltos.
public struct ParcheShare: Codable, Hashable, Sendable {
    public var participantID: UUID
    public var amount: Int

    public init(participantID: UUID, amount: Int) {
        self.participantID = participantID
        self.amount = amount
    }
}

/// El reparto resuelto de un gasto: total con propina y lo que le toca a cada uno, en el orden del parche.
public struct ParcheAllocation: Hashable, Sendable {
    public let base: Int
    public let tip: Int
    public let total: Int
    public let shares: [ParcheShare]
}

/// Por qué no se pudo repartir un gasto, con su mensaje para la pantalla.
public enum ParcheSplitError: Error, Equatable, Sendable {
    case noWeights
    case negativeWeight
    case negativeAmount
    case noParticipants
    case unknownParticipant
    case invalidItemAmount
    case itemsDoNotMatch(difference: Int)
    case percentagesDoNotSum(total: Int)
    case invalidTip

    public var message: String {
        switch self {
        case .noWeights: "Elige al menos a una persona con una parte mayor que cero."
        case .negativeWeight: "Las partes no pueden ser negativas."
        case .negativeAmount: "El monto no puede ser negativo."
        case .noParticipants: "Elige al menos a una persona."
        case .unknownParticipant: "Una de las personas ya no está en el parche."
        case .invalidItemAmount: "Cada ítem necesita un monto mayor que $0."
        case .itemsDoNotMatch(let difference):
            difference > 0
                ? "Los ítems suman \(Money.format(difference)) menos que el monto."
                : "Los ítems suman \(Money.format(-difference)) más que el monto."
        case .percentagesDoNotSum(let total): "Los porcentajes suman \(total) % y deben sumar 100 %."
        case .invalidTip: "La propina va de 0 a 100 %."
        }
    }
}

/// Reparto en pesos enteros de los gastos de parches. Un solo algoritmo: proporcional por pesos con mayor residuo.
public enum Allocation {
    /// Reparte `total` en proporción a `weights` con el método del mayor residuo.
    /// A cada uno `total * w / Σw` (división entera); los pesos que sobran van de a uno a los residuos más grandes,
    /// y en empate a quien va primero. Siempre suma exactamente `total`.
    public static func split(total: Int, weights: [Int]) throws(ParcheSplitError) -> [Int] {
        guard total >= 0 else { throw .negativeAmount }
        guard weights.allSatisfy({ $0 >= 0 }) else { throw .negativeWeight }
        let sum = weights.reduce(0, +)
        guard sum > 0 else { throw .noWeights }

        // Multiplicación de doble ancho: `total * w` puede pasarse de 64 bits con montos y pesos grandes.
        var amounts: [Int] = []
        var remainders: [(index: Int, remainder: Int)] = []
        for (index, weight) in weights.enumerated() {
            let product = total.multipliedFullWidth(by: weight)
            let (quotient, remainder) = sum.dividingFullWidth(product)
            amounts.append(quotient)
            remainders.append((index, remainder))
        }
        let leftover = total - amounts.reduce(0, +)
        // Orden estable: residuo de mayor a menor y, en empate, el primero.
        let winners = remainders.sorted {
            $0.remainder != $1.remainder ? $0.remainder > $1.remainder : $0.index < $1.index
        }
        for winner in winners.prefix(leftover) {
            amounts[winner.index] += 1
        }
        return amounts
    }

    /// Resuelve el reparto de un gasto de `base` pesos más la propina (0–100 %, redondeada hacia abajo).
    /// El total con propina se reparte con los mismos pesos, así la propina queda proporcional a lo consumido.
    /// `order` es el orden de los participantes en el parche (orden de unión) y decide los empates.
    public static func allocate(
        base: Int, split: ParcheSplit, tipPercent: Int = 0, order: [UUID]
    ) throws(ParcheSplitError) -> ParcheAllocation {
        guard base >= 0 else { throw .negativeAmount }
        guard (0...100).contains(tipPercent) else { throw .invalidTip }
        let weights = try weights(for: split, base: base, order: order)
        let tip = base * tipPercent / 100
        let total = base + tip
        let amounts = try Self.split(total: total, weights: weights)
        let shares = zip(order, zip(weights, amounts))
            .filter { $0.1.0 > 0 }
            .map { ParcheShare(participantID: $0.0, amount: $0.1.1) }
        return ParcheAllocation(base: base, tip: tip, total: total, shares: shares)
    }

    /// Los pesos de cada participante, en el orden del parche.
    private static func weights(for split: ParcheSplit, base: Int, order: [UUID]) throws(ParcheSplitError) -> [Int] {
        let known = Set(order)
        switch split {
        case .equal(let ids):
            guard !ids.isEmpty else { throw .noParticipants }
            guard ids.isSubset(of: known) else { throw .unknownParticipant }
            return order.map { ids.contains($0) ? 1 : 0 }

        case .shares(let values):
            guard Set(values.keys).isSubset(of: known) else { throw .unknownParticipant }
            guard values.values.allSatisfy({ $0 >= 0 }) else { throw .negativeWeight }
            return order.map { values[$0] ?? 0 }

        case .percentage(let values):
            guard Set(values.keys).isSubset(of: known) else { throw .unknownParticipant }
            guard values.values.allSatisfy({ $0 >= 0 }) else { throw .negativeWeight }
            let sum = values.values.reduce(0, +)
            guard sum == 100 else { throw .percentagesDoNotSum(total: sum) }
            return order.map { values[$0] ?? 0 }

        case .items(let items):
            // Cada ítem se reparte en partes iguales entre quienes lo consumieron; el subtotal es el peso.
            var subtotals = [Int](repeating: 0, count: order.count)
            for item in items {
                guard item.amount > 0 else { throw .invalidItemAmount }
                guard !item.participantIDs.isEmpty else { throw .noParticipants }
                guard item.participantIDs.isSubset(of: known) else { throw .unknownParticipant }
                let parts = try Self.split(
                    total: item.amount, weights: order.map { item.participantIDs.contains($0) ? 1 : 0 })
                for index in subtotals.indices {
                    subtotals[index] += parts[index]
                }
            }
            let sum = subtotals.reduce(0, +)
            guard sum == base else { throw .itemsDoNotMatch(difference: base - sum) }
            return subtotals
        }
    }
}
