import CruceCore
import SwiftUI

/// "Elige tu @usuario": el paso de la entrada después del nombre. Arranca con la sugerencia que la base le puso a partir
/// del nombre; mientras se escribe dice si está disponible. "Seguir" lo guarda y pasa a invitar.
struct ChooseUsernameView: View {
    @Environment(SessionStore.self) private var session
    @State private var username = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Elige tu @usuario").textStyle(.title1Compact)
                Text("Así tus amigos te distinguen de otra persona con tu mismo nombre.")
                    .textStyle(.bodyLarge)
                    .foregroundStyle(CruceColor.textBody)
            }

            FolderCard(tab: "TU @USUARIO", tabColor: CruceColor.yellow) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 14) {
                        Avatar(member: session.me, size: 72, shadow: ShadowOffset.s)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(session.me.name).font(.archivo(16, .extraBold))
                            Text(Username.display(Username.normalize(username)))
                                .textStyle(.secondary)
                                .foregroundStyle(CruceColor.textSecondary)
                            Text("Puedes cambiarlo después en Tu perfil.")
                                .textStyle(.secondary)
                                .foregroundStyle(CruceColor.textSecondary)
                        }
                    }
                    UsernameField(username: $username)
                    if let problem = session.error { ProblemText(problem: problem) }
                }
            }

            Spacer(minLength: 0)

            Button {
                Task { await session.chooseUsername(username) }
            } label: {
                Text(session.isWorking ? "Guardando…" : "Seguir")
            }
            .buttonStyle(
                NeoButtonStyle(kind: .dark, height: 56, shadow: ShadowOffset.m, shadowTint: CruceColor.yellow)
            )
            .disabled(session.isWorking || !isAvailable)
        }
        .foregroundStyle(CruceColor.ink)
        .padding(.horizontal, Spacing.screen)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .screenBackground()
        .onAppear {
            if username.isEmpty { username = session.me.username ?? "" }
        }
    }

    private var isAvailable: Bool {
        if case .available(let checked) = session.usernameCheck {
            return checked == Username.normalize(username)
        }
        return false
    }
}

/// El campo del @usuario con su revisión en vivo: lo revisa un momento después de dejar de escribir
/// (`SessionStore.checkUsername`) y dice si está disponible, si está ocupado o por qué no sirve. Lo usan la entrada y
/// Tu perfil.
struct UsernameField: View {
    @Environment(SessionStore.self) private var session
    @Binding var username: String

    init(username: Binding<String>) {
        _username = username
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            NeoTextField(label: "Tu @usuario", text: $username, placeholder: "tu.usuario", fill: CruceColor.cream)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.asciiCapable)
                .textContentType(.username)
                .onChange(of: username) { _, newValue in
                    // Uno más que el máximo (y la @), para que se vea el aviso en vez de cortar sin explicar.
                    let limit = Username.maxLength + 2
                    if newValue.count > limit { username = String(newValue.prefix(limit)) }
                }
            status
        }
        .task(id: username) {
            // Espera a que deje de escribir; si cambia antes, esta tarea se cancela y no pregunta.
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            await session.checkUsername(username)
        }
    }

    @ViewBuilder
    private var status: some View {
        let normalized = Username.normalize(username)
        // Solo la respuesta del @usuario que está escrito ahora (mientras se escribe otro, "Revisando…").
        switch session.usernameChecked == normalized ? session.usernameCheck : nil {
        case .available(let checked):
            // En Tu perfil, el que ya tiene no se anuncia como "disponible".
            Label(
                checked == session.me.username
                    ? "Es tu @usuario" : "\(Username.display(checked)) está disponible",
                systemImage: "checkmark.circle.fill"
            )
            .font(.archivo(14, .bold))
            .accessibilityAddTraits(.updatesFrequently)
        case .rejected(_, let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.archivo(14, .bold))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.updatesFrequently)
        default:
            Text(normalized.isEmpty ? "De 3 a 20: minúsculas, números, punto o guion bajo." : "Revisando…")
                .textStyle(.secondary)
                .foregroundStyle(CruceColor.textSecondary)
        }
    }
}

#if DEBUG
    #Preview("Elige tu @usuario") {
        ChooseUsernameView().cruceStores(.sample(phase: .chooseUsername, userID: MockData.joan.id))
    }
#endif
