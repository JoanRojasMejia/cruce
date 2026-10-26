import CruceCore
import SwiftUI

/// Inicio: el saldo neto es el protagonista.
/// Pantallas del canvas: 02 Inicio vacío, 03 Te deben, 04 Debes, 20 Vista de Jesús.
struct HomeView: View {
    @Environment(SessionStore.self) private var session
    @Environment(LedgerStore.self) private var ledger
    @Environment(Router.self) private var router

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    if ledger.isEmpty {
                        EmptyHomeContent()
                            .frame(maxHeight: .infinity)
                    } else {
                        BalanceCard()
                        actions
                        recent
                    }
                    HomeParchesSection()
                        .padding(.top, 4)
                }
                .padding(.horizontal, Spacing.screen)
                .padding(.top, 8)
                .padding(.bottom, 24)
                // Al menos el alto de la pantalla: el inicio vacío lleva su botón abajo y en pantallas chicas hace scroll.
                .frame(minHeight: proxy.size.height, alignment: .top)
            }
            .scrollIndicators(.hidden)
        }
        .screenBackground()
    }

    private var header: some View {
        HStack {
            CruceLogo()
            Spacer()
            if ledger.isOffline {
                Button {
                    router.push(.offline)
                } label: {
                    Badge(text: "Sin conexión", fill: CruceColor.pink)
                }
                .buttonStyle(.plain)
            }
            IconButton(systemName: "gearshape", accessibilityLabel: "Ajustes", size: 44) {
                router.push(.settings)
            }
        }
    }

    @ViewBuilder
    private var actions: some View {
        HStack(spacing: 12) {
            switch ledger.balance {
            case .youOwe:
                Button {
                    router.push(.addMovement)
                } label: {
                    Label("Agregar gasto", systemImage: "plus")
                }
                .buttonStyle(.neoSecondary)
                Button {
                    router.push(.settle)
                } label: {
                    Label("Pagarle a \(session.partner.name)", systemImage: "checkmark")
                }
                .buttonStyle(NeoButtonStyle(kind: .primary, height: 54, text: .buttonSecondary))
            case .theyOweYou:
                Button {
                    router.push(.addMovement)
                } label: {
                    Label("Agregar gasto", systemImage: "plus")
                }
                .buttonStyle(.neoPrimary)
                Button {
                    router.push(.settle)
                } label: {
                    Label("Saldar", systemImage: "checkmark")
                }
                .buttonStyle(NeoButtonStyle(kind: .secondary))
                .frame(width: 118)
            case .settled:
                Button {
                    router.push(.addMovement)
                } label: {
                    Label("Agregar gasto", systemImage: "plus")
                }
                .buttonStyle(.neoPrimary)
            }
        }
        .labelStyle(NeoLabelStyle())
    }

    private var recent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Últimos movimientos").textStyle(.sectionTitle)
                Spacer()
                // El subrayado va en el Text: aplicado al Button no llega a la etiqueta.
                Button {
                    router.push(.history)
                } label: {
                    Text("Ver todo").font(.archivo(14, .bold)).underline()
                }
                .foregroundStyle(CruceColor.ink)
            }
            ForEach(ledger.visibleMovements.prefix(3)) { movement in
                Button {
                    router.push(.detail(movement.id))
                } label: {
                    MovementRow(
                        movement: movement,
                        impact: ledger.impact(of: movement),
                        payerName: session.member(movement.payerID).name,
                        partnerName: session.partner.name,
                        isPayerMe: movement.payerID == session.me.id,
                        dateText: DateText.relative(movement.date)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .foregroundStyle(CruceColor.ink)
    }
}

/// Ícono + texto con el espaciado del diseño.
struct NeoLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            configuration.icon.font(.system(size: 17, weight: .heavy))
            configuration.title
        }
    }
}

/// Tarjeta del saldo neto con la ilustración del estado.
struct BalanceCard: View {
    @Environment(SessionStore.self) private var session
    @Environment(LedgerStore.self) private var ledger

