import CruceCore
import SwiftUI

/// Saldar cuentas: confirma el pago que deja el saldo en $0 (pantalla 08). Con "Cambiar monto" el pago puede ser
/// parcial, de $1 hasta el total.
struct SettleView: View {
    enum Method: String, CaseIterable, Hashable {
        case efectivo = "Efectivo"
        case nequi = "Nequi"
        case transferencia = "Transferencia"
    }

    @Environment(SessionStore.self) private var session
    @Environment(LedgerStore.self) private var ledger
    @State private var method: Method = .nequi
    /// Monto elegido con "Cambiar monto", o `nil` para pagar el total.
    @State private var customAmount: Int?
    @State private var isChangingAmount = false

    var body: some View {
        FittingScroll {
            content
        }
        .foregroundStyle(CruceColor.ink)
        .screenBackground()
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            ScreenHeader(title: "Saldar cuentas")

            if ledger.balance == .settled {
                Spacer()
                VStack(spacing: 12) {
                    IllustrationView(illustration: .allClear, height: 220)
                    Text("Ya están a paz y salvo").font(.archivo(24, .black))
                    Text("No hay nada que saldar por ahora.").textStyle(.body).foregroundStyle(CruceColor.textBody)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                IllustrationView(illustration: .settle, height: 150)
                paymentCard
                methodPicker
                HStack {
                    Text("Fecha").font(.archivo(14, .bold))
                    Spacer()
                    Text(DateText.long(.now)).font(.archivo(14, .extraBold))
                }
                .padding(.horizontal, 14)
                .frame(height: 48)
                .neoSurface(radius: Radius.input, border: BorderWidth.thin)

                Spacer(minLength: 0)

                VStack(spacing: 10) {
                    Button {
                        Task {
                            await ledger.settle(paymentMethod: method.rawValue, amount: customAmount)
                        }
                    } label: {
                        Label("Confirmar pago de \(Money.format(paid))", systemImage: "checkmark")
                    }
                    .buttonStyle(NeoButtonStyle(kind: .primary, height: 58, shadow: ShadowOffset.l))
                    .labelStyle(NeoLabelStyle())

                    Button(customAmount == nil ? "Cambiar monto" : "Pagar el total") {
                        if customAmount == nil {
                            isChangingAmount = true
                        } else {
                            customAmount = nil
                        }
                    }
                    .buttonStyle(.neoLink)
                }
            }
        }
        .padding(.horizontal, Spacing.screen)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .sheet(isPresented: $isChangingAmount) {
            ChangeAmountSheet(total: ledger.balance.amount, initial: customAmount) { amount in
                // El total es lo mismo que no cambiar el monto.
                customAmount = amount == ledger.balance.amount ? nil : amount
            }
            .presentationDetents([.large])
            .presentationCornerRadius(Radius.sheet)
            .presentationBackground { SheetBackground() }
        }
    }

    /// Lo que se va a pagar: el monto elegido o, si no, el total.
    private var paid: Int {
        customAmount ?? ledger.balance.amount
    }

    /// Cómo queda el saldo después del pago, desde la vista de quien usa la app.
    private var after: String {
        let remaining = iOwe ? ledger.net + paid : ledger.net - paid
        return remaining == 0 ? "$0 · a paz y salvo" : ledger.phrase(forNet: remaining)
    }

