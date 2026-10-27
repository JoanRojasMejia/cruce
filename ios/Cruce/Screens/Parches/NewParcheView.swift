import CruceCore
import SwiftUI

/// Nuevo parche: solo el nombre. Al crearlo se abre su detalle con el código para compartir.
struct NewParcheView: View {
    @Environment(ParcheStore.self) private var parches
    @Environment(Router.self) private var router
    @State private var name = ""
    @FocusState private var focused: Bool

    var body: some View {
        FittingScroll {
            VStack(alignment: .leading, spacing: 20) {
                ScreenHeader(title: "Nuevo parche")
                Text(
                    "Un parche es para un viaje, una cena o un paseo con varias personas. Cada quien anota lo que pagó."
                )
                .textStyle(.bodyLarge)
                .foregroundStyle(CruceColor.textBody)
                VStack(alignment: .trailing, spacing: 6) {
                    NeoTextField(
                        label: "Nombre del parche", text: $name, placeholder: "Ej. Santa Marta", focus: $focused)
                    Text("\(name.count)/\(Parche.maxNameLength)")
                        .textStyle(.secondary)
                        .foregroundStyle(CruceColor.textSecondary)
                }
                if let error = parches.error {
                    ParcheProblem(text: error.message)
                }
                IllustrationView(illustration: .welcome, height: 180, minHeight: 100)
                Spacer(minLength: 0)
                Button("Crear parche") { Task { await create() } }
                    .buttonStyle(NeoButtonStyle(kind: .primary, height: 58, shadow: ShadowOffset.l))
                    .disabled(trimmed.isEmpty || trimmed.count > Parche.maxNameLength || parches.isWorking)
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .screenBackground()
        .foregroundStyle(CruceColor.ink)
        .onAppear { focused = true }
        .onChange(of: name) { _, newValue in
            if newValue.count > Parche.maxNameLength { name = String(newValue.prefix(Parche.maxNameLength)) }
        }
    }

    private var trimmed: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func create() async {
        guard let detail = await parches.createParche(name: name) else { return }
        router.pop()
        router.push(.parche(detail.id))
    }
}

/// "Tengo un código": `CRZ-` va al cruce, `PCH-` une a un parche y `SOY-` se queda con un lugar.
struct EnterCodeView: View {
    @Environment(SessionStore.self) private var session
    @Environment(ParcheStore.self) private var parches
    @Environment(Router.self) private var router
    @State private var code = ""
    @State private var problem: String?
    @FocusState private var focused: Bool

    var body: some View {
        FittingScroll {
            VStack(alignment: .leading, spacing: 20) {
                ScreenHeader(title: "Tengo un código")
                Text("Escribe el código que te mandaron, con sus letras del comienzo.")
                    .textStyle(.bodyLarge)
                    .foregroundStyle(CruceColor.textBody)
                TextField("PCH-XXXXXX", text: $code)
                    .font(.archivo(28, .black))
                    .tracking(1.5)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .focused($focused)
                    .submitLabel(.go)
                    .onSubmit { Task { await enter() } }
                    .padding(.horizontal, 16)
                    .frame(height: 64)
                    .neoSurface(
                        fill: focused ? CruceColor.yellow : CruceColor.surface, radius: Radius.input,
                        shadow: ShadowOffset.s
                    )
                    .accessibilityLabel("Código")
                VStack(alignment: .leading, spacing: 10) {
                    hint(prefix: "CRZ-", text: "para unirte al cruce de tu amigo")
                    hint(prefix: "PCH-", text: "para entrar a un parche")
                    hint(prefix: "SOY-", text: "para quedarte con tu lugar en un parche donde te anotaron sin la app")
                }
                if let problem {
                    ParcheProblem(text: problem)
                }
                Spacer(minLength: 0)
                Button("Entrar") { Task { await enter() } }
                    .buttonStyle(NeoButtonStyle(kind: .primary, height: 58, shadow: ShadowOffset.l))
                    .disabled(ParcheCode.normalize(code).isEmpty || parches.isWorking)
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .screenBackground()
        .foregroundStyle(CruceColor.ink)
        .onAppear { focused = true }
        .onChange(of: code) { problem = nil }
    }

    private func hint(prefix: String, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(prefix)
                .font(.archivo(12, .black))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 6).fill(CruceColor.ink))
            Text(text).textStyle(.body).foregroundStyle(CruceColor.textBody)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func enter() async {
        switch ParcheStore.codeKind(code) {
        case .cruce:
            if session.phase == .main {
                // Unirse a otro cruce teniendo ya uno llega con el CP4b ("Tus cruces").
                problem = "Pronto vas a poder tener más de un cruce."
            } else {
                // El código del cruce se escribe en su propia pantalla, que arranca con él.
                session.pendingJoinCode = SessionStore.inviteCode(from: code)
                router.popToRoot()
                session.phase = .join
            }
        case .parche, .place:
            if let detail = await parches.enter(code: code) {
                router.pop()
                router.push(.parche(detail.id))
            } else {
                problem = parches.error?.message ?? ParcheStore.Problem.invalidCode.message
            }
        case nil:
            problem = ParcheStore.Problem.invalidCode.message
        }
    }
}

#if DEBUG
    #Preview("Nuevo parche") {
        NavigationStack { NewParcheView().toolbar(.hidden, for: .navigationBar) }
            .cruceStores(.sample())
    }

    #Preview("Tengo un código") {
        NavigationStack { EnterCodeView().toolbar(.hidden, for: .navigationBar) }
            .cruceStores(.sample())
    }
#endif
