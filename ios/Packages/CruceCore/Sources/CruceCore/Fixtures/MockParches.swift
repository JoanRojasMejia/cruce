import Foundation

/// Parches de ejemplo para Debug, vistas previas y pruebas. Desde la vista de Joan:
/// "Santa Marta" abierto (con Carlos sin la app, un pago pendiente y avisos sin ver) y "Cena de Ana" a paz y salvo.
public enum MockParches {
    /// Ana tiene la app; su cuenta es otra persona además de Joan y Jesús.
    public static let anaUserID = UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!

    public static let santaMartaID = UUID(uuidString: "00000000-0000-0000-0000-00000000B001")!
    public static let cenaID = UUID(uuidString: "00000000-0000-0000-0000-00000000B002")!

    public static let joan = UUID(uuidString: "00000000-0000-0000-0000-00000000C001")!
    public static let jesus = UUID(uuidString: "00000000-0000-0000-0000-00000000C002")!
    public static let ana = UUID(uuidString: "00000000-0000-0000-0000-00000000C003")!
    public static let carlos = UUID(uuidString: "00000000-0000-0000-0000-00000000C004")!

    /// El color del perfil de cada quien con la app: Joan amarillo, Jesús violeta y Ana verde (Carlos, sin la app, es
    /// durazno dentro de "Santa Marta").
    public static let colors: [UUID: AvatarColor] = [
        MockData.joan.id: .yellow, MockData.jesus.id: .violet, anaUserID: .green,
    ]

    /// Un backend en memoria con los dos parches; Joan y Jesús comparten un cruce.
    public static func backend(reference: Date = .now) -> InMemoryParcheBackend {
        InMemoryParcheBackend(
            parches: parches(reference: reference), cruces: [[MockData.joan.id, MockData.jesus.id]], colors: colors)
    }

    /// Los parches tal como están guardados (sin la vista de nadie).
    public static func parches(reference: Date = .now) -> [ParcheDetail] {
        [santaMarta(reference: reference), cena(reference: reference)]
    }

    private static func santaMarta(reference: Date) -> ParcheDetail {
        func hoursAgo(_ hours: Double) -> Date { reference.addingTimeInterval(-hours * 3_600) }
        let parche = Parche(id: santaMartaID, name: "Santa Marta", code: "PCH-SM4R7A", createdAt: hoursAgo(72))
        let participants = [
            ParcheParticipant(
                id: joan, userID: MockData.joan.id, displayName: "Joan", joinedAt: hoursAgo(72),
                lastSeenAt: hoursAgo(10), avatarColor: .yellow),
            ParcheParticipant(
                id: jesus, userID: MockData.jesus.id, displayName: "Jesús", joinedAt: hoursAgo(71),
                lastSeenAt: hoursAgo(1), avatarColor: .violet),
            ParcheParticipant(
                id: ana, userID: anaUserID, displayName: "Ana", joinedAt: hoursAgo(70), lastSeenAt: hoursAgo(2),
                avatarColor: .green),
            ParcheParticipant(
                id: carlos, displayName: "Carlos", claimCode: "SOY-K7QX2M", joinedAt: hoursAgo(69), avatarColor: .peach),
        ]
        let order = participants.map(\.id)
        // El almuerzo de la spec: por consumo con 10 % de propina, pagado por Ana.
        let lunch = try! ParcheExpense.resolve(
            id: UUID(uuidString: "00000000-0000-0000-0000-00000000E001")!, parcheID: santaMartaID,
            concept: "Almuerzo en Taganga", base: 200_000, tipPercent: 10,
            split: .items([
                ParcheSplitItem(amount: 30_000, participantIDs: [joan]),
                ParcheSplitItem(amount: 100_000, participantIDs: [jesus]),
                ParcheSplitItem(amount: 50_000, participantIDs: [ana]),
                ParcheSplitItem(amount: 20_000, participantIDs: [carlos]),
            ]),
            payers: [ParchePayer(participantID: ana, amount: 220_000)], order: order, recordedBy: ana, at: hoursAgo(5))
        let lodging = try! ParcheExpense.resolve(
            id: UUID(uuidString: "00000000-0000-0000-0000-00000000E002")!, parcheID: santaMartaID,
            concept: "Hospedaje", base: 600_000, split: .shares([joan: 1, jesus: 1, ana: 1, carlos: 1]),
            payers: [
                ParchePayer(participantID: jesus, amount: 400_000), ParchePayer(participantID: joan, amount: 200_000),
            ], order: order, recordedBy: jesus, at: hoursAgo(60))
        let taxi = try! ParcheExpense.resolve(
            id: UUID(uuidString: "00000000-0000-0000-0000-00000000E003")!, parcheID: santaMartaID,
            concept: "Taxi al aeropuerto", base: 45_000, split: .equal([joan, jesus, ana]),
            payers: [ParchePayer(participantID: joan, amount: 45_000)], order: order, recordedBy: joan, at: hoursAgo(3))
        let pendingPayment = ParchePayment(
            id: UUID(uuidString: "00000000-0000-0000-0000-00000000F001")!, parcheID: santaMartaID, fromID: carlos,
            toID: joan, amount: 50_000, recordedBy: ana, createdAt: hoursAgo(4))
        let activity = [
            ParcheActivity(parcheID: santaMartaID, kind: .parcheCreated, actorID: joan, createdAt: hoursAgo(72)),
            ParcheActivity(
                parcheID: santaMartaID, kind: .participantJoined, actorID: jesus, participantID: jesus,
                createdAt: hoursAgo(71)),
            ParcheActivity(
                parcheID: santaMartaID, kind: .participantJoined, actorID: ana, participantID: ana,
                createdAt: hoursAgo(70)),
            ParcheActivity(
                parcheID: santaMartaID, kind: .participantAdded, actorID: jesus, participantID: carlos,
                createdAt: hoursAgo(69)),
            ParcheActivity(
                parcheID: santaMartaID, kind: .expenseCreated, actorID: jesus, recordedByID: jesus,
                amount: lodging.amount, concept: lodging.concept, createdAt: hoursAgo(60)),
            ParcheActivity(
                parcheID: santaMartaID, kind: .expenseCreated, actorID: ana, recordedByID: ana, amount: lunch.amount,
                concept: lunch.concept, createdAt: hoursAgo(5)),
            ParcheActivity(
                parcheID: santaMartaID, kind: .paymentRecorded, actorID: ana, participantID: carlos,
                otherParticipantID: joan, recordedByID: ana, amount: pendingPayment.amount, createdAt: hoursAgo(4)),
            ParcheActivity(
                parcheID: santaMartaID, kind: .expenseCreated, actorID: joan, recordedByID: joan, amount: taxi.amount,
                concept: taxi.concept, createdAt: hoursAgo(3)),
        ]
        return ParcheDetail(
            parche: parche, participants: participants, expenses: [lunch, lodging, taxi], payments: [pendingPayment],
            activity: activity)
    }

