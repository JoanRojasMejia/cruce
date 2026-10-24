import SwiftUI

/// Fila de un movimiento con su efecto en el saldo.
/// La dirección nunca depende solo del color: lleva signo, texto y flecha.
struct MovementRow: View {
    let movement: Movement
    /// Efecto en el saldo de quien usa la app.
    let impact: Int
    let payerName: String
    let partnerName: String
    let isPayerMe: Bool
    var dateText: String?
    var compact: Bool = false
    /// Nombre de quien usa la app. Si se pasa, el subtítulo nombra a ambos como en el historial
    /// ("Pagó Joan · $36.000 · 50/50"); si no, habla en segunda persona ("Pagaste $36.000").
    var viewerName: String?

    var body: some View {
        HStack(spacing: 12) {
            CategoryIcon(category: movement.category, kind: movement.kind, size: compact ? 36 : 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(movement.concept)
                    .textStyle(.rowTitle)
                    .lineLimit(2)
                Text(subtitle)
                    .textStyle(.secondary)
                    .foregroundStyle(CruceColor.textSecondary)
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 3) {
                    if compact {
                        Image(systemName: impact >= 0 ? "arrow.down.left" : "arrow.up.right")
                            .font(.system(size: 11, weight: .heavy))
                    }
                    Text(Money.format(impact, showsSign: true))
                        .font(.archivo(15, .black))
                }
                Text(impact >= 0 ? "a tu favor" : "a favor de \(partnerName)")
                    .font(.archivo(11, .bold))
                    .foregroundStyle(CruceColor.textSecondary)
            }
        }
        .foregroundStyle(CruceColor.ink)
        .padding(.horizontal, 12)
        .padding(.vertical, compact ? 9 : 10)
        .neoSurface(
            radius: compact ? 12 : Radius.button,
            border: compact ? BorderWidth.thin : BorderWidth.regular,
            shadow: compact ? ShadowOffset.xs : ShadowOffset.s
        )
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        var parts: [String]
        let other: String
        if let viewerName {
            parts = ["Pagó \(payerName)", Money.format(movement.amount)]
            other = isPayerMe ? partnerName : viewerName
        } else {
            parts = ["\(isPayerMe ? "Pagaste" : "\(payerName) pagó") \(Money.format(movement.amount))"]
            other = isPayerMe ? partnerName : "ti"
        }
        if movement.kind == .expense {
            parts.append(movement.split == .fullOther ? "todo de \(other)" : movement.split.title)
        }
        if let dateText { parts.append(dateText) }
        return parts.joined(separator: " · ")
    }
}

#Preview {
    let movement = MockData.movements().last!
    return MovementRow(
        movement: movement,
        impact: 18_000,
        payerName: "Joan",
        partnerName: "Jesús",
        isPayerMe: true,
        dateText: "Hoy"
    )
    .padding()
    .screenBackground()
}
