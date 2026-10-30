import CruceCore
import Foundation
import Supabase

/// Los parches de quien entró, con Supabase. Lee las tablas con RLS (solo ve sus parches) y escribe solo con las
/// funciones de la migración `parches` (`create_parche`, `save_parche_expense`…), que son las que validan.
/// El JSON se traduce en `ParcheRemote` (CruceCore), donde está probado. Los errores de la base llegan como
/// `ParcheRepositoryError` según su pista (`hint`); sin red, como `.offline`, y `ParcheStore` encola y reintenta.
struct SupabaseParcheRepository: ParcheRepository {
    let client: SupabaseClient

    // MARK: - Lecturas

    func loadParches() async throws -> [ParcheDetail] {
        try await run {
            // Sin sesión no hay parches que ver (pasa al arrancar antes de entrar).
            guard let userID = await sessionUserID() else { return [] }
            async let parches = client.from("parches").select(ParcheRemote.detailSelect).execute().data
            async let partners = crucePartners(of: userID)
            return try ParcheRemote.details(from: await parches, userID: userID, crucePartners: await partners)
        }
    }

    func loadParche(id: UUID) async throws -> ParcheDetail {
        try await run {
            let userID = try await currentUserID()
            async let parches = client.from("parches").select(ParcheRemote.detailSelect).eq("id", value: id)
                .execute().data
            async let partners = crucePartners(of: userID)
            let details = try ParcheRemote.details(
                from: await parches, userID: userID, crucePartners: await partners)
            // RLS: si no es del parche, no lo ve.
            guard let detail = details.first else { throw ParcheRepositoryError.notFound }
            return detail
        }
    }

    func loadActivity(parcheID: UUID) async throws -> [ParcheActivity] {
        try await run {
            let data = try await client.from("parche_activity").select().eq("parche_id", value: parcheID)
                .order("created_at", ascending: false).execute().data
            return try ParcheRemote.activity(from: data)
        }
    }

    // MARK: - Parches y personas

    func createParche(id: UUID, name: String, displayName: String) async throws -> ParcheDetail {
        let parcheID = try await call(
            "create_parche", ParcheRemote.CreateParams(id: id, name: name, displayName: displayName))
        return try await loadParche(id: ParcheRemote.uuid(from: parcheID))
    }

    func joinParche(code: String, displayName: String) async throws -> ParcheDetail {
        let parcheID = try await call("join_parche", ParcheRemote.JoinParams(code: code, displayName: displayName))
        return try await loadParche(id: ParcheRemote.joinedParcheID(from: parcheID))
    }

    func addParticipant(id: UUID, parcheID: UUID, displayName: String) async throws -> ParcheParticipant {
        let row = try await call(
            "add_parche_participant",
            ParcheRemote.AddParticipantParams(id: id, parcheID: parcheID, displayName: displayName))
        return try ParcheRemote.participant(from: row)
    }

    func claimPlace(code: String) async throws -> ParcheDetail {
        let parcheID = try await call("claim_parche_place", ParcheRemote.CodeParams(code: code))
        return try await loadParche(id: ParcheRemote.joinedParcheID(from: parcheID))
    }

    func previewCode(_ code: String) async throws -> CodePreview {
        try ParcheRemote.codePreview(from: try await call("preview_parche_code", ParcheRemote.CodeParams(code: code)))
    }

    // MARK: - Gastos y pagos

    func saveExpense(_ expense: ParcheExpense) async throws {
        _ = try await call("save_parche_expense", ParcheRemote.SaveExpenseParams(expense))
    }

    func deleteExpense(id: UUID, parcheID: UUID, at date: Date) async throws {
        // La base pone la fecha del borrado (`now()`); la del teléfono solo sirve mientras está en la cola.
        _ = try await call("delete_parche_expense", ParcheRemote.IDParams(id: id))
    }

    func recordPayment(_ payment: ParchePayment) async throws {
        _ = try await call("record_parche_payment", ParcheRemote.RecordPaymentParams(payment))
    }

    func confirmPayment(id: UUID, parcheID: UUID) async throws {
        _ = try await call("confirm_parche_payment", ParcheRemote.IDParams(id: id))
    }

    // MARK: - Cerrar y pasar al cruce

    func closeParche(id: UUID) async throws {
        _ = try await call("close_parche", ParcheRemote.IDParams(id: id))
    }

    func proposeCruceTransfer(parcheID: UUID, otherParticipantID: UUID) async throws -> ParcheCruceTransfer {
        let row = try await call(
            "propose_parche_debt_to_cruce",
            ParcheRemote.ProposeCruceParams(parcheID: parcheID, otherParticipantID: otherParticipantID))
        return try ParcheRemote.transfer(from: row)
    }

    func acceptCruceTransfer(id: UUID, parcheID: UUID) async throws -> ParcheCruceTransfer {
        let row = try await call("accept_parche_cruce_transfer", ParcheRemote.IDParams(id: id))
        return try ParcheRemote.transfer(from: row)
    }

    func rejectCruceTransfer(id: UUID, parcheID: UUID) async throws -> ParcheCruceTransfer {
        let row = try await call("reject_parche_cruce_transfer", ParcheRemote.IDParams(id: id))
        return try ParcheRemote.transfer(from: row)
    }

    func markSeen(parcheID: UUID) async throws {
        _ = try await call("mark_parche_seen", ParcheRemote.IDParams(id: parcheID))
    }

    // MARK: - Ayudas

    /// La cuenta de quien entró. `session` renueva el token si venció; sin sesión no hay parches que ver.
    private func currentUserID() async throws -> UUID {
        guard let userID = await sessionUserID() else { throw ParcheRepositoryError.notAllowed }
        return userID
    }

    private func sessionUserID() async -> UUID? {
        if let session = try? await client.auth.session { return session.user.id }
        return client.auth.currentUser?.id
    }

    /// Las cuentas con las que comparte un cruce abierto (RLS de `ledger_members` deja ver los miembros de sus
    /// cuentas, y la de `ledgers` si están cerradas).
    private func crucePartners(of userID: UUID) async throws -> Set<UUID> {
        let data = try await client.from("ledger_members").select(ParcheRemote.memberSelect).execute().data
        return ParcheRemote.crucePartners(of: userID, members: try ParcheRemote.members(from: data))
    }

    /// Llama una función de la base y devuelve el JSON de la respuesta.
    private func call(_ function: String, _ params: some Encodable & Sendable) async throws -> Data {
        try await run { try await client.rpc(function, params: params).execute().data }
    }

    /// Traduce los errores: la pista de la base a `ParcheRepositoryError` y la falta de red a `.offline`.
    private func run<T>(_ operation: () async throws -> T) async throws -> T {
        do {
            return try await operation()
        } catch let error as PostgrestError {
            throw ParcheRepositoryError(databaseCode: error.code, hint: error.hint) ?? error
        } catch let error as URLError where error.code == .cancelled {
            // La tarea se canceló (por ejemplo, otra carga la reemplazó): no es falta de red.
            throw CancellationError()
        } catch is URLError {
            throw ParcheRepositoryError.offline
        }
    }
}
