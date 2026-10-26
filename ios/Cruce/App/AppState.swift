import SwiftUI
import CruceCore

/// Pantallas que se apilan dentro del flujo principal.
enum Route: Hashable {
    case addMovement
    case editMovement(UUID)
    case history
    case detail(UUID)
    case settle
    case settings
    case offline
}

/// Estado global de la app. Las pantallas leen de aquí y llaman sus acciones.
@MainActor
@Observable
final class AppState {
    /// Etapas del flujo de entrada.
    enum Phase: Equatable {
        case onboarding
        case signUp
        case invite
        case join
        case connected
        case main
    }

    var phase: Phase
    var me: Member
    var partner: Member
    private(set) var movements: [Movement] = []

    /// Navegación del flujo principal.
    var path: [Route] = []
    /// Último movimiento guardado; muestra la hoja "Gasto guardado" en el inicio.
    var lastSaved: Movement?
    /// Pago recién registrado; muestra la pantalla "A paz y salvo".
    var lastSettlement: Movement?

    var isOffline = false
    var pendingSyncCount = 0

    private let repository: LedgerRepository

    init(phase: Phase, me: Member, partner: Member, repository: LedgerRepository) {
        self.phase = phase
        self.me = me
        self.partner = partner
        self.repository = repository
    }

    // MARK: - Lecturas

    var sortedMovements: [Movement] {
        movements.sorted { $0.date > $1.date }
    }

    var net: Int {
        BalanceCalculator.net(of: movements, for: me.id)
    }

    var balance: BalanceState {
        BalanceState(net: net)
    }

    var movementsSinceLastSettlement: Int {
        BalanceCalculator.movementsSinceLastSettlement(movements).count
    }

    var lastSettlementDate: Date? {
        movements.filter { $0.kind == .settlement }.map(\.date).max()
    }

    func impact(of movement: Movement) -> Int {
        BalanceCalculator.impact(of: movement, for: me.id)
    }

    /// "Jesús te debe $20.000", "Le debes $20.000 a Jesús" o "Están a paz y salvo".
    func phrase(forNet net: Int) -> String {
        switch BalanceState(net: net) {
        case .theyOweYou(let v): return "\(partner.name) te debe \(Money.format(v))"
        case .youOwe(let v): return "Le debes \(Money.format(v)) a \(partner.name)"
        case .settled: return "Están a paz y salvo"
        }
    }

    func member(_ id: UUID) -> Member {
        id == me.id ? me : partner
    }

    func movement(_ id: UUID) -> Movement? {
        movements.first { $0.id == id }
    }

    /// Ilustración del saldo según el estado y la variante de quien usa la app.
    var balanceIllustration: Illustration {
        switch balance {
        case .theyOweYou: return .theyOweYou(me.tikeVariant)
        case .youOwe: return .youOwe(me.tikeVariant)
        case .settled: return .allClear
        }
    }

    // MARK: - Acciones

    func load() async {
        do {
            movements = try await repository.loadMovements()
        } catch {
            isOffline = true
        }
    }

    func save(_ movement: Movement) async {
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

    func delete(_ id: UUID) async {
        movements.removeAll { $0.id == id }
        do {
            try await repository.delete(id: id)
        } catch {
            pendingSyncCount += 1
            isOffline = true
        }
    }

    /// Registra el pago que deja el saldo en $0.
    func settle(paymentMethod: String?) async {
        guard let payment = BalanceCalculator.settlement(
            movements: movements,
            me: me.id,
            other: partner.id,
            createdBy: me.id,
            paymentMethod: paymentMethod
        ) else { return }
        movements.append(payment)
        try? await repository.save(payment)
        lastSettlement = payment
    }

    func retrySync() async {
        isOffline = false
        pendingSyncCount = 0
        await load()
    }

    func signOut() {
        path = []
        phase = .onboarding
    }
}

extension AppState {
    /// Estado con los datos de ejemplo del canvas, visto por Joan.
    static func preview(phase: Phase = .main, viewer: Member = MockData.joan, movements: [Movement] = MockData.movements()) -> AppState {
        let other = viewer.id == MockData.joan.id ? MockData.jesus : MockData.joan
        let state = AppState(
            phase: phase,
            me: viewer,
            partner: other,
            repository: InMemoryLedgerRepository(movements: movements)
        )
        state.movements = movements
        return state
    }
}
