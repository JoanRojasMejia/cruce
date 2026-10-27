import CruceCore
import SwiftUI

/// Ajustes → la tarjeta del perfil: cambiar el nombre propio. La otra persona lo ve cuando vuelve a cargar sus cruces.
struct ProfileView: View {
    @Environment(SessionStore.self) private var session
    @Environment(Router.self) private var router
    @State private var name = ""
    @State private var failed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ScreenHeader(title: "Tu perfil")

            FolderCard(tab: "TU PERFIL", tabColor: CruceColor.yellow) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 14) {
                        Avatar(member: previewMember, size: 72, shadow: ShadowOffset.s)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Así te ven tus amigos").font(.archivo(16, .extraBold))
                            Text("Lo verán la próxima vez que abran Cruce.")
                                .textStyle(.secondary)
                                .foregroundStyle(CruceColor.textSecondary)
                        }
                    }
                    NeoTextField(label: "Tu nombre", text: $name, placeholder: "Tu nombre", fill: CruceColor.cream)
                        .textContentType(.givenName)
                        .onChange(of: name) { _, newValue in
                            if newValue.count > SessionStore.maxNameLength {
                                name = String(newValue.prefix(SessionStore.maxNameLength))
                            }
                        }
                    if failed, let problem = session.error { ProblemText(problem: problem) }
                }
            }

            Spacer(minLength: 0)

            Button {
                Task {
                    if await session.updateName(name) {
                        router.pop()
                    } else {
                        failed = true
                    }
                }
            } label: {
                Text(session.isWorking ? "Guardando…" : "Guardar")
            }
            .buttonStyle(NeoButtonStyle(kind: .primary, height: 56, shadow: ShadowOffset.m))
            .disabled(session.isWorking || trimmed.isEmpty || trimmed == session.me.name)
        }
        .foregroundStyle(CruceColor.ink)
        .padding(.horizontal, Spacing.screen)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .screenBackground()
        .onAppear { name = session.me.name }
    }

    private var trimmed: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var previewMember: Member {
        var member = session.me
        if !trimmed.isEmpty { member.name = trimmed }
        return member
    }
}

#if DEBUG
    #Preview {
        NavigationStack {
            ProfileView().toolbar(.hidden, for: .navigationBar)
        }
        .cruceStores(.sample())
    }
#endif
