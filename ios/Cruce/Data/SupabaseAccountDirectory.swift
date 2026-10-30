import CruceCore
import Foundation
import Supabase

/// Perfil y cruces de quien entró. El perfil se lee y se edita en `profiles`, y el reparto por defecto en `ledgers` (con
/// RLS); para vincular y desvincular se usan solo las funciones de la base (`my_cruces`, `create_ledger_with_invite`,
/// `preview_invite`, `redeem_invite` y `close_cruce`), que usan la sesión abierta.
/// La traducción del JSON vive en `CruceRemote` (CruceCore), probada con `swift test`.
struct SupabaseAccountDirectory: AccountDirectory {
    let client: SupabaseClient

    /// Una fila de `profiles`. Al crearla no se manda el color: la base elige uno al azar.
    private struct ProfileRow: Codable {
        let id: UUID
        let displayName: String
        /// Opcional para seguir leyendo una base sin la migración de colores (queda amarillo).
        var avatarColor: AvatarColor?

        enum CodingKeys: String, CodingKey {
            case id
            case displayName = "display_name"
            case avatarColor = "avatar_color"
        }
    }

    func profile(for userID: UUID) async throws -> Profile? {
        // Todas las columnas: así una base sin `avatar_color` todavía no rompe la entrada.
        let rows: [ProfileRow] =
            try await client
            .from("profiles")
            .select()
            .eq("id", value: userID)
            .limit(1)
            .execute()
            .value
        return rows.first.map {
            Profile(id: $0.id, displayName: $0.displayName, avatarColor: $0.avatarColor ?? .yellow)
        }
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

    func updateDisplayName(_ name: String, for userID: UUID) async throws {
        // La política "editar mi perfil" solo deja cambiar la fila propia.
        try await client
            .from("profiles")
            .update(["display_name": name])
            .eq("id", value: userID)
            .execute()
    }

    func updateAvatarColor(_ color: AvatarColor, for userID: UUID) async throws {
        // Igual que el nombre: solo la fila propia. La base copia el color a sus lugares en los parches.
        try await client
            .from("profiles")
            .update(["avatar_color": color.rawValue])
            .eq("id", value: userID)
            .execute()
    }

    func setDefaultOtherPercent(_ percent: Int, in cruceID: UUID, for userID: UUID) async throws {
        // Solo `default_other_percent` tiene permiso de edición en `ledgers`, y RLS deja solo los cruces propios.
        try await client
            .from("ledgers")
            .update(["default_other_percent": percent])
            .eq("id", value: cruceID)
            .execute()
    }

    func closeCruce(_ cruceID: UUID, for userID: UUID) async throws -> Date {
        try CruceRemote.closedAt(
            from: try await client.rpc("close_cruce", params: ["p_ledger": cruceID]).execute().data)
    }

    func createProfile(_ profile: Profile) async throws {
        // La política "crear mi perfil" solo deja insertar la fila con `id = auth.uid()`.
        try await client
            .from("profiles")
            .insert(ProfileRow(id: profile.id, displayName: profile.displayName, avatarColor: nil))
            .execute()
    }
}
