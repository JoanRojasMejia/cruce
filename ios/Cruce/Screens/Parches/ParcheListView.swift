import CruceCore
import SwiftUI

/// "Tus parches": todos los parches de quien usa la app, primero los abiertos.
struct ParcheListView: View {
    @Environment(ParcheStore.self) private var parches
    @Environment(Router.self) private var router

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ScreenHeader(title: "Tus parches")
                ParcheSyncBanner()
                if parches.parches.isEmpty {
                    ParchesEmptyContent()
                } else {
                    ForEach(parches.parches) { detail in
                        Button {
                            router.push(.parche(detail.id))
                        } label: {
                            ParcheRow(detail: detail)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .refreshable { await parches.load() }
        .safeAreaInset(edge: .bottom) {
            ParcheEntryButtons()
                .padding(.horizontal, Spacing.screen)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .background(CruceColor.cream)
        }
        .screenBackground()
        .foregroundStyle(CruceColor.ink)
    }
}

/// "Nuevo parche" y "Tengo un código", lado a lado.
struct ParcheEntryButtons: View {
    @Environment(Router.self) private var router
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // Con texto grande van uno debajo del otro.
        let layout =
            dynamicTypeSize >= .xxLarge ? AnyLayout(VStackLayout(spacing: 14)) : AnyLayout(HStackLayout(spacing: 12))
        return layout {
            Button {
                router.push(.newParche)
            } label: {
                Label("Nuevo parche", systemImage: "plus")
            }
            .buttonStyle(NeoButtonStyle(kind: .primary, height: 54, text: .buttonSecondary))
            Button {
                router.push(.enterCode)
            } label: {
                Label("Tengo un código", systemImage: "number")
            }
            .buttonStyle(.neoSecondary)
        }
        .labelStyle(NeoLabelStyle())
    }
}

/// Sin parches todavía.
struct ParchesEmptyContent: View {
    var body: some View {
        VStack(spacing: 12) {
            IllustrationView(illustration: .empty, height: 200, minHeight: 120)
            Text("Aún no tienes parches")
                .font(.archivo(24, .black, relativeTo: .title))
                .tracking(-0.6)
                .multilineTextAlignment(.center)
            Text(
                "Un parche es para un viaje o una cena con varias personas: cada quien anota lo que pagó y al final se salda todo."
            )
            .textStyle(.body)
            .foregroundStyle(CruceColor.textBody)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
    }
}

/// Una fila de parche: nombre, estado, avisos sin ver y tu saldo en el parche.
struct ParcheRow: View {
    @Environment(ParcheStore.self) private var parches
    let detail: ParcheDetail

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(detail.parche.name)
                    .textStyle(.rowTitle)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Badge(text: parches.statusLabel(for: detail), fill: statusColor)
                    if detail.unseenCount > 0 {
                        Badge(text: unseenText, fill: CruceColor.pink)
                    }
                }
                Text(myBalance)
                    .textStyle(.secondary)
                    .foregroundStyle(CruceColor.textSecondary)
            }
            Spacer(minLength: 8)
            HStack(spacing: -6) {
                ForEach(Array(detail.participants.prefix(3).enumerated()), id: \.element.id) { index, person in
                    ParcheAvatar(participant: person, index: detail.index(of: person.id), size: 30)
                        .zIndex(Double(-index))
                }
            }
            .accessibilityHidden(true)
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

    private var statusColor: Color {
        if detail.isSettled { return CruceColor.green }
        return detail.parche.isOpen ? CruceColor.yellow : CruceColor.neutral
    }

    private var unseenText: String {
        detail.unseenCount == 1 ? "1 nuevo" : "\(detail.unseenCount) nuevos"
    }

    private var myBalance: String {
        let people = detail.participants.count == 1 ? "1 persona" : "\(detail.participants.count) personas"
        guard let me = detail.myParticipantID else { return people }
        let net = detail.balance(of: me)
        return "\(people) · \(parches.balanceText(net: net, for: me, in: detail))"
    }
}

/// "Tus parches" en el inicio: los tres primeros y el acceso a la lista.
struct HomeParchesSection: View {
    @Environment(ParcheStore.self) private var parches
    @Environment(Router.self) private var router

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Tus parches").textStyle(.sectionTitle)
                if parches.unseenTotal > 0 {
                    Badge(text: "\(parches.unseenTotal) sin ver", fill: CruceColor.pink)
                }
                Spacer()
                Button {
                    router.push(.parches)
                } label: {
                    Text("Ver todos").font(.archivo(14, .bold)).underline()
                }
                .foregroundStyle(CruceColor.ink)
                .frame(minHeight: Spacing.minTouch)
            }
            if parches.parches.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Para un viaje o una cena con más personas, arma un parche.")
                        .textStyle(.body)
                        .foregroundStyle(CruceColor.textBody)
                    ParcheEntryButtons()
                }
                .padding(14)
                .neoSurface(fill: .clear, radius: Radius.card, border: BorderWidth.thin, dashed: true)
            } else {
                ForEach(parches.parches.prefix(3)) { detail in
                    Button {
                        router.push(.parche(detail.id))
                    } label: {
                        ParcheRow(detail: detail)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .foregroundStyle(CruceColor.ink)
    }
}

#if DEBUG
    #Preview("Tus parches") {
        let stores = AppStores.sample()
        return NavigationStack {
            ParcheListView().toolbar(.hidden, for: .navigationBar)
        }
        .cruceStores(stores)
        .task { await stores.parches.load() }
    }
#endif
