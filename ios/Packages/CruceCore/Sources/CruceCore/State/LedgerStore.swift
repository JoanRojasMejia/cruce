import Foundation
import Observation

/// Movimientos de cada cruce, el saldo y las acciones que los cambian.
/// Sin conexión (CP7): cada cambio se aplica en pantalla, entra a una cola (`pending`) y se guarda en el teléfono
/// (`LedgerLocalStore`); la cola se envía en orden apenas hay red, sin perder ni duplicar nada.
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
    /// Cuántos cambios faltan por enviar (el largo de `pending`; las vistas previas lo fijan a mano).
    public var pendingSyncCount = 0
    /// Cambios que todavía no llegaron a la base, en el orden en que se hicieron.
    public private(set) var pending: [LedgerPendingOperation] = []
    /// Hay red según el sistema (`networkChanged`). Sin red, `isOffline` queda en verdadero.
    private var networkAvailable = true
    /// De quién ya se trajo lo guardado en el teléfono (`restore()` corre una vez por persona).
    private var restoredUser: UUID?

    private let session: SessionStore
    private let repository: LedgerRepository
    /// Cambios de la otra persona en tiempo real (`follow()`); `nil` en las vistas previas.
    private let feed: (any MovementFeed)?
    /// Dónde se guarda lo del cruce en el teléfono; `nil` en las vistas previas.
    private let localStore: (any LedgerLocalStore)?
    /// Reloj del borrado; las pruebas inyectan una fecha fija.
    private let now: () -> Date

    public init(
        session: SessionStore,
        repository: LedgerRepository,
        movements: [Movement] = [],
        movementsByCruce: [UUID: [Movement]] = [:],
        feed: (any MovementFeed)? = nil,
        localStore: (any LedgerLocalStore)? = nil,
        now: @escaping () -> Date = { .now }
    ) {
        self.session = session
        self.repository = repository
        self.feed = feed
        self.localStore = localStore
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

    /// Envía lo pendiente y después carga los movimientos de todos los cruces de la sesión. Lo que siga pendiente se
    /// vuelve a aplicar encima, para que no desaparezca. Si no se puede cargar, se queda lo que había.
    public func load() async {
        await flush()
        // Sin sesión o sin cruces no hay nada que cargar, y no se pisa lo guardado en el teléfono.
        guard !session.cruces.isEmpty else { return }
        do {
            var loaded: [UUID: [Movement]] = [:]
            for cruce in session.cruces {
                loaded[cruce.id] = try await repository.loadMovements(in: cruce.id)
            }
            movementsByCruce = loaded
            for operation in pending { applyLocally(operation) }
            if pending.isEmpty { isOffline = !networkAvailable }
        } catch {
            isOffline = true
        }
        await persist()
    }

    /// Crea o reemplaza un movimiento del cruce abierto. Si es nuevo, abre la hoja "Gasto guardado".
    /// Sin cruce abierto, o con el cruce cerrado (solo lectura), no hace nada.
    public func save(_ movement: Movement) async {
        guard let cruce = session.openCruceID, !session.isOpenCruceClosed else { return }
        let isNew = self.movement(movement.id) == nil
        if isNew {
            lastSaved = movement
        }
        await enqueue(.save(movement, cruce: cruce))
    }

    /// Borrado suave: marca el movimiento con la fecha del borrado y lo conserva en la lista.
    public func delete(_ id: UUID) async {
        guard let cruce = session.openCruceID, !session.isOpenCruceClosed,
            movementsByCruce[cruce]?.contains(where: { $0.id == id }) == true
        else { return }
        await enqueue(.delete(id: id, cruce: cruce, at: now()))
    }

    /// Registra el pago de quien debe en el cruce abierto: sin `amount`, el total (el saldo queda en $0); con `amount`,
    /// un pago parcial de $1 hasta el total. En $0, con un monto fuera de rango o en un cruce cerrado no hace nada.
    public func settle(paymentMethod: String?, amount: Int? = nil) async {
        guard let cruce = session.openCruceID, !session.isOpenCruceClosed,
            let payment = BalanceCalculator.settlement(
                movements: movements,
                me: session.me.id,
                other: session.partner.id,
                createdBy: session.me.id,
                paymentMethod: paymentMethod,
                amount: amount
            )
        else { return }
        lastSettlement = payment
        await enqueue(.save(payment, cruce: cruce))
    }

    /// Envía lo pendiente y vuelve a cargar (botón "Reintentar").
    public func retrySync() async {
        await load()
    }

    // MARK: - Sin conexión

    /// Al arrancar: trae lo guardado en el teléfono si es de quien tiene la sesión (para abrir sin red). Lo de otra
    /// persona se borra.
    public func restore() async {
        guard let localStore, restoredUser == nil || restoredUser != session.userID,
            let state = try? await localStore.load()
        else { return }
        restoredUser = session.userID
        guard let user = session.userID, state.userID == user else {
            if state.userID != nil { try? await localStore.save(LedgerLocalState()) }
            return
        }
        movementsByCruce = state.movementsByCruce
        pending = state.pending
        pendingSyncCount = pending.count
        if !pending.isEmpty { isOffline = true }
    }

    /// El sistema avisa si hay red. Sin red, la app queda sin conexión; al volver, envía lo pendiente y recarga.
    public func networkChanged(isAvailable: Bool) async {
        networkAvailable = isAvailable
        if isAvailable {
            await load()
        } else {
            isOffline = true
        }
    }

    /// Cerrar sesión: vacía los movimientos, la cola y lo guardado en el teléfono.
    public func reset() async {
        movementsByCruce = [:]
        pending = []
        pendingSyncCount = 0
        isOffline = false
        lastSaved = nil
        lastSettlement = nil
        restoredUser = nil
        try? await localStore?.save(LedgerLocalState())
    }

    /// Aplica el cambio en pantalla, lo agrega a la cola, lo guarda en el teléfono e intenta enviarlo.
    private func enqueue(_ operation: LedgerPendingOperation) async {
        applyLocally(operation)
        pending.append(operation)
        pendingSyncCount = pending.count
        await persist()
        let rejected = await flush()
        if rejected { await load() }
    }

    /// Envía la cola en orden. Lo que llega sale de la cola; lo que la base rechaza también sale (reintentarlo no
    /// sirve) y devuelve `true` para recargar. La primera falla de red detiene el envío y deja la app sin conexión.
    @discardableResult
    private func flush() async -> Bool {
        var rejected = false
        while let operation = pending.first {
            do {
                switch operation {
                case .save(let movement, let cruce): try await repository.save(movement, in: cruce)
                case .delete(let id, let cruce, _): try await repository.delete(id: id, in: cruce)
                }
                pending.removeFirst()
            } catch LedgerRepositoryError.rejected {
                pending.removeFirst()
                rejected = true
            } catch {
                isOffline = true
                break
            }
        }
        pendingSyncCount = pending.count
        if pending.isEmpty { isOffline = !networkAvailable }
        await persist()
        return rejected
    }

    /// El efecto de una operación sobre los movimientos en pantalla.
    private func applyLocally(_ operation: LedgerPendingOperation) {
        switch operation {
        case .save(let movement, let cruce):
            apply(MovementChange(cruce: cruce, movement: movement))
        case .delete(let id, let cruce, let at):
            if let index = movementsByCruce[cruce]?.firstIndex(where: { $0.id == id }) {
                movementsByCruce[cruce]?[index].deletedAt = at
            }
        }
    }

    /// Guarda en el teléfono los movimientos y la cola, de quien tiene la sesión.
    private func persist() async {
        guard let localStore, session.userID != nil else { return }
        try? await localStore.save(
            LedgerLocalState(userID: session.userID, movementsByCruce: movementsByCruce, pending: pending))
    }

    // MARK: - Tiempo real

    /// Aplica un cambio que llegó de la base: reemplaza el movimiento con ese `id` en su cruce o lo agrega.
    /// El eco de lo que uno mismo guardó no duplica nada y no abre "Gasto guardado".
    public func apply(_ change: MovementChange) {
        var list = movementsByCruce[change.cruce, default: []]
        if let index = list.firstIndex(where: { $0.id == change.movement.id }) {
            list[index] = change.movement
        } else {
            list.append(change.movement)
        }
        movementsByCruce[change.cruce] = list
    }

    /// Aplica los cambios de los cruces de la sesión mientras la tarea siga viva. `MainView` la cancela y la vuelve a
    /// abrir al cambiar los cruces o al volver a la app.
    public func follow() async {
        guard let feed, !session.cruces.isEmpty else { return }
        for await change in feed.changes(in: session.cruces.map(\.id)) {
            apply(change)
        }
    }

}
