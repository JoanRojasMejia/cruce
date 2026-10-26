import Foundation
import Observation

/// Una persona con la que quien usa la app comparte un cruce y con quien tiene una deuda directa en un parche cerrado.
public struct ParcheCruceCandidate: Hashable, Sendable {
    public let other: ParcheParticipant
    /// Positivo: el otro te debe; negativo: tú le debes.
    public let amountYouAreOwed: Int

    public init(other: ParcheParticipant, amountYouAreOwed: Int) {
        self.other = other
        self.amountYouAreOwed = amountYouAreOwed
    }
}

/// Los parches de quien usa la app, sus frases y las acciones que los cambian.
/// Los gastos y pagos se anotan también sin conexión: lo que no se pudo enviar queda en una cola guardada en el
/// teléfono (`PendingStore`) y se reintenta con `retryPending()` o al volver a cargar. Los `id` los genera el
/// cliente, así que reintentar no duplica nada.
@MainActor
@Observable
public final class ParcheStore {
    /// Lo que salió mal en el último paso, con su mensaje para la pantalla.
    public enum Problem: Equatable, Sendable {
        case invalidParcheName
        case invalidPersonName
        case invalidCode
        case alreadyInParche
        case parcheClosed
        case parcheOpen
        case expense(ParcheExpenseError)
        case invalidPayment
        case notAllowed
        case noSharedCruce
        case alreadyMoved
        case nothingToMove
        case notFound
        case invalidData
        case network

        public var message: String {
            switch self {
            case .invalidParcheName: "El nombre del parche debe tener entre 1 y 60 caracteres."
            case .invalidPersonName: "El nombre debe tener entre 1 y 40 caracteres."
            case .invalidCode: "Ese código no existe"
            case .alreadyInParche: "Ya estás en este parche, así que no puedes quedarte con ese lugar."
            case .parcheClosed: "El parche está cerrado: ya no se pueden anotar ni editar gastos."
            case .parcheOpen: "Primero cierra el parche."
            case .expense(let error): error.message
            case .invalidPayment: "Revisa el pago: necesita un monto mayor que $0 y dos personas distintas."
            case .notAllowed: "Eso no lo puedes hacer en este parche."
            case .noSharedCruce: "No tienen un cruce juntos, así que la deuda se salda en el parche."
            case .alreadyMoved: "Esa deuda ya pasó a su cruce."
            case .nothingToMove: "No se deben nada entre ustedes."
            case .notFound: "Ese parche ya no está disponible."
            case .invalidData: "Algo no cuadra en los datos. Revísalos y vuelve a intentarlo."
            case .network: "No pudimos conectarnos. Revisa tu conexión y vuelve a intentarlo."
            }
        }
    }

    /// Ventana del aviso de posible duplicado.
    public static let duplicateWindow: TimeInterval = 3 * 3_600

    /// Los parches de quien usa la app: primero los abiertos y luego los más recientes.
    public private(set) var parches: [ParcheDetail]
    /// Lo que falta por enviar, en orden.
    public private(set) var pending: [ParchePendingOperation] = []
    public private(set) var isOffline = false
    /// El problema del último paso, o `nil` si salió bien.
    public private(set) var error: Problem?
    /// Hay una llamada en curso (para desactivar los botones).
    public private(set) var isWorking = false

    public var pendingSyncCount: Int { pending.count }

    /// Avisos sin ver en todos los parches.
    public var unseenTotal: Int { parches.map(\.unseenCount).reduce(0, +) }

    private let session: SessionStore
    private let repository: any ParcheRepository
    private let pendingStore: any PendingStore
    /// Reloj del aviso de duplicado y de las fechas locales; las pruebas inyectan uno fijo.
    private let now: () -> Date
    private var declinedCruce: Set<ParcheDeclinedCruce> = []
    private var hasLoadedLocalState = false
    private var isFlushing = false

    public init(
        session: SessionStore,
        repository: any ParcheRepository,
        pendingStore: any PendingStore = InMemoryPendingStore(),
        parches: [ParcheDetail] = [],
        now: @escaping () -> Date = { .now }
    ) {
        self.session = session
        self.repository = repository
        self.pendingStore = pendingStore
        self.parches = Self.sorted(parches)
        self.now = now
    }

    // MARK: - Lecturas

    public func parche(_ id: UUID) -> ParcheDetail? {
        parches.first { $0.id == id }
    }

