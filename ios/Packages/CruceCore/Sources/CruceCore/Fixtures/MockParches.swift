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

    /// Ana y Joan dentro de "Cena de Ana".
    public static let cenaAna = UUID(uuidString: "00000000-0000-0000-0000-00000000C011")!
    public static let cenaJoan = UUID(uuidString: "00000000-0000-0000-0000-00000000C012")!

    /// "Finca" (solo Debug y pruebas, fuera de `parches()`): Joan, Yisus, Laura y Nata (sin la app). Yisus pagó el
    /// mercado de $516.000 y Nata el Uber de $114.000, los dos entre los cuatro. Saldos: Joan y Laura −$157.500,
    /// Nata −$43.500 y Yisus +$358.500; en "Para saldar" los tres le pagan a Yisus.
    public static let fincaID = UUID(uuidString: "00000000-0000-0000-0000-00000000B003")!
    public static let fincaJoan = UUID(uuidString: "00000000-0000-0000-0000-00000000C021")!
    public static let fincaYisus = UUID(uuidString: "00000000-0000-0000-0000-00000000C022")!
    public static let fincaLaura = UUID(uuidString: "00000000-0000-0000-0000-00000000C023")!
    public static let fincaNata = UUID(uuidString: "00000000-0000-0000-0000-00000000C024")!
    /// La cuenta de Laura (tiene la app).
    public static let lauraUserID = UUID(uuidString: "00000000-0000-0000-0000-0000000000A5")!

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
        // Joan lo creó: solo él lo cierra.
        let parche = Parche(
            id: santaMartaID, name: "Santa Marta", code: "PCH-SM4R7A", createdAt: hoursAgo(72), createdBy: joan)
        let participants = [
            ParcheParticipant(
                id: joan, userID: MockData.joan.id, displayName: "Joan", joinedAt: hoursAgo(72),
                lastSeenAt: hoursAgo(10), avatarColor: .yellow, username: "joan"),
            ParcheParticipant(
                id: jesus, userID: MockData.jesus.id, displayName: "Jesús", joinedAt: hoursAgo(71),
                lastSeenAt: hoursAgo(1), avatarColor: .violet, username: "jesus"),
            ParcheParticipant(
                id: ana, userID: anaUserID, displayName: "Ana", joinedAt: hoursAgo(70), lastSeenAt: hoursAgo(2),
                avatarColor: .green, username: "ana"),
            ParcheParticipant(
                id: carlos, displayName: "Carlos", claimCode: "SOY-K7QX2M", joinedAt: hoursAgo(69), avatarColor: .peach),
        ]
        let order = participants.map(\.id)
        // El almuerzo de la spec: por consumo con 10 % de propina, pagado por Ana.
        let lunch = try! ParcheExpense.resolve(
            id: UUID(uuidString: "00000000-0000-0000-0000-00000000E001")!, parcheID: santaMartaID,
            concept: "Almuerzo en Taganga", base: 200_000, tipPercent: 10,
            split: .items([
                ParcheSplitItem(amount: 30_000, participantIDs: [joan], name: "Arroz de coco"),
                ParcheSplitItem(amount: 100_000, participantIDs: [jesus], name: "Langosta"),
                ParcheSplitItem(amount: 50_000, participantIDs: [ana], name: "Cazuela"),
                ParcheSplitItem(amount: 20_000, participantIDs: [carlos], name: "Mojarra"),
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

    /// El parche "Finca" (ver `fincaID`), abierto y creado por Joan.
    public static func finca(reference: Date = .now) -> ParcheDetail {
        func hoursAgo(_ hours: Double) -> Date { reference.addingTimeInterval(-hours * 3_600) }
        let parche = Parche(
            id: fincaID, name: "Finca", code: "PCH-FNC4XQ", createdAt: hoursAgo(30), createdBy: fincaJoan)
        let participants = [
            ParcheParticipant(
                id: fincaJoan, userID: MockData.joan.id, displayName: "Joan", joinedAt: hoursAgo(30),
                lastSeenAt: hoursAgo(1), avatarColor: .yellow),
            ParcheParticipant(
                id: fincaYisus, userID: MockData.jesus.id, displayName: "Yisus", joinedAt: hoursAgo(29),
                lastSeenAt: hoursAgo(1), avatarColor: .violet),
            ParcheParticipant(
                id: fincaLaura, userID: lauraUserID, displayName: "Laura", joinedAt: hoursAgo(28),
                lastSeenAt: hoursAgo(2), avatarColor: .green),
            ParcheParticipant(
                id: fincaNata, displayName: "Nata", claimCode: "SOY-N4T4QZ", joinedAt: hoursAgo(27),
                avatarColor: .peach),
        ]
        let order = participants.map(\.id)
        let everyone: Set<UUID> = [fincaJoan, fincaYisus, fincaLaura, fincaNata]
        let market = try! ParcheExpense.resolve(
            id: UUID(uuidString: "00000000-0000-0000-0000-00000000E021")!, parcheID: fincaID, concept: "Mercado",
            base: 516_000, split: .equal(everyone), payers: [ParchePayer(participantID: fincaYisus, amount: 516_000)],
            order: order, recordedBy: fincaYisus, at: hoursAgo(26))
        let uber = try! ParcheExpense.resolve(
            id: UUID(uuidString: "00000000-0000-0000-0000-00000000E022")!, parcheID: fincaID, concept: "Uber",
            base: 114_000, split: .equal(everyone), payers: [ParchePayer(participantID: fincaNata, amount: 114_000)],
            order: order, recordedBy: fincaJoan, at: hoursAgo(25))
        return ParcheDetail(parche: parche, participants: participants, expenses: [market, uber])
    }

    private static func cena(reference: Date) -> ParcheDetail {
        func daysAgo(_ days: Double) -> Date { reference.addingTimeInterval(-days * 86_400) }
        let parche = Parche(
            id: cenaID, name: "Cena de Ana", code: "PCH-C3NA9B", status: .closed, createdAt: daysAgo(20),
            closedAt: daysAgo(19), createdBy: cenaAna)
        let participants = [
            ParcheParticipant(
                id: cenaAna, userID: anaUserID, displayName: "Ana",
                joinedAt: daysAgo(20), lastSeenAt: daysAgo(18), avatarColor: .green),
            ParcheParticipant(
                id: cenaJoan, userID: MockData.joan.id,
                displayName: "Joan", joinedAt: daysAgo(20), lastSeenAt: daysAgo(18), avatarColor: .yellow),
        ]
        let anaID = cenaAna
        let joanID = cenaJoan
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
