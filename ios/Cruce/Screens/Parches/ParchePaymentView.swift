import CruceCore
import SwiftUI

/// Anotar un pago entre dos del parche. Cuenta de una vez si lo anota quien recibe o si quien recibe no tiene la app;
/// si no, queda pendiente hasta que lo confirme.
struct ParchePaymentView: View {
    @Environment(ParcheStore.self) private var parches
    @Environment(Router.self) private var router

    private let parcheID: UUID
    @State private var fromID: UUID?
    @State private var toID: UUID?
    @State private var amount = 0
    @State private var problem: String?

    init(parcheID: UUID) {
        self.parcheID = parcheID
    }

    var body: some View {
        if let detail = parches.parche(parcheID) {
            content(detail)
        } else {
            ParcheMissing(parcheID: parcheID)
        }
    }

    private func content(_ detail: ParcheDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ScreenHeader(title: "Anotar un pago")
                suggestions(detail)
                picker("¿Quién pagó?", detail: detail, selection: $fromID)
                picker("¿A quién le pagó?", detail: detail, selection: $toID)
                MoneyField(label: "Monto", amount: $amount, height: 52)
                if let from = fromID, let to = toID, from != to, amount > 0 {
                    Text(summary(from: from, to: to, in: detail))
                        .font(.archivo(14, .extraBold))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .neoSurface(fill: CruceColor.lime, radius: Radius.button)
                }
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
            Button("Anotar el pago") { Task { await save() } }
                .buttonStyle(NeoButtonStyle(kind: .primary, height: 54))
                .disabled(fromID == nil || toID == nil || fromID == toID || amount == 0)
                .padding(.horizontal, Spacing.screen)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .background(CruceColor.cream)
        }
        .screenBackground()
        .foregroundStyle(CruceColor.ink)
        .onChange(of: amount) { problem = nil }
    }

    @ViewBuilder
    private func suggestions(_ detail: ParcheDetail) -> some View {
        let transfers = detail.suggestedTransfers
        if !transfers.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Para saldar (toca uno para llenarlo)").textStyle(.fieldLabel)
                ForEach(Array(transfers.enumerated()), id: \.offset) { _, transfer in
                    Button {
                        fromID = transfer.fromID
                        toID = transfer.toID
                        amount = transfer.amount
                    } label: {
                        HStack {
                            Text(parches.phrase(for: transfer, in: detail))
                                .font(.archivo(14, .extraBold))
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 8)
                            Image(systemName: "arrow.down.left").font(.system(size: 13, weight: .black))
                                .accessibilityHidden(true)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .neoSurface(
                            fill: isSelected(transfer) ? CruceColor.peach : CruceColor.surface,
                            radius: Radius.button, border: BorderWidth.thin)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected(transfer) ? .isSelected : [])
                }
            }
        }
    }

    private func picker(_ title: String, detail: ParcheDetail, selection: Binding<UUID?>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).textStyle(.fieldLabel)
            FlowLayout(spacing: 8) {
                ForEach(detail.order, id: \.self) { id in
                    Chip(title: name(id, in: detail), isSelected: selection.wrappedValue == id) {
                        selection.wrappedValue = id
                    }
                }
            }
        }
    }

    private func isSelected(_ transfer: ParcheTransfer) -> Bool {
        transfer.fromID == fromID && transfer.toID == toID && transfer.amount == amount
    }

    private func name(_ id: UUID, in detail: ParcheDetail) -> String {
        guard let person = detail.participant(id) else { return "Alguien" }
        return id == detail.myParticipantID ? "\(person.displayName) (tú)" : person.label
    }

    /// Qué va a pasar con el pago: cuenta de una vez o queda esperando la confirmación.
    private func summary(from: UUID, to: UUID, in detail: ParcheDetail) -> String {
        let transfer = ParcheTransfer(fromID: from, toID: to, amount: amount)
        let phrase = parches.phrase(for: transfer, in: detail)
        guard let me = detail.myParticipantID else { return phrase }
        if ParcheCalculator.confirmsImmediately(recordedBy: me, toID: to, participants: detail.participants) {
            return "\(phrase). Cuenta de una vez en los saldos."
        }
        let receiver = detail.participant(to)?.displayName ?? "quien recibió"
        return "\(phrase). Queda pendiente hasta que \(receiver) lo confirme."
    }

    private func save() async {
        guard let fromID, let toID else { return }
        if await parches.recordPayment(in: parcheID, from: fromID, to: toID, amount: amount) != nil {
            router.pop()
        } else {
            problem = parches.error?.message
        }
    }
}

