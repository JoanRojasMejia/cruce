import CruceCore
import SwiftUI

/// Historial agrupado por día, con filtros por persona y categoría (pantalla 07).
struct HistoryView: View {
    enum PersonFilter: Hashable {
        case all
        case member(UUID)
    }

    @Environment(SessionStore.self) private var session
    @Environment(LedgerStore.self) private var ledger
    @Environment(Router.self) private var router
    @State private var personFilter: PersonFilter = .all
    @State private var categoryFilter: MovementCategory?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ScreenHeader(title: "Historial") {
                    Badge(text: ledger.phrase(forNet: ledger.net), fill: badgeColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                filters
                if groups.isEmpty {
                    Text("No hay movimientos con estos filtros.")
                        .textStyle(.body)
                        .foregroundStyle(CruceColor.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(groups, id: \.day) { group in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(DateText.groupHeader(group.day))
                                    .textStyle(.label)
                                ForEach(group.movements) { movement in
                                    Button {
                                        router.push(.detail(movement.id))
                                    } label: {
                                        MovementRow(
                                            movement: movement,
                                            impact: ledger.impact(of: movement),
                                            payerName: session.member(movement.payerID).name,
                                            partnerName: session.partner.name,
                                            isPayerMe: movement.payerID == session.me.id,
                                            compact: true,
                                            viewerName: session.me.name
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.top, 8)
            .padding(.bottom, 24)
            .foregroundStyle(CruceColor.ink)
        }
        .scrollIndicators(.hidden)
        .screenBackground()
    }

    private var filters: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Chip(title: "Todos", isSelected: personFilter == .all) { personFilter = .all }
                Chip(
                    title: "Pagó \(session.me.name)", isSelected: personFilter == .member(session.me.id),
                    member: session.me
                ) {
                    personFilter = .member(session.me.id)
                }
                Chip(
                    title: "Pagó \(session.partner.name)", isSelected: personFilter == .member(session.partner.id),
                    member: session.partner
                ) {
                    personFilter = .member(session.partner.id)
                }
            }
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    Chip(
                        title: "Todas", isSelected: categoryFilter == nil, selectedColor: CruceColor.yellow,
                        showsCheck: false
                    ) {
                        categoryFilter = nil
                    }
                    ForEach(MovementCategory.allCases) { item in
                        Chip(
                            title: item.title, isSelected: categoryFilter == item, selectedColor: item.color,
                            dotColor: item.color
                        ) {
                            categoryFilter = item
                        }
                    }
                }
                .padding(.vertical, 2)
                .padding(.trailing, 4)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var badgeColor: Color {
        switch ledger.balance {
        case .theyOweYou: return CruceColor.green
        case .youOwe: return CruceColor.pink
        case .settled: return CruceColor.neutral
        }
    }

    private var filtered: [Movement] {
        ledger.visibleMovements.filter { movement in
            switch personFilter {
            case .all: break
            case .member(let id): if movement.payerID != id { return false }
            }
            if let categoryFilter, movement.category != categoryFilter { return false }
            return true
        }
    }

    private var groups: [DayGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filtered) { calendar.startOfDay(for: $0.date) }
        return
            grouped
            .map { DayGroup(day: $0.key, movements: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.day > $1.day }
    }
}

private struct DayGroup {
    let day: Date
    let movements: [Movement]
}

#if DEBUG
    #Preview {
        NavigationStack {
            HistoryView().toolbar(.hidden, for: .navigationBar)
        }
        .cruceStores(.sample())
    }
#endif
