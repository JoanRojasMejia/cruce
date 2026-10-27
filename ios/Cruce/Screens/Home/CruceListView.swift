import CruceCore
import SwiftUI

/// "Tus cruces": el inicio cuando hay dos o más cruces. Una fila por cruce con la otra persona y su saldo;
/// al tocarla se abre el inicio de ese cruce. Sin captura en el canvas: se arma con las piezas de "Tus parches".
struct CruceListView: View {
    @Environment(SessionStore.self) private var session
    @Environment(LedgerStore.self) private var ledger
    @Environment(Router.self) private var router

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                MainHeader { CruceLogo() }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Tus cruces").textStyle(.title1Compact)
                    Text("Un saldo con cada amigo. Toca uno para ver sus gastos.")
                        .textStyle(.body)
                        .foregroundStyle(CruceColor.textBody)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 10) {
                    ForEach(session.cruces) { cruce in
                        Button {
                            session.open(cruce.id)
                            router.push(.cruce(cruce.id))
                        } label: {
                            CruceRow(cruce: cruce)
                        }
                        .buttonStyle(.plain)
                    }
                }

                CruceEntryButtons()

                HomeParchesSection()
                    .padding(.top, 4)
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        // Deslizar hacia abajo recarga los saldos de todos los cruces.
        .refreshable { await ledger.load() }
        .screenBackground()
    }
}

/// Una fila de "Tus cruces": la otra persona, la frase y el monto con signo. La dirección de la deuda va en texto,
/// no solo en el color. Un cruce cerrado lleva la marca "Cerrado".
struct CruceRow: View {
    @Environment(LedgerStore.self) private var ledger
    let cruce: CruceLink

    init(cruce: CruceLink) {
        self.cruce = cruce
    }

    private var net: Int { ledger.net(of: cruce.id) }

    var body: some View {
        HStack(spacing: 12) {
            Avatar(member: cruce.partner, size: 44)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("Con \(cruce.partner.name)")
                        .textStyle(.rowTitle)
                        .lineLimit(1)
                    // Desvinculado: sigue en la lista para ver su historial, al final y marcado.
                    if cruce.isClosed {
                        Text("Cerrado")
                            .font(.archivo(11, .extraBold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .neoSurface(fill: CruceColor.pink, radius: 6, border: BorderWidth.thin)
                    }
                }
                Text(ledger.phrase(forNet: net, partner: cruce.partner))
                    .textStyle(.secondary)
                    .foregroundStyle(CruceColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(Money.format(net, showsSign: true))
                    .font(.archivo(18, .black))
                    .lineLimit(1)
                if let side {
                    Text(side)
                        .font(.archivo(11, .bold))
                        .foregroundStyle(CruceColor.textSecondary)
                }
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .black))
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .neoSurface(radius: Radius.card, shadow: ShadowOffset.s)
        .foregroundStyle(CruceColor.ink)
        .accessibilityElement(children: .combine)
    }

    /// "a tu favor" o "a favor de Ana"; en $0 no dice nada (la frase ya dice que están a paz y salvo).
    private var side: String? {
        switch BalanceState(net: net) {
        case .theyOweYou: return "a tu favor"
        case .youOwe: return "a favor de \(cruce.partner.name)"
        case .settled: return nil
        }
    }
}

/// "Invitar a alguien" y "Tengo un código", con el mismo estilo de los botones de parches.
struct CruceEntryButtons: View {
    @Environment(Router.self) private var router

    var body: some View {
        // Lado a lado si hay aire para los dos textos; en pantallas chicas (iPhone SE: 335 pt útiles) o con texto
        // grande, uno debajo del otro. Los 340 pt dejan margen a "Invitar a alguien" y "Tengo un código".
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { buttons }.frame(minWidth: 340)
            VStack(spacing: 14) { buttons }
        }
        .buttonStyle(NeoButtonStyle(kind: .secondary, height: 52))
        .labelStyle(NeoLabelStyle())
    }

    @ViewBuilder
    private var buttons: some View {
        Button {
            router.push(.invite)
        } label: {
            Label("Invitar a alguien", systemImage: "person.badge.plus")
        }
        Button {
            router.push(.enterCode)
        } label: {
            Label("Tengo un código", systemImage: "number")
        }
    }
}

/// Encabezado del inicio y de "Tus cruces": lo de la izquierda (logo o volver), el aviso sin conexión y Ajustes.
struct MainHeader<Leading: View>: View {
    @Environment(LedgerStore.self) private var ledger
    @Environment(Router.self) private var router
    @ViewBuilder var leading: Leading

    var body: some View {
        HStack(spacing: 12) {
            leading
            Spacer(minLength: 0)
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
}

#if DEBUG
    #Preview("Tus cruces") {
        NavigationStack {
            CruceListView().toolbar(.hidden, for: .navigationBar)
        }
        .cruceStores(.sample(withAna: true))
    }
#endif
