// swift-tools-version: 6.0
// Lógica pura de Cruce (modelos, saldo, formato de pesos y fechas).
// Se prueba sin Xcode ni simulador: `cd ios/Packages/CruceCore && swift test`.

import PackageDescription

let package = Package(
    name: "CruceCore",
    // macOS hace falta para que `swift test` corra en la Mac.
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "CruceCore", targets: ["CruceCore"])
    ],
    targets: [
        .target(name: "CruceCore"),
        .testTarget(name: "CruceCoreTests", dependencies: ["CruceCore"]),
    ],
    // Modo de lenguaje Swift 6 (concurrencia estricta). La app sigue en SWIFT_VERSION 5.0:
    // el modo es por módulo y la app consume el paquete sin problema.
    swiftLanguageModes: [.v6]
)
