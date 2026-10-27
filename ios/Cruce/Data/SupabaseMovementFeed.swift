import CruceCore
import Foundation
import Supabase

/// Los cambios de `movements` en tiempo real (Supabase Realtime): un canal por cruce, filtrado por `ledger_id`.
/// RLS decide qué cambios recibe cada quien. Las inserciones y ediciones (también el borrado suave) llegan como
/// `MovementChange`; los borrados físicos se ignoran porque la app no los hace. Al terminar la secuencia (la tarea que
/// la recorre se cancela) se cierran los canales.
struct SupabaseMovementFeed: MovementFeed {
    let client: SupabaseClient

    func changes(in cruces: [UUID]) -> AsyncStream<MovementChange> {
        AsyncStream { continuation in
            let task = Task {
                await withTaskGroup(of: Void.self) { group in
                    for cruce in cruces {
                        group.addTask { await listen(to: cruce, continuation: continuation) }
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func listen(to cruce: UUID, continuation: AsyncStream<MovementChange>.Continuation) async {
        let channel = client.channel("movements-\(cruce.uuidString.lowercased())")
        let actions = channel.postgresChange(
            AnyAction.self, schema: "public", table: "movements",
            filter: .eq("ledger_id", value: cruce.uuidString.lowercased()))
        do {
            try await channel.subscribeWithError()
        } catch {
            // Sin tiempo real la app sigue: deslizar y volver a la app recargan.
            return
        }
        for await action in actions {
            let record: [String: AnyJSON]
            switch action {
            case .insert(let insert): record = insert.record
            case .update(let update): record = update.record
            case .delete: continue
            }
            if let data = try? JSONEncoder().encode([record]),
                let movement = try? MovementRemote.movements(from: data).first
            {
                continuation.yield(MovementChange(cruce: cruce, movement: movement))
            }
        }
        await client.removeChannel(channel)
    }
}
