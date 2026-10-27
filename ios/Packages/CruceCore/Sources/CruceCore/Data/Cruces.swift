import Foundation

/// Un cruce completo (de dos personas) de quien usa la app: con quién es y qué color y recibo tiene cada uno.
/// El color y el recibo son por cruce: quien creó ese cruce es amarillo y rosa, y quien se unió, violeta y verde.
public struct CruceLink: Identifiable, Codable, Equatable, Sendable {
    /// El id del cruce (`ledgers.id`).
    public let id: UUID
    public var partner: Member
    public var myAvatarColor: AvatarColor
    public var myTikeVariant: TikeVariant
    /// Cuándo se unió la segunda persona: el cruce más reciente es el que se completó último.
    public var linkedAt: Date
    /// Cuándo se cerró (al desvincular), o `nil` si sigue abierto. Un cruce cerrado es de solo lectura.
    public var closedAt: Date?
    /// Lo que le toca a quien no pagó, en %, al anotar un movimiento nuevo (`ledgers.default_other_percent`).
    public var defaultOtherPercent: Int

    /// El reparto por defecto de un cruce nuevo: mitad y mitad.
    public static let standardOtherPercent = 50

    public var isClosed: Bool { closedAt != nil }

    public init(
        id: UUID, partner: Member, myAvatarColor: AvatarColor, myTikeVariant: TikeVariant, linkedAt: Date,
        closedAt: Date? = nil, defaultOtherPercent: Int = CruceLink.standardOtherPercent
    ) {
        self.id = id
        self.partner = partner
        self.myAvatarColor = myAvatarColor
        self.myTikeVariant = myTikeVariant
        self.linkedAt = linkedAt
        self.closedAt = closedAt
        self.defaultOtherPercent = defaultOtherPercent
    }

    private enum CodingKeys: String, CodingKey {
        case id, partner, myAvatarColor, myTikeVariant, linkedAt, closedAt, defaultOtherPercent
    }

    /// Una sesión guardada antes del CP11 (`sesion.json`) no trae `closedAt` ni `defaultOtherPercent`: se leen como
    /// abierto y 50 %.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        partner = try container.decode(Member.self, forKey: .partner)
        myAvatarColor = try container.decode(AvatarColor.self, forKey: .myAvatarColor)
        myTikeVariant = try container.decode(TikeVariant.self, forKey: .myTikeVariant)
        linkedAt = try container.decode(Date.self, forKey: .linkedAt)
        closedAt = try container.decodeIfPresent(Date.self, forKey: .closedAt)
        defaultOtherPercent =
            try container.decodeIfPresent(Int.self, forKey: .defaultOtherPercent) ?? Self.standardOtherPercent
    }
}

/// Por qué la base rechazó un código `CRZ-` (el campo `error` de `preview_invite` y `redeem_invite`).
public enum InviteRejection: String, Equatable, Sendable {
    /// No existe, venció o ya se usó.
    case invalid
    /// Es el código de quien lo usa.
    case own
    /// 5 intentos fallidos en la última hora.
    case tooManyAttempts = "too_many_attempts"
    /// Ya hay un cruce con quien invitó (un cruce por pareja).
    case alreadyLinked = "already_linked"
}

/// Resultado de ver o canjear un código: de quién es, o por qué no sirve con el mensaje de la base.
public enum InviteCheck: Equatable, Sendable {
    case valid(inviterName: String)
    case rejected(InviteRejection, message: String)
}

/// Traducción del JSON de las funciones de vinculación (`preview_invite`, `redeem_invite` y `my_cruces`).
/// No depende de supabase-swift, así se prueba con `swift test`.
public enum CruceRemote {
    /// Mensaje de respaldo si la base no manda uno.
    static let invalidMessage = "El código no es válido o ya venció"

    private struct InviteResponse: Decodable {
        let ok: Bool
        let inviterName: String?
        let error: String?
        let message: String?

        enum CodingKeys: String, CodingKey {
            case ok, error, message
            case inviterName = "inviter_name"
        }
    }

    /// `{"ok": true, "inviter_name"}` o `{"ok": false, "error", "message"}`. Un `error` que la app no conoce se trata
    /// como código inválido, con el mensaje que mandó la base.
    public static func inviteCheck(from data: Data) throws -> InviteCheck {
        let response = try JSONDecoder().decode(InviteResponse.self, from: data)
        if response.ok {
            guard let name = response.inviterName else {
                throw DecodingError.dataCorrupted(
                    .init(codingPath: [], debugDescription: "Falta inviter_name en una respuesta correcta"))
            }
            return .valid(inviterName: name)
        }
        let kind = response.error.flatMap(InviteRejection.init(rawValue:)) ?? .invalid
        return .rejected(kind, message: response.message ?? invalidMessage)
    }

    private struct CruceRow: Decodable {
        let ledgerId: UUID
        let partnerId: UUID
        let partnerName: String
        let myTike: TikeVariant
        let myAvatar: AvatarColor
        let partnerTike: TikeVariant
        let partnerAvatar: AvatarColor
        let linkedAt: Date
        let closedAt: Date?
        let defaultOtherPercent: Int?

        enum CodingKeys: String, CodingKey {
            case ledgerId = "ledger_id"
            case partnerId = "partner_id"
            case partnerName = "partner_name"
            case myTike = "my_tike"
            case myAvatar = "my_avatar"
            case partnerTike = "partner_tike"
            case partnerAvatar = "partner_avatar"
            case linkedAt = "linked_at"
            case closedAt = "closed_at"
            case defaultOtherPercent = "default_other_percent"
        }
    }

    /// La fecha que devuelve `close_cruce` (un `timestamptz` en JSON).
    public static func closedAt(from data: Data) throws -> Date {
        try ParcheRemote.decoder().decode(Date.self, from: data)
    }

    /// Las filas de `my_cruces()`, en el mismo orden (los abiertos primero, cada grupo del más reciente al más viejo).
    public static func cruceLinks(from data: Data) throws -> [CruceLink] {
        try ParcheRemote.decoder().decode([CruceRow].self, from: data).map { row in
            CruceLink(
                id: row.ledgerId,
                partner: Member(
                    id: row.partnerId, name: row.partnerName, avatarColor: row.partnerAvatar,
                    tikeVariant: row.partnerTike),
                myAvatarColor: row.myAvatar, myTikeVariant: row.myTike, linkedAt: row.linkedAt,
                closedAt: row.closedAt, defaultOtherPercent: row.defaultOtherPercent ?? CruceLink.standardOtherPercent)
        }
    }
}