    /// El tipo de código que se escribió en "Tengo un código".
    public static func codeKind(_ code: String) -> ParcheCode.Kind? {
        ParcheCode.kind(of: code)
    }

    /// "Abierto", "Parche cerrado" o "A paz y salvo".
    public func statusLabel(for detail: ParcheDetail) -> String {
        if detail.isSettled { return "A paz y salvo" }
        return detail.parche.isOpen ? "Abierto" : "Parche cerrado"
    }

    /// "Le deben $165.000", "Debe $110.000" o "A paz y salvo"; con "tú" para quien usa la app.
    public func balanceText(net: Int, for participantID: UUID, in detail: ParcheDetail) -> String {
        let isMe = participantID == detail.myParticipantID
        let amount = Money.format(abs(net))
        if net > 0 { return isMe ? "Te deben \(amount)" : "Le deben \(amount)" }
        if net < 0 { return isMe ? "Debes \(amount)" : "Debe \(amount)" }
        return isMe ? "Estás a paz y salvo" : "A paz y salvo"
    }

    /// "Ana le paga $45.000 a Jesús", "Ana te paga $45.000" o "Le pagas $45.000 a Jesús".
    public func phrase(for transfer: ParcheTransfer, in detail: ParcheDetail) -> String {
        let amount = Money.format(transfer.amount)
        let from = name(transfer.fromID, in: detail)
        let to = name(transfer.toID, in: detail)
        if transfer.fromID == detail.myParticipantID { return "Le pagas \(amount) a \(to)" }
        if transfer.toID == detail.myParticipantID { return "\(from) te paga \(amount)" }
        return "\(from) le paga \(amount) a \(to)"
    }

    /// Pagos que recibió quien usa la app y que esperan su confirmación.
    public func pendingConfirmations(in detail: ParcheDetail) -> [ParchePayment] {
        detail.pendingPayments.filter { $0.toID == detail.myParticipantID }
    }

    /// "Carlos te pagó $87.500, ¿confirmas?"
    public func confirmationPrompt(for payment: ParchePayment, in detail: ParcheDetail) -> String {
        "\(paymentPhrase(from: payment.fromID, to: payment.toID, amount: payment.amount, in: detail)), ¿confirmas?"
    }

    /// El aviso de la actividad desde la vista de quien usa la app ("Ana editó un gasto que anotaste").
    public func phrase(for activity: ParcheActivity, in detail: ParcheDetail) -> String {
        let me = detail.myParticipantID
        let isMe = activity.actorID != nil && activity.actorID == me
        let who = activity.actorID.map { name($0, in: detail) } ?? "Alguien"
        let expense = "un gasto: \(activity.concept ?? "sin concepto") (\(Money.format(activity.amount ?? 0)))"
        let payment = paymentPhrase(
            from: activity.participantID, to: activity.otherParticipantID, amount: activity.amount ?? 0, in: detail)
        let subject = activity.participantID.flatMap(detail.participant)?.label ?? "alguien"
        switch activity.kind {
        case .parcheCreated:
            return isMe ? "Creaste el parche" : "\(who) creó el parche"
        case .expenseCreated:
            return isMe ? "Anotaste \(expense)" : "\(who) anotó \(expense)"
        case .expenseEdited:
            if isMe { return "Editaste \(expense)" }
            return activity.recordedByID == me ? "\(who) editó un gasto que anotaste" : "\(who) editó \(expense)"
        case .expenseDeleted:
            if isMe { return "Borraste \(expense)" }
            return activity.recordedByID == me ? "\(who) borró un gasto que anotaste" : "\(who) borró \(expense)"
        case .paymentRecorded:
            return isMe ? "Anotaste: \(payment)" : "\(who) anotó: \(payment)"
        case .paymentConfirmed:
            return isMe ? "Confirmaste: \(payment)" : "\(who) confirmó: \(payment)"
        case .participantAdded:
            return isMe ? "Agregaste a \(subject)" : "\(who) agregó a \(subject)"
        case .participantJoined:
            return isMe ? "Te uniste al parche" : "\(who) se unió al parche"
        case .placeClaimed:
            return isMe ? "Te quedaste con tu lugar en el parche" : "\(who) ahora tiene la app"
        case .parcheClosed:
            return isMe ? "Cerraste el parche" : "\(who) cerró el parche"
        case .debtMovedToCruce:
            let ids = [activity.participantID, activity.otherParticipantID].compactMap { $0 }
            if let me, ids.contains(me), let other = ids.first(where: { $0 != me }) {
                let otherName = name(other, in: detail)
                return "Tu deuda con \(otherName) pasó a tu cruce con \(otherName)"
            }
            let names = ids.map { name($0, in: detail) }.joined(separator: " y ")
            return "La deuda entre \(names) pasó a su cruce"
        }
    }

