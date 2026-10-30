import CruceCore
import SwiftUI

/// Diálogo "¿Borrar tu cuenta?" (Tu perfil): dice qué se borra y cómo quedan los cruces y los parches para los demás
/// antes de borrar. No se puede deshacer.
struct DeleteAccountConfirmation: View {
    @Environment(SessionStore.self) private var session
    /// El último intento falló (por ejemplo, sin red): muestra el problema.
    let failed: Bool
    let onCancel: () -> Void
    let onDelete: () -> Void

    init(failed: Bool = false, onCancel: @escaping () -> Void, onDelete: @escaping () -> Void) {
        self.failed = failed
        self.onCancel = onCancel
        self.onDelete = onDelete
    }

    /// Lo que pasa al borrar, en el orden en que se lee.
    private let consequences = [
        "Se borran tu nombre, tu @usuario, tu color y tu correo.",
        "Tus cruces se cierran: la otra persona conserva el historial y te ve como “Cuenta borrada”.",
        "En los parches, tu lugar y tus gastos quedan como “Cuenta borrada”, sin cambiar las cuentas de nadie.",
        "Si vuelves con el mismo correo, empiezas con una cuenta nueva.",
    ]

    var body: some View {
        ZStack {
            CruceColor.scrim.ignoresSafeArea().onTapGesture(perform: onCancel)

            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: "person.crop.circle.badge.xmark")
                    .font(.system(size: 24, weight: .bold))
                    .frame(width: 56, height: 56)
                    .neoSurface(fill: CruceColor.pink, radius: 16, shadow: ShadowOffset.s)
                    .rotationEffect(.degrees(-6))
                    .accessibilityHidden(true)
                Text("¿Borrar tu cuenta?")
                    .font(.archivo(26, .black, relativeTo: .title))
                    .tracking(-0.8)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(consequences, id: \.self) { line in
                        Label {
                            Text(line).fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Image(systemName: "circle.fill").font(.system(size: 6))
                        }
                        .textStyle(.body)
                        .foregroundStyle(CruceColor.textBody)
                    }
                }
                Text("No se puede deshacer.")
                    .font(.archivo(14, .extraBold))
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .neoSurface(fill: CruceColor.peach, radius: Radius.input, border: BorderWidth.thin)
                if failed, let problem = session.error { ProblemText(problem: problem) }
                HStack(spacing: 10) {
                    Button("Cancelar", action: onCancel)
                        .buttonStyle(
                            NeoButtonStyle(kind: .secondary, height: 50, shadow: ShadowOffset.s, radius: Radius.input))
                    Button(session.isWorking ? "Borrando…" : "Borrar", action: onDelete)
                        .buttonStyle(
                            NeoButtonStyle(kind: .destructive, height: 50, shadow: ShadowOffset.s, radius: Radius.input)
                        )
                        .disabled(session.isWorking)
                        .accessibilityLabel("Borrar mi cuenta")
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
        DeleteAccountConfirmation(onCancel: {}, onDelete: {})
            .cruceStores(.sample())
    }
#endif