/// Cerrar el parche: confirma que ya no se anotan gastos y luego pregunta, por cada persona con la que compartes
/// un cruce, si la deuda pasa a su cruce.
struct CloseParcheView: View {
    @Environment(ParcheStore.self) private var parches
    @Environment(Router.self) private var router

    private let parcheID: UUID
    @State private var closed: Bool

    init(parcheID: UUID, closed: Bool = false) {
        self.parcheID = parcheID
        _closed = State(initialValue: closed)
    }

    var body: some View {
        if let detail = parches.parche(parcheID) {
            FittingScroll {
                VStack(alignment: .leading, spacing: 18) {
                    ScreenHeader(title: closed ? "Parche cerrado" : "Cerrar el parche")
                    if closed || !detail.parche.isOpen {
                        afterClosing(detail)
                    } else {
                        confirmation(detail)
                    }
                }
                .padding(.horizontal, Spacing.screen)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
            .screenBackground()
            .foregroundStyle(CruceColor.ink)
        } else {
            ParcheMissing(parcheID: parcheID)
        }
    }

    @ViewBuilder
    private func confirmation(_ detail: ParcheDetail) -> some View {
        IllustrationView(illustration: .settle, height: 200, minHeight: 110)
        Text("¿Cerrar \(detail.parche.name)?")
            .font(.archivo(30, .black, relativeTo: .largeTitle))
            .tracking(-1)
            .fixedSize(horizontal: false, vertical: true)
        Text(
            "Ya no se podrán anotar gastos ni editarlos. Los pagos se siguen anotando hasta que todos queden a paz y salvo. Un parche cerrado no se vuelve a abrir."
        )
        .textStyle(.body)
        .foregroundStyle(CruceColor.textBody)
        HStack(spacing: 10) {
            summaryBox(title: "GASTADO", value: Money.format(detail.totalSpent))
            summaryBox(title: "PARA SALDAR", value: transfersText(detail.suggestedTransfers.count))
        }
        .fixedSize(horizontal: false, vertical: true)
        if let error = parches.error {
            ParcheProblem(text: error.message)
        }
        Spacer(minLength: 0)
        Button("Sí, cerrar el parche") {
            Task {
                if await parches.close(parcheID) {
                    if let updated = parches.parche(parcheID), parches.cruceCandidates(in: updated).isEmpty {
                        router.pop()
                    } else {
                        closed = true
                    }
                }
            }
        }
        .buttonStyle(NeoButtonStyle(kind: .dark, height: 56, shadow: ShadowOffset.l))
        .disabled(parches.isWorking)
        Button("Cancelar") { router.pop() }
            .buttonStyle(.neoSecondary)
    }

    @ViewBuilder
    private func afterClosing(_ detail: ParcheDetail) -> some View {
        let candidates = parches.cruceCandidates(in: detail)
        Text(candidates.isEmpty ? "Listo, el parche quedó cerrado." : "Una pregunta más")
            .font(.archivo(30, .black, relativeTo: .largeTitle))
            .tracking(-1)
        Text(
            candidates.isEmpty
                ? "Ya no se anotan gastos. Los pagos que falten se anotan en el parche."
                : "Con quien compartes un cruce, lo que se deben en el parche puede pasar a su cruce."
        )
        .textStyle(.body)
        .foregroundStyle(CruceColor.textBody)
        ForEach(candidates, id: \.other.id) { candidate in
            CruceQuestionCard(parcheID: parcheID, candidate: candidate)
        }
        if let error = parches.error {
            ParcheProblem(text: error.message)
        }
        Spacer(minLength: 0)
        Button("Volver al parche") { router.pop() }
            .buttonStyle(candidates.isEmpty ? NeoButtonStyle(kind: .primary, height: 56) : .neoSecondary)
    }

    private func summaryBox(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.archivo(11, .extraBold)).tracking(1)
            Text(value).font(.archivo(16, .black))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .neoSurface(radius: Radius.input, border: BorderWidth.thin)
    }

    private func transfersText(_ count: Int) -> String {
        switch count {
        case 0: return "Nada"
        case 1: return "1 pago"
        default: return "\(count) pagos"
        }
    }
}

#if DEBUG
    #Preview("Anotar un pago") {
        let stores = AppStores.sample()
        return NavigationStack {
            ParchePaymentView(parcheID: MockParches.santaMartaID).toolbar(.hidden, for: .navigationBar)
        }
        .cruceStores(stores)
        .task { await stores.parches.load() }
    }

    #Preview("Cerrar el parche") {
        let stores = AppStores.sample()
        return NavigationStack {
            CloseParcheView(parcheID: MockParches.santaMartaID).toolbar(.hidden, for: .navigationBar)
        }
        .cruceStores(stores)
        .task { await stores.parches.load() }
    }
#endif
