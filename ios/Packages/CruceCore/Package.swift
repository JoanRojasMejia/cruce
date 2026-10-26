// swift-tools-version: 6.0
// Lógica pura de Cruce (modelos, saldo, formato de pesos y fechas).
// Se prueba sin Xcode ni simulador: `cd ios/Packages/CruceCore && swift test`.

import PackageDescription

let package = Package(
    name: "CruceCore",
    // macOS hace falta para que `swift test` corra en la Mac.
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "CruceCore", targets: ["CruceCore"]),
    ],
    targets: [
        .target(name: "CruceCore"),
        .testTarget(name: "CruceCoreTests", dependencies: ["CruceCore"]),
    ],
    // Mismo modo de lenguaje que la app (SWIFT_VERSION 5.0).
    swiftLanguageModes: [.v5]
)
