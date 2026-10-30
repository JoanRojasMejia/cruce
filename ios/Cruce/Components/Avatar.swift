import CruceCore
import SwiftUI

extension AvatarColor {
    /// El token de `CruceColor` con el mismo nombre.
    var color: Color {
        switch self {
        case .yellow: return CruceColor.yellow
        case .violet: return CruceColor.violet
        case .green: return CruceColor.green
        case .peach: return CruceColor.peach
        case .pink: return CruceColor.pink
        case .lime: return CruceColor.lime
        }
    }

    /// Nombre para VoiceOver y para "Tu perfil".
    var title: String {
        switch self {
        case .yellow: return "Amarillo"
        case .violet: return "Violeta"
        case .green: return "Verde"
        case .peach: return "Durazno"
        case .pink: return "Rosado"
        case .lime: return "Lima"
        }
    }
}

/// Avatar circular con iniciales ("Jo", "Je"), con el color fijo de la persona.
struct Avatar: View {
    let member: Member
    var size: CGFloat = 44
    var shadow: CGFloat = 0
    var label: String?

    var body: some View {
        Text(label ?? member.initials)
            .font(.archivo(size * 0.36, .black))
            .foregroundStyle(CruceColor.ink)
            .frame(width: size, height: size)
            .background(Circle().fill(member.avatarColor.color))
            .overlay(
                Circle().strokeBorder(CruceColor.ink, lineWidth: size >= 40 ? BorderWidth.regular : BorderWidth.thin)
            )
            .background(Circle().fill(CruceColor.ink).offset(x: shadow, y: shadow))
            .accessibilityLabel(member.name)
    }
}

#Preview {
    HStack {
        Avatar(member: MockData.joan)
        Avatar(member: MockData.jesus, size: 60, shadow: 3)
    }
    .padding()
    .screenBackground()
}
