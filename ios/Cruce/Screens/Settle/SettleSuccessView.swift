import SwiftUI

/// "¡A paz y salvo!" después de saldar (pantalla 09).
struct SettleSuccessView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    let payment: Movement

    init(payment: Movement) {
        self.payment = payment
    }

    var body: some View {
        ZStack {
            CruceColor.yellow.ignoresSafeArea()
            decorations

            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    IllustrationView(illustration: .allClear, height: 260)
                    Text("¡A paz y salvo!")
                        .textStyle(.title1)
                        .multilineTextAlignment(.center)
                    Text(message)
                        .textStyle(.body)
                        .foregroundStyle(CruceColor.textBody)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 22)
                .padding(.top, 20)
                .padding(.bottom, 26)
                .neoSurface(radius: Radius.dialog, border: BorderWidth.thick, shadow: ShadowOffset.xxl)

                Spacer(minLength: 0)

                VStack(spacing: 12) {
                    Button("Volver al inicio") {
                        app.path = []
                        dismiss()
                    }
                    .buttonStyle(.neoDark)

                    ShareLink(item: shareText) {
                        Label("Compartir con \(app.partner.name)", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.neoSecondary)
                    .labelStyle(NeoLabelStyle())
                }
            }
            .foregroundStyle(CruceColor.ink)
            .padding(.horizontal, 24)
            .padding(.top, 40)
            .padding(.bottom, 16)
        }
    }

    private var message: String {
        let amount = Money.format(payment.amount)
        let method = payment.paymentMethod.map { " por \($0)" } ?? ""
        if payment.payerID == app.me.id {
            return "Le pagaste \(amount) a \(app.partner.name)\(method).\nEl saldo quedó en $0."
        }
        return "\(app.partner.name) te pagó \(amount)\(method).\nEl saldo quedó en $0."
    }

    private var shareText: String {
        "Quedamos a paz y salvo en Cruce: \(Money.format(payment.amount)) el \(DateText.long(payment.date).lowercased())."
    }

    private var decorations: some View {
        ZStack {
            Circle().fill(CruceColor.pink).frame(width: 220).offset(x: -170, y: -230)
            Rectangle().fill(CruceColor.violet).frame(width: 300, height: 300).rotationEffect(.degrees(-14)).offset(x: 170, y: 380)
            RoundedRectangle(cornerRadius: 2).fill(CruceColor.green).frame(width: 16, height: 16)
                .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(CruceColor.ink, lineWidth: 2.5))
                .rotationEffect(.degrees(18)).offset(x: 120, y: -360)
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    let state = AppState.preview()
    let payment = BalanceCalculator.settlement(
        movements: state.sortedMovements, me: MockData.joan.id, other: MockData.jesus.id,
        createdBy: MockData.joan.id, paymentMethod: "Nequi"
    )!
    return SettleSuccessView(payment: payment).environment(state)
}
