import Foundation

/// Dirección y clave anónima de Supabase, leídas del `Info.plist` (que las toma de `ios/Config.xcconfig`).
/// La clave anónima es pública por diseño: lo que protege los datos es RLS.
/// Cada configuración de Xcode trae solo las de su ambiente; si faltan, no se toman las de otro.
public struct SupabaseConfig: Sendable, Equatable {
    public let url: URL
    public let anonKey: String

    public init(url: URL, anonKey: String) {
        self.url = url
        self.anonKey = anonKey
    }

    public struct Missing: Error, CustomStringConvertible, Equatable {
        public let key: String
        public var description: String {
            "Falta \(key) en la configuración. Copia ios/Config.example.xcconfig como ios/Config.xcconfig, "
                + "llena las claves y vuelve a correr xcodegen."
        }
    }

    /// Lee las claves de un `Info.plist`. Un valor vacío, sin reemplazar (`$(…)`) o de plantilla
    /// (`pega-aqui…`) cuenta como faltante.
    public static func read(from info: [String: Any]) -> Result<SupabaseConfig, Missing> {
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
