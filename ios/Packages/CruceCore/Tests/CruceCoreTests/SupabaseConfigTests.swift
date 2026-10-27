import Foundation
import Testing

@testable import CruceCore

@Suite("Configuración de Supabase por ambiente")
struct SupabaseConfigTests {
    @Test("Con las claves del ambiente las usa")
    func readsKeys() throws {
        let info = ["SUPABASE_URL": "https://abc.supabase.co", "SUPABASE_ANON_KEY": "clave"]
        let config = try SupabaseConfig.read(from: info).get()
        #expect(config == SupabaseConfig(url: URL(string: "https://abc.supabase.co")!, anonKey: "clave"))
    }

    @Test(
        "Prod sin claves falla y nombra la que falta, sin tomar otras",
        arguments: [
            ([:], "SUPABASE_URL"),
            (["SUPABASE_URL": "pega-aqui-la-url-de-prod", "SUPABASE_ANON_KEY": "pega-aqui-la-clave"], "SUPABASE_URL"),
            (["SUPABASE_URL": "$(SUPABASE_URL)", "SUPABASE_ANON_KEY": "$(SUPABASE_ANON_KEY)"], "SUPABASE_URL"),
            (["SUPABASE_URL": "https://abc.supabase.co", "SUPABASE_ANON_KEY": " "], "SUPABASE_ANON_KEY"),
        ])
    func missingKeysFail(info: [String: String], missing: String) {
        #expect(throws: SupabaseConfig.Missing(key: missing)) { try SupabaseConfig.read(from: info).get() }
    }
}
