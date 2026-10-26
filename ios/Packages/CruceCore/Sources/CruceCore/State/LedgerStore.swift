import Foundation
import Observation

/// Movimientos de la cuenta compartida, el saldo y las acciones que los cambian.
/// Guarda todos los movimientos, incluidos los eliminados; las lecturas visibles solo muestran los vigentes.
@MainActor
@Observable
public final class LedgerStore {
    /// Todos los movimientos, también los eliminados (borrado suave).
    public private(set) var movements: [Movement]
    /// Último movimiento guardado; muestra la hoja "Gasto guardado" en el inicio.
    public var lastSaved: Movement?
    /// Pago recién registrado; muestra la pantalla "A paz y salvo".
    public var lastSettlement: Movement?
    public var isOffline = false
    public var pendingSyncCount = 0

    private let session: SessionStore
    private let repository: LedgerRepository
    /// Reloj del borrado; las pruebas inyectan una fecha fija.
    private let now: () -> Date

    public init(
        session: SessionStore,
        repository: LedgerRepository,
        movements: [Movement] = [],
        now: @escaping () -> Date = { .now }
    ) {
        self.session = session
        self.repository = repository
        self.movements = movements
        self.now = now
    }

    // MARK: - Lecturas

    /// Movimientos vigentes, del más reciente al más antiguo.
    public var visibleMovements: [Movement] {
        movements.filter { !$0.isDeleted }.sorted { $0.date > $1.date }
    }

    /// No hay movimientos vigentes: el inicio muestra el estado vacío.
    public var isEmpty: Bool {
        !movements.contains { !$0.isDeleted }
    }

    /// Saldo de quien usa la app. `BalanceCalculator` ignora los eliminados.
    public var net: Int {
        BalanceCalculator.net(of: movements, for: session.me.id)
    }

    public var balance: BalanceState {
        BalanceState(net: net)
    }

    public var movementsSinceLastSettlement: Int {
        BalanceCalculator.movementsSinceLastSettlement(movements).count
    }

    /// Fecha del último pago para saldar vigente.
    public var lastSettlementDate: Date? {
        movements.filter { $0.kind == .settlement && !$0.isDeleted }.map(\.date).max()
    }

    /// Efecto de un movimiento en el saldo de quien usa la app.
    public func impact(of movement: Movement) -> Int {
        BalanceCalculator.impact(of: movement, for: session.me.id)
    }

    /// "Jesús te debe $20.000", "Le debes $20.000 a Jesús" o "Están a paz y salvo".
    public func phrase(forNet net: Int) -> String {
        let partner = session.partner.name
        switch BalanceState(net: net) {
        case .theyOweYou(let v): return "\(partner) te debe \(Money.format(v))"
        case .youOwe(let v): return "Le debes \(Money.format(v)) a \(partner)"
        case .settled: return "Están a paz y salvo"
        }
    }

    /// Un movimiento vigente por su `id`; `nil` si no existe o está eliminado.
    public func movement(_ id: UUID) -> Movement? {
        movements.first { $0.id == id && !$0.isDeleted }
    }

    // MARK: - Acciones

    public func load() async {
        do {
            movements = try await repository.loadMovements()
        } catch {
            isOffline = true
        }
    }

    /// Crea o reemplaza un movimiento. Si es nuevo, abre la hoja "Gasto guardado".
    public func save(_ movement: Movement) async {
        let isNew = self.movement(movement.id) == nil
        if let index = movements.firstIndex(where: { $0.id == movement.id }) {
            movements[index] = movement
        } else {
            movements.append(movement)
        }
        do {
            try await repository.save(movement)
        } catch {
            pendingSyncCount += 1
            isOffline = true
        }
        if isNew {
            lastSaved = movement
        }
    }

    /// Borrado suave: marca el movimiento con la fecha del borrado y lo conserva en la lista.
    public func delete(_ id: UUID) async {
        guard let index = movements.firstIndex(where: { $0.id == id }) else { return }
        movements[index].deletedAt = now()
        do {
            try await repository.delete(id: id)
        } catch {
            pendingSyncCount += 1
            isOffline = true
        }
    }

    /// Registra el pago que deja el saldo en $0. En $0 no hace nada.
    public func settle(paymentMethod: String?) async {
        guard
            let payment = BalanceCalculator.settlement(
                movements: movements,
                me: session.me.id,
                other: session.partner.id,
                createdBy: session.me.id,
                paymentMethod: paymentMethod
            )
        else { return }
        movements.append(payment)
        try? await repository.save(payment)
        lastSettlement = payment
    }

    /// Limpia lo pendiente y vuelve a cargar del repositorio.
    public func retrySync() async {
        isOffline = false
        pendingSyncCount = 0
        await load()
    }
}
