import CruceCore
import SwiftUI

extension MovementCategory {
    /// Color de la categoría en íconos y chips.
    var color: Color {
        switch self {
        case .comida: return CruceColor.pink
        case .mercado: return CruceColor.green
        case .transporte: return CruceColor.peach
        case .hogar: return CruceColor.yellow
        case .ocio: return CruceColor.violet
        case .prestamo: return CruceColor.lime
        case .otro: return CruceColor.neutral
        }
    }
}

/// Cuadro de color con el ícono de la categoría.
struct CategoryIcon: View {
    let category: MovementCategory
    var kind: Movement.Kind = .expense
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: kind == .settlement ? "checkmark" : category.symbol)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(CruceColor.ink)
            .frame(width: size, height: size)
            .neoSurface(
                fill: kind == .settlement ? CruceColor.lime : category.color,
                radius: size / 4,
                border: BorderWidth.thin
            )
            .accessibilityHidden(true)
    }
}

#Preview {
    HStack {
        ForEach(MovementCategory.allCases) { CategoryIcon(category: $0) }
    }
    .padding()
    .screenBackground()
}
