import CruceCore
import SwiftUI

/// Teclado de Cruce para el monto principal (1 a 9, `000`, `0` y borrar). La regla de cada tecla vive en
/// `AmountEntry`; después de cada tecla, VoiceOver anuncia el monto nuevo ("Monto: 60000 pesos").
struct AmountKeypad: View {
    @Binding var amount: Int

    private static let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 3)

    var body: some View {
        LazyVGrid(columns: Self.columns, spacing: 6) {
            ForEach(AmountKey.layout, id: \.self) { key in
                Button {
                    tap(key)
                } label: {
                    Group {
                        if key == .delete {
                            Image(systemName: "delete.left").font(.system(size: 20, weight: .semibold))
                        } else {
                            Text(key.title).font(.archivo(key == .tripleZero ? 16 : 18, .extraBold))
                        }
                    }
                    .foregroundStyle(CruceColor.ink)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .neoSurface(radius: Radius.chip, border: BorderWidth.thin)
                    // Se ven de 40 pt como en el diseño, pero el área táctil sigue siendo de 44 pt.
                    .contentShape(Rectangle().inset(by: -2))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(key.accessibilityLabel)
            }
        }
    }

    private func tap(_ key: AmountKey) {
        amount = AmountEntry.press(key, on: amount)
        AccessibilityNotification.Announcement(AmountEntry.announcement(amount)).post()
    }
}

#if DEBUG
    #Preview {
        struct Wrapper: View {
            @State var amount = 60_000
            var body: some View {
                VStack {
                    Text(Money.format(amount)).textStyle(.amountMedium)
                    AmountKeypad(amount: $amount)
                }
                .padding()
                .screenBackground()
            }
        }
        return Wrapper()
    }
#endif
