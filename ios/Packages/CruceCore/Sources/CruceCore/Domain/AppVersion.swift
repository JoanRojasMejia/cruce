import Foundation

/// Línea de la versión que muestra Ajustes, con el ambiente cuando no es prod.
public enum AppVersion {
    /// "Cruce 1.0 (1) · testing" fuera de prod; "Cruce 1.0 (1)" en prod o si el ambiente no llegó al `Info.plist`.
    public static func line(version: String, build: String, environment: String?) -> String {
        let base = "Cruce \(version) (\(build))"
        guard let name = environment?.trimmingCharacters(in: .whitespaces), !name.isEmpty,
            !name.hasPrefix("$("), name != "prod"
        else { return base }
        return "\(base) · \(name)"
    }
}
