import CruceCore
import SwiftUI

/// Diálogo "¿Desvincular a Jesús?": explica que el cruce se cierra para los dos y, si hay, el saldo pendiente.
/// Con saldo pendiente ofrece "Saldar primero", porque un cruce cerrado ya no acepta pagos.
struct UnlinkConfirmation: View {
    @Environment(SessionStore.self) private var session
    @Environment(LedgerStore.self) private var ledger
    /// El último intento falló (por ejemplo, sin red): muestra el problema.
    let failed: Bool
    let onCancel: () -> Void
    let onUnlink: () -> Void
    /// Cierra el diálogo y abre "Saldar cuentas".
    let onSettleFirst: () -> Void

    init(
        failed: Bool = false, onCancel: @escaping () -> Void, onUnlink: @escaping () -> Void,
        onSettleFirst: @escaping () -> Void = {}
    ) {
        self.failed = failed
        self.onCancel = onCancel
        self.onUnlink = onUnlink
        self.onSettleFirst = onSettleFirst
    }

    var body: some View {
        ZStack {
            CruceColor.scrim.ignoresSafeArea().onTapGesture(perform: onCancel)

            VStack(alignment: .leading, spacing: 14) {
                if Illustration.cruceClosed.isAvailable {
                    IllustrationView(illustration: .cruceClosed, height: 120).accessibilityHidden(true)
                } else {
                    Image(systemName: "xmark")
                        .font(.system(size: 24, weight: .bold))
                        .frame(width: 56, height: 56)
                        .neoSurface(fill: CruceColor.pink, radius: 16, shadow: ShadowOffset.s)
                        .rotationEffect(.degrees(-6))
                        .accessibilityHidden(true)
                }
                Text("¿Desvincular a \(session.partner.name)?")
                    .font(.archivo(26, .black, relativeTo: .title))
                    .tracking(-0.8)
                Text(
                    "Su cruce se cierra para los dos: ya no se puede anotar ni saldar. El historial queda guardado para verlo y exportarlo. Si quieren volver, se vinculan con un código nuevo."
                )
                .textStyle(.body)
                .foregroundStyle(CruceColor.textBody)
                if ledger.net != 0 {
                    Text(pendingText)
                        .font(.archivo(14, .extraBold))
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .neoSurface(fill: CruceColor.peach, radius: Radius.input, border: BorderWidth.thin)
                }
                if failed, let problem = session.error { ProblemText(problem: problem) }
                if ledger.offersSettleBeforeUnlink {
                    Button(action: onSettleFirst) {
                        Label("Saldar primero", systemImage: "checkmark")
                    }
                    .buttonStyle(
                        NeoButtonStyle(kind: .primary, height: 50, shadow: ShadowOffset.s, radius: Radius.input)
                    )
                    .disabled(session.isWorking)
                    .padding(.top, 4)
                }
                HStack(spacing: 10) {
                    Button("Cancelar", action: onCancel)
                        .buttonStyle(
                            NeoButtonStyle(kind: .secondary, height: 50, shadow: ShadowOffset.s, radius: Radius.input))
                    Button(session.isWorking ? "Cerrando…" : "Desvincular", action: onUnlink)
                        .buttonStyle(
                            NeoButtonStyle(kind: .destructive, height: 50, shadow: ShadowOffset.s, radius: Radius.input)
                        )
                        .disabled(session.isWorking)
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

    /// El saldo pendiente y qué pasa con él: después de desvincular ya no se puede saldar.
    private var pendingText: String {
        let phrase = ledger.phrase(forNet: ledger.net)
        return ledger.offersSettleBeforeUnlink
            ? "Saldo pendiente: \(phrase). Después de desvincular ya no se puede saldar."
            : "Saldo pendiente: \(phrase). Queda anotado en el historial."
    }
}

#if DEBUG
    #Preview("Con saldo pendiente") {
        UnlinkConfirmation(onCancel: {}, onUnlink: {})
            .cruceStores(.sample())
    }

    #Preview("A paz y salvo") {
        UnlinkConfirmation(onCancel: {}, onUnlink: {})
            .cruceStores(.sample(movements: []))
    }
#endif