    private static func cena(reference: Date) -> ParcheDetail {
        func daysAgo(_ days: Double) -> Date { reference.addingTimeInterval(-days * 86_400) }
        let parche = Parche(
            id: cenaID, name: "Cena de Ana", code: "PCH-C3NA9B", status: .closed, createdAt: daysAgo(20),
            closedAt: daysAgo(19))
        let participants = [
            ParcheParticipant(
                id: UUID(uuidString: "00000000-0000-0000-0000-00000000C011")!, userID: anaUserID, displayName: "Ana",
                joinedAt: daysAgo(20), lastSeenAt: daysAgo(18), avatarColor: .green),
            ParcheParticipant(
                id: UUID(uuidString: "00000000-0000-0000-0000-00000000C012")!, userID: MockData.joan.id,
                displayName: "Joan", joinedAt: daysAgo(20), lastSeenAt: daysAgo(18), avatarColor: .yellow),
        ]
        let anaID = participants[0].id
        let joanID = participants[1].id
        let dinner = try! ParcheExpense.resolve(
            id: UUID(uuidString: "00000000-0000-0000-0000-00000000E011")!, parcheID: cenaID, concept: "Cena",
            base: 120_000, split: .equal([anaID, joanID]), payers: [ParchePayer(participantID: anaID, amount: 120_000)],
            order: [anaID, joanID], recordedBy: anaID, at: daysAgo(20))
        let payment = ParchePayment(
            id: UUID(uuidString: "00000000-0000-0000-0000-00000000F011")!, parcheID: cenaID, fromID: joanID,
            toID: anaID, amount: 60_000, recordedBy: anaID, createdAt: daysAgo(19), confirmedAt: daysAgo(19))
        let activity = [
            ParcheActivity(parcheID: cenaID, kind: .parcheCreated, actorID: anaID, createdAt: daysAgo(20)),
            ParcheActivity(parcheID: cenaID, kind: .parcheClosed, actorID: anaID, createdAt: daysAgo(19)),
        ]
        return ParcheDetail(
            parche: parche, participants: participants, expenses: [dinner], payments: [payment], activity: activity)
    }
}
