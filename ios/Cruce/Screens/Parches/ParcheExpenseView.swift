import CruceCore
import SwiftUI

/// Anotar un gasto del parche (o editarlo): concepto, monto, quién pagó, reparto, propina y la vista previa de lo
/// que le toca a cada quien. Antes de guardar avisa si parece un gasto ya anotado.
struct ParcheExpenseView: View {
    /// Cómo se reparte el gasto.
    enum Method: Hashable, CaseIterable {
        case equalAll, equalSome, items, shares, percentage

        var title: String {
            switch self {
            case .equalAll: return "Iguales entre todos"
            case .equalSome: return "Iguales entre algunos"
            case .items: return "Por consumo"
            case .shares: return "Por partes"
            case .percentage: return "Por porcentaje"
            }
        }

        /// Un ejemplo de una línea para cada forma de repartir que no es "Iguales entre todos".
        var example: String {
            switch self {
            case .equalAll: return "Todos ponen lo mismo."
            case .equalSome: return "Si Ana no tomó, el vino se reparte solo entre los demás."
            case .items: return "Cada quien paga lo suyo: la mojarra de Carlos va solo a Carlos."
            case .shares: return "Si Ana va con su pareja, ella cuenta 2 y los demás 1."
            case .percentage: return "Jesús pone el 50 % y Ana y Joan el 25 % cada uno."
            }
        }

        /// Las que se abren con "Otra forma de repartir".
        static let others: [Method] = [.equalSome, .items, .shares, .percentage]
    }

    /// Un ítem del reparto por consumo, mientras se escribe.
    struct ItemDraft: Identifiable, Hashable {
        let id: UUID
        var amount: Int
        var people: Set<UUID>
        /// Opcional ("Mojarra"); sale en el ticket.
        var name = ""
    }

    @Environment(ParcheStore.self) private var parches
    @Environment(Router.self) private var router

    private let parcheID: UUID
    private let expenseID: UUID?

    @State private var prepared = false
    @State private var concept = ""
    @State private var base = 0
    @State private var tip = 0
    /// Quiénes pagaron y cuánto puso cada uno (la regla vive en CruceCore).
    @State private var payersDraft = ParchePayersDraft(order: [], payerIDs: [])
    @State private var method: Method = .equalAll
    /// "Otra forma de repartir" abierta (también al editar un gasto que no es en partes iguales entre todos).
    @State private var showsOtherMethods = false
    @State private var someIDs: Set<UUID> = []
    @State private var items: [ItemDraft] = []
    @State private var shares: [UUID: Int] = [:]
    @State private var percents: [UUID: Int] = [:]
    @State private var problem: String?
    @State private var duplicate: (expense: ParcheExpense, message: String)?
    @State private var confirmingDelete = false

    init(parcheID: UUID, editing expenseID: UUID? = nil, confirmingDelete: Bool = false) {
        self.parcheID = parcheID
        self.expenseID = expenseID
        _confirmingDelete = State(initialValue: confirmingDelete)
    }

    var body: some View {
        if let detail = parches.parche(parcheID) {
            form(detail)
                .onAppear { prepare(detail) }
        } else {
            ParcheMissing(parcheID: parcheID)
        }
    }