    /// "Parece que Ana ya anotó este gasto" si hay un gasto vigente con el mismo monto y el mismo pagador principal
    /// anotado en las últimas 3 horas. Se puede guardar igual.
    public func duplicateWarning(for expense: ParcheExpense) -> String? {
        guard let detail = parche(expense.parcheID) else { return nil }
        let date = now()
        let match = detail.expenses.first { other in
            !other.isDeleted && other.id != expense.id && other.amount == expense.amount
                && other.mainPayerID == expense.mainPayerID
                && date.timeIntervalSince(other.createdAt) <= Self.duplicateWindow
        }
        guard let match else { return nil }
        if match.recordedBy == detail.myParticipantID { return "Parece que ya anotaste este gasto" }
        return "Parece que \(name(match.recordedBy, in: detail)) ya anotó este gasto"
    }

    /// Con quiénes se puede pasar la deuda al cruce: parche cerrado, comparten un cruce, tienen la app, se deben algo
    /// directamente, no la han pasado y no se respondió "No, se salda en el parche".
    public func cruceCandidates(in detail: ParcheDetail) -> [ParcheCruceCandidate] {
        guard !detail.parche.isOpen, let me = detail.myParticipantID else { return [] }
        return detail.participants.compactMap { other in
            guard
                other.id != me, other.hasApp, detail.crucePartnerIDs.contains(other.id),
                !detail.transfers.contains(where: { Set([$0.fromID, $0.toID]) == Set([me, other.id]) }),
                !declinedCruce.contains(ParcheDeclinedCruce(parcheID: detail.id, otherID: other.id))
            else { return nil }
            let owed = detail.directDebt(from: other.id, to: me)
            return owed == 0 ? nil : ParcheCruceCandidate(other: other, amountYouAreOwed: owed)
        }
    }

    /// "Joan te debe $64.000. ¿Lo pasas a tu cruce con Joan?"
    public func crucePrompt(for candidate: ParcheCruceCandidate) -> String {
        let other = candidate.other.displayName
        let amount = Money.format(abs(candidate.amountYouAreOwed))
        let debt = candidate.amountYouAreOwed > 0 ? "\(other) te debe \(amount)" : "Le debes \(amount) a \(other)"
        return "\(debt). ¿Lo pasas a tu cruce con \(other)?"
    }

    // MARK: - Cargar

    /// Lee la cola guardada, reintenta lo pendiente y carga los parches.
    public func load() async {
        await loadLocalStateIfNeeded()
        await flush()
        do {
            parches = Self.sorted(try await repository.loadParches().map(applyingPending))
            isOffline = false
        } catch {
            handle(error)
        }
    }

    /// Vuelve a leer un parche del repositorio, con lo pendiente aplicado encima.
    public func refresh(_ parcheID: UUID) async {
        do {
            upsert(applyingPending(try await repository.loadParche(id: parcheID)))
        } catch ParcheRepositoryError.notFound {
            parches.removeAll { $0.id == parcheID }
        } catch {
            handle(error)
        }
    }

    /// Abre un parche: lo recarga y marca su actividad como vista (el contador vuelve a cero).
    public func open(_ parcheID: UUID) async {
        await refresh(parcheID)
        guard let index = parches.firstIndex(where: { $0.id == parcheID }),
            let me = parches[index].myParticipantID,
            let participant = parches[index].participants.firstIndex(where: { $0.id == me })
        else { return }
        parches[index].participants[participant].lastSeenAt = now()
        try? await repository.markSeen(parcheID: parcheID)
    }

    // MARK: - Parches y personas

