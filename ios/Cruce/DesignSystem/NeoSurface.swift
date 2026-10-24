import SwiftUI

/// Superficie neobrutalista: relleno plano, borde de tinta y sombra sólida desplazada.
struct NeoSurface: ViewModifier {
    var fill: Color = CruceColor.surface
    var radius: CGFloat = Radius.card
    var border: CGFloat = BorderWidth.regular
    var shadow: CGFloat = 0
    var shadowColor: Color = CruceColor.ink
    var dashed: Bool = false

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .circular)
        content
            .background(shape.fill(fill))
            .overlay(
                shape.strokeBorder(
                    CruceColor.ink,
                    style: StrokeStyle(lineWidth: border, dash: dashed ? [6, 5] : [])
                )
            )
            // Sin sombra no se pinta nada detrás: con relleno transparente se vería un bloque de tinta.
            .background(
                shape.fill(shadow > 0 ? shadowColor : .clear).offset(x: shadow, y: shadow)
            )
    }
}

extension View {
    func neoSurface(
        fill: Color = CruceColor.surface,
        radius: CGFloat = Radius.card,
        border: CGFloat = BorderWidth.regular,
        shadow: CGFloat = 0,
        shadowColor: Color = CruceColor.ink,
        dashed: Bool = false
    ) -> some View {
        modifier(NeoSurface(fill: fill, radius: radius, border: border, shadow: shadow, shadowColor: shadowColor, dashed: dashed))
    }

    /// Fondo crema de pantalla completa.
    func screenBackground(_ color: Color = CruceColor.cream) -> some View {
        background(color.ignoresSafeArea())
    }
}
