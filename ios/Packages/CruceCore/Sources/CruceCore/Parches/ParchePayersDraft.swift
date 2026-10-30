import Foundation

/// Quiénes pagaron un gasto del parche y cuánto puso cada uno, mientras se escribe ("¿Cuánto puso cada uno?").
///
/// Con un solo pagador, ese pone todo el total. Con varios, el total se reparte en partes iguales (mayor residuo, como
/// `Allocation`) y se vuelve a repartir al agregar o quitar pagadores o al cambiar el total, hasta que alguien escribe
/// un monto a mano. Desde ahí los montos se quedan como están y solo se avisa cuánto falta o sobra.
public struct ParchePayersDraft: Hashable, Sendable {
    /// Orden del parche: los pagadores se muestran y se reparten en este orden.
    public let order: [UUID]
    /// Quienes pagaron, en el orden del parche. Nunca queda vacío si empezó con alguien.
    public private(set) var payerIDs: [UUID]
    /// Total con propina; es lo que deben sumar los pagadores.
    public private(set) var total: Int
    /// Alguien escribió un monto a mano: ya no se reparte solo.
    public private(set) var isEditedByHand: Bool
    private var amounts: [UUID: Int]

    public init(order: [UUID], payerIDs: [UUID], total: Int = 0) {
        self.order = order
        self.payerIDs = []
        self.total = total
        self.isEditedByHand = false
        self.amounts = [:]
        self.payerIDs = sorted(Set(payerIDs))
        splitEqually()
    }

    /// Para editar un gasto: conserva lo que puso cada uno. Si estaba en partes iguales, sigue repartiéndose solo.
    public init(order: [UUID], editing payers: [ParchePayer], total: Int) {
        self.init(order: order, payerIDs: payers.map(\.participantID), total: total)
        let saved = Dictionary(payers.map { ($0.participantID, $0.amount) }, uniquingKeysWith: +)
        if hasSeveralPayers && saved != amounts {
            amounts = saved
            isEditedByHand = true
        }
    }

    /// Partes iguales de `total` entre `count` personas; los pesos que sobran van a las primeras.
    public static func equalAmounts(total: Int, count: Int) -> [Int] {
        guard count > 0 else { return [] }
        return (try? Allocation.split(total: max(total, 0), weights: Array(repeating: 1, count: count)))
            ?? Array(repeating: 0, count: count)
    }

    public var hasSeveralPayers: Bool { payerIDs.count > 1 }

    /// Lo que puso esa persona (0 si no pagó).
    public func amount(of id: UUID) -> Int {
        guard payerIDs.contains(id) else { return 0 }
        return hasSeveralPayers ? amounts[id] ?? 0 : total
    }

    /// Los pagadores para guardar el gasto.
    public var payers: [ParchePayer] {
        payerIDs.map { ParchePayer(participantID: $0, amount: amount(of: $0)) }
    }

    /// Lo que suman los pagadores.
    public var paid: Int { payerIDs.map(amount(of:)).reduce(0, +) }

    /// Lo que falta para llegar al total (negativo si sobra).
    public var difference: Int { total - paid }

    /// La suma da el total: se puede guardar.
    public var isBalanced: Bool { difference == 0 }

    /// "Faltan $X" o "Sobran $X"; `nil` si la suma da el total.
    public var mismatchMessage: String? {
        if difference > 0 { return "Faltan \(Money.format(difference))" }
        if difference < 0 { return "Sobran \(Money.format(-difference))" }
        return nil
    }

    /// Alguien que está como pagador no puso nada ($0): la base no lo acepta (`.noPayers`). Pasa al escribir $0 a mano
    /// o cuando el total es menor que el número de pagadores.
    public var hasPayerWithoutAmount: Bool { payerIDs.isEmpty || payerIDs.contains { amount(of: $0) <= 0 } }

    /// La suma da el total y cada pagador puso algo: se puede guardar.
    public var canSave: Bool { isBalanced && !hasPayerWithoutAmount }

    /// Lo que impide guardar, para mostrarlo bajo "¿Cuánto puso cada uno?": primero si faltan o sobran pesos, después si
    /// alguien quedó en $0. `nil` si se puede guardar (con un solo pagador, el monto del gasto ya se valida aparte).
    public var problemMessage: String? {
        if let mismatchMessage { return mismatchMessage }
        if hasSeveralPayers && hasPayerWithoutAmount { return "Cada quien que pagó tiene que poner algo" }
        return nil
    }

    /// Agrega o quita a esa persona. El último pagador no se puede quitar.
    public mutating func toggle(_ id: UUID) {
        if payerIDs.contains(id) {
            guard hasSeveralPayers else { return }
            payerIDs.removeAll { $0 == id }
            amounts[id] = nil
            // Con uno solo no queda nada escrito a mano que conservar: pone el total.
            if !hasSeveralPayers { isEditedByHand = false }
        } else {
            payerIDs = sorted(Set(payerIDs).union([id]))
            if isEditedByHand { amounts[id] = 0 }
        }
        splitEqually()
    }

    /// Cambió el monto o la propina.
    public mutating func setTotal(_ total: Int) {
        self.total = total
        splitEqually()
    }

    /// Alguien escribió lo que puso esa persona: desde ahora no se reparte solo.
    public mutating func setAmount(_ amount: Int, for id: UUID) {
        guard hasSeveralPayers, payerIDs.contains(id), amount != self.amount(of: id) else { return }
        amounts[id] = max(amount, 0)
        isEditedByHand = true
    }

    private mutating func splitEqually() {
        guard !isEditedByHand else { return }
        amounts = Dictionary(
            uniqueKeysWithValues: zip(payerIDs, Self.equalAmounts(total: total, count: payerIDs.count)))
    }

    /// En el orden del parche; quien no esté en el orden va al final.
    private func sorted(_ ids: Set<UUID>) -> [UUID] {
        order.filter(ids.contains) + ids.subtracting(order).sorted { $0.uuidString < $1.uuidString }
    }
}
