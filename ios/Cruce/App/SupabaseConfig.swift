import CruceCore
import Foundation

extension SupabaseConfig {
    /// Lee la configuración al arrancar. Si falta, la app se detiene con un mensaje que dice cómo arreglarlo.
    static func load(from bundle: Bundle = .main) -> SupabaseConfig {
        switch read(from: bundle.infoDictionary ?? [:]) {
        case .success(let config): return config
        case .failure(let problem): fatalError(problem.description)
        }
    }
}
