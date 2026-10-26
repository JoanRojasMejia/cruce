import CruceCore
import SwiftUI

/// Saldar cuentas: confirma el pago que deja el saldo en $0 (pantalla 08).
struct SettleView: View {
    enum Method: String, CaseIterable, Hashable {
        case efectivo = "Efectivo"
        case nequi = "Nequi"
        case transferencia = "Transferencia"
    }

    @Environment(SessionStore.self) private var session
    @Environment(LedgerStore.self) private var ledger
    @State private var method: Method = .nequi

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
                            await ledger.settle(paymentMethod: method.rawValue)
                        }
                    } label: {
                        Label("Confirmar pago de \(Money.format(ledger.balance.amount))", systemImage: "checkmark")
                    }
                    .buttonStyle(NeoButtonStyle(kind: .primary, height: 58, shadow: ShadowOffset.l))
                    .labelStyle(NeoLabelStyle())

                    Button("Cambiar monto") {}
                        .buttonStyle(.neoLink)
                }
            }
        }
        .padding(.horizontal, Spacing.screen)
        .padding(.top, 8)
        .padding(.bottom, 16)
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
                        Text(Money.format(ledger.balance.amount))
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
                    after: "$0 · a paz y salvo"
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

#if DEBUG
    #Preview {
        NavigationStack {
            SettleView().toolbar(.hidden, for: .navigationBar)
        }
        .cruceStores(.sample())
    }
#endif
