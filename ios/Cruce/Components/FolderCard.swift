import SwiftUI

/// Tarjeta tipo carpeta: pestaña de color arriba a la izquierda y tarjeta con sombra.
/// Es la pieza central del saldo neto.
struct FolderCard<Content: View>: View {
    let tab: String
    var tabColor: Color = CruceColor.green
    var tabWidth: CGFloat = 150
    var fill: Color = CruceColor.surface
    var shadow: CGFloat = ShadowOffset.xl
    var padding: EdgeInsets = EdgeInsets(top: 16, leading: 18, bottom: 18, trailing: 18)
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: -BorderWidth.regular) {
            Text(tab)
                .textStyle(.label)
                .foregroundStyle(CruceColor.ink)
                .lineLimit(1)
                .fixedSize()
                .padding(.leading, 12)
                .padding(.trailing, 16)
                // Ancho del diseño como mínimo; crece si el texto es más grande (Dynamic Type).
                .frame(minWidth: tabWidth, minHeight: 26, alignment: .leading)
                .background(tabShape.fill(tabColor))
                .overlay(tabShape.stroke(CruceColor.ink, lineWidth: BorderWidth.regular))
                .padding(.leading, 14)

            content
                .padding(padding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .neoSurface(fill: fill, radius: Radius.card, shadow: shadow)
        }
    }

    private var tabShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 10, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 14)
    }
}

#Preview {
    FolderCard(tab: "SALDO NETO") {
        VStack(alignment: .leading) {
            Text("Jesús te debe").textStyle(.balancePhrase)
            Text("$20.000").textStyle(.amount)
        }
    }
    .padding()
    .screenBackground()
}
