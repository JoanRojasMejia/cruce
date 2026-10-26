import SwiftUI
import CruceCore

/// Hoja "¡Gasto guardado!" que sube sobre el inicio (pantalla 06).
struct MovementSavedSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    let movement: Movement

    init(movement: Movement) {
        self.movement = movement
    }

    var body: some View {
        VStack(spacing: 14) {
            // Agarrador propio: el del sistema es gris y fino.
            Capsule().fill(CruceColor.ink).frame(width: 48, height: 6)
                .accessibilityHidden(true)

            IllustrationView(illustration: .saved, height: 170)

            Text("¡Gasto guardado!")
                .font(.archivo(30, .black, relativeTo: .largeTitle))
                .tracking(-1)

            MovementRow(
                movement: movement,
                impact: app.impact(of: movement),
                payerName: app.member(movement.payerID).name,
                partnerName: app.partner.name,
                isPayerMe: movement.payerID == app.me.id,
                dateText: movement.category.title
            )

            BeforeAfter(
                beforeTitle: "ANTES",
                before: app.phrase(forNet: app.net - app.impact(of: movement)),
                afterTitle: "AHORA",
                after: app.phrase(forNet: app.net),
                afterColor: app.net >= 0 ? CruceColor.green : CruceColor.pink
            )

            HStack(spacing: 10) {
                Button("Agregar otro") {
                    dismiss()
                    app.path.append(.addMovement)
                }
                .buttonStyle(.neoSecondary)

                Button("Listo") { dismiss() }
                    .buttonStyle(NeoButtonStyle(kind: .primary, height: 54))
            }
            .padding(.top, 2)
        }
        .foregroundStyle(CruceColor.ink)
        .padding(.horizontal, Spacing.screen)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

/// Fondo de una hoja inferior: crema con borde de tinta en el canto superior.
struct SheetBackground: View {
    var body: some View {
        UnevenRoundedRectangle(topLeadingRadius: Radius.sheet, topTrailingRadius: Radius.sheet, style: .circular)
            .fill(CruceColor.cream)
            .overlay(
                UnevenRoundedRectangle(topLeadingRadius: Radius.sheet, topTrailingRadius: Radius.sheet, style: .circular)
                    .strokeBorder(CruceColor.ink, lineWidth: BorderWidth.thick)
            )
            .ignoresSafeArea(edges: .bottom)
    }
}

#Preview {
    let state = AppState.preview()
    return Color.clear
        .sheet(isPresented: .constant(true)) {
            MovementSavedSheet(movement: state.sortedMovements[0])
                .presentationDetents([.height(620)])
                .presentationBackground(CruceColor.cream)
        }
        .environment(state)
}
