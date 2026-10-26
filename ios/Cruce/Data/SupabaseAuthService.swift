import CruceCore
import Foundation
import Supabase

/// Inicio de sesión con un código de 6 dígitos por correo, con Supabase Auth.
/// supabase-swift guarda la sesión en el llavero, así sobrevive a cerrar y abrir la app.
struct SupabaseAuthService: AuthService {
    let client: SupabaseClient

    func currentUserID() async -> UUID? {
        // `session` renueva el token si venció; sin conexión se usa la sesión guardada.
        if let session = try? await client.auth.session { return session.user.id }
        return client.auth.currentUser?.id
    }

    func sendCode(to email: String) async throws {
        do {
            // Sin `redirectTo`: no se usa el enlace mágico, solo el código (`{{ .Token }}` en la plantilla).
            try await client.auth.signInWithOTP(email: email, shouldCreateUser: true)
        } catch let error as AuthError where Self.isRateLimit(error) {
            throw AuthServiceError.rateLimited
        }
    }

    func verify(email: String, code: String) async throws -> UUID {
        do {
            return try await client.auth.verifyOTP(email: email, token: code, type: .email).user.id
        } catch let error as AuthError where Self.isRateLimit(error) {
            throw AuthServiceError.rateLimited
        } catch AuthError.api(_, _, _, let response) where (400..<500).contains(response.statusCode) {
            // Supabase responde 403 `otp_expired` tanto para un código equivocado como para uno vencido.
            throw AuthServiceError.invalidCode
        }
    }

    func signOut() async throws {
        // supabase-swift borra la sesión guardada antes de avisarle al servidor, así que se borra aunque falle la red.
        try await client.auth.signOut()
    }

    private static func isRateLimit(_ error: AuthError) -> Bool {
        guard case .api(_, let code, _, let response) = error else { return false }
        return response.statusCode == 429 || code == .overEmailSendRateLimit || code == .overRequestRateLimit
    }
}
