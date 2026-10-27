import Foundation

/// Un cruce completo (de dos personas) de quien usa la app: con quién es y qué color y recibo tiene cada uno.
/// El color y el recibo son por cruce: quien creó ese cruce es amarillo y rosa, y quien se unió, violeta y verde.
public struct CruceLink: Identifiable, Equatable, Sendable {
    /// El id del cruce (`ledgers.id`).
    public let id: UUID
    public var partner: Member
    public var myAvatarColor: AvatarColor
    public var myTikeVariant: TikeVariant
    /// Cuándo se unió la segunda persona: el cruce más reciente es el que se completó último.
    public var linkedAt: Date

    public init(id: UUID, partner: Member, myAvatarColor: AvatarColor, myTikeVariant: TikeVariant, linkedAt: Date) {
        self.id = id
        self.partner = partner
        self.myAvatarColor = myAvatarColor
        self.myTikeVariant = myTikeVariant
        self.linkedAt = linkedAt
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

        enum CodingKeys: String, CodingKey {
            case ledgerId = "ledger_id"
            case partnerId = "partner_id"
            case partnerName = "partner_name"
            case myTike = "my_tike"
            case myAvatar = "my_avatar"
            case partnerTike = "partner_tike"
            case partnerAvatar = "partner_avatar"
            case linkedAt = "linked_at"
        }
    }

    /// Las filas de `my_cruces()`, en el mismo orden (del más reciente al más viejo).
    public static func cruceLinks(from data: Data) throws -> [CruceLink] {
        try ParcheRemote.decoder().decode([CruceRow].self, from: data).map { row in
            CruceLink(
                id: row.ledgerId,
                partner: Member(
                    id: row.partnerId, name: row.partnerName, avatarColor: row.partnerAvatar,
                    tikeVariant: row.partnerTike),
                myAvatarColor: row.myAvatar, myTikeVariant: row.myTike, linkedAt: row.linkedAt)
        }
    }
}
