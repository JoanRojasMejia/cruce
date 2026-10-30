import Foundation

/// Lo que el backend de parches puede responder además de los datos.
public enum ParcheRepositoryError: Error, Equatable, Sendable {
    /// Sin conexión: `ParcheStore` guarda la operación y la reintenta.
    case offline
    /// El código `PCH-` o `SOY-` no existe (o ya se usó).
    case invalidCode
    /// Quien quiere quedarse con un lugar ya es participante de ese parche.
    case alreadyParticipant
    /// No existe o quien usa la app no es del parche (RLS: no lo ve).
    case notFound
    /// La acción no le corresponde a quien usa la app (por ejemplo, confirmar un pago que no recibió).
    case notAllowed
    /// El parche está cerrado: no acepta gastos nuevos ni ediciones.
    case parcheClosed
    /// La acción necesita el parche cerrado (proponer pasar la deuda al cruce).
    case parcheOpen
    /// Datos que no cumplen las reglas (sumas, nombres, montos).
    case invalidData
    /// Los dos no comparten un cruce abierto.
    case noSharedCruce
    /// La deuda de ese par ya pasó al cruce.
    case alreadyMoved
    /// En el plan "Para saldar" no hay una transferencia entre los dos (o cambió antes de aceptarla).
    case nothingToMove
}

/// Acceso a los parches de quien tiene la sesión abierta. Cada operación corresponde a una consulta o función
/// de la base (`create_parche`, `join_parche`, `claim_parche_place`, `close_parche`, `confirm_parche_payment`,
/// `propose_parche_debt_to_cruce`, `accept_parche_cruce_transfer`, `reject_parche_cruce_transfer`, `mark_parche_seen`). Hoy lo implementa `InMemoryParcheRepository`; en la app,
/// `SupabaseParcheRepository`. Los `id` de gastos y pagos los genera el cliente: guardar dos veces es idempotente.
/// Sin conexión, las implementaciones lanzan `ParcheRepositoryError.offline` (o un `URLError`).
public protocol ParcheRepository: Sendable {
    /// Los parches de quien usa la app, con todo su detalle.
    func loadParches() async throws -> [ParcheDetail]
    func loadParche(id: UUID) async throws -> ParcheDetail
    /// La actividad de un parche (también viene en el detalle).
    func loadActivity(parcheID: UUID) async throws -> [ParcheActivity]

    /// Crea el parche abierto, con su código `PCH-` y quien lo crea como único participante.
    func createParche(id: UUID, name: String, displayName: String) async throws -> ParcheDetail
    /// Se une con el código `PCH-`. Si ya es participante no se agrega otra vez.
    func joinParche(code: String, displayName: String) async throws -> ParcheDetail
    /// Agrega a alguien sin la app; la base le genera su código `SOY-`.
    func addParticipant(id: UUID, parcheID: UUID, displayName: String) async throws -> ParcheParticipant
    /// Se queda con el lugar del código `SOY-`; el código deja de servir.
    func claimPlace(code: String) async throws -> ParcheDetail
    /// A qué parche o a qué lugar lleva un código `PCH-` o `SOY-`, sin entrar (`preview_parche_code`). Los códigos que
    /// no sirven cuentan como intento fallido (5 por hora, junto con los `CRZ-`).
    func previewCode(_ code: String) async throws -> CodePreview

    /// Crea o reemplaza el gasto con ese `id` (`upsert`). Solo con el parche abierto.
    func saveExpense(_ expense: ParcheExpense) async throws
    /// Borrado suave. Borrar uno ya borrado no hace nada.
    func deleteExpense(id: UUID, parcheID: UUID, at date: Date) async throws
    /// Anota el pago (`upsert` por `id`). La base decide si cuenta de una vez o queda pendiente.
    func recordPayment(_ payment: ParchePayment) async throws
    /// Confirma un pago pendiente; solo quien lo recibió.
    func confirmPayment(id: UUID, parcheID: UUID) async throws

