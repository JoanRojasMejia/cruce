import CruceCore
import SwiftUI

/// Ajustes → la tarjeta del perfil: cambiar el nombre y el color propios. Los demás los ven cuando vuelven a cargar sus
/// cruces y parches. El color es el mismo en todos los cruces y parches.
struct ProfileView: View {
    @Environment(SessionStore.self) private var session
    @Environment(ParcheStore.self) private var parches
    @Environment(Router.self) private var router
    @State private var name = ""
    @State private var color: AvatarColor = .yellow
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
                    colorPicker
                    if failed, let problem = session.error { ProblemText(problem: problem) }
                }
            }

            Spacer(minLength: 0)

            Button {
                Task { await save() }
            } label: {
                Text(session.isWorking ? "Guardando…" : "Guardar")
            }
            .buttonStyle(NeoButtonStyle(kind: .primary, height: 56, shadow: ShadowOffset.m))
            .disabled(session.isWorking || trimmed.isEmpty || !hasChanges)
        }
        .foregroundStyle(CruceColor.ink)
        .padding(.horizontal, Spacing.screen)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .screenBackground()
        .onAppear {
            name = session.me.name
            color = session.me.avatarColor
        }
    }

    /// "Tu color": las 6 muestras de la paleta; la elegida lleva borde grueso y un chulo.
    private var colorPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Tu color").textStyle(.fieldLabel)
            HStack(spacing: 8) {
                ForEach(AvatarColor.palette, id: \.self) { option in
                    let selected = option == color
                    Button {
                        color = option
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 15, weight: .black))
                            .opacity(selected ? 1 : 0)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(option.color))
                            .overlay(
                                Circle().strokeBorder(
                                    CruceColor.ink, lineWidth: selected ? BorderWidth.thick : BorderWidth.thin)
                            )
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(option.title)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
        .foregroundStyle(CruceColor.ink)
    }

    private var trimmed: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasChanges: Bool {
        trimmed != session.me.name || color != session.me.avatarColor
    }

    /// Guarda lo que cambió (nombre, color o los dos). Con el color nuevo se recargan los parches, donde también cambia.
    private func save() async {
        if color != session.me.avatarColor {
            guard await session.updateColor(color) else {
                failed = true
                return
            }
            await parches.load()
        }
        if trimmed != session.me.name {
            guard await session.updateName(name) else {
                failed = true
                return
            }
        }
        router.pop()
    }

    private var previewMember: Member {
        var member = session.me
        if !trimmed.isEmpty { member.name = trimmed }
        member.avatarColor = color
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
