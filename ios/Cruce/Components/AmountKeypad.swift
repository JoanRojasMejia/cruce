import SwiftUI

/// Teclado numérico propio de la pantalla "Nuevo movimiento".
struct AmountKeypad: View {
    @Binding var digits: String
    var maxDigits: Int = 9

    private static let keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "000", "0", "⌫"]
    private static let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 3)

    var body: some View {
        LazyVGrid(columns: Self.columns, spacing: 6) {
            ForEach(Self.keys, id: \.self) { key in
                Button {
                    tap(key)
                } label: {
                    Group {
                        if key == "⌫" {
                            Image(systemName: "delete.left").font(.system(size: 20, weight: .semibold))
                        } else {
                            Text(key).font(.archivo(key == "000" ? 16 : 18, .extraBold))
                        }
                    }
                    .foregroundStyle(CruceColor.ink)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .neoSurface(radius: Radius.chip, border: BorderWidth.thin)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(key == "⌫" ? "Borrar" : key)
            }
        }
    }

    private func tap(_ key: String) {
        switch key {
        case "⌫":
            if !digits.isEmpty { digits.removeLast() }
        default:
            let next = digits + key
            let trimmed = String(next.drop { $0 == "0" })
            guard trimmed.count <= maxDigits else { return }
            digits = trimmed
        }
    }
}

#Preview {
    struct Wrapper: View {
        @State var digits = "60000"
        var body: some View {
            VStack {
                Text(Money.format(Money.parse(digits: digits))).textStyle(.amountMedium)
                AmountKeypad(digits: $digits)
            }
            .padding()
            .screenBackground()
        }
    }
    return Wrapper()
}
