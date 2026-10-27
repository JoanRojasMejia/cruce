import CruceCore
import Foundation
import Network

/// Avisa a `LedgerStore` cuando el teléfono gana o pierde la red (`NWPathMonitor`), para enviar lo pendiente apenas
/// vuelve. Solo en la app: CruceCore no depende de `Network`.
@MainActor
final class NetworkMonitor {
    private let monitor = NWPathMonitor()
    private var lastAvailable: Bool?

    /// Empieza a escuchar. Cada cambio llama `ledger.networkChanged(isAvailable:)`.
    func start(updating ledger: LedgerStore) {
        monitor.pathUpdateHandler = { [weak self] path in
            let available = path.status == .satisfied
            Task { @MainActor in
                guard let self, self.lastAvailable != available else { return }
                self.lastAvailable = available
                await ledger.networkChanged(isAvailable: available)
            }
        }
        monitor.start(queue: DispatchQueue(label: "com.joanrojas.cruce.red"))
    }
}
