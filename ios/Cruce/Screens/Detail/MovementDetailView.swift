import CruceCore
import SwiftUI

/// Detalle de un movimiento con editar y eliminar (pantallas 17 y 18).
struct MovementDetailView: View {
    @Environment(SessionStore.self) private var session
    @Environment(LedgerStore.self) private var ledger
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    let movementID: UUID
    @State private var confirmingDelete: Bool

    init(movementID: UUID, confirmingDelete: Bool = false) {
        self.movementID = movementID
        _confirmingDelete = State(initialValue: confirmingDelete)
    }

    var body: some View {
        Group {
            if let movement = ledger.movement(movementID) {
                content(movement)
                    .overlay {
                        if confirmingDelete {
                            DeleteConfirmation(
                                movement: movement,
                                afterNet: ledger.net - ledger.impact(of: movement),
                                onCancel: { confirmingDelete = false },
                                onDelete: {
                                    confirmingDelete = false
                                    Task {
                                        await ledger.delete(movement.id)
                                        dismiss()
                                    }
                                }
                            )
                            .transition(.opacity)
                        }
                    }
                    .animation(.easeOut(duration: 0.15), value: confirmingDelete)
            } else {
                VStack(spacing: 16) {
                    ScreenHeader(title: "Movimiento")
                    Spacer()
                    Text("Este movimiento ya no existe.").textStyle(.body)
                    Spacer()
                }
                .padding(.horizontal, Spacing.screen)
            }
        }
        .screenBackground()
        .foregroundStyle(CruceColor.ink)
    }

    private func content(_ movement: Movement) -> some View {
        let payer = session.member(movement.payerID)
        let other = session.member(movement.payerID == session.me.id ? session.partner.id : session.me.id)
        let impact = ledger.impact(of: movement)

        return VStack(alignment: .leading, spacing: 16) {
            ScreenHeader(title: "Movimiento") {
                if movement.kind == .expense {
                    IconButton(systemName: "pencil", accessibilityLabel: "Editar movimiento") {
                        router.push(.editMovement(movement.id))
                    }
                }
            }

            FolderCard(
                tab: movement.kind == .settlement ? "PAGO" : movement.category.title.uppercased(),
                tabColor: movement.kind == .settlement ? CruceColor.lime : movement.category.color,
                tabWidth: 120
            ) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 12) {
                        CategoryIcon(category: movement.category, kind: movement.kind, size: 44)
                        Text(movement.concept).font(.archivo(20, .extraBold))
                    }
                    Text(Money.format(movement.amount))
                        .textStyle(.amountMedium)
                        .padding(.top, 6)
                    Text("\(DateText.long(movement.date)) · \(DateText.hour(movement.date))")
                        .textStyle(.secondary)
                        .foregroundStyle(CruceColor.textSecondary)
                }
            }

            VStack(spacing: 0) {
                infoRow("Pagó") {
                    HStack(spacing: 8) {
                        Avatar(member: payer, size: 26)
                        Text(payer.id == session.me.id ? "\(payer.name) (tú)" : payer.name)
                    }
                }
                Rectangle().fill(CruceColor.line).frame(height: 1.5)
                infoRow(movement.kind == .settlement ? "Medio" : "Reparto") {
                    Text(movement.kind == .settlement ? (movement.paymentMethod ?? "—") : movement.split.title)
                }
            }
            .padding(.horizontal, 14)
            .neoSurface(radius: Radius.button)

            if movement.kind == .expense {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Cómo se repartió").textStyle(.fieldLabel)
                    SplitBar(
                        leftName: payer.name, leftAmount: movement.payerShare, leftColor: payer.avatarColor.color,
                        rightName: other.name, rightAmount: movement.owedByOther, rightColor: other.avatarColor.color
                    )
                }
            }

            HStack(spacing: 12) {
                Image(systemName: impact >= 0 ? "arrow.down.left" : "arrow.up.right")
                    .font(.system(size: 16, weight: .heavy))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(.white))
                    .overlay(Circle().strokeBorder(CruceColor.ink, lineWidth: BorderWidth.thin))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text("En el saldo").font(.archivo(12, .bold))
                    Text(
                        "\(Money.format(impact, showsSign: true)) \(impact >= 0 ? "a tu favor" : "a favor de \(session.partner.name)")"
                    )
                    .font(.archivo(17, .black))
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .neoSurface(fill: impact >= 0 ? CruceColor.lime : CruceColor.peach, radius: Radius.button)

            // Usa la fecha del movimiento: todavía no se guarda cuándo se anotó (llega con Supabase en el CP5).
            Text("Lo anotó \(session.member(movement.createdBy).name) \(DateText.moment(movement.date))")
                .textStyle(.secondary)
                .foregroundStyle(CruceColor.textSecondary)

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                if movement.kind == .expense {
                    Button {
                        router.push(.editMovement(movement.id))
                    } label: {
                        Label("Editar", systemImage: "pencil")
                    }
                    .buttonStyle(.neoSecondary)
                }
                Button {
                    confirmingDelete = true
                } label: {
                    Label("Eliminar", systemImage: "trash")
                }
                .buttonStyle(.neoDestructive)
            }
            .labelStyle(NeoLabelStyle())
        }
        .padding(.horizontal, Spacing.screen)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    private func infoRow<Value: View>(_ title: String, @ViewBuilder value: () -> Value) -> some View {
        HStack {
            Text(title).font(.archivo(14, .bold)).foregroundStyle(CruceColor.textSecondary)
            Spacer()
            value().font(.archivo(15, .extraBold))
        }
        .frame(height: 46)
    }
}

