import CruceCore
import Foundation
import Supabase

#if DEBUG
    import OSLog
#endif

/// Los movimientos de cada cruce en la tabla `movements` (RLS: solo los de los cruces de quien entró).
/// Guardar es `upsert` por `id`: el `id` lo genera la app, así un reintento no duplica. Eliminar es borrado suave
/// (`deleted_at`). El JSON se traduce en `MovementRemote` (CruceCore), donde está probado. Los errores se lanzan tal
/// cual: `LedgerStore` los trata como sin conexión.
struct SupabaseLedgerRepository: LedgerRepository {
    let client: SupabaseClient

    func loadMovements(in cruce: UUID) async throws -> [Movement] {
        let data =
            try await client
            .from("movements")
            .select(MovementRemote.select)
            .eq("ledger_id", value: cruce)
            .order("occurred_at")
            .execute()
            .data
        let movements = try MovementRemote.movements(from: data)
        #if DEBUG
            await checkBalances(of: movements, in: cruce)
        #endif
        return movements
    }

    func save(_ movement: Movement, in cruce: UUID) async throws {
        try await client
            .from("movements")
            .upsert(MovementRemote.row(for: movement, cruce: cruce), onConflict: "id")
            .execute()
    }

    func delete(id: UUID, in cruce: UUID) async throws {
        // La fecha del borrado es la del teléfono, la misma que `LedgerStore` ya puso en el movimiento.
        try await client
            .from("movements")
            .update(["deleted_at": ParcheRemote.timestamp(.now)])
            .eq("id", value: id)
            .eq("ledger_id", value: cruce)
            .execute()
    }

    #if DEBUG
        private struct BalanceRow: Decodable {
            let userId: UUID
            let net: Int

            enum CodingKeys: String, CodingKey {
                case net
                case userId = "user_id"
            }
        }

        /// Solo Debug: compara el saldo que calcula la app con el de `ledger_balances` para cada persona del cruce y
        /// avisa en la consola si no coinciden. No detiene la app ni corre en Release.
        private func checkBalances(of movements: [Movement], in cruce: UUID) async {
            let logger = Logger(subsystem: "com.joanrojas.cruce", category: "cuadre")
            do {
                let data =
                    try await client
                    .from("ledger_balances")
                    .select("user_id, net")
                    .eq("ledger_id", value: cruce)
                    .execute()
                    .data
                for row in try JSONDecoder().decode([BalanceRow].self, from: data) {
                    let app = BalanceCalculator.net(of: movements, for: row.userId)
                    if app != row.net {
                        logger.warning(
                            "El saldo no cuadra en el cruce \(cruce): la app dice \(app) y la base \(row.net)")
                    } else {
                        logger.info("Cuadre en orden en el cruce \(cruce): \(app)")
                    }
                }
            } catch {
                logger.debug("No se pudo revisar el cuadre: \(error.localizedDescription)")
            }
        }
    #endif
}
