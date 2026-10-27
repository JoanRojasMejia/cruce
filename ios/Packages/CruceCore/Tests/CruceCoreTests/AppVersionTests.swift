import Testing

@testable import CruceCore

@Suite("Línea de la versión en Ajustes")
struct AppVersionTests {
    @Test(
        "Fuera de prod nombra el ambiente",
        arguments: [
            ("local", "Cruce 1.0 (1) · local"),
            ("testing", "Cruce 1.0 (1) · testing"),
        ])
    func namesEnvironmentOutsideProd(environment: String, expected: String) {
        #expect(AppVersion.line(version: "1.0", build: "1", environment: environment) == expected)
    }

    @Test("En prod muestra solo la versión")
    func prodShowsOnlyVersion() {
        #expect(AppVersion.line(version: "1.0", build: "1", environment: "prod") == "Cruce 1.0 (1)")
    }

    @Test(
        "Sin ambiente, o sin reemplazar, muestra solo la versión",
        arguments: [nil, "", "  ", "$(APP_ENVIRONMENT)"])
    func missingEnvironmentShowsOnlyVersion(environment: String?) {
        #expect(AppVersion.line(version: "2.3", build: "14", environment: environment) == "Cruce 2.3 (14)")
    }
}
