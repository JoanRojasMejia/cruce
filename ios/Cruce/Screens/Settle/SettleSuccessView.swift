import CruceCore
import SwiftUI

/// "¡A paz y salvo!" después de saldar (pantalla 09). Después de un pago parcial dice "Pago anotado" y cuánto falta.
struct SettleSuccessView: View {
    @Environment(SessionStore.self) private var session
    @Environment(LedgerStore.self) private var ledger
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    let payment: Movement

    init(payment: Movement) {
        self.payment = payment
    }

    var body: some View {
        ZStack {
            CruceColor.yellow.ignoresSafeArea()
                .onAppear { Feedback.play(remaining == 0 ? .settled : .paymentRecorded) }
            decorations

            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    IllustrationView(illustration: remaining == 0 ? .allClear : .settle, height: 260)
                    Text(remaining == 0 ? "¡A paz y salvo!" : "Pago anotado")
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
                        router.popToRoot()
                        dismiss()
                    }
                    .buttonStyle(.neoDark)

                    ShareLink(item: shareText) {
                        Label("Compartir con \(session.partner.name)", systemImage: "square.and.arrow.up")
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

    /// El saldo después del pago, desde la vista de quien usa la app. El pago ya está en el cruce; si no (vistas
    /// previas), se suma aquí.
    private var remaining: Int {
        ledger.movement(payment.id) != nil ? ledger.net : ledger.net + ledger.impact(of: payment)
    }

    private var message: String {
        let amount = Money.format(payment.amount)
        let method = payment.paymentMethod.map { " por \($0)" } ?? ""
        let paid =
            payment.payerID == session.me.id
            ? "Le pagaste \(amount) a \(session.partner.name)\(method)."
            : "\(session.partner.name) te pagó \(amount)\(method)."
        if remaining == 0 { return paid + "\nEl saldo quedó en $0." }
        let left = Money.format(abs(remaining))
        return paid + (remaining > 0 ? "\nTodavía te debe \(left)." : "\nTodavía le debes \(left).")
    }

    private var shareText: String {
        if remaining == 0 {
            return "Quedamos a paz y salvo en Cruce: \(Money.format(payment.amount)) el \(DateText.day(payment.date))."
        }
        return "Anoté en Cruce un pago de \(Money.format(payment.amount)) el \(DateText.day(payment.date)). "
            + "Faltan \(Money.format(abs(remaining)))."
    }

    private var decorations: some View {
        ZStack {
            Circle().fill(CruceColor.pink).frame(width: 220).offset(x: -170, y: -230)
            Rectangle().fill(CruceColor.violet).frame(width: 420, height: 420).rotationEffect(.degrees(-14)).offset(
                x: 200, y: 330)
            RoundedRectangle(cornerRadius: 2).fill(CruceColor.green).frame(width: 16, height: 16)
                .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(CruceColor.ink, lineWidth: 2.5))
                .rotationEffect(.degrees(18)).offset(x: 120, y: -360)
            RoundedRectangle(cornerRadius: 2).fill(CruceColor.surface).frame(width: 12, height: 22)
                .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(CruceColor.ink, lineWidth: 2.5))
                .rotationEffect(.degrees(-28)).offset(x: -148, y: -362)
        }
        .accessibilityHidden(true)
    }
}

#if DEBUG
    #Preview {
        let stores = AppStores.sample()
        let payment = BalanceCalculator.settlement(
            movements: stores.ledger.visibleMovements, me: MockData.joan.id, other: MockData.jesus.id,
            createdBy: MockData.joan.id, paymentMethod: "Nequi"
        )!
        return SettleSuccessView(payment: payment).cruceStores(stores)
    }

    #Preview("Pago parcial") {
        let stores = AppStores.sample()
        let payment = BalanceCalculator.settlement(
            movements: stores.ledger.visibleMovements, me: MockData.joan.id, other: MockData.jesus.id,
            createdBy: MockData.joan.id, paymentMethod: "Nequi", amount: 5_000
        )!
        return SettleSuccessView(payment: payment).cruceStores(stores)
    }
#endif
