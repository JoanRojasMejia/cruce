import CruceCore
import SwiftUI

/// Piezas comunes de los Ajustes de la cuenta y de los Ajustes del cruce.

/// Sección con su rótulo ("TU CUENTA", "DATOS") y una tarjeta con las filas.
struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).textStyle(.label).padding(.leading, 4)
            VStack(spacing: 0) { content }
                .padding(.horizontal, 14)
                .neoSurface(radius: Radius.button)
        }
    }
}

/// Fila de alto mínimo 48 pt.
struct SettingsRow<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 10) { content }.frame(minHeight: 48)
    }
}

/// Línea entre filas.
struct SettingsDivider: View {
    var body: some View {
        Rectangle().fill(CruceColor.line).frame(height: 1.5)
    }
}

/// Fila de una acción: ícono a la izquierda y texto. Con `tint` es una acción delicada (cuadro de color).
struct SettingsActionLabel: View {
    let title: String
    let systemImage: String
    var tint: Color = CruceColor.ink
    /// Lleva la flecha de "abre otra pantalla".
    var showsChevron = false

    var body: some View {
        HStack(spacing: 10) {
            Group {
                if tint == CruceColor.ink {
                    Image(systemName: systemImage).font(.system(size: 16, weight: .bold))
                } else {
                    // Acción delicada: cuadro de color con borde y símbolo en tinta, como en el diseño.
                    Image(systemName: systemImage)
                        .font(.system(size: 10, weight: .black))
                        .frame(width: 20, height: 20)
                        .background(RoundedRectangle(cornerRadius: 5).fill(tint))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5).strokeBorder(
                                CruceColor.ink, lineWidth: BorderWidth.thin))
                }
            }
            // Ancho fijo para que los textos de las filas queden alineados.
            .frame(width: 24)
            Text(title).font(.archivo(15, tint == CruceColor.ink ? .bold : .extraBold))
            Spacer()
            if showsChevron {
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .heavy))
            }
        }
        .foregroundStyle(CruceColor.ink)
        .frame(minHeight: 48)
        .contentShape(Rectangle())
    }
}

/// Botón con el aspecto de `SettingsActionLabel`.
struct SettingsActionRow: View {
    let title: String
    let systemImage: String
    var tint: Color = CruceColor.ink
    var showsChevron = false
    let action: () -> Void

    init(
        _ title: String, systemImage: String, tint: Color = CruceColor.ink, showsChevron: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.showsChevron = showsChevron
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            SettingsActionLabel(title: title, systemImage: systemImage, tint: tint, showsChevron: showsChevron)
        }
        .buttonStyle(.plain)
    }
}
