import CruceCore
import SwiftUI

/// Actividad del parche, en su propia pantalla (se abre desde el encabezado del detalle).
/// Al abrirla queda vista: el contador "sin ver" vuelve a cero, pero se resaltan los avisos que eran nuevos.
struct ParcheActivityView: View {
    @Environment(ParcheStore.self) private var parches

    private let parcheID: UUID
    /// Avisos sin ver al entrar.
    @State private var unseenOnOpen: Int?
    /// Última vez que habías visto la actividad: lo de otros después de eso se marca "nuevo".
    @State private var lastSeenOnOpen: Date?

    init(parcheID: UUID) {
        self.parcheID = parcheID
    }

    var body: some View {
        Group {
            if let detail = parches.parche(parcheID) {
                content(detail)
            } else {
                ParcheMissing(parcheID: parcheID)
            }
        }
        .task {
            if unseenOnOpen == nil {
                if parches.parche(parcheID) == nil { await parches.refresh(parcheID) }
                unseenOnOpen = parches.parche(parcheID)?.unseenCount ?? 0
                lastSeenOnOpen = parches.parche(parcheID)?.me?.lastSeenAt ?? .distantPast
            }
            await parches.open(parcheID)
        }
    }

    private func content(_ detail: ParcheDetail) -> some View {
        let items = detail.sortedActivity
        let unseen = unseenOnOpen ?? 0
        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ScreenHeader(title: "Actividad") {
                    if unseen > 0 {
                        Badge(text: unseen == 1 ? "1 sin ver" : "\(unseen) sin ver", fill: CruceColor.pink)
                    }
                }
                Text(detail.parche.name)
                    .textStyle(.secondary)
                    .foregroundStyle(CruceColor.textSecondary)
                if items.isEmpty {
                    Text("Todavía no hay actividad en el parche.")
                        .textStyle(.body)
                        .foregroundStyle(CruceColor.textBody)
                } else {
                    ParcheCard {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            if index > 0 { CardDivider() }
                            row(item, in: detail)
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .refreshable { await parches.refresh(parcheID) }
        .screenBackground()
        .foregroundStyle(CruceColor.ink)
    }

    private func row(_ item: ParcheActivity, in detail: ParcheDetail) -> some View {
        let new = isNew(item, in: detail)
        return HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(new ? CruceColor.pink : CruceColor.neutral)
                .overlay(Circle().strokeBorder(CruceColor.ink, lineWidth: 1.5))
                .frame(width: 10, height: 10)
                .padding(.top, 4)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(parches.phrase(for: item, in: detail))
                    .font(.archivo(14, new ? .extraBold : .bold))
                    .fixedSize(horizontal: false, vertical: true)
                Text(DateText.moment(item.createdAt).capitalizedFirst + (new ? " · nuevo" : ""))
                    .textStyle(.secondary)
                    .foregroundStyle(CruceColor.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }

    /// Un aviso de otra persona que llegó después de la última vez que viste la actividad.
    private func isNew(_ item: ParcheActivity, in detail: ParcheDetail) -> Bool {
        guard let lastSeenOnOpen, (unseenOnOpen ?? 0) > 0 else { return false }
        return item.actorID != detail.myParticipantID && item.createdAt > lastSeenOnOpen
    }
}

/// Botón de la actividad en el encabezado del detalle, con el número de avisos sin ver.
struct ParcheActivityButton: View {
    let unseen: Int
    let action: () -> Void

    var body: some View {
        IconButton(systemName: "bell", accessibilityLabel: label, size: 44, action: action)
            .overlay(alignment: .topTrailing) {
                if unseen > 0 {
                    Text(unseen > 9 ? "9+" : "\(unseen)")
                        .font(.archivo(11, .black))
                        .foregroundStyle(CruceColor.ink)
                        .padding(.horizontal, 5)
                        .frame(minWidth: 20, minHeight: 20)
                        .neoSurface(fill: CruceColor.pink, radius: 10, border: BorderWidth.thin)
                        .offset(x: 6, y: -6)
                        .accessibilityHidden(true)
                }
            }
    }

    private var label: String {
        switch unseen {
        case 0: return "Actividad"
        case 1: return "Actividad, 1 sin ver"
        default: return "Actividad, \(unseen) sin ver"
        }
    }
}

#if DEBUG
    #Preview("Actividad") {
        let stores = AppStores.sample()
        return NavigationStack {
            ParcheActivityView(parcheID: MockParches.santaMartaID).toolbar(.hidden, for: .navigationBar)
        }
        .cruceStores(stores)
        .task { await stores.parches.load() }
    }
#endif