    /// Quién paga y quién recibe, con el antes y el después.
    private var paymentCard: some View {
        let payer = iOwe ? session.me : session.partner
        let receiver = iOwe ? session.partner : session.me

        return FolderCard(tab: "PAGO PARA SALDAR", tabColor: CruceColor.pink, tabWidth: 160) {
            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    person(payer, caption: iOwe ? "Tú pagas" : "\(payer.name) paga")
                    VStack(spacing: 2) {
                        Text(Money.format(paid))
                            .font(.archivo(30, .black))
                            .tracking(-1)
                            .lineLimit(1)
                            .minimumScaleFactor(0.4)
                        HStack(spacing: 0) {
                            Rectangle().fill(CruceColor.ink).frame(height: 3)
                            Image(systemName: "chevron.right").font(.system(size: 16, weight: .black))
                        }
                    }
                    .padding(.bottom, 22)
                    person(receiver, caption: iOwe ? "\(receiver.name) recibe" : "Tú recibes")
                }
                BeforeAfter(
                    beforeTitle: "ANTES",
                    before: ledger.phrase(forNet: ledger.net),
                    afterTitle: "DESPUÉS",
                    after: after
                )
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func person(_ member: Member, caption: String) -> some View {
        VStack(spacing: 6) {
            Avatar(member: member, size: 54, shadow: ShadowOffset.s)
            Text(caption).font(.archivo(13, .extraBold)).lineLimit(1).minimumScaleFactor(0.8)
        }
    }

    /// Quien usa la app es quien debe y, por tanto, quien paga.
    private var iOwe: Bool {
        if case .youOwe = ledger.balance { return true }
        return false
    }

    private var methodPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(iOwe ? "¿Cómo le pagaste?" : "¿Cómo te pagó?").textStyle(.fieldLabel)
            HStack(spacing: 8) {
                ForEach(Method.allCases, id: \.self) { item in
                    Button {
                        method = item
                    } label: {
                        // Ancho según el texto, como en el diseño ("Transferencia" es más ancho).
                        Text(item.rawValue)
                            .font(.archivo(14, item == method ? .extraBold : .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .foregroundStyle(item == method ? .white : CruceColor.ink)
                            .padding(.horizontal, 16)
                            .frame(minHeight: 44)
                            .neoSurface(
                                fill: item == method ? CruceColor.ink : CruceColor.surface, radius: Radius.input,
                                border: BorderWidth.thin)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(item == method ? .isSelected : [])
                }
            }
        }
    }
}

/// "Cambiar monto": el teclado para escribir un pago parcial, de $1 hasta el total.
struct ChangeAmountSheet: View {
    @Environment(\.dismiss) private var dismiss
    private let total: Int
    private let onDone: (Int) -> Void
    @State private var digits: String

    /// `initial`: el monto elegido antes; sin él, el teclado arranca vacío para escribir el pago parcial.
    init(total: Int, initial: Int?, onDone: @escaping (Int) -> Void) {
        self.total = total
        self.onDone = onDone
        _digits = State(initialValue: initial.map(String.init) ?? "")
    }

    private var amount: Int { Money.parse(digits: digits) }
    private var isValid: Bool { (1...max(total, 1)).contains(amount) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("¿Cuánto se paga?").font(.archivo(22, .black))
            VStack(alignment: .leading, spacing: 4) {
                Text(Money.format(amount))
                    .font(.archivo(46, .black, relativeTo: .largeTitle))
                    .tracking(-2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(amount > total ? "No puede ser más de \(Money.format(total))" : "Máximo \(Money.format(total))")
                    .textStyle(.secondary)
                    .foregroundStyle(amount > total ? CruceColor.ink : CruceColor.textSecondary)
            }
            .accessibilityElement(children: .combine)
            AmountKeypad(digits: $digits)
            Spacer(minLength: 0)
            Button("Listo") {
                onDone(amount)
                dismiss()
            }
            .buttonStyle(NeoButtonStyle(kind: .primary, height: 54))
            .disabled(!isValid)
        }
        .foregroundStyle(CruceColor.ink)
        .padding(.horizontal, Spacing.screen)
        .padding(.top, 24)
        .padding(.bottom, 16)
    }
}

#if DEBUG
    #Preview {
        NavigationStack {
            SettleView().toolbar(.hidden, for: .navigationBar)
        }
        .cruceStores(.sample())
    }

    #Preview("Cambiar monto") {
        ChangeAmountSheet(total: 50_000, initial: 20_000) { _ in }
            .cruceStores(.sample())
    }
#endif
