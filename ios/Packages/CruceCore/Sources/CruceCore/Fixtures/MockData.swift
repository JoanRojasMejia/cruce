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

    /// Ana creó su cruce con Joan y Joan se unió con código: en ese cruce Ana es amarilla y rosa, y Joan, violeta y verde.
    public static let ana = Member(
        id: UUID(uuidString: "00000000-0000-0000-0000-00000000000C")!,
        name: "Ana",
        avatarColor: .yellow,
        tikeVariant: .rosa
    )

    /// El cruce de Joan y Jesús (el del canvas).
    public static let joanJesusCruceID = UUID(uuidString: "00000000-0000-0000-0000-0000000000C1")!
    /// El cruce de Joan y Ana, para probar varios cruces.
    public static let joanAnaCruceID = UUID(uuidString: "00000000-0000-0000-0000-0000000000C2")!

    /// El cruce de Joan y Jesús visto por `viewer` (Joan o Jesús): Joan lo creó.
    public static func joanJesusCruce(viewer: Member) -> CruceLink {
        let isJoan = viewer.id == joan.id
        return CruceLink(
            id: joanJesusCruceID, partner: isJoan ? jesus : joan, myAvatarColor: isJoan ? .yellow : .violet,
            myTikeVariant: isJoan ? .rosa : .verde, linkedAt: Date(timeIntervalSince1970: 1_792_000_000))
    }

    /// El cruce de Joan y Ana visto por Joan: más reciente que el de Jesús.
    public static let joanAnaCruce = CruceLink(
        id: joanAnaCruceID, partner: ana, myAvatarColor: .violet, myTikeVariant: .verde,
        linkedAt: Date(timeIntervalSince1970: 1_792_500_000))

    /// Movimientos del cruce de Joan y Ana: Joan le debe $15.000 a Ana.
    public static func anaMovements(reference: Date = .now) -> [Movement] {
        let day = Calendar.current.date(byAdding: .day, value: -3, to: reference) ?? reference
        return [
            Movement(
                payerID: ana.id, amount: 30_000, concept: "Pizza", category: .comida, date: day, createdBy: ana.id)
        ]
    }

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
