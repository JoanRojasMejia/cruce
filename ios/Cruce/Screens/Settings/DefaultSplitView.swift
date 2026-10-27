import CruceCore
import SwiftUI

/// Ajustes → "Reparto por defecto": el reparto con que arranca "Nuevo movimiento" en el cruce abierto.
/// Es del cruce: lo comparten las dos personas.
struct DefaultSplitView: View {
    @Environment(SessionStore.self) private var session
    @Environment(Router.self) private var router
    @State private var mode: AddMovementView.SplitMode = .equal
    @State private var otherShare: Double = 50
    @State private var failed = false

    /// Monto de ejemplo para explicar el reparto.
    private static let example = 100_000

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ScreenHeader(title: "Reparto por defecto")

            Text("Así arranca cada gasto nuevo con \(session.partner.name). Lo pueden cambiar en cada gasto.")
                .textStyle(.body)
                .foregroundStyle(CruceColor.textBody)

            VStack(alignment: .leading, spacing: 8) {
                NeoSegmented(options: AddMovementView.SplitMode.allCases, selection: $mode, title: \.title)
                if mode == .percentage {
                    Text("Parte del otro: \(Int(otherShare))%").font(.archivo(13, .bold))
                    Slider(value: $otherShare, in: 0...100, step: 5)
                        .tint(CruceColor.ink)
                        .accessibilityLabel("Parte del otro")
                        .accessibilityValue("\(Int(otherShare)) por ciento")
                }
            }

            Text(exampleText)
                .font(.archivo(15, .extraBold))
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .neoSurface(fill: CruceColor.surface, radius: Radius.input, border: BorderWidth.thin)

            if failed, let problem = session.error { ProblemText(problem: problem) }

            Spacer(minLength: 0)

            Button {
                Task {
                    if await session.setDefaultSplit(split.otherPercent) {
                        router.pop()
                    } else {
                        failed = true
                    }
                }
            } label: {
                Text(session.isWorking ? "Guardando…" : "Guardar")
            }
            .buttonStyle(NeoButtonStyle(kind: .primary, height: 56, shadow: ShadowOffset.m))
            .disabled(session.isWorking || split.otherPercent == current)
        }
        .foregroundStyle(CruceColor.ink)
        .padding(.horizontal, Spacing.screen)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .screenBackground()
        .onAppear(perform: load)
    }

    private var current: Int {
        session.openCruce?.defaultOtherPercent ?? CruceLink.standardOtherPercent
    }

    private var split: SplitRule {
        switch mode {
        case .equal: return .equal
        case .percentage: return SplitRule(otherPercent: Int(otherShare))
        case .fullOther: return .fullOther
        }
    }

    /// "Si pagas $100.000, a Jesús le tocan $70.000."
    private var exampleText: String {
        let share = Money.share(of: Self.example, percent: split.otherPercent)
        return "Si pagas \(Money.format(Self.example)), a \(session.partner.name) le tocan \(Money.format(share))."
    }

    private func load() {
        switch SplitRule(otherPercent: current) {
        case .equal:
            mode = .equal
        case .percentage(let share):
            mode = .percentage
            otherShare = Double(share)
        case .fullOther:
            mode = .fullOther
        }
    }
}

#if DEBUG
    #Preview {
        NavigationStack {
            DefaultSplitView().toolbar(.hidden, for: .navigationBar)
        }
        .cruceStores(.sample())
    }
#endif