    /// Cierra el parche; no se reabre.
    func closeParche(id: UUID) async throws
    /// Propone pasar a su cruce la transferencia del plan "Para saldar" entre quien usa la app y
    /// `otherParticipantID`. Queda por confirmar; si ya hay una por confirmar para el par, devuelve esa.
    func proposeCruceTransfer(parcheID: UUID, otherParticipantID: UUID) async throws -> ParcheCruceTransfer
    /// La otra persona (no quien la propuso) la acepta: se crea el movimiento en el cruce y en el parche cuenta
    /// como un pago. Aceptar una ya aceptada no hace nada.
    func acceptCruceTransfer(id: UUID, parcheID: UUID) async throws -> ParcheCruceTransfer
    /// La otra persona no la acepta: la deuda sigue en el parche.
    func rejectCruceTransfer(id: UUID, parcheID: UUID) async throws -> ParcheCruceTransfer
    /// Marca la actividad como vista (`last_seen_at`).
    func markSeen(parcheID: UUID) async throws
}

/// Un "backend" en memoria con varias personas, para pruebas, vistas previas y Debug.
/// Aplica las mismas reglas que la base: RLS, parche abierto o cerrado, sumas y actividad.
public actor InMemoryParcheBackend {
    private var details: [UUID: ParcheDetail]
    /// Pares de usuarios que comparten un cruce.
    private var cruces: Set<Set<UUID>>
    /// El color del perfil de cada usuario (`profiles.avatar_color`); amarillo si no está.
    private var colors: [UUID: AvatarColor]
    private var isOffline = false
    private var dropsResponses = false
    private let now: @Sendable () -> Date
    /// Los códigos `SOY-` ya usados y quién se quedó con cada lugar (`parche_participants.claimed_code`).
    private var claimedCodes: [String: UUID] = [:]
    /// Intentos fallidos de cada usuario al ver un código (`invite_attempts`).
    private var failedAttempts: [UUID: [Date]] = [:]

    /// `parches` se guardan sin `myParticipantID` ni `crucePartnerIDs`, que dependen de quién pregunta.
    /// `colors` es el color del perfil de cada usuario: quien entra con la app toma ese color.
    public init(
        parches: [ParcheDetail] = [], cruces: [Set<UUID>] = [], colors: [UUID: AvatarColor] = [:],
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        details = Dictionary(uniqueKeysWithValues: parches.map { ($0.id, $0) })
        self.cruces = Set(cruces)
        self.colors = colors
        self.now = now
    }

    /// Alguien cambia su color en Tu perfil: como en la base, sus lugares en los parches cambian con él.
    public func setColor(_ color: AvatarColor, for user: UUID) {
        colors[user] = color
        for (id, var detail) in details {
            for index in detail.participants.indices where detail.participants[index].userID == user {
                detail.participants[index].avatarColor = color
            }
            details[id] = detail
        }
    }

    private func color(of user: UUID) -> AvatarColor {
        colors[user] ?? .yellow
    }

    /// Simula que se va (o vuelve) la conexión: todo lanza `.offline`.
    public func setOffline(_ offline: Bool) {
        isOffline = offline
    }

    /// Simula que la operación llega pero la respuesta se pierde: se aplica y luego lanza `.offline`.
    public func setDropsResponses(_ drops: Bool) {
        dropsResponses = drops
    }

    public func addCruce(_ a: UUID, _ b: UUID) {
        cruces.insert([a, b])
    }

    // MARK: - Lecturas

    func loadParches(user: UUID) throws -> [ParcheDetail] {
        try checkConnection()
        return details.values.filter { member(user, of: $0) != nil }.map { view($0, for: user) }
    }

    func loadParche(id: UUID, user: UUID) throws -> ParcheDetail {
        try checkConnection()
        return view(try record(id, user: user).detail, for: user)
    }

    // MARK: - Parches y personas

    func createParche(id: UUID, name: String, displayName: String, user: UUID) throws -> ParcheDetail {
        try checkConnection()
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...Parche.maxNameLength).contains(name.count) else { throw ParcheRepositoryError.invalidData }
        let date = now()
        let creator = ParcheParticipant(
            userID: user, displayName: displayName, joinedAt: date, lastSeenAt: date, avatarColor: color(of: user))
        var detail = ParcheDetail(
            parche: Parche(id: id, name: name, code: uniqueCode(.parche), createdAt: date, createdBy: creator.id),
            participants: [creator])
        detail.activity.append(ParcheActivity(parcheID: id, kind: .parcheCreated, actorID: creator.id, createdAt: date))
        details[id] = detail
        return try respond(view(detail, for: user))
    }

    func joinParche(code: String, displayName: String, user: UUID) throws -> ParcheDetail {
        try checkConnection()
        let code = ParcheCode.normalize(code)
        guard var detail = details.values.first(where: { $0.parche.code == code }) else {
            throw ParcheRepositoryError.invalidCode
        }
        if member(user, of: detail) == nil {
            let date = now()
            let participant = ParcheParticipant(
                userID: user, displayName: displayName, joinedAt: date, lastSeenAt: date, avatarColor: color(of: user))
            detail.participants.append(participant)
            detail.activity.append(
                ParcheActivity(
                    parcheID: detail.id, kind: .participantJoined, actorID: participant.id,
                    participantID: participant.id, createdAt: date))
            details[detail.id] = detail
        }
        return try respond(view(detail, for: user))
    }

    /// Las mismas reglas que `preview_parche_code` en la base.
    func previewCode(_ code: String, user: UUID) throws -> CodePreview {
        try checkConnection()
        let date = now()
        if failedAttempts[user, default: []].filter({ $0 > date - 60 * 60 }).count >= 5 {
            return .rejected(.tooManyAttempts, message: CodeRejection.tooManyAttempts.defaultMessage)
        }
        let code = ParcheCode.normalize(code)
        let rejection: CodeRejection
        if let detail = details.values.first(where: { $0.parche.code == code }) {
            return .parche(name: detail.parche.name, alreadyMember: member(user, of: detail) != nil)
        } else if let detail = details.values.first(where: { $0.participants.contains { $0.claimCode == code } }),
            let place = detail.participants.first(where: { $0.claimCode == code })
        {
            guard member(user, of: detail) == nil else {
                return .rejected(
                    .alreadyParticipant,
                    message: "Ya estás en \(detail.parche.name), así que no puedes quedarte con ese lugar.")
            }
            return .place(parcheName: detail.parche.name, personName: place.displayName)
        } else if let owner = claimedCodes[code] {
            rejection = owner == user ? .own : .used
        } else {
            rejection = .invalid
        }
        failedAttempts[user, default: []].append(date)
        return .rejected(rejection, message: rejection == .own ? "Ese lugar ya es tuyo." : rejection.defaultMessage)
    }

    func addParticipant(id: UUID, parcheID: UUID, displayName: String, user: UUID) throws -> ParcheParticipant {
        try checkConnection()
        var (detail, me) = try record(parcheID, user: user)
        if let existing = detail.participant(id) { return try respond(existing) }
        guard detail.parche.isOpen else { throw ParcheRepositoryError.parcheClosed }
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...ParcheParticipant.maxNameLength).contains(name.count) else {
            throw ParcheRepositoryError.invalidData
        }
        let date = now()
        // Sin la app: el siguiente color libre del parche, y lo conserva.
        let participant = ParcheParticipant(
            id: id, displayName: name, claimCode: uniqueCode(.place), joinedAt: date,
            avatarColor: .nextFree(after: detail.participants.map(\.avatarColor)))
        detail.participants.append(participant)
        detail.activity.append(
            ParcheActivity(
                parcheID: parcheID, kind: .participantAdded, actorID: me.id, participantID: id, createdAt: date))
        details[parcheID] = detail
        return try respond(participant)
    }

    func claimPlace(code: String, user: UUID) throws -> ParcheDetail {
        try checkConnection()
        let code = ParcheCode.normalize(code)
        guard
            var detail = details.values.first(where: { $0.participants.contains { $0.claimCode == code } }),
            let index = detail.participants.firstIndex(where: { $0.claimCode == code })
        else { throw ParcheRepositoryError.invalidCode }
        guard member(user, of: detail) == nil else { throw ParcheRepositoryError.alreadyParticipant }
        let date = now()
        detail.participants[index].userID = user
        detail.participants[index].claimCode = nil
        claimedCodes[code] = user
        detail.participants[index].avatarColor = color(of: user)
        detail.participants[index].lastSeenAt = date
        let id = detail.participants[index].id
        detail.activity.append(
            ParcheActivity(parcheID: detail.id, kind: .placeClaimed, actorID: id, participantID: id, createdAt: date))
        details[detail.id] = detail
        return try respond(view(detail, for: user))
    }

    // MARK: - Gastos y pagos

    func saveExpense(_ expense: ParcheExpense, user: UUID) throws {
        try checkConnection()
        var (detail, me) = try record(expense.parcheID, user: user)
        guard detail.parche.isOpen else { throw ParcheRepositoryError.parcheClosed }
        // Igual que el trigger de validación: pagadores y partes suman el total, y todos son del parche.
        let known = Set(detail.order)
        guard
            expense.amount > 0, expense.payers.map(\.amount).reduce(0, +) == expense.amount,
            expense.shares.map(\.amount).reduce(0, +) == expense.amount,
            expense.payers.allSatisfy({ known.contains($0.participantID) }),
            expense.shares.allSatisfy({ known.contains($0.participantID) })
        else { throw ParcheRepositoryError.invalidData }
        let date = now()
        if let index = detail.expenses.firstIndex(where: { $0.id == expense.id }) {
            let stored = detail.expenses[index]
            // Un reintento con el mismo contenido no cambia nada ni deja aviso.
            guard !Self.sameContent(stored, expense) else { return try respond(()) }
            var updated = expense
            updated.recordedBy = stored.recordedBy
            updated.createdAt = stored.createdAt
            updated.updatedAt = date
            updated.updatedBy = me.id
            updated.deletedAt = stored.deletedAt
            updated.deletedBy = stored.deletedBy
            detail.expenses[index] = updated
            detail.activity.append(activity(.expenseEdited, for: updated, actor: me.id, at: date))
        } else {
            var created = expense
            created.recordedBy = me.id
            created.createdAt = date
            created.updatedAt = date
            created.updatedBy = nil
            created.deletedAt = nil
            created.deletedBy = nil
            detail.expenses.append(created)
            detail.activity.append(activity(.expenseCreated, for: created, actor: me.id, at: date))
        }
        details[detail.id] = detail
        try respond(())
    }

    func deleteExpense(id: UUID, parcheID: UUID, at date: Date, user: UUID) throws {
        try checkConnection()
        var (detail, me) = try record(parcheID, user: user)
        guard let index = detail.expenses.firstIndex(where: { $0.id == id }) else {
            throw ParcheRepositoryError.notFound
        }
        guard !detail.expenses[index].isDeleted else { return try respond(()) }
        guard detail.parche.isOpen else { throw ParcheRepositoryError.parcheClosed }
        detail.expenses[index].deletedAt = date
        detail.expenses[index].deletedBy = me.id
        detail.activity.append(activity(.expenseDeleted, for: detail.expenses[index], actor: me.id, at: now()))
        details[parcheID] = detail
        try respond(())
    }

    func recordPayment(_ payment: ParchePayment, user: UUID) throws {
        try checkConnection()
        var (detail, me) = try record(payment.parcheID, user: user)
        if detail.payments.contains(where: { $0.id == payment.id }) { return try respond(()) }
        guard
            payment.amount > 0, payment.fromID != payment.toID, detail.participant(payment.fromID) != nil,
            detail.participant(payment.toID) != nil
        else { throw ParcheRepositoryError.invalidData }
        let date = now()
        var stored = payment
        stored.recordedBy = me.id
        stored.createdAt = date
        let confirms = ParcheCalculator.confirmsImmediately(
            recordedBy: me.id, toID: payment.toID, participants: detail.participants)
        stored.confirmedAt = confirms ? date : nil
        detail.payments.append(stored)
        detail.activity.append(
            ParcheActivity(
                parcheID: detail.id, kind: .paymentRecorded, actorID: me.id, participantID: payment.fromID,
                otherParticipantID: payment.toID, recordedByID: me.id, amount: payment.amount, createdAt: date))
        details[detail.id] = detail
        try respond(())
    }

    func confirmPayment(id: UUID, parcheID: UUID, user: UUID) throws {
        try checkConnection()
        var (detail, me) = try record(parcheID, user: user)
        guard let index = detail.payments.firstIndex(where: { $0.id == id }) else {
            throw ParcheRepositoryError.notFound
        }
        let payment = detail.payments[index]
        guard !payment.isConfirmed else { return try respond(()) }
        guard payment.toID == me.id else { throw ParcheRepositoryError.notAllowed }
        let date = now()
        detail.payments[index].confirmedAt = date
        detail.activity.append(
            ParcheActivity(
                parcheID: parcheID, kind: .paymentConfirmed, actorID: me.id, participantID: payment.fromID,
                otherParticipantID: payment.toID, recordedByID: payment.recordedBy, amount: payment.amount,
                createdAt: date))
        details[parcheID] = detail
        try respond(())
    }

    // MARK: - Cerrar y pasar al cruce

    func closeParche(id: UUID, user: UUID) throws {
        try checkConnection()
        var (detail, me) = try record(id, user: user)
        // Igual que `close_parche`: solo quien lo creó (o, si ya no tiene la app, cualquiera con la app).
        guard detail.mayClose(me.id) else { throw ParcheRepositoryError.notAllowed }
        guard detail.parche.isOpen else { return try respond(()) }
        let date = now()
        detail.parche.status = .closed
        detail.parche.closedAt = date
        detail.activity.append(ParcheActivity(parcheID: id, kind: .parcheClosed, actorID: me.id, createdAt: date))
        details[id] = detail
        try respond(())
    }

    /// Igual que `propose_parche_debt_to_cruce`: la transferencia del plan entre los dos, por confirmar.
    func proposeCruceTransfer(parcheID: UUID, otherParticipantID: UUID, user: UUID) throws -> ParcheCruceTransfer {
        try checkConnection()
        var (detail, me) = try record(parcheID, user: user)
        guard !detail.parche.isOpen else { throw ParcheRepositoryError.parcheOpen }
        guard let other = detail.participant(otherParticipantID), let otherUser = other.userID, other.id != me.id
        else { throw ParcheRepositoryError.notAllowed }
        guard cruces.contains([user, otherUser]) else { throw ParcheRepositoryError.noSharedCruce }
        if let live = detail.liveCruceTransfer(between: me.id, and: other.id) {
            guard live.isPending else { throw ParcheRepositoryError.alreadyMoved }
            return try respond(live)
        }
        guard
            let planned = detail.suggestedTransfers.first(where: {
                ($0.fromID == me.id && $0.toID == other.id) || ($0.fromID == other.id && $0.toID == me.id)
            })
        else { throw ParcheRepositoryError.nothingToMove }
        let date = now()
        let transfer = ParcheCruceTransfer(
            parcheID: parcheID, fromID: planned.fromID, toID: planned.toID, amount: planned.amount, createdAt: date,
            status: .pending, proposedBy: me.id)
        detail.transfers.append(transfer)
        detail.activity.append(cruceActivity(.debtProposedToCruce, for: transfer, actor: me.id, at: date))
        details[parcheID] = detail
        return try respond(transfer)
    }

    /// Igual que `accept_parche_cruce_transfer`.
    func acceptCruceTransfer(id: UUID, parcheID: UUID, user: UUID) throws -> ParcheCruceTransfer {
        try checkConnection()
        var (detail, me) = try record(parcheID, user: user)
        guard let index = detail.transfers.firstIndex(where: { $0.id == id }) else {
            throw ParcheRepositoryError.notFound
        }
        let transfer = detail.transfers[index]
        if transfer.isAccepted { return try respond(transfer) }
        let otherID = try respondent(transfer, me: me.id)
        guard transfer.isPending else { throw ParcheRepositoryError.notAllowed }
        guard let otherUser = detail.participant(otherID)?.userID, cruces.contains([user, otherUser]) else {
            throw ParcheRepositoryError.noSharedCruce
        }
        // Si las cuentas cambiaron, el plan ya no tiene esa misma transferencia.
        guard
            detail.suggestedTransfers.contains(
                ParcheTransfer(fromID: transfer.fromID, toID: transfer.toID, amount: transfer.amount))
        else { throw ParcheRepositoryError.nothingToMove }
        let date = now()
        detail.transfers[index].status = .accepted
        detail.transfers[index].movementID = UUID()
        detail.transfers[index].respondedAt = date
        detail.activity.append(cruceActivity(.debtMovedToCruce, for: transfer, actor: me.id, at: date))
        details[parcheID] = detail
        return try respond(detail.transfers[index])
    }

    /// Igual que `reject_parche_cruce_transfer`.
    func rejectCruceTransfer(id: UUID, parcheID: UUID, user: UUID) throws -> ParcheCruceTransfer {
        try checkConnection()
        var (detail, me) = try record(parcheID, user: user)
        guard let index = detail.transfers.firstIndex(where: { $0.id == id }) else {
            throw ParcheRepositoryError.notFound
        }
        let transfer = detail.transfers[index]
        _ = try respondent(transfer, me: me.id)
        switch transfer.status {
        case .rejected: return try respond(transfer)
        case .accepted: throw ParcheRepositoryError.alreadyMoved
        case .pending: break
        }
        let date = now()
        detail.transfers[index].status = .rejected
        detail.transfers[index].respondedAt = date
        detail.activity.append(cruceActivity(.debtRejectedForCruce, for: transfer, actor: me.id, at: date))
        details[parcheID] = detail
        return try respond(detail.transfers[index])
    }

    func markSeen(parcheID: UUID, user: UUID) throws {
        try checkConnection()
        var (detail, me) = try record(parcheID, user: user)
        guard let index = detail.participants.firstIndex(where: { $0.id == me.id }) else { return }
        detail.participants[index].lastSeenAt = now()
        details[parcheID] = detail
        try respond(())
    }

    // MARK: - Ayudas

    private func checkConnection() throws {
        if isOffline { throw ParcheRepositoryError.offline }
    }

    /// Devuelve la respuesta, o lanza `.offline` después de aplicar la operación si se pierden las respuestas.
    private func respond<T>(_ value: T) throws -> T {
        if dropsResponses { throw ParcheRepositoryError.offline }
        return value
    }

    private func member(_ user: UUID, of detail: ParcheDetail) -> ParcheParticipant? {
        detail.participants.first { $0.userID == user }
    }

    /// El parche y el participante de quien pregunta; si no es del parche, no existe (como con RLS).
    private func record(_ id: UUID, user: UUID) throws -> (detail: ParcheDetail, me: ParcheParticipant) {
        guard let detail = details[id], let me = member(user, of: detail) else {
            throw ParcheRepositoryError.notFound
        }
        return (detail, me)
    }

    private func view(_ detail: ParcheDetail, for user: UUID) -> ParcheDetail {
        var view = detail
        view.myParticipantID = member(user, of: detail)?.id
        view.crucePartnerIDs = Set(
            detail.participants.filter { participant in
                guard let other = participant.userID, other != user else { return false }
                return cruces.contains([user, other])
            }.map(\.id))
        return view
    }

    private func uniqueCode(_ kind: ParcheCode.Kind) -> String {
        let used = Set(details.values.flatMap { [$0.parche.code] + $0.participants.compactMap(\.claimCode) })
        while true {
            let code = ParcheCode.generate(kind)
            if !used.contains(code) { return code }
        }
    }

    private func activity(
        _ kind: ParcheActivityKind, for expense: ParcheExpense, actor: UUID, at date: Date
    ) -> ParcheActivity {
        ParcheActivity(
            parcheID: expense.parcheID, kind: kind, actorID: actor, recordedByID: expense.recordedBy,
            amount: expense.amount, concept: expense.concept, createdAt: date)
    }

    /// Solo responde la otra persona del par (no quien la propuso); devuelve a quien la propuso o, en las de antes,
    /// a la otra persona.
    private func respondent(_ transfer: ParcheCruceTransfer, me: UUID) throws -> UUID {
        guard transfer.fromID == me || transfer.toID == me, transfer.proposedBy != me else {
            throw ParcheRepositoryError.notAllowed
        }
        return transfer.fromID == me ? transfer.toID : transfer.fromID
    }

    private func cruceActivity(
        _ kind: ParcheActivityKind, for transfer: ParcheCruceTransfer, actor: UUID, at date: Date
    ) -> ParcheActivity {
        ParcheActivity(
            parcheID: transfer.parcheID, kind: kind, actorID: actor, participantID: transfer.fromID,
            otherParticipantID: transfer.toID, amount: transfer.amount, createdAt: date)
    }

    private static func sameContent(_ a: ParcheExpense, _ b: ParcheExpense) -> Bool {
        a.concept == b.concept && a.baseAmount == b.baseAmount && a.tipPercent == b.tipPercent && a.amount == b.amount
            && a.spentOn == b.spentOn && a.split == b.split && a.payers == b.payers && a.shares == b.shares
    }
}

