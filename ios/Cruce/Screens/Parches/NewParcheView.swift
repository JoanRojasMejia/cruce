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
                IllustrationView(illustration: .newParche, height: 200, minHeight: 100)
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

#if DEBUG
    #Preview("Nuevo parche") {
        NavigationStack { NewParcheView().toolbar(.hidden, for: .navigationBar) }
            .cruceStores(.sample())
    }
#endif
