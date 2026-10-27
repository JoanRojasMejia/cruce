import Foundation
import Observation

/// Movimientos de cada cruce, el saldo y las acciones que los cambian.
/// Las lecturas y las acciones son del cruce abierto (`SessionStore.openCruceID`); `net(of:)` da el saldo de cualquiera.
/// Guarda todos los movimientos, incluidos los eliminados; las lecturas visibles solo muestran los vigentes.
@MainActor
@Observable
public final class LedgerStore {
    /// Los movimientos de cada cruce (por el id del cruce), también los eliminados (borrado suave).
    public private(set) var movementsByCruce: [UUID: [Movement]] = [:]
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
        movementsByCruce: [UUID: [Movement]] = [:],
        now: @escaping () -> Date = { .now }
    ) {
        self.session = session
        self.repository = repository
        self.now = now
        // Para las vistas previas y las pruebas sin `load()`: `movements` son los del cruce abierto y
        // `movementsByCruce`, los de los demás.
        self.movementsByCruce = movementsByCruce
        if let open = session.openCruceID, !movements.isEmpty || movementsByCruce[open] == nil {
            self.movementsByCruce[open] = movements
        }
    }

    // MARK: - Lecturas

    /// Todos los movimientos del cruce abierto, también los eliminados (borrado suave).
    public var movements: [Movement] {
        session.openCruceID.flatMap { movementsByCruce[$0] } ?? []
    }

    /// Saldo de quien usa la app en ese cruce (para "Tus cruces").
    public func net(of cruce: UUID) -> Int {
        BalanceCalculator.net(of: movementsByCruce[cruce] ?? [], for: session.me.id)
    }

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

    /// "Jesús te debe $20.000", "Le debes $20.000 a Jesús" o "Están a paz y salvo", con la otra persona del cruce
    /// abierto.
    public func phrase(forNet net: Int) -> String {
        phrase(forNet: net, partner: session.partner)
    }

    /// La misma frase con la otra persona de cualquier cruce.
    public func phrase(forNet net: Int, partner: Member) -> String {
        switch BalanceState(net: net) {
        case .theyOweYou(let v): return "\(partner.name) te debe \(Money.format(v))"
        case .youOwe(let v): return "Le debes \(Money.format(v)) a \(partner.name)"
        case .settled: return "Están a paz y salvo"
        }
    }

    /// Un movimiento vigente por su `id`; `nil` si no existe o está eliminado.
    public func movement(_ id: UUID) -> Movement? {
        movements.first { $0.id == id && !$0.isDeleted }
    }

    // MARK: - Acciones

    /// Carga los movimientos de todos los cruces de la sesión.
    public func load() async {
        do {
            var loaded: [UUID: [Movement]] = [:]
            for cruce in session.cruces {
                loaded[cruce.id] = try await repository.loadMovements(in: cruce.id)
            }
            movementsByCruce = loaded
        } catch {
            isOffline = true
        }
    }

    /// Crea o reemplaza un movimiento del cruce abierto. Si es nuevo, abre la hoja "Gasto guardado".
    /// Sin cruce abierto no hace nada.
    public func save(_ movement: Movement) async {
        guard let cruce = session.openCruceID else { return }
        let isNew = self.movement(movement.id) == nil
        if let index = movementsByCruce[cruce, default: []].firstIndex(where: { $0.id == movement.id }) {
            movementsByCruce[cruce]?[index] = movement
        } else {
            movementsByCruce[cruce, default: []].append(movement)
        }
        do {
            try await repository.save(movement, in: cruce)
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
        guard let cruce = session.openCruceID,
            let index = movementsByCruce[cruce]?.firstIndex(where: { $0.id == id })
        else { return }
        movementsByCruce[cruce]?[index].deletedAt = now()
        do {
            try await repository.delete(id: id, in: cruce)
        } catch {
            pendingSyncCount += 1
            isOffline = true
        }
    }

    /// Registra el pago que deja el saldo del cruce abierto en $0. En $0 no hace nada.
    public func settle(paymentMethod: String?) async {
        guard let cruce = session.openCruceID,
            let payment = BalanceCalculator.settlement(
                movements: movements,
                me: session.me.id,
                other: session.partner.id,
                createdBy: session.me.id,
                paymentMethod: paymentMethod
            )
        else { return }
        movementsByCruce[cruce, default: []].append(payment)
        try? await repository.save(payment, in: cruce)
        lastSettlement = payment
    }

    /// Limpia lo pendiente y vuelve a cargar del repositorio.
    public func retrySync() async {
        isOffline = false
        pendingSyncCount = 0
        await load()
    }
}