/// `ParcheRepository` en memoria: un `InMemoryParcheBackend` visto por un usuario.
/// Varias personas pueden compartir el mismo backend, cada una con su repositorio.
public struct InMemoryParcheRepository: ParcheRepository {
    public let backend: InMemoryParcheBackend
    public let userID: UUID

    public init(backend: InMemoryParcheBackend = InMemoryParcheBackend(), userID: UUID) {
        self.backend = backend
        self.userID = userID
    }

    public func loadParches() async throws -> [ParcheDetail] {
        try await backend.loadParches(user: userID)
    }

    public func loadParche(id: UUID) async throws -> ParcheDetail {
        try await backend.loadParche(id: id, user: userID)
    }

    public func loadActivity(parcheID: UUID) async throws -> [ParcheActivity] {
        try await backend.loadParche(id: parcheID, user: userID).activity
    }

    public func createParche(id: UUID, name: String, displayName: String) async throws -> ParcheDetail {
        try await backend.createParche(id: id, name: name, displayName: displayName, user: userID)
    }

    public func joinParche(code: String, displayName: String) async throws -> ParcheDetail {
        try await backend.joinParche(code: code, displayName: displayName, user: userID)
    }

    public func addParticipant(id: UUID, parcheID: UUID, displayName: String) async throws -> ParcheParticipant {
        try await backend.addParticipant(id: id, parcheID: parcheID, displayName: displayName, user: userID)
    }

