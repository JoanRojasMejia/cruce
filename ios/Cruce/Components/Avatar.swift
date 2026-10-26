import SwiftUI
import CruceCore

extension AvatarColor {
    var color: Color {
        switch self {
        case .yellow: return CruceColor.yellow
        case .violet: return CruceColor.violet
        }
    }
}

/// Avatar circular con iniciales ("Jo", "Je").
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
            .overlay(Circle().strokeBorder(CruceColor.ink, lineWidth: size >= 40 ? BorderWidth.regular : BorderWidth.thin))
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
