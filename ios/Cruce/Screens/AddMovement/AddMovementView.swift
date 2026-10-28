import CruceCore
import SwiftUI

/// Nuevo movimiento (pantalla 05) y edición de uno existente.
struct AddMovementView: View {
    enum SplitMode: Hashable, CaseIterable {
        case equal, percentage, fullOther

        var title: String {
            switch self {
            case .equal: return "50/50"
            case .percentage: return "Porcentaje"
            case .fullOther: return "Todo es del otro"
            }
        }
    }

    @Environment(SessionStore.self) private var session
    @Environment(LedgerStore.self) private var ledger
    @Environment(Router.self) private var router

    private let editing: Movement?
    @State private var digits: String
    @State private var payerID: UUID?
    @State private var concept: String
    @State private var category: MovementCategory
    @State private var splitMode: SplitMode
    @State private var otherShare: Double
    @FocusState private var editingConcept: Bool

    /// `defaultSplit`: el reparto con que arranca un movimiento nuevo (el reparto por defecto del cruce). Al editar se
    /// usa el reparto del movimiento.
    init(editing: Movement? = nil, defaultSplit: SplitRule = .equal) {
        self.editing = editing
        _digits = State(initialValue: editing.map { String($0.amount) } ?? "")
        _payerID = State(initialValue: editing?.payerID)
        _concept = State(initialValue: editing?.concept ?? "")
        _category = State(initialValue: editing?.category ?? .comida)
        let mode: SplitMode
        let share: Int
        switch editing?.split ?? defaultSplit {
        case .percentage(let s):
            mode = .percentage
            share = s
        case .fullOther:
            mode = .fullOther
            share = 100
        case .equal:
            mode = .equal
            share = 50
        }
        _splitMode = State(initialValue: mode)
        _otherShare = State(initialValue: Double(share))
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                content
                    // Ocupa al menos el alto visible, para que tocar el espacio vacío de abajo también baje el teclado.
                    .frame(minHeight: proxy.size.height, alignment: .top)
                    // Tocar el espacio vacío baja el teclado del sistema y vuelve a mostrar el del monto. Va en el
                    // fondo, no en el contenedor, para que tocar el campo del concepto no le quite el foco.
                    .background {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { editingConcept = false }
                    }
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        // Solo el botón queda fijo: el teclado numérico va en el contenido, debajo de la vista previa,
        // para que nunca la tape. En pantallas chicas se llega con scroll.
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                Button(editing == nil ? "Guardar movimiento" : "Guardar cambios") {
                    Task { await save() }
                }
                .buttonStyle(NeoButtonStyle(kind: .primary, height: 54))
                .disabled(amount == 0)
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(CruceColor.cream)
        }
        // Elegir quién pagó, la categoría o el reparto también baja el teclado.
        .onChange(of: payerID) { editingConcept = false }
        .onChange(of: category) { editingConcept = false }
        .onChange(of: splitMode) { editingConcept = false }
        .screenBackground()
        .foregroundStyle(CruceColor.ink)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScreenHeader(title: editing == nil ? "Nuevo movimiento" : "Editar movimiento")
            amountCard
            payerPicker
            NeoTextField(label: "Concepto", text: $concept, placeholder: "Ej. Cena viernes", focus: $editingConcept)
                .submitLabel(.done)
                // La base acepta conceptos de hasta 80 caracteres (`movements.concept`).
                .onChange(of: concept) { _, newValue in
                    if newValue.count > 80 { concept = String(newValue.prefix(80)) }
                }
            categoryPicker
            splitPicker
            previewCard
            // Mientras se escribe el concepto, el teclado del sistema reemplaza al numérico.
            if !editingConcept {
                AmountKeypad(digits: $digits)
            }
        }
        .padding(.horizontal, Spacing.screen)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    // MARK: - Secciones

    private var amountCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("MONTO").textStyle(.label)
            HStack(spacing: 4) {
                Text(Money.format(amount))
                    .font(.archivo(46, .black, relativeTo: .largeTitle))
                    .tracking(-2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Rectangle().fill(CruceColor.ink).frame(width: 3, height: 40)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .neoSurface(fill: CruceColor.yellow, radius: Radius.card, shadow: ShadowOffset.m)
        // Tocar el monto mientras se escribe el concepto baja el teclado y muestra el teclado del monto.
        .contentShape(Rectangle())
        .onTapGesture { editingConcept = false }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Monto \(Money.format(amount))")
    }

    private var payerPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("¿Quién pagó?").textStyle(.fieldLabel)
            HStack(spacing: 10) {
                payerButton(session.me, title: "\(session.me.name) (tú)")
                payerButton(session.partner, title: session.partner.name)
            }
        }
    }

    private func payerButton(_ member: Member, title: String) -> some View {
        let selected = currentPayerID == member.id
        return Button {
            payerID = member.id
        } label: {
            HStack(spacing: 8) {
                Avatar(member: member, size: 24)
                Text(title).font(.archivo(15, .extraBold))
            }
            .foregroundStyle(selected ? .white : CruceColor.ink)
            .frame(maxWidth: .infinity, minHeight: 44)
            .neoSurface(
                fill: selected ? CruceColor.ink : CruceColor.surface,
                radius: Radius.input,
                shadow: selected ? 0 : ShadowOffset.s
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var categoryPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Categoría").textStyle(.fieldLabel)
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(MovementCategory.allCases) { item in
                        Chip(title: item.title, isSelected: item == category, selectedColor: item.color) {
                            category = item
                        }
                    }
                }
                .padding(.vertical, 2)
                .padding(.trailing, 4)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var splitPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Reparto").textStyle(.fieldLabel)
            NeoSegmented(options: SplitMode.allCases, selection: $splitMode, title: \.title)
            if splitMode == .percentage {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Parte de \(otherMember.name): \(Int(otherShare))% · \(Money.format(draft.owedByOther))")
                        .font(.archivo(13, .bold))
                    Slider(value: $otherShare, in: 0...100, step: 5)
                        .tint(CruceColor.ink)
                }
                .padding(.top, 4)
            }
        }
    }

    private var previewCard: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Ahora: \(ledger.phrase(forNet: baseNet))")
                    .font(.archivo(12, .bold))
                Text("Después de esto: \(ledger.phrase(forNet: baseNet + newImpact))")
                    .font(.archivo(16, .black))
                    .tracking(-0.2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: newImpact >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 16, weight: .heavy))
                .frame(width: 34, height: 34)
                .background(Circle().fill(.white))
                .overlay(Circle().strokeBorder(CruceColor.ink, lineWidth: BorderWidth.thin))
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .neoSurface(fill: CruceColor.lime, radius: Radius.button)
    }

    // MARK: - Cálculos

    private var amount: Int { Money.parse(digits: digits) }

    private var currentPayerID: UUID { payerID ?? session.me.id }

    private var otherMember: Member {
        currentPayerID == session.me.id ? session.partner : session.me
    }

    private var split: SplitRule {
        switch splitMode {
        case .equal: return .equal
        case .percentage: return .percentage(otherShare: Int(otherShare))
        case .fullOther: return .fullOther
        }
    }

    private var draft: Movement {
        let trimmed = concept.trimmingCharacters(in: .whitespacesAndNewlines)
        return Movement(
            id: editing?.id ?? UUID(),
            payerID: currentPayerID,
            amount: amount,
            concept: trimmed.isEmpty ? category.title : trimmed,
            category: category,
            split: split,
            date: editing?.date ?? .now,
            createdBy: editing?.createdBy ?? session.me.id
        )
    }

    /// Saldo actual sin el movimiento que se está editando.
    private var baseNet: Int {
        guard let editing else { return ledger.net }
        return ledger.net - ledger.impact(of: editing)
    }

    private var newImpact: Int { ledger.impact(of: draft) }

    private func save() async {
        guard amount > 0 else { return }
        let movement = draft
        router.pop()
        await ledger.save(movement)
    }
}

#if DEBUG
    #Preview {
        NavigationStack {
            AddMovementView()
                .toolbar(.hidden, for: .navigationBar)
        }
        .cruceStores(.sample())
    }
#endif
