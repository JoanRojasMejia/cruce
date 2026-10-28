import CruceCore
import SwiftUI

/// Historial agrupado por día, con filtros por persona y categoría (pantalla 07). Deslizar una fila a la izquierda
/// muestra "Eliminar", con la misma confirmación del detalle.
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

    /// El movimiento que se va a eliminar desde el historial (deslizar → "Eliminar"), mientras se confirma.
    @State private var deleting: Movement?

    var body: some View {
        // `List` para tener deslizar con "Eliminar" (también para VoiceOver); sin separadores ni fondo, para verse igual
        // que el resto de la app.
        List {
            // Volver con el router: dentro de una fila de `List`, `dismiss` no cierra la pantalla.
            ScreenHeader(title: "Historial", onBack: { router.pop() }) {
                Badge(text: ledger.phrase(forNet: ledger.net), fill: badgeColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .historyRow(top: 8, bottom: 14)
            filters
                .historyRow(bottom: 14)
            if groups.isEmpty {
                Text("No hay movimientos con estos filtros.")
                    .textStyle(.body)
                    .foregroundStyle(CruceColor.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                    .historyRow()
            } else {
                ForEach(groups, id: \.day) { group in
                    Text(DateText.groupHeader(group.day))
                        .textStyle(.label)
                        .historyRow(bottom: 6)
                    ForEach(group.movements) { movement in
                        row(movement)
                            .historyRow(bottom: movement.id == group.movements.last?.id ? 12 : 6)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, 0)
        .scrollIndicators(.hidden)
        .foregroundStyle(CruceColor.ink)
        .screenBackground()
        .overlay {
            if let movement = deleting {
                DeleteConfirmation(
                    movement: movement,
                    afterNet: ledger.net - ledger.impact(of: movement),
                    onCancel: { deleting = nil },
                    onDelete: {
                        deleting = nil
                        Task { await ledger.delete(movement.id) }
                    }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: deleting?.id)
    }

    private func row(_ movement: Movement) -> some View {
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
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            // Un cruce cerrado (desvinculado) es de solo lectura: no se elimina.
            if !session.isOpenCruceClosed {
                Button {
                    deleting = movement
                } label: {
                    Label("Eliminar", systemImage: "trash")
                }
                .tint(CruceColor.pink)
            }
        }
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

extension View {
    /// Una fila del historial sin separador ni fondo, con los márgenes de la pantalla y el espacio de abajo que se pida.
    fileprivate func historyRow(top: CGFloat = 0, bottom: CGFloat = 0) -> some View {
        listRowInsets(EdgeInsets(top: top, leading: Spacing.screen, bottom: bottom, trailing: Spacing.screen))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
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
