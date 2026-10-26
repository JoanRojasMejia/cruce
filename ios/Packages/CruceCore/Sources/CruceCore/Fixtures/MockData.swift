import Foundation

/// Datos de ejemplo iguales a los del canvas de diseño.
/// Desde la vista de Joan, el saldo queda en "Jesús te debe $20.000".
public enum MockData {
    public static let joan = Member(
        id: UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!,
        name: "Joan",
        avatarColor: .yellow,
        tikeVariant: .rosa
    )

    public static let jesus = Member(
        id: UUID(uuidString: "00000000-0000-0000-0000-00000000000B")!,
        name: "Jesús",
        avatarColor: .violet,
        tikeVariant: .verde
    )

    public static func movements(reference: Date = .now) -> [Movement] {
        let calendar = Calendar.current
        func daysAgo(_ days: Int, hour: Int = 13) -> Date {
            let day = calendar.date(byAdding: .day, value: -days, to: reference) ?? reference
            return calendar.date(bySettingHour: hour, minute: 15, second: 0, of: day) ?? day
        }

        return [
            Movement(
                payerID: joan.id, amount: 824_000, concept: "Arriendo octubre", category: .hogar,
                date: daysAgo(10, hour: 9), createdBy: joan.id),
            Movement(
                kind: .settlement, payerID: jesus.id, amount: 412_000, concept: "Saldar cuentas",
                category: .otro, split: .fullOther, date: daysAgo(9), createdBy: jesus.id, paymentMethod: "Nequi"),
            Movement(
                payerID: joan.id, amount: 40_000, concept: "Préstamo", category: .prestamo,
                split: .fullOther, date: daysAgo(8), createdBy: joan.id),
            Movement(
                payerID: joan.id, amount: 30_000, concept: "Gasolina de la moto", category: .transporte,
                date: daysAgo(6), createdBy: joan.id),
            Movement(
                payerID: jesus.id, amount: 32_000, concept: "Uber al aeropuerto", category: .transporte,
                date: daysAgo(5), createdBy: jesus.id),
            Movement(
                payerID: joan.id, amount: 48_000, concept: "Cine Andino", category: .ocio,
                date: daysAgo(4, hour: 20), createdBy: joan.id),
            Movement(
                payerID: jesus.id, amount: 22_000, concept: "Domicilio Rappi", category: .comida,
                date: daysAgo(2, hour: 21), createdBy: jesus.id),
            Movement(
                payerID: jesus.id, amount: 100_000, concept: "Mercado Éxito", category: .mercado,
                date: daysAgo(1, hour: 18), createdBy: jesus.id),
            Movement(
                payerID: joan.id, amount: 36_000, concept: "Almuerzo corrientazo", category: .comida,
                date: daysAgo(0), createdBy: joan.id),
        ]
    }
}
