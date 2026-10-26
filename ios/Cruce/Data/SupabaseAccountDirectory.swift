import CruceCore
import Foundation
import Supabase

/// Perfil y cuenta compartida de quien entró, leídos de `profiles` y `ledger_members` (con RLS).
struct SupabaseAccountDirectory: AccountDirectory {
    let client: SupabaseClient

    /// Una fila de `profiles`.
    private struct ProfileRow: Codable {
        let id: UUID
        let displayName: String

        enum CodingKeys: String, CodingKey {
            case id
            case displayName = "display_name"
        }
    }

    func profile(for userID: UUID) async throws -> Profile? {
        let rows: [ProfileRow] =
            try await client
            .from("profiles")
            .select("id, display_name")
            .eq("id", value: userID)
            .limit(1)
            .execute()
            .value
        return rows.first.map { Profile(id: $0.id, displayName: $0.displayName) }
    }

    func hasLedger(_ userID: UUID) async throws -> Bool {
        let response =
            try await client
            .from("ledger_members")
            .select("ledger_id", head: true, count: .exact)
            .eq("user_id", value: userID)
            .execute()
        return (response.count ?? 0) > 0
    }

    func createProfile(_ profile: Profile) async throws {
        // La política "crear mi perfil" solo deja insertar la fila con `id = auth.uid()`.
        try await client
            .from("profiles")
            .insert(ProfileRow(id: profile.id, displayName: profile.displayName))
            .execute()
    }
}
