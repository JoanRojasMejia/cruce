import CruceCore
import SwiftUI

/// Historial agrupado por día, con filtros por persona y categoría (pantalla 07).
struct HistoryView: View {
    enum PersonFilter: Hashable {
        case all
        case member(UUID)
    }

    @Environment(AppState.self) private var app
    @State private var personFilter: PersonFilter = .all
    @State private var categoryFilter: MovementCategory?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ScreenHeader(title: "Historial") {
                    Badge(text: app.phrase(forNet: app.net), fill: badgeColor)
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
                                        app.path.append(.detail(movement.id))
                                    } label: {
                                        MovementRow(
                                            movement: movement,
                                            impact: app.impact(of: movement),
                                            payerName: app.member(movement.payerID).name,
                                            partnerName: app.partner.name,
                                            isPayerMe: movement.payerID == app.me.id,
                                            compact: true,
                                            viewerName: app.me.name
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
                Chip(title: "Pagó \(app.me.name)", isSelected: personFilter == .member(app.me.id), member: app.me) {
                    personFilter = .member(app.me.id)
                }
                Chip(
                    title: "Pagó \(app.partner.name)", isSelected: personFilter == .member(app.partner.id),
                    member: app.partner
                ) {
                    personFilter = .member(app.partner.id)
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
        switch app.balance {
        case .theyOweYou: return CruceColor.green
        case .youOwe: return CruceColor.pink
        case .settled: return CruceColor.neutral
        }
    }

    private var filtered: [Movement] {
        app.sortedMovements.filter { movement in
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

#Preview {
    NavigationStack {
        HistoryView().toolbar(.hidden, for: .navigationBar)
    }
    .environment(AppState.preview())
}
