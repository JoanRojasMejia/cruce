import SwiftUI

/// Botón neobrutalista. Al presionar, el botón baja hasta tapar su sombra.
struct NeoButtonStyle: ButtonStyle {
    enum Kind {
        /// Amarillo con texto negro.
        case primary
        /// Blanco con texto negro.
        case secondary
        /// Rosa con texto negro (eliminar, desvincular).
        case destructive
        /// Negro con texto blanco y sombra blanca, para fondos de color.
        case dark
    }

    var kind: Kind = .primary
    var height: CGFloat = 56
    var shadow: CGFloat = ShadowOffset.m
    var radius: CGFloat = Radius.button
    /// Estilo del texto; por defecto `.button` en primario y oscuro, `.buttonSecondary` en el resto.
    /// Los botones que van lado a lado usan `.buttonSecondary` aunque sean primarios.
    var text: TextStyleToken?
    /// Color de la sombra cuando no es el del tipo (por ejemplo, amarilla en "Continuar con Apple").
    var shadowTint: Color?

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let shape = RoundedRectangle(cornerRadius: radius, style: .circular)
        return configuration.label
            .textStyle(text ?? (kind == .primary || kind == .dark ? .button : .buttonSecondary))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            // Deshabilitado: se apagan el relleno y el texto, pero el borde y la sombra siguen en tinta.
            .foregroundStyle(foreground.opacity(isEnabled ? 1 : 0.45))
            .frame(maxWidth: .infinity, minHeight: height)
            .background(shape.fill(isEnabled ? background : CruceColor.surface))
            .overlay(shape.strokeBorder(CruceColor.ink, lineWidth: BorderWidth.regular))
            .offset(x: pressed ? shadow : 0, y: pressed ? shadow : 0)
            .background(shape.fill(shadowTint ?? shadowColor).offset(x: shadow, y: shadow))
            .contentShape(shape)
            .animation(.easeOut(duration: 0.08), value: pressed)
    }

    private var background: Color {
        switch kind {
        case .primary: return CruceColor.yellow
        case .secondary: return CruceColor.surface
        case .destructive: return CruceColor.pink
        case .dark: return CruceColor.ink
        }
    }

    private var foreground: Color {
        kind == .dark ? .white : CruceColor.ink
    }

    private var shadowColor: Color {
        kind == .dark ? .white : CruceColor.ink
    }
}

extension ButtonStyle where Self == NeoButtonStyle {
    static var neoPrimary: NeoButtonStyle { NeoButtonStyle(kind: .primary) }
    static var neoSecondary: NeoButtonStyle { NeoButtonStyle(kind: .secondary, height: 54) }
    static var neoDestructive: NeoButtonStyle { NeoButtonStyle(kind: .destructive, height: 54) }
    static var neoDark: NeoButtonStyle { NeoButtonStyle(kind: .dark, shadow: ShadowOffset.l) }
}

/// Botón de texto subrayado ("Ya tengo una cuenta", "Saltar").
struct LinkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.archivo(15, .extraBold))
            .underline()
            .foregroundStyle(CruceColor.ink)
            .frame(maxWidth: .infinity, minHeight: Spacing.minTouch)
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

extension ButtonStyle where Self == LinkButtonStyle {
    static var neoLink: LinkButtonStyle { LinkButtonStyle() }
}