    public func claimPlace(code: String) async throws -> ParcheDetail {
        try await backend.claimPlace(code: code, user: userID)
    }

    public func previewCode(_ code: String) async throws -> CodePreview {
        try await backend.previewCode(code, user: userID)
    }

    public func saveExpense(_ expense: ParcheExpense) async throws {
        try await backend.saveExpense(expense, user: userID)
    }

    public func deleteExpense(id: UUID, parcheID: UUID, at date: Date) async throws {
        try await backend.deleteExpense(id: id, parcheID: parcheID, at: date, user: userID)
    }

    public func recordPayment(_ payment: ParchePayment) async throws {
        try await backend.recordPayment(payment, user: userID)
    }

    public func confirmPayment(id: UUID, parcheID: UUID) async throws {
        try await backend.confirmPayment(id: id, parcheID: parcheID, user: userID)
    }

    public func closeParche(id: UUID) async throws {
        try await backend.closeParche(id: id, user: userID)
    }

    public func proposeCruceTransfer(parcheID: UUID, otherParticipantID: UUID) async throws -> ParcheCruceTransfer {
        try await backend.proposeCruceTransfer(parcheID: parcheID, otherParticipantID: otherParticipantID, user: userID)
    }

    public func acceptCruceTransfer(id: UUID, parcheID: UUID) async throws -> ParcheCruceTransfer {
        try await backend.acceptCruceTransfer(id: id, parcheID: parcheID, user: userID)
    }

    public func rejectCruceTransfer(id: UUID, parcheID: UUID) async throws -> ParcheCruceTransfer {
        try await backend.rejectCruceTransfer(id: id, parcheID: parcheID, user: userID)
    }

    public func markSeen(parcheID: UUID) async throws {
        try await backend.markSeen(parcheID: parcheID, user: userID)
    }
}
