import CruceCore
import SwiftUI

/// Detalle de un parche: tu saldo, cómo saldar, pagos por confirmar, gastos, personas, el código y la actividad.
struct ParcheDetailView: View {
    @Environment(SessionStore.self) private var session
    @Environment(ParcheStore.self) private var parches
    @Environment(Router.self) private var router

    private let parcheID: UUID
    /// Avisos sin ver al entrar; al abrir el parche el contador vuelve a cero, pero se resaltan estos.
    @State private var unseenOnOpen: Int?
    @State private var newPerson = ""
    @State private var confirming: ParchePayment?
    @State private var copied = false
    @State private var showsAllActivity = false

    /// Abre la pantalla desde abajo (actividad y cerrar); solo lo usa `DebugScreen`.
    private let startsAtBottom: Bool

    init(parcheID: UUID, startsAtBottom: Bool = false) {
        self.parcheID = parcheID
        self.startsAtBottom = startsAtBottom
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
            }
            await parches.open(parcheID)
        }
    }

    private func content(_ detail: ParcheDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ScreenHeader(title: detail.parche.name) {
                    IconButton(systemName: "square.and.arrow.up", accessibilityLabel: "Ticket del parche", size: 44) {
                        router.push(.parcheTicket(parcheID: parcheID, participantID: nil))
                    }
                }
                HStack(spacing: 8) {
                    Badge(text: parches.statusLabel(for: detail), fill: statusColor(detail))
                    Badge(text: peopleText(detail))
                }
                ParcheSyncBanner()
                if let error = parches.error {
                    ParcheProblem(text: error.message)
                }
                myBalance(detail)
                actions(detail)
                cruceQuestions(detail)
                confirmations(detail)
                transfers(detail)
                balances(detail)
                expenses(detail)
                people(detail)
                codeCard(detail)
                activity(detail)
                if detail.parche.isOpen {
                    Button("Cerrar el parche") { router.push(.closeParche(parcheID: parcheID)) }
                        .buttonStyle(.neoSecondary)
                        .padding(.top, 8)
                }
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .defaultScrollAnchor(startsAtBottom ? .bottom : .top)
        .refreshable { await parches.refresh(parcheID) }
        .screenBackground()
        .foregroundStyle(CruceColor.ink)
        .overlay {
            if let payment = confirming {
                NeoDialog(
                    systemImage: "checkmark", iconFill: CruceColor.green,
                    title: parches.confirmationPrompt(for: payment, in: detail),
                    message: "Cuando confirmes, el pago cuenta en los saldos del parche.",
                    onDismiss: dismissConfirmation
                ) {
                    Button("Sí, confirmo") {
                        confirming = nil
                        Task { await parches.confirmPayment(payment.id, in: parcheID) }
                    }
                    .buttonStyle(.dialog(.primary))
                    Button("Todavía no") { confirming = nil }
                        .buttonStyle(.dialog(.secondary))
                }
            }
        }
        .animation(.easeOut(duration: 0.15), value: confirming)
    }

    // MARK: - Secciones

    private func myBalance(_ detail: ParcheDetail) -> some View {
        let net = detail.myParticipantID.map { detail.balance(of: $0) } ?? 0
        let state = BalanceState(net: net)
        let tab: Color = net > 0 ? CruceColor.green : net < 0 ? CruceColor.pink : CruceColor.neutral
        return FolderCard(
            tab: "TU SALDO EN EL PARCHE", tabColor: tab, tabWidth: 200,
            padding: EdgeInsets(top: 14, leading: 18, bottom: 16, trailing: 18)
        ) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(myPhrase(detail, net: net)).textStyle(.balancePhrase)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(Money.format(net, showsSign: true))
                        .font(.archivo(40, .black, relativeTo: .largeTitle))
                        .tracking(-1.6)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    if let favor = favorText(net: net, for: detail.myParticipantID, in: detail) {
                        Text(favor).font(.archivo(13, .extraBold))
                    }
                }
                Spacer(minLength: 0)
                IllustrationView(
                    illustration: Illustration.balance(state, variant: session.me.tikeVariant), height: 96
                )
                .frame(width: 96)
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func actions(_ detail: ParcheDetail) -> some View {
        HStack(spacing: 12) {
            if detail.parche.isOpen {
                Button {
                    router.push(.addParcheExpense(parcheID: parcheID))
                } label: {
                    Label("Anotar un gasto", systemImage: "plus")
                }
                .buttonStyle(NeoButtonStyle(kind: .primary, height: 54, text: .buttonSecondary))
            }
            Button {
                router.push(.parchePayment(parcheID: parcheID))
            } label: {
                Label("Anotar un pago", systemImage: "arrow.left.arrow.right")
            }
            .buttonStyle(detail.parche.isOpen ? .neoSecondary : NeoButtonStyle(kind: .primary, height: 54))
        }
        .labelStyle(NeoLabelStyle())
    }

    @ViewBuilder
    private func cruceQuestions(_ detail: ParcheDetail) -> some View {
        ForEach(parches.cruceCandidates(in: detail), id: \.other.id) { candidate in
            CruceQuestionCard(parcheID: parcheID, candidate: candidate)
        }
    }

    @ViewBuilder
    private func confirmations(_ detail: ParcheDetail) -> some View {
        let mine = parches.pendingConfirmations(in: detail)
        let others = detail.pendingPayments.filter { $0.toID != detail.myParticipantID }
        if !mine.isEmpty || !others.isEmpty {
            SectionTitle("Pagos por confirmar")
            ForEach(mine) { payment in
                HStack(spacing: 10) {
                    Text(parches.confirmationPrompt(for: payment, in: detail))
                        .font(.archivo(15, .extraBold))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    Button("Confirmar") { confirming = payment }
                        .buttonStyle(
                            NeoButtonStyle(
                                kind: .primary, height: 40, shadow: ShadowOffset.xs, radius: Radius.chip,
                                text: .fieldLabel)
                        )
                        .frame(width: 110)
                }
                .padding(14)
                .neoSurface(fill: CruceColor.peach, radius: Radius.card, shadow: ShadowOffset.s)
            }
            ForEach(others) { payment in
                let receiver = detail.participant(payment.toID)?.displayName ?? "quien recibió"
                VStack(alignment: .leading, spacing: 3) {
                    Text(paymentText(payment, in: detail)).font(.archivo(14, .extraBold))
                    Text("Falta que \(receiver) lo confirme · Anotado por \(detail.recorderName(payment.recordedBy))")
                        .textStyle(.secondary)
                        .foregroundStyle(CruceColor.textSecondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .neoSurface(fill: .clear, radius: Radius.card, border: BorderWidth.thin, dashed: true)
            }
        }
    }

    @ViewBuilder
    private func transfers(_ detail: ParcheDetail) -> some View {
        SectionTitle("Para saldar")
        let transfers = detail.suggestedTransfers
        ParcheCard {
            if transfers.isEmpty {
                Text(detail.expenses.isEmpty ? "Todavía no hay gastos anotados." : "Ya están a paz y salvo.")
                    .textStyle(.body)
                    .padding(14)
            } else {
                ForEach(Array(transfers.enumerated()), id: \.offset) { index, transfer in
                    if index > 0 { CardDivider() }
                    HStack(spacing: 10) {
                        if let from = detail.participant(transfer.fromID) {
                            ParcheAvatar(participant: from, index: detail.index(of: from.id), size: 28)
                        }
                        Image(systemName: "arrow.right").font(.system(size: 12, weight: .black))
                            .accessibilityHidden(true)
                        if let to = detail.participant(transfer.toID) {
                            ParcheAvatar(participant: to, index: detail.index(of: to.id), size: 28)
                        }
                        Text(parches.phrase(for: transfer, in: detail))
                            .font(.archivo(14, .extraBold))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    @ViewBuilder
    private func balances(_ detail: ParcheDetail) -> some View {
        SectionTitle("Saldos")
        ParcheCard {
            ForEach(Array(detail.balances.enumerated()), id: \.element.participantID) { index, balance in
                if index > 0 { CardDivider() }
                if let person = detail.participant(balance.participantID) {
                    Button {
                        router.push(.parcheTicket(parcheID: parcheID, participantID: person.id))
                    } label: {
                        balanceRow(balance, person: person, index: index, in: detail)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Toca para ver y compartir su ticket")
                }
            }
        }
        Text("Toca a una persona para compartir su ticket.")
            .textStyle(.secondary)
            .foregroundStyle(CruceColor.textSecondary)
    }

    private func balanceRow(
        _ balance: ParcheBalance, person: ParcheParticipant, index: Int, in detail: ParcheDetail
    ) -> some View {
        HStack(spacing: 10) {
            ParcheAvatar(participant: person, index: index, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(name(person, in: detail)).textStyle(.rowTitle)
                Text(balanceLine(balance.net, person: person, in: detail))
                    .textStyle(.secondary)
                    .foregroundStyle(CruceColor.textSecondary)
            }
            Spacer(minLength: 8)
            Text(Money.format(balance.net, showsSign: true))
                .font(.archivo(16, .black))
                .lineLimit(1)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .black))
                .accessibilityHidden(true)
        }
        .foregroundStyle(CruceColor.ink)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func expenses(_ detail: ParcheDetail) -> some View {
        let list = detail.visibleExpenses
        SectionTitle(title: "Gastos") {
            Text(Money.format(detail.totalSpent)).font(.archivo(14, .extraBold))
        }
        if list.isEmpty {
            Text(detail.parche.isOpen ? "Anota el primer gasto del parche." : "Este parche no tuvo gastos.")
                .textStyle(.body)
                .foregroundStyle(CruceColor.textBody)
        } else {
            ParcheCard {
                ForEach(Array(list.enumerated()), id: \.element.id) { index, expense in
                    if index > 0 { CardDivider() }
                    Button {
                        router.push(.editParcheExpense(parcheID: parcheID, expenseID: expense.id))
                    } label: {
                        ParcheExpenseRow(expense: expense, detail: detail, editable: detail.parche.isOpen)
                    }
                    .buttonStyle(.plain)
                    .disabled(!detail.parche.isOpen)
                }
            }
        }
    }

    @ViewBuilder
    private func people(_ detail: ParcheDetail) -> some View {
        SectionTitle("Los del parche")
        ParcheCard {
            ForEach(Array(detail.participants.enumerated()), id: \.element.id) { index, person in
                if index > 0 { CardDivider() }
                HStack(spacing: 10) {
                    ParcheAvatar(participant: person, index: detail.index(of: person.id), size: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(name(person, in: detail)).textStyle(.rowTitle)
                        if let code = person.claimCode, !person.hasApp {
                            Text("Su código para quedarse con su lugar: \(code)")
                                .textStyle(.secondary)
                                .foregroundStyle(CruceColor.textSecondary)
                                .textSelection(.enabled)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            if detail.parche.isOpen {
                CardDivider()
                HStack(spacing: 10) {
                    TextField("Nombre de alguien sin la app", text: $newPerson)
                        .font(.archivo(14, .bold))
                        .padding(.horizontal, 12)
                        .frame(height: 40)
                        .neoSurface(radius: Radius.input, border: BorderWidth.thin)
                        .accessibilityLabel("Nombre de alguien sin la app")
                        .submitLabel(.done)
                        .onSubmit { Task { await addPerson() } }
                    Button("Agregar") { Task { await addPerson() } }
                        .buttonStyle(
                            NeoButtonStyle(
                                kind: .primary, height: 40, shadow: ShadowOffset.xs, radius: Radius.chip,
                                text: .fieldLabel)
                        )
                        .frame(width: 96)
                        .disabled(newPerson.trimmingCharacters(in: .whitespaces).isEmpty || parches.isWorking)
                }
                .padding(14)
            }
        }
    }

    private func codeCard(_ detail: ParcheDetail) -> some View {
        let code = detail.parche.code
        return FolderCard(tab: "CÓDIGO DEL PARCHE", tabColor: CruceColor.violet, tabWidth: 180, shadow: ShadowOffset.m)
        {
            VStack(alignment: .leading, spacing: 12) {
                Text(code)
                    .font(.archivo(34, .black))
                    .tracking(1.5)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .textSelection(.enabled)
                Text("Compártelo con los del parche para que entren desde su app.")
                    .textStyle(.secondary)
                    .foregroundStyle(CruceColor.textSecondary)
                HStack(spacing: 10) {
                    ShareLink(item: "Únete al parche \(detail.parche.name) en Cruce con el código \(code)") {
                        Label("Compartir", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.dialog(.primary))
                    Button {
                        UIPasteboard.general.string = code
                        copied = true
                    } label: {
                        Label(copied ? "Copiado" : "Copiar", systemImage: copied ? "checkmark" : "doc.on.doc")
                    }
                    .buttonStyle(.dialog(.secondary))
                }
                .labelStyle(NeoLabelStyle())
            }
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private func activity(_ detail: ParcheDetail) -> some View {
        let items = detail.sortedActivity
        let unseen = unseenOnOpen ?? 0
        SectionTitle(title: "Actividad") {
            if unseen > 0 {
                Badge(text: unseen == 1 ? "1 sin ver" : "\(unseen) sin ver", fill: CruceColor.pink)
            }
        }
        ParcheCard {
            let shown = showsAllActivity ? items : Array(items.prefix(6))
            ForEach(Array(shown.enumerated()), id: \.element.id) { index, item in
                if index > 0 { CardDivider() }
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(index < unseen ? CruceColor.pink : CruceColor.neutral)
                        .overlay(Circle().strokeBorder(CruceColor.ink, lineWidth: 1.5))
                        .frame(width: 10, height: 10)
                        .padding(.top, 4)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(parches.phrase(for: item, in: detail))
                            .font(.archivo(14, index < unseen ? .extraBold : .bold))
                            .fixedSize(horizontal: false, vertical: true)
                        Text(DateText.moment(item.createdAt).capitalizedFirst + (index < unseen ? " · nuevo" : ""))
                            .textStyle(.secondary)
                            .foregroundStyle(CruceColor.textSecondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .accessibilityElement(children: .combine)
            }
            if items.count > 6 && !showsAllActivity {
                CardDivider()
                Button("Ver toda la actividad") { showsAllActivity = true }
                    .buttonStyle(.neoLink)
            }
        }
    }

    // MARK: - Textos

    private func statusColor(_ detail: ParcheDetail) -> Color {
        if detail.isSettled { return CruceColor.green }
        return detail.parche.isOpen ? CruceColor.yellow : CruceColor.neutral
    }

    private func peopleText(_ detail: ParcheDetail) -> String {
        detail.participants.count == 1 ? "1 persona en el parche" : "\(detail.participants.count) personas en el parche"
    }

    private func name(_ person: ParcheParticipant, in detail: ParcheDetail) -> String {
        person.id == detail.myParticipantID ? "\(person.displayName) (tú)" : person.label
    }

    private func myPhrase(_ detail: ParcheDetail, net: Int) -> String {
        if net > 0 { return "Te deben en el parche" }
        if net < 0 { return "Debes en el parche" }
        return detail.isSettled ? "Ya están a paz y salvo" : "Estás a paz y salvo"
    }

    /// "Le deben $125.000 · a favor de Jesús", "Debes $33.000" o "A paz y salvo".
    private func balanceLine(_ net: Int, person: ParcheParticipant, in detail: ParcheDetail) -> String {
        let text = parches.balanceText(net: net, for: person.id, in: detail)
        guard let favor = favorText(net: net, for: person.id, in: detail) else { return text }
        return "\(text) · \(favor)"
    }

    private func favorText(net: Int, for participantID: UUID?, in detail: ParcheDetail) -> String? {
        guard net > 0, let participantID else { return nil }
        if participantID == detail.myParticipantID { return "a tu favor" }
        return "a favor de \(detail.participant(participantID)?.displayName ?? "alguien")"
    }

    private func paymentText(_ payment: ParchePayment, in detail: ParcheDetail) -> String {
        let from = detail.participant(payment.fromID)?.displayName ?? "Alguien"
        let to = detail.participant(payment.toID)?.displayName ?? "alguien"
        let amount = Money.format(payment.amount)
        if payment.fromID == detail.myParticipantID { return "Le pagaste \(amount) a \(to)" }
        return "\(from) le pagó \(amount) a \(to)"
    }

    private func dismissConfirmation() {
        confirming = nil
    }

    private func addPerson() async {
        let name = newPerson
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        if await parches.addParticipant(name: name, to: parcheID) != nil {
            newPerson = ""
        }
    }
}

/// Una fila de gasto: concepto, monto, quién pagó, tu parte y quién lo anotó.
struct ParcheExpenseRow: View {
    let expense: ParcheExpense
    let detail: ParcheDetail
    var editable: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(expense.concept).textStyle(.rowTitle).lineLimit(2)
                Text(payersText).textStyle(.secondary).foregroundStyle(CruceColor.textSecondary)
                Text("Anotado por \(detail.recorderName(expense.recordedBy)) · \(DateText.relative(expense.spentOn))")
                    .textStyle(.secondary)
                    .foregroundStyle(CruceColor.textSecondary)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 3) {
                Text(Money.format(expense.amount)).font(.archivo(16, .black)).lineLimit(1)
                if let me = detail.myParticipantID {
                    Text("Tu parte: \(Money.format(expense.share(of: me)))")
                        .textStyle(.secondary)
                        .foregroundStyle(CruceColor.textSecondary)
                        .lineLimit(1)
                }
            }
            if editable {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .black))
                    .padding(.top, 3)
                    .accessibilityHidden(true)
            }
        }
        .foregroundStyle(CruceColor.ink)
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(editable ? "Toca para editar" : "")
    }

    private var payersText: String {
        let names = expense.payers.map { payer in
            payer.participantID == detail.myParticipantID
                ? "tú" : detail.participant(payer.participantID)?.displayName ?? "alguien"
        }
        guard let first = names.first else { return "" }
        if names.count == 1 { return first == "tú" ? "Pagaste tú" : "Pagó \(first)" }
        return "Pagaron " + names.dropLast().joined(separator: ", ") + " y " + names.last!
    }
}

/// "Joan y tú tienen un cruce": pasar la deuda del parche a su cruce o saldarla en el parche.
struct CruceQuestionCard: View {
    @Environment(ParcheStore.self) private var parches
    let parcheID: UUID
    let candidate: ParcheCruceCandidate

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(candidate.other.displayName) y tú tienen un cruce").textStyle(.sectionTitle)
            Text(parches.crucePrompt(for: candidate))
                .textStyle(.body)
                .fixedSize(horizontal: false, vertical: true)
            Button("Sí, pasarla a tu cruce") {
                Task { await parches.moveDebtToCruce(in: parcheID, with: candidate.other.id) }
            }
            .buttonStyle(.dialog(.primary))
            .disabled(parches.isWorking)
            Button("No, se salda en el parche") {
                Task { await parches.declineCruce(in: parcheID, with: candidate.other.id) }
            }
            .buttonStyle(.dialog(.secondary))
        }
        .foregroundStyle(CruceColor.ink)
        .padding(16)
        .neoSurface(fill: CruceColor.lime, radius: Radius.card, shadow: ShadowOffset.m)
    }
}

extension String {
    /// "hoy a las 3:00 p. m." → "Hoy a las 3:00 p. m.".
    var capitalizedFirst: String {
        prefix(1).uppercased() + dropFirst()
    }
}

#if DEBUG
    #Preview("Santa Marta") {
        let stores = AppStores.sample()
        return NavigationStack {
            ParcheDetailView(parcheID: MockParches.santaMartaID).toolbar(.hidden, for: .navigationBar)
        }
        .cruceStores(stores)
        .task { await stores.parches.load() }
    }
#endif
