import Foundation
import Testing

@testable import CruceCore

@Suite("Exportar el historial a CSV")
struct HistoryCSVTests {
    private let joan = MockData.joan
    private let jesus = MockData.jesus
    private let bogota = TimeZone(identifier: "America/Bogota")!

    /// Mediodía en Bogotá de ese día de octubre de 2026.
    private func october(_ day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = bogota
        return calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: 12))!
    }

    private func lines(_ csv: String) -> [String] {
        csv.components(separatedBy: "\r\n").filter { !$0.isEmpty }
    }

    @Test("La primera fila son los encabezados")
    func header() {
        let csv = HistoryCSV.make(movements: [], me: joan, partner: jesus, timeZone: bogota)
        #expect(
            lines(csv) == [
                "Fecha,Tipo,Concepto,Categoría,Pagó,Monto,Parte del otro (%),Le debe a quien pagó,Medio de pago"
            ])
    }

    @Test("Una cena a medias y un pago por Nequi, de la más vieja a la más nueva")
    func rows() {
        let dinner = Movement(
            payerID: joan.id, amount: 60_000, concept: "Cena", category: .comida, date: october(12),
            createdBy: joan.id)
        let payment = Movement(
            kind: .settlement, payerID: jesus.id, amount: 20_000, concept: "Saldar cuentas", category: .otro,
            split: .fullOther, date: october(20), createdBy: joan.id, paymentMethod: "Nequi")
        let csv = HistoryCSV.make(movements: [payment, dinner], me: joan, partner: jesus, timeZone: bogota)
        #expect(
            Array(lines(csv).dropFirst()) == [
                "2026-10-12,Gasto,Cena,Comida,Joan,60000,50,30000,",
                "2026-10-20,Pago,Saldar cuentas,Otro,Jesús,20000,100,20000,Nequi",
            ])
    }

    @Test("Los eliminados no aparecen")
    func skipsDeleted() {
        var deleted = Movement(
            payerID: joan.id, amount: 6_000, concept: "Café", category: .comida, date: october(3), createdBy: joan.id)
        deleted.deletedAt = october(4)
        let kept = Movement(
            payerID: jesus.id, amount: 100_000, concept: "Mercado", category: .mercado, date: october(5),
            createdBy: jesus.id)
        let other = Movement(
            payerID: joan.id, amount: 10_000, concept: "Taxi", category: .transporte, date: october(6),
            createdBy: joan.id)
        let csv = HistoryCSV.make(movements: [deleted, kept, other], me: joan, partner: jesus, timeZone: bogota)
        #expect(lines(csv).count == 3)
        #expect(!csv.contains("Café"))
    }

    @Test("Un concepto con coma y comillas va entre comillas, con las comillas dobladas")
    func quotesFields() {
        let pizza = Movement(
            payerID: joan.id, amount: 30_000, concept: "Pizza, \"la buena\"", category: .comida, date: october(1),
            createdBy: joan.id)
        let csv = HistoryCSV.make(movements: [pizza], me: joan, partner: jesus, timeZone: bogota)
        #expect(lines(csv)[1].hasPrefix("2026-10-01,Gasto,\"Pizza, \"\"la buena\"\"\",Comida,"))
    }

    @Test("El archivo va en UTF-8 con marca de orden de bytes")
    func fileDataHasBOM() {
        let data = HistoryCSV.fileData("Pagó\r\n")
        #expect(Array(data.prefix(3)) == [0xEF, 0xBB, 0xBF])
        #expect(String(decoding: data.dropFirst(3), as: UTF8.self) == "Pagó\r\n")
    }

    @Test("El nombre del archivo va en minúsculas, sin tildes y con la fecha")
    func fileName() {
        #expect(
            HistoryCSV.fileName(partner: "Jesús", date: october(27), timeZone: bogota)
                == "cruce-con-jesus-2026-10-27.csv")
        #expect(
            HistoryCSV.fileName(partner: "María José", date: october(27), timeZone: bogota)
                == "cruce-con-maria-jose-2026-10-27.csv")
    }
}