    private func form(_ detail: ParcheDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(title: expenseID == nil ? "Anotar un gasto" : "Editar el gasto")
                NeoTextField(label: "Concepto", text: $concept, placeholder: "Ej. Almuerzo en Taganga")
                    .submitLabel(.done)
                amountCard
                payersSection(detail)
                methodSection(detail)
                tipSection
                preview(detail)
                if let problem {
                    ParcheProblem(text: problem)
                }
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 6) {
                Button(expenseID == nil ? "Guardar el gasto" : "Guardar cambios") { save(detail) }
                    .buttonStyle(NeoButtonStyle(kind: .primary, height: 54))
                    .disabled(
                        base == 0 || concept.trimmingCharacters(in: .whitespaces).isEmpty || !payersDraft.canSave
                    )
                // Al editar, borrar es un botón de texto debajo de guardar (pide confirmación).
                if expenseID != nil {
                    Button("Borrar el gasto") { confirmingDelete = true }
                        .buttonStyle(.neoLink)
                        .frame(minHeight: 44)
                }
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(CruceColor.cream)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Listo") { hideKeyboard() }.font(.archivo(16, .extraBold))
            }
        }
        .screenBackground()
        .foregroundStyle(CruceColor.ink)
        .onChange(of: concept) { problem = nil }
        .onChange(of: base) { problem = nil }
        .onChange(of: total) { _, newTotal in payersDraft.setTotal(newTotal) }
        .overlay { dialogs(detail) }
        .animation(.easeOut(duration: 0.15), value: confirmingDelete)
        .animation(.easeOut(duration: 0.15), value: duplicate?.message)
    }

    // MARK: - Secciones

    private var amountCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("MONTO (SIN PROPINA)").textStyle(.label)
            TextField(
                "$0",
                text: Binding(
                    get: { base == 0 ? "" : Money.format(base) },
                    set: { base = Money.parse(digits: $0) })
            )
            .keyboardType(.numberPad)
            .font(.archivo(40, .black, relativeTo: .largeTitle))
            .tracking(-1.6)
            .accessibilityLabel("Monto sin propina")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .neoSurface(fill: CruceColor.yellow, radius: Radius.card, shadow: ShadowOffset.m)
    }

    private func payersSection(_ detail: ParcheDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("¿Quién pagó? Puedes elegir a varios").textStyle(.fieldLabel)
            peopleChips(detail, selected: Set(payersDraft.payerIDs)) { id in
                payersDraft.toggle(id)
                problem = nil
            }
            if payersDraft.hasSeveralPayers {
                Text("¿Cuánto puso cada uno?").textStyle(.fieldLabel).padding(.top, 4)
                VStack(spacing: 8) {
                    ForEach(payersDraft.payerIDs, id: \.self) { id in
                        HStack(spacing: 10) {
                            Text(name(id, in: detail)).font(.archivo(14, .extraBold))
                            Spacer(minLength: 8)
                            MoneyField(
                                label: nil, amount: amountBinding(for: id), height: 40,
                                accessibilityName: "Lo que pagó \(name(id, in: detail))"
                            )
                            .frame(width: 150)
                        }
                    }
                }
                if let mismatch = payersDraft.problemMessage {
                    ParcheProblem(text: mismatch)
                }
            }
        }
    }

    private func methodSection(_ detail: ParcheDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Reparto").textStyle(.fieldLabel)
            // Lo común a la vista; las demás formas se abren con "Otra forma de repartir", cada una con su ejemplo.
            FlowLayout(spacing: 8) {
                Chip(title: Method.equalAll.title, isSelected: !othersOpen) {
                    method = .equalAll
                    showsOtherMethods = false
                }
                Chip(title: "Otra forma de repartir", isSelected: othersOpen) { showsOtherMethods = true }
            }
            if othersOpen {
                VStack(spacing: 8) {
                    ForEach(Method.others, id: \.self) { option in
                        methodOption(option)
                    }
                }
            }
            switch method {
            case .equalAll:
                Text("Lo pagan por partes iguales los \(detail.participants.count) del parche.")
                    .textStyle(.secondary)
                    .foregroundStyle(CruceColor.textSecondary)
            case .equalSome:
                peopleChips(detail, selected: someIDs) { id in
                    if someIDs.contains(id) { someIDs.remove(id) } else { someIDs.insert(id) }
                }
            case .items:
                itemsEditor(detail)
            case .shares:
                weightsEditor(detail, values: $shares, suffix: "partes", range: 0...99)
            case .percentage:
                weightsEditor(detail, values: $percents, suffix: "%", range: 0...100)
            }
        }
    }

    /// Abierta si se pidió o si el gasto ya usa otra forma.
    private var othersOpen: Bool { showsOtherMethods || method != .equalAll }

    /// Una forma de repartir con su ejemplo de una línea; la elegida va marcada.
    private func methodOption(_ option: Method) -> some View {
        let selected = option == method
        return Button {
            method = option
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 18, weight: .bold))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.title).font(.archivo(15, .extraBold))
                    Text(option.example)
                        .textStyle(.secondary)
                        .foregroundStyle(CruceColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(CruceColor.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .neoSurface(
                fill: selected ? CruceColor.yellow : CruceColor.surface, radius: Radius.button,
                border: BorderWidth.thin
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func itemsEditor(_ detail: ParcheDetail) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Cada ítem se reparte entre quienes lo consumieron. Los ítems suman el monto sin propina.")
                .textStyle(.secondary)
                .foregroundStyle(CruceColor.textSecondary)
            ForEach($items) { $item in
                VStack(alignment: .leading, spacing: 8) {
                    TextField(
                        "Nombre (opcional), ej. Mojarra",
                        text: Binding(
                            get: { item.name },
                            set: { item.name = String($0.prefix(ParcheSplitItem.maxNameLength)) })
                    )
                    .font(.archivo(15, .bold))
                    .padding(.horizontal, 12)
                    .frame(height: 40)
                    .neoSurface(radius: Radius.input, border: BorderWidth.thin)
                    .accessibilityLabel("Nombre del ítem")
                    HStack(spacing: 10) {
                        MoneyField(label: nil, amount: $item.amount, height: 40, accessibilityName: "Monto del ítem")
                        IconButton(systemName: "trash", accessibilityLabel: "Quitar el ítem", size: 40) {
                            items.removeAll { $0.id == item.id }
                        }
                    }
                    peopleChips(detail, selected: item.people) { id in
                        if item.people.contains(id) { item.people.remove(id) } else { item.people.insert(id) }
                    }
                }
                .padding(12)
                .neoSurface(radius: Radius.button, border: BorderWidth.thin)
            }
            Button {
                items.append(ItemDraft(id: UUID(), amount: 0, people: []))
            } label: {
                Label("Agregar un ítem", systemImage: "plus")
            }
            .buttonStyle(.dialog(.secondary))
            .labelStyle(NeoLabelStyle())
            // Mientras los ítems no sumen el monto: "Faltan $X por repartir" (o cuánto sobra).
            if base > 0, let remaining = Allocation.itemsRemainingText(base: base, items: splitItems) {
                ParcheProblem(text: remaining)
            }
        }
    }

    private func weightsEditor(
        _ detail: ParcheDetail, values: Binding<[UUID: Int]>, suffix: String, range: ClosedRange<Int>
    ) -> some View {
        VStack(spacing: 8) {
            ForEach(detail.order, id: \.self) { id in
                HStack(spacing: 10) {
                    Text(name(id, in: detail)).font(.archivo(14, .extraBold))
                    Spacer(minLength: 8)
                    NumberField(
                        value: Binding(
                            get: { values.wrappedValue[id] ?? 0 },
                            set: { values.wrappedValue[id] = $0 }),
                        suffix: suffix, range: range,
                        accessibilityName: "\(suffix == "%" ? "Porcentaje" : "Partes") de \(name(id, in: detail))")
                }
            }
            if method == .percentage {
                let sum = percents.values.reduce(0, +)
                Text("Suman \(sum) % de 100 %")
                    .font(.archivo(13, .bold))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private var tipSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Propina").textStyle(.fieldLabel)
            HStack(spacing: 8) {
                ForEach([0, 10, 15], id: \.self) { value in
                    Chip(title: value == 0 ? "Sin propina" : "\(value) %", isSelected: tip == value) { tip = value }
                }
                Spacer(minLength: 0)
                NumberField(value: $tip, suffix: "%", range: 0...100, accessibilityName: "Propina en porcentaje")
            }
        }
    }

    @ViewBuilder
    private func preview(_ detail: ParcheDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Lo que le toca a cada quien").font(.archivo(15, .black))
                Spacer()
                if tip > 0 && base > 0 {
                    Text("Total \(Money.format(total))").font(.archivo(13, .extraBold))
                }
            }
            if base == 0 {
                Text("Escribe el monto para ver cuánto le toca a cada quien.").font(.archivo(13, .bold))
            } else {
                switch allocation(detail) {
                case .success(let result):
                    ForEach(result.shares, id: \.participantID) { share in
                        HStack {
                            Text(name(share.participantID, in: detail)).font(.archivo(14, .bold))
                            Spacer()
                            Text(Money.format(share.amount)).font(.archivo(14, .black))
                        }
                    }
                    if result.tip > 0 {
                        Text(
                            "Incluye \(Money.format(result.tip)) de propina, repartida según lo que consumió cada quien."
                        )
                        .textStyle(.secondary)
                    }
                case .failure(let error):
                    Text(error.message).font(.archivo(13, .bold))
                }
            }
        }
        .foregroundStyle(CruceColor.ink)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .neoSurface(fill: CruceColor.lime, radius: Radius.button)
    }

    @ViewBuilder
    private func dialogs(_ detail: ParcheDetail) -> some View {
        if confirmingDelete, let expenseID {
            NeoDialog(
                systemImage: "trash", iconFill: CruceColor.pink, title: "¿Borrar este gasto?",
                message:
                    "\(concept) · \(Money.format(total)). Deja de contar en los saldos y los del parche ven el aviso.",
                onDismiss: dismissDialogs
            ) {
                HStack(spacing: 10) {
                    Button("Cancelar") { confirmingDelete = false }
                        .buttonStyle(.dialog(.secondary))
                    Button("Borrar") {
                        confirmingDelete = false
                        router.pop()
                        Feedback.play(.expenseDeleted)
                        Task { await parches.deleteExpense(expenseID, in: parcheID) }
                    }
                    .buttonStyle(.dialog(.destructive))
                }
            }
        } else if let duplicate {
            NeoDialog(
                systemImage: "doc.on.doc", iconFill: CruceColor.peach, title: duplicate.message,
                message:
                    "Hay un gasto de \(Money.format(duplicate.expense.amount)) con el mismo pagador anotado hace poco. Revisa que no lo estén anotando dos veces.",
                onDismiss: dismissDialogs
            ) {
                Button("Guardar igual") {
                    let expense = duplicate.expense
                    self.duplicate = nil
                    commit(expense)
                }
                .buttonStyle(.dialog(.primary))
                Button("No guardar") { self.duplicate = nil }
                    .buttonStyle(.dialog(.secondary))
            }
        }
    }

    private func peopleChips(_ detail: ParcheDetail, selected: Set<UUID>, toggle: @escaping (UUID) -> Void)
        -> some View
    {
        // Las personas en filas que se acomodan al ancho.
        FlowLayout(spacing: 8) {
            ForEach(detail.order, id: \.self) { id in
                Chip(title: name(id, in: detail), isSelected: selected.contains(id)) { toggle(id) }
            }
        }
    }

    // MARK: - Cálculos

    private var total: Int { base + base * tip / 100 }

    /// Los ítems del reparto por consumo como los guarda CruceCore (el nombre sin espacios; vacío es sin nombre).
    private var splitItems: [ParcheSplitItem] {
        items.map { ParcheSplitItem(id: $0.id, amount: $0.amount, participantIDs: $0.people, name: $0.name) }
    }

    private func split(_ detail: ParcheDetail) -> ParcheSplit {
        switch method {
        case .equalAll: return .equal(Set(detail.order))
        case .equalSome: return .equal(someIDs)
        case .items:
            return .items(splitItems)
        case .shares: return .shares(shares.filter { $0.value > 0 })
        case .percentage: return .percentage(percents.filter { $0.value > 0 })
        }
    }

    private func allocation(_ detail: ParcheDetail) -> Result<ParcheAllocation, ParcheSplitError> {
        Result { () throws(ParcheSplitError) in
            try Allocation.allocate(base: base, split: split(detail), tipPercent: tip, order: detail.order)
        }
    }

    private func amountBinding(for id: UUID) -> Binding<Int> {
        Binding(get: { payersDraft.amount(of: id) }, set: { payersDraft.setAmount($0, for: id) })
    }

    private func name(_ id: UUID, in detail: ParcheDetail) -> String {
        guard let person = detail.participant(id) else { return "Alguien" }
        return id == detail.myParticipantID ? "\(person.displayName) (tú)" : person.label
    }

    // MARK: - Acciones

    /// Llena el formulario una sola vez: con el gasto que se edita o con los valores de un gasto nuevo.
    private func prepare(_ detail: ParcheDetail) {
        guard !prepared else { return }
        prepared = true
        let everyone = detail.order
        someIDs = Set(everyone)
        shares = Dictionary(uniqueKeysWithValues: everyone.map { ($0, 1) })
        let even = everyone.isEmpty ? 0 : 100 / everyone.count
        percents = Dictionary(
            uniqueKeysWithValues: everyone.enumerated().map { index, id in
                (id, even + (index < 100 - even * everyone.count ? 1 : 0))
            })
        payersDraft = ParchePayersDraft(
            order: everyone, payerIDs: detail.myParticipantID.map { [$0] } ?? Array(everyone.prefix(1)))
        guard let expenseID, let expense = detail.expenses.first(where: { $0.id == expenseID }) else { return }
        concept = expense.concept
        base = expense.baseAmount
        tip = expense.tipPercent
        payersDraft = ParchePayersDraft(order: everyone, editing: expense.payers, total: expense.amount)
        switch expense.split {
        case .equal(let ids):
            if ids == Set(everyone) {
                method = .equalAll
            } else {
                method = .equalSome
                someIDs = ids
            }
        case .items(let list):
            method = .items
            items = list.map {
                ItemDraft(id: $0.id, amount: $0.amount, people: $0.participantIDs, name: $0.name ?? "")
            }
        case .shares(let values):
            method = .shares
            shares = values
        case .percentage(let values):
            method = .percentage
            percents = values
        }
    }

    private func save(_ detail: ParcheDetail) {
        hideKeyboard()
        guard
            let expense = parches.validateExpense(
                in: parcheID, editing: expenseID, concept: concept, base: base, tipPercent: tip,
                split: split(detail), payers: payersDraft.payers)
        else {
            problem = parches.error?.message
            return
        }
        if let message = parches.duplicateWarning(for: expense) {
            duplicate = (expense, message)
        } else {
            commit(expense)
        }
    }

    private func commit(_ expense: ParcheExpense) {
        router.pop()
        Feedback.play(.expenseSaved)
        Task { await parches.save(expense) }
    }

    private func dismissDialogs() {
        confirmingDelete = false
        duplicate = nil
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

/// Acomoda las vistas en filas, pasando a la siguiente cuando no caben (chips de personas).
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let extra =
                rows[rows.count - 1].indices.isEmpty ? size.width : rows[rows.count - 1].width + spacing + size.width
            if extra > width && !rows[rows.count - 1].indices.isEmpty {
                rows.append(Row())
            }
            var row = rows[rows.count - 1]
            row.width = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            row.height = max(row.height, size.height)
            row.indices.append(index)
            rows[rows.count - 1] = row
        }
        return rows.filter { !$0.indices.isEmpty }
    }
}

#if DEBUG
    #Preview("Anotar un gasto") {
        let stores = AppStores.sample()
        return NavigationStack {
            ParcheExpenseView(parcheID: MockParches.santaMartaID).toolbar(.hidden, for: .navigationBar)
        }
        .cruceStores(stores)
        .task { await stores.parches.load() }
    }
#endif
