import CruceCore
import Foundation

/// El historial de un cruce como archivo CSV en la carpeta temporal, para compartirlo con `ShareLink`.
/// El texto sale de `HistoryCSV` (CruceCore). Se comparte la URL de un archivo ya escrito porque con un
/// `Transferable` (`FileRepresentation`) "Guardar en Archivos" fallaba o no recibía nada.
enum HistoryExport {
    /// Escribe el archivo (reemplaza el anterior) y devuelve su URL.
    static func write(movements: [Movement], me: Member, partner: Member, date: Date = .now) throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appending(path: "Exportar", directoryHint: .isDirectory)
        // Solo queda el último archivo exportado.
        try? FileManager.default.removeItem(at: folder)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: HistoryCSV.fileName(partner: partner.name, date: date))
        let csv = HistoryCSV.make(movements: movements, me: me, partner: partner)
        try HistoryCSV.fileData(csv).write(to: url, options: .atomic)
        return url
    }
}