    var body: some View {
        FolderCard(
            tab: "SALDO NETO", tabColor: tabColor, padding: EdgeInsets(top: 14, leading: 18, bottom: 18, trailing: 18)
        ) {
            VStack(alignment: .leading, spacing: 8) {
                IllustrationView(
                    illustration: Illustration.balance(ledger.balance, variant: session.me.tikeVariant), height: 140)
                VStack(alignment: .leading, spacing: 2) {
                    Text(phrase).textStyle(.balancePhrase)
                    Text(Money.format(ledger.balance.amount))
                        .textStyle(.amount)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    caption
                        .padding(.top, 4)
                }
            }
            .foregroundStyle(CruceColor.ink)
        }
        .accessibilityElement(children: .combine)
    }

    private var tabColor: Color {
        switch ledger.balance {
        case .theyOweYou: return CruceColor.green
        case .youOwe: return CruceColor.pink
        case .settled: return CruceColor.neutral
        }
    }

    private var phrase: String {
        switch ledger.balance {
        case .theyOweYou: return "\(session.partner.name) te debe"
        case .youOwe: return "Le debes a \(session.partner.name)"
        case .settled: return "Están a paz y salvo"
        }
    }

    @ViewBuilder
    private var caption: some View {
        HStack(spacing: 6) {
            switch ledger.balance {
            case .theyOweYou:
                DirectionLabel(from: session.partner.name, to: "tú")
            case .youOwe:
                DirectionLabel(from: "Tú", to: session.partner.name)
            case .settled:
                EmptyView()
            }
            Text(summary)
                .textStyle(.secondary)
                .foregroundStyle(CruceColor.textSecondary)
        }
    }

    private var summary: String {
        let count = ledger.movementsSinceLastSettlement
        let noun = count == 1 ? "movimiento" : "movimientos"
        guard let last = ledger.lastSettlementDate else { return "· \(count) \(noun)" }
        let relative = DateText.relative(last)
        let when = (relative == "Hoy" || relative == "Ayer") ? relative.lowercased() : "el \(relative)"
        if ledger.balance == .settled { return "Saldaron \(when)" }
        return "· \(count) \(noun) desde \(when)"
    }
}

/// "Jesús → tú": quién le debe a quién, sin depender del color.
struct DirectionLabel: View {
    let from: String
    let to: String

    var body: some View {
        HStack(spacing: 3) {
            Text(from)
            Image(systemName: "arrow.right").font(.system(size: 11, weight: .black))
            Text(to)
        }
        .font(.archivo(13, .extraBold))
        .foregroundStyle(CruceColor.ink)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(from) le debe a \(to)")
    }
}

/// Inicio sin movimientos (primera vez).
struct EmptyHomeContent: View {
    @Environment(SessionStore.self) private var session
    @Environment(Router.self) private var router

    var body: some View {
        VStack(spacing: 20) {
            FolderCard(tab: "SALDO NETO", tabColor: CruceColor.neutral) {
                HStack {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Están a paz y salvo").font(.archivo(18, .extraBold))
                        Text("$0").textStyle(.amountMedium)
                    }
                    Spacer()
                    HStack(spacing: -10) {
                        Avatar(member: session.me)
                        Avatar(member: session.partner)
                    }
                }
                .foregroundStyle(CruceColor.ink)
            }

            Spacer(minLength: 20)

            VStack(spacing: 12) {
                IllustrationView(illustration: .empty, height: 250)
                Text("Aún no hay movimientos")
                    .font(.archivo(26, .black, relativeTo: .title))
                    .tracking(-0.6)
                Text(
                    "Cuando uno de los dos pague algo, anótalo aquí. Cruce compensa cada gasto y les muestra un solo saldo."
                )
                .textStyle(.body)
                .foregroundStyle(CruceColor.textBody)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            }
            .foregroundStyle(CruceColor.ink)

            Spacer(minLength: 20)

            Button {
                router.push(.addMovement)
            } label: {
                Label("Agregar el primer gasto", systemImage: "plus")
            }
            .buttonStyle(NeoButtonStyle(kind: .primary, height: 58, shadow: ShadowOffset.l))
            .labelStyle(NeoLabelStyle())
        }
    }
}

#if DEBUG
    #Preview("Te deben") {
        MainView().cruceStores(.sample())
    }

    #Preview("Vista de Jesús") {
        MainView().cruceStores(.sample(viewer: MockData.jesus))
    }

    #Preview("Vacío") {
        MainView().cruceStores(.sample(movements: []))
    }
#endif
