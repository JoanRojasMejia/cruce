import Foundation

/// El historial de un cruce como CSV, para "Exportar historial (CSV)" en Ajustes.
/// Una fila por movimiento vigente, de la más vieja a la más nueva, con los montos en pesos enteros para que una hoja de
/// cálculo los pueda sumar. Separado por comas y con comillas solo donde hacen falta (RFC 4180).
public enum HistoryCSV {
    static let header = [
        "Fecha", "Tipo", "Concepto", "Categoría", "Pagó", "Monto", "Parte del otro (%)", "Le debe a quien pagó",
        "Medio de pago",
    ]

    /// El texto del archivo. `me` y `partner` dan el nombre de quien pagó; los eliminados no aparecen.
    public static func make(
        movements: [Movement], me: Member, partner: Member, timeZone: TimeZone = .current
    ) -> String {
        let rows =
            movements
            .filter { !$0.isDeleted }
            .sorted { $0.date < $1.date }
            .map { movement in
                [
                    day(movement.date, timeZone: timeZone),
                    movement.kind == .settlement ? "Pago" : "Gasto",
                    movement.concept,
                    movement.category.title,
                    movement.payerID == me.id ? me.name : partner.name,
                    String(movement.amount),
                    String(movement.split.otherSharePercent),
                    String(movement.owedByOther),
                    movement.kind == .settlement ? movement.paymentMethod ?? "" : "",
                ]
            }
        return ([header] + rows).map { $0.map(field).joined(separator: ",") }.joined(separator: "\r\n") + "\r\n"
    }

    /// Los bytes del archivo: UTF-8 con marca de orden de bytes, para que Excel muestre las tildes.
    public static func fileData(_ csv: String) -> Data {
        Data([0xEF, 0xBB, 0xBF]) + Data(csv.utf8)
    }

    /// `cruce-con-jesus-2026-10-27.csv`: el nombre de la otra persona en minúsculas, sin tildes y con guiones.
    public static func fileName(partner: String, date: Date, timeZone: TimeZone = .current) -> String {
        let slug =
            partner
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es_CO"))
            .lowercased()
            .split { !($0.isASCII && ($0.isLetter || $0.isNumber)) }
            .joined(separator: "-")
        return "cruce-con-\(slug.isEmpty ? "cruce" : slug)-\(day(date, timeZone: timeZone)).csv"
    }

    /// AAAA-MM-DD en el calendario gregoriano, en la zona horaria del teléfono.
    private static func day(_ date: Date, timeZone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// Entre comillas si tiene coma, comillas o salto de línea, con las comillas internas dobladas.
    private static func field(_ value: String) -> String {
        guard value.contains(where: { $0 == "," || $0 == "\"" || $0.isNewline }) else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
