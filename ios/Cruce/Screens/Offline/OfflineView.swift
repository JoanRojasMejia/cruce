import SwiftUI

/// Sin conexión: los movimientos quedan pendientes en el celular (pantalla 10).
struct OfflineView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        FittingScroll { content }
            .foregroundStyle(CruceColor.ink)
            .screenBackground()
    }

    private var content: some View {
        VStack(spacing: 20) {
            HStack {
                CruceLogo()
                Spacer()
                Label("Sin conexión", systemImage: "wifi.slash")
                    .font(.archivo(12, .extraBold))
                    .padding(.horizontal, 10)
                    .frame(height: 32)
                    .neoSurface(fill: CruceColor.pink, radius: 8, border: BorderWidth.thin)
            }

            Spacer(minLength: 0)

            VStack(spacing: 14) {
                IllustrationView(illustration: .offline, height: 290, minHeight: 180)
                Text("No pudimos sincronizar")
                    .font(.archivo(28, .black, relativeTo: .title))
                    .tracking(-0.8)
                    .multilineTextAlignment(.center)
                Text(
                    "Revisa tu internet. Lo que anotes mientras tanto queda guardado en tu celular y se cruza con \(app.partner.name) cuando vuelva la señal."
                )
                .textStyle(.body)
                .foregroundStyle(CruceColor.textBody)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 310)
                if app.pendingSyncCount > 0 {
                    HStack(spacing: 10) {
                        Text("\(app.pendingSyncCount)")
                            .font(.archivo(13, .black))
                            .frame(width: 26, height: 26)
                            .neoSurface(fill: CruceColor.peach, radius: 8, border: BorderWidth.thin)
                        Text(
                            app.pendingSyncCount == 1
                                ? "movimiento pendiente por sincronizar" : "movimientos pendientes por sincronizar"
                        )
                        .font(.archivo(13, .bold))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .neoSurface(radius: Radius.input, border: BorderWidth.thin, dashed: true)
                }
            }

            Spacer(minLength: 0)

            VStack(spacing: 8) {
                Button {
                    Task {
                        await app.retrySync()
                        if !app.isOffline { dismiss() }
                    }
                } label: {
                    Label("Reintentar", systemImage: "arrow.clockwise")
                }
                .buttonStyle(NeoButtonStyle(kind: .primary, height: 58, shadow: ShadowOffset.l))
                .labelStyle(NeoLabelStyle())

                Button("Seguir sin conexión") { dismiss() }
                    .buttonStyle(.neoLink)
            }
        }
        .padding(.horizontal, Spacing.screen)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }
}

#Preview {
    let state = AppState.preview()
    state.pendingSyncCount = 1
    state.isOffline = true
    return NavigationStack { OfflineView().toolbar(.hidden, for: .navigationBar) }.environment(state)
}