    /// Crea un parche con un nombre de 1 a 60 caracteres.
    @discardableResult
    public func createParche(name: String) async -> ParcheDetail? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...Parche.maxNameLength).contains(trimmed.count) else {
            error = .invalidParcheName
            return nil
        }
        return await perform {
            let detail = try await repository.createParche(id: UUID(), name: trimmed, displayName: session.me.name)
            upsert(detail)
            return detail
        }
    }

    /// Se une con un código `PCH-`. Si ya estaba, no se agrega otra vez.
    @discardableResult
    public func join(code: String) async -> ParcheDetail? {
        guard ParcheCode.kind(of: code) == .parche else {
            error = .invalidCode
            return nil
        }
        return await perform {
            let detail = try await repository.joinParche(code: ParcheCode.normalize(code), displayName: session.me.name)
            upsert(detail)
            return detail
        }
    }

    /// "Tengo un código": `PCH-` se une al parche y `SOY-` se queda con el lugar. Los `CRZ-` van al cruce
    /// (la pantalla los distingue con `codeKind(_:)`).
    @discardableResult
    public func enter(code: String) async -> ParcheDetail? {
        switch ParcheCode.kind(of: code) {
        case .parche:
            return await join(code: code)
        case .place:
            return await perform {
                let detail = try await repository.claimPlace(code: ParcheCode.normalize(code))
                upsert(detail)
                return detail
            }
        case .cruce, nil:
            error = .invalidCode
            return nil
        }
    }

    /// Agrega a alguien sin la app con un nombre de 1 a 40 caracteres; recibe su código `SOY-`.
    @discardableResult
    public func addParticipant(name: String, to parcheID: UUID) async -> ParcheParticipant? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...ParcheParticipant.maxNameLength).contains(trimmed.count) else {
            error = .invalidPersonName
            return nil
        }
        let participant = await perform {
            try await repository.addParticipant(id: UUID(), parcheID: parcheID, displayName: trimmed)
        }
        if participant != nil { await refresh(parcheID) }
        return participant
    }

    /// Cierra el parche después de confirmar. No se reabre.
    @discardableResult
    public func close(_ parcheID: UUID) async -> Bool {
        let ok = await perform { try await repository.closeParche(id: parcheID) } != nil
        await refresh(parcheID)
        return ok
    }

    /// Pasa al cruce lo que se deben directamente quien usa la app y `otherID`.
    @discardableResult
    public func moveDebtToCruce(in parcheID: UUID, with otherID: UUID) async -> Bool {
        let transfer = await perform {
            try await repository.moveDebtToCruce(parcheID: parcheID, otherParticipantID: otherID)
        }
        await refresh(parcheID)
        return transfer != nil
    }

    /// "No, se salda en el parche": no se vuelve a preguntar por ese par en este teléfono.
    public func declineCruce(in parcheID: UUID, with otherID: UUID) async {
        await loadLocalStateIfNeeded()
        declinedCruce.insert(ParcheDeclinedCruce(parcheID: parcheID, otherID: otherID))
        await persist()
    }

    // MARK: - Gastos

    /// Valida y resuelve un gasto (nuevo o, con `editing`, uno existente) sin guardarlo, para mostrar antes el aviso
    /// de duplicado. Si algo no cuadra deja el problema en `error` y devuelve `nil`.
    public func validateExpense(
        in parcheID: UUID, editing expenseID: UUID? = nil, concept: String, base: Int, tipPercent: Int = 0,
        split: ParcheSplit, payers: [ParchePayer], spentOn: Date? = nil
    ) -> ParcheExpense? {
        error = nil
        guard let detail = parche(parcheID), let me = detail.myParticipantID else {
            error = .notFound
            return nil
        }
        guard detail.parche.isOpen else {
            error = .parcheClosed
            return nil
        }
        let existing = expenseID.flatMap { id in detail.expenses.first { $0.id == id } }
        let date = now()
        do {
            var expense = try ParcheExpense.resolve(
                id: expenseID ?? UUID(), parcheID: parcheID, concept: concept, base: base, tipPercent: tipPercent,
                split: split, payers: payers, order: detail.order, recordedBy: existing?.recordedBy ?? me,
                at: existing?.createdAt ?? date, spentOn: spentOn ?? existing?.spentOn)
            if existing != nil {
                expense.updatedAt = date
                expense.updatedBy = me
            }
            return expense
        } catch {
            self.error = .expense(error)
            return nil
        }
    }

    /// Guarda un gasto ya validado (nuevo o editado). Sin conexión queda en la cola y se ve igual en el teléfono.
    public func save(_ expense: ParcheExpense) async {
        guard parche(expense.parcheID)?.parche.isOpen == true else {
            error = .parcheClosed
            return
        }
        await send(.saveExpense(expense))
    }

    /// Borrado suave: el gasto se queda marcado y deja de contar.
    public func deleteExpense(_ expenseID: UUID, in parcheID: UUID) async {
        await send(.deleteExpense(id: expenseID, parcheID: parcheID, at: now()))
    }

    // MARK: - Pagos

    /// Anota que `fromID` le pagó `amount` a `toID`. Cuenta de una vez si lo anota quien recibe o si quien recibe
    /// no tiene la app; si no, queda pendiente hasta que quien recibió lo confirme.
    @discardableResult
    public func recordPayment(in parcheID: UUID, from fromID: UUID, to toID: UUID, amount: Int) async -> ParchePayment?
    {
        error = nil
        guard let detail = parche(parcheID), let me = detail.myParticipantID else {
            error = .notFound
            return nil
        }
        guard amount > 0, fromID != toID, detail.participant(fromID) != nil, detail.participant(toID) != nil else {
            error = .invalidPayment
            return nil
        }
        let date = now()
        let confirms = ParcheCalculator.confirmsImmediately(
            recordedBy: me, toID: toID, participants: detail.participants)
        let payment = ParchePayment(
            parcheID: parcheID, fromID: fromID, toID: toID, amount: amount, recordedBy: me, createdAt: date,
            confirmedAt: confirms ? date : nil)
        await send(.recordPayment(payment))
        return payment
    }

    /// Confirma un pago que recibió quien usa la app.
    public func confirmPayment(_ paymentID: UUID, in parcheID: UUID) async {
        await send(.confirmPayment(id: paymentID, parcheID: parcheID, at: now()))
    }

    // MARK: - Cola sin conexión

    /// Reintenta lo pendiente, en orden. Para en el primer error de conexión.
    public func retryPending() async {
        await loadLocalStateIfNeeded()
        await flush()
    }

    /// Aplica la operación en el teléfono, la guarda en la cola y trata de enviarla.
    private func send(_ operation: ParchePendingOperation) async {
        error = nil
        await loadLocalStateIfNeeded()
        if let index = parches.firstIndex(where: { $0.id == operation.parcheID }) {
            Self.apply(operation, to: &parches[index])
        }
        enqueue(operation)
        await persist()
        await flush()
    }

    /// Una edición de un gasto que todavía no se envió reemplaza a la anterior en su mismo lugar de la cola.
    private func enqueue(_ operation: ParchePendingOperation) {
        if case .saveExpense(let expense) = operation,
            let index = pending.firstIndex(where: {
                if case .saveExpense(let queued) = $0 { return queued.id == expense.id }
                return false
            })
        {
            pending[index] = operation
        } else {
            pending.append(operation)
        }
    }

    private func flush() async {
        guard !isFlushing else { return }
        isFlushing = true
        defer { isFlushing = false }
        var touched: [UUID] = []
        while let operation = pending.first {
            do {
                try await perform(operation)
                isOffline = false
            } catch  where Self.isConnectivity(error) {
                isOffline = true
                break
            } catch {
                // No es de conexión: reintentarla no sirve. Se descarta y se muestra el problema.
                self.error = Self.problem(for: error)
            }
            // Si mientras se enviaba la reemplazó una edición, la edición se queda en la cola.
            if let index = pending.firstIndex(of: operation) { pending.remove(at: index) }
            if !touched.contains(operation.parcheID) { touched.append(operation.parcheID) }
            await persist()
        }
        for parcheID in touched {
            await refresh(parcheID)
        }
    }

    private func perform(_ operation: ParchePendingOperation) async throws {
        switch operation {
        case .saveExpense(let expense): try await repository.saveExpense(expense)
        case .deleteExpense(let id, let parcheID, let date):
            try await repository.deleteExpense(id: id, parcheID: parcheID, at: date)
        case .recordPayment(let payment): try await repository.recordPayment(payment)
        case .confirmPayment(let id, let parcheID, _): try await repository.confirmPayment(id: id, parcheID: parcheID)
        }
    }

    private func loadLocalStateIfNeeded() async {
        guard !hasLoadedLocalState else { return }
        hasLoadedLocalState = true
        guard let state = try? await pendingStore.load() else { return }
        // Lo que se anotó antes de leer el archivo va después de lo guardado.
        pending = state.pending + pending
        declinedCruce.formUnion(state.declinedCruce)
    }

    private func persist() async {
        try? await pendingStore.save(ParcheLocalState(pending: pending, declinedCruce: declinedCruce))
    }

    private func applyingPending(_ detail: ParcheDetail) -> ParcheDetail {
        var detail = detail
        for operation in pending where operation.parcheID == detail.id {
            Self.apply(operation, to: &detail)
        }
        return detail
    }

    /// El efecto de una operación pendiente en lo que se ve en el teléfono.
    private static func apply(_ operation: ParchePendingOperation, to detail: inout ParcheDetail) {
        switch operation {
        case .saveExpense(let expense):
            if let index = detail.expenses.firstIndex(where: { $0.id == expense.id }) {
                detail.expenses[index] = expense
            } else {
                detail.expenses.append(expense)
            }
        case .deleteExpense(let id, _, let date):
            if let index = detail.expenses.firstIndex(where: { $0.id == id }), !detail.expenses[index].isDeleted {
                detail.expenses[index].deletedAt = date
                detail.expenses[index].deletedBy = detail.myParticipantID
            }
        case .recordPayment(let payment):
            if !detail.payments.contains(where: { $0.id == payment.id }) { detail.payments.append(payment) }
        case .confirmPayment(let id, _, let date):
            if let index = detail.payments.firstIndex(where: { $0.id == id }), !detail.payments[index].isConfirmed {
                detail.payments[index].confirmedAt = date
            }
        }
    }

    // MARK: - Ayudas

    /// Corre una llamada que necesita conexión (no va a la cola), con `isWorking`, y traduce su error.
    private func perform<T>(_ work: () async throws -> T) async -> T? {
        isWorking = true
        error = nil
        defer { isWorking = false }
        do {
            let value = try await work()
            isOffline = false
            return value
        } catch {
            handle(error)
            return nil
        }
    }

    private func handle(_ error: any Error) {
        // Una tarea cancelada (otra carga la reemplazó) no es un problema que mostrar.
        if error is CancellationError { return }
        if Self.isConnectivity(error) { isOffline = true }
        self.error = Self.problem(for: error)
    }

    private func upsert(_ detail: ParcheDetail) {
        if let index = parches.firstIndex(where: { $0.id == detail.id }) {
            parches[index] = detail
        } else {
            parches.append(detail)
        }
        parches = Self.sorted(parches)
    }

    private func name(_ id: UUID, in detail: ParcheDetail) -> String {
        detail.participant(id)?.displayName ?? "Alguien"
    }

    /// "Carlos te pagó $87.500", "Le pagaste $87.500 a Jesús" o "Carlos le pagó $87.500 a Jesús".
    private func paymentPhrase(from: UUID?, to: UUID?, amount: Int, in detail: ParcheDetail) -> String {
        let value = Money.format(amount)
        let fromName = from.map { name($0, in: detail) } ?? "Alguien"
        let toName = to.map { name($0, in: detail) } ?? "alguien"
        if from != nil && from == detail.myParticipantID { return "Le pagaste \(value) a \(toName)" }
        if to != nil && to == detail.myParticipantID { return "\(fromName) te pagó \(value)" }
        return "\(fromName) le pagó \(value) a \(toName)"
    }

    private static func sorted(_ parches: [ParcheDetail]) -> [ParcheDetail] {
        parches.sorted { lhs, rhs in
            lhs.parche.isOpen != rhs.parche.isOpen ? lhs.parche.isOpen : lhs.parche.createdAt > rhs.parche.createdAt
        }
    }

    private static func isConnectivity(_ error: any Error) -> Bool {
        (error as? ParcheRepositoryError) == .offline || error is URLError
    }

    private static func problem(for error: any Error) -> Problem {
        guard let error = error as? ParcheRepositoryError else { return .network }
        switch error {
        case .offline: return .network
        case .invalidCode: return .invalidCode
        case .alreadyParticipant: return .alreadyInParche
        case .notFound: return .notFound
        case .notAllowed: return .notAllowed
        case .parcheClosed: return .parcheClosed
        case .parcheOpen: return .parcheOpen
        case .invalidData: return .invalidData
        case .noSharedCruce: return .noSharedCruce
        case .alreadyMoved: return .alreadyMoved
        case .nothingToMove: return .nothingToMove
        }
    }
}