/// Barra que muestra cuánto le tocó a cada uno.
struct SplitBar: View {
    let leftName: String
    let leftAmount: Int
    let leftColor: Color
    let rightName: String
    let rightAmount: Int
    let rightColor: Color

    var body: some View {
        GeometryReader { proxy in
            let total = max(leftAmount + rightAmount, 1)
            let leftWidth = proxy.size.width * CGFloat(leftAmount) / CGFloat(total)
            HStack(spacing: 0) {
                segment("\(leftName) · \(Money.format(leftAmount))", color: leftColor)
                    .frame(width: leftWidth)
                Rectangle().fill(CruceColor.ink).frame(
                    width: leftAmount > 0 && rightAmount > 0 ? BorderWidth.regular : 0)
                segment("\(rightName) · \(Money.format(rightAmount))", color: rightColor)
            }
        }
        .frame(height: 38)
        .clipShape(RoundedRectangle(cornerRadius: Radius.input))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.input).strokeBorder(CruceColor.ink, lineWidth: BorderWidth.regular)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(leftName) \(Money.format(leftAmount)), \(rightName) \(Money.format(rightAmount))")
    }

    private func segment(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.archivo(13, .extraBold))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.leading, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(color)
    }
}

/// Diálogo "¿Eliminar este movimiento?".
struct DeleteConfirmation: View {
    @Environment(SessionStore.self) private var session
    @Environment(LedgerStore.self) private var ledger
    let movement: Movement
    let afterNet: Int
    let onCancel: () -> Void
    let onDelete: () -> Void

    init(movement: Movement, afterNet: Int, onCancel: @escaping () -> Void, onDelete: @escaping () -> Void) {
        self.movement = movement
        self.afterNet = afterNet
        self.onCancel = onCancel
        self.onDelete = onDelete
    }

    var body: some View {
        ZStack {
            CruceColor.scrim.ignoresSafeArea().onTapGesture(perform: onCancel)

            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: "trash")
                    .font(.system(size: 24, weight: .bold))
                    .frame(width: 56, height: 56)
                    .neoSurface(fill: CruceColor.pink, radius: 16, shadow: ShadowOffset.s)
                    .rotationEffect(.degrees(-6))
                    .accessibilityHidden(true)
                Text("¿Eliminar este movimiento?")
                    .font(.archivo(26, .black, relativeTo: .title))
                    .tracking(-0.8)
                Text(
                    "\(movement.concept) · \(Money.format(movement.amount)). Se borra para los dos y \(session.partner.name) recibe un aviso."
                )
                .textStyle(.body)
                .foregroundStyle(CruceColor.textBody)
                BeforeAfter(
                    beforeTitle: "AHORA",
                    before: ledger.phrase(forNet: ledger.net),
                    afterTitle: "SI LO ELIMINAS",
                    after: ledger.phrase(forNet: afterNet),
                    afterColor: CruceColor.peach,
                    beforeFill: CruceColor.surface
                )
                HStack(spacing: 10) {
                    Button("Cancelar", action: onCancel)
                        .buttonStyle(
                            NeoButtonStyle(kind: .secondary, height: 50, shadow: ShadowOffset.s, radius: Radius.input))
                    Button("Eliminar", action: onDelete)
                        .buttonStyle(
                            NeoButtonStyle(kind: .destructive, height: 50, shadow: ShadowOffset.s, radius: Radius.input)
                        )
                }
                .padding(.top, 4)
            }
            .foregroundStyle(CruceColor.ink)
            .padding(.horizontal, 20)
            .padding(.vertical, 22)
            .neoSurface(
                fill: CruceColor.cream, radius: Radius.dialog, border: BorderWidth.thick, shadow: ShadowOffset.xxl
            )
            .padding(.horizontal, 24)
            .accessibilityAddTraits(.isModal)
        }
    }
}

#if DEBUG
    #Preview {
        let stores = AppStores.sample()
        return NavigationStack {
            MovementDetailView(movementID: stores.ledger.visibleMovements[0].id)
                .toolbar(.hidden, for: .navigationBar)
        }
        .cruceStores(stores)
    }
#endif
