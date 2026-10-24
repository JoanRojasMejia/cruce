import SwiftUI

/// Botón cuadrado de ícono (volver, ajustes, editar).
struct IconButton: View {
    let systemName: String
    let accessibilityLabel: String
    var size: CGFloat = 40
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size * 0.45, weight: .bold))
                .foregroundStyle(CruceColor.ink)
                .frame(width: size, height: size)
                .neoSurface(radius: 12, shadow: ShadowOffset.s)
        }
        .buttonStyle(.plain)
        .frame(minWidth: Spacing.minTouch, minHeight: Spacing.minTouch)
        .accessibilityLabel(accessibilityLabel)
    }
}

/// Botón de volver que cierra la pantalla actual.
struct BackButton: View {
    @Environment(\.dismiss) private var dismiss
    var action: (() -> Void)?

    init(action: (() -> Void)? = nil) {
        self.action = action
    }

    var body: some View {
        IconButton(systemName: "arrow.left", accessibilityLabel: "Volver") {
            if let action { action() } else { dismiss() }
        }
    }
}

/// Encabezado con botón de volver y título.
/// Contenido de pantalla completa que ocupa al menos el alto disponible (los `Spacer` siguen empujando
/// los botones hacia abajo) y hace scroll solo si no cabe: iPhone SE o texto grande.
struct FittingScroll<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                content.frame(minHeight: proxy.size.height, alignment: .top)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
        }
    }
}

struct ScreenHeader<Trailing: View>: View {
    let title: String
    var onBack: (() -> Void)?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            BackButton(action: onBack)
            Text(title)
                .textStyle(.title2)
                .foregroundStyle(CruceColor.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
            trailing
        }
    }
}

extension ScreenHeader where Trailing == EmptyView {
    init(title: String, onBack: (() -> Void)? = nil) {
        self.init(title: title, onBack: onBack) { EmptyView() }
    }
}

/// Chip seleccionable (categorías, filtros).
struct Chip: View {
    let title: String
    var isSelected: Bool
    var selectedColor: Color = CruceColor.ink
    var dotColor: Color?
    /// Mini avatar en lugar del punto de color (filtros por persona).
    var member: Member?
    /// Check al estar seleccionado con color (categorías); el filtro "Todas" no lo lleva.
    var showsCheck: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isSelected && selectedColor != CruceColor.ink && showsCheck {
                    Image(systemName: "checkmark").font(.system(size: 11, weight: .black))
                } else if let member {
                    Avatar(member: member, size: 18)
                } else if let dotColor {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(dotColor)
                        .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(CruceColor.ink, lineWidth: 1.5))
                        .frame(width: 10, height: 10)
                }
                Text(title)
                    .font(.archivo(13, isSelected ? .extraBold : .bold))
            }
            .foregroundStyle(isSelected && selectedColor == CruceColor.ink ? .white : CruceColor.ink)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .neoSurface(
                fill: isSelected ? selectedColor : CruceColor.surface,
                radius: Radius.chip,
                border: isSelected ? BorderWidth.regular : BorderWidth.thin,
                shadow: isSelected && selectedColor != CruceColor.ink ? ShadowOffset.xs : 0
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Control segmentado (quién pagó, reparto, medio de pago).
struct NeoSegmented<Option: Hashable>: View {
    let options: [Option]
    @Binding var selection: Option
    let title: (Option) -> String
    var height: CGFloat = 34

    var body: some View {
        HStack(spacing: 3) {
            ForEach(options, id: \.self) { option in
                let selected = option == selection
                Button {
                    selection = option
                } label: {
                    Text(title(option))
                        .font(.archivo(13, selected ? .extraBold : .bold))
                        .foregroundStyle(selected ? .white : CruceColor.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, minHeight: height)
                        .background(RoundedRectangle(cornerRadius: 8).fill(selected ? CruceColor.ink : .clear))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(3)
        .neoSurface(radius: Radius.input)
    }
}

/// Campo de texto con etiqueta.
struct NeoTextField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var fill: Color = CruceColor.surface
    /// Opcional: para que la pantalla sepa cuándo se está escribiendo (por ejemplo, para ocultar su teclado propio).
    var focus: FocusState<Bool>.Binding?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).textStyle(.fieldLabel)
            field
                .font(.archivo(15, .bold))
                .padding(.horizontal, 14)
                .frame(height: 44)
                .neoSurface(fill: fill, radius: Radius.input)
                .accessibilityLabel(label)
        }
        .foregroundStyle(CruceColor.ink)
    }

    @ViewBuilder
    private var field: some View {
        if let focus {
            TextField(placeholder, text: $text).focused(focus)
        } else {
            TextField(placeholder, text: $text)
        }
    }
}

/// Estilo de switch neobrutalista.
struct NeoToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer()
            Button {
                configuration.isOn.toggle()
            } label: {
                Capsule()
                    .fill(configuration.isOn ? CruceColor.green : CruceColor.neutral)
                    .overlay(Capsule().strokeBorder(CruceColor.ink, lineWidth: BorderWidth.regular))
                    .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                        Circle()
                            .fill(.white)
                            .overlay(Circle().strokeBorder(CruceColor.ink, lineWidth: BorderWidth.thin))
                            .frame(width: 20, height: 20)
                            .padding(.horizontal, 5)
                    }
                    .frame(width: 52, height: 30)
                    .animation(.easeOut(duration: 0.15), value: configuration.isOn)
            }
            .buttonStyle(.plain)
            .accessibilityValue(configuration.isOn ? "Activado" : "Desactivado")
        }
    }
}

/// Indicador de páginas del onboarding.
struct PageDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == current ? CruceColor.ink : CruceColor.surface)
                    .overlay(Capsule().strokeBorder(CruceColor.ink, lineWidth: BorderWidth.thin))
                    .frame(width: index == current ? 28 : 10, height: 10)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Paso \(current + 1) de \(count)")
    }
}

/// Insignia pequeña ("1 de 3", "Sin conexión").
struct Badge: View {
    let text: String
    var fill: Color = CruceColor.surface

    var body: some View {
        Text(text)
            .font(.archivo(12, .extraBold))
            .foregroundStyle(CruceColor.ink)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .neoSurface(fill: fill, radius: 8, border: BorderWidth.thin)
    }
}

/// Par de cajas "Antes / Después" que muestran cómo cambia el saldo.
struct BeforeAfter: View {
    let beforeTitle: String
    let before: String
    let afterTitle: String
    let after: String
    var afterColor: Color = CruceColor.lime
    /// Relleno de la caja punteada: transparente sobre crema, blanco dentro de diálogos.
    var beforeFill: Color = .clear

    var body: some View {
        // Las dos cajas con el mismo alto y el texto arriba, aunque una frase ocupe más líneas.
        HStack(spacing: 10) {
            box(title: beforeTitle, value: before)
                .neoSurface(fill: beforeFill, radius: Radius.input, border: BorderWidth.thin, dashed: true)
            box(title: afterTitle, value: after)
                .neoSurface(fill: afterColor, radius: Radius.input)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func box(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.archivo(11, .extraBold)).tracking(1)
            Text(value).font(.archivo(14, .extraBold)).fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(CruceColor.ink)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
