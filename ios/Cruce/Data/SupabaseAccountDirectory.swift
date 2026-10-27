import CruceCore
import Foundation
import Supabase

/// Perfil y cruces de quien entró. El perfil se lee de `profiles` (con RLS); para vincular se usan solo las funciones de
/// la base (`my_cruces`, `create_ledger_with_invite`, `preview_invite` y `redeem_invite`), que usan la sesión abierta.
/// La traducción del JSON vive en `CruceRemote` (CruceCore), probada con `swift test`.
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

    func cruces(for userID: UUID) async throws -> [CruceLink] {
        try CruceRemote.cruceLinks(from: try await client.rpc("my_cruces").execute().data)
    }

    func inviteCode(for userID: UUID) async throws -> String {
        let data = try await client.rpc("create_ledger_with_invite").execute().data
        return try JSONDecoder().decode(String.self, from: data)
    }

    func previewInvite(_ code: String, for userID: UUID) async throws -> InviteCheck {
        try CruceRemote.inviteCheck(
            from: try await client.rpc("preview_invite", params: ["p_code": code]).execute().data)
    }

    func redeemInvite(_ code: String, for userID: UUID) async throws -> InviteCheck {
        try CruceRemote.inviteCheck(
            from: try await client.rpc("redeem_invite", params: ["p_code": code]).execute().data)
    }

    func createProfile(_ profile: Profile) async throws {
        // La política "crear mi perfil" solo deja insertar la fila con `id = auth.uid()`.
        try await client
            .from("profiles")
            .insert(ProfileRow(id: profile.id, displayName: profile.displayName))
            .execute()
    }
}
