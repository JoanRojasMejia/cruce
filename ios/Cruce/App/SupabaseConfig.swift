import Foundation

/// Dirección y clave anónima de Supabase, leídas del `Info.plist` (que las toma de `ios/Config.xcconfig`).
/// La clave anónima es pública por diseño: lo que protege los datos es RLS.
struct SupabaseConfig {
    let url: URL
    let anonKey: String

    /// Lee la configuración al arrancar. Si falta, la app se detiene con un mensaje que dice cómo arreglarlo.
    static func load(from bundle: Bundle = .main) -> SupabaseConfig {
        switch read(from: bundle.infoDictionary ?? [:]) {
        case .success(let config): return config
        case .failure(let problem): fatalError(problem.description)
        }
    }

    struct Missing: Error, CustomStringConvertible {
        let key: String
        var description: String {
            "Falta \(key) en la configuración. Copia ios/Config.example.xcconfig como ios/Config.xcconfig, "
                + "llena las claves y vuelve a correr xcodegen."
        }
    }

    static func read(from info: [String: Any]) -> Result<SupabaseConfig, Missing> {
        func value(_ key: String) -> String? {
            guard let text = (info[key] as? String)?.trimmingCharacters(in: .whitespaces),
                !text.isEmpty, !text.hasPrefix("$("), !text.hasPrefix("pega-aqui")
            else { return nil }
            return text
        }
        guard let text = value("SUPABASE_URL"), let url = URL(string: text), url.scheme != nil else {
            return .failure(Missing(key: "SUPABASE_URL"))
        }
        guard let key = value("SUPABASE_ANON_KEY") else { return .failure(Missing(key: "SUPABASE_ANON_KEY")) }
        return .success(SupabaseConfig(url: url, anonKey: key))
    }
}
