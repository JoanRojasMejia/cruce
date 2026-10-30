import CruceCore
import SwiftUI

/// Ajustes de la cuenta (pantalla 19): perfil, notificaciones, recordatorios, sonidos, invitar, cerrar sesión y versión.
/// Lo del cruce abierto (con quién, moneda, reparto, exportar y desvincular) está en `CruceSettingsView`.
struct SettingsView: View {
    @Environment(SessionStore.self) private var session
    @Environment(LedgerStore.self) private var ledger
    @Environment(Router.self) private var router
    @State private var notifyNewExpense = true
    @AppStorage(Feedback.soundsKey) private var soundsOn = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(title: "Ajustes")

                Button {
                    router.push(.profile)
                } label: {
                    HStack(spacing: 14) {
                        Avatar(member: session.me, size: 54)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.me.name).font(.archivo(18, .extraBold))
                            Text("Entraste con tu correo").textStyle(.secondary).foregroundStyle(
                                CruceColor.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 15, weight: .heavy))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .neoSurface(radius: Radius.card, shadow: ShadowOffset.l)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Cambiar tu nombre y tu color")

                SettingsSection("NOTIFICACIONES") {
                    // Es de la cuenta: aplica a todos tus cruces, no a una sola persona.
                    Toggle(isOn: $notifyNewExpense) {
                        Text("Cuando alguien anote un gasto").font(.archivo(15, .bold))
                    }
                    .toggleStyle(NeoToggleStyle())
                    .frame(minHeight: 52)
                    SettingsDivider()
                    SettingsRow {
                        Text("Recordarme saldar").font(.archivo(15, .bold))
                        Spacer()
                        Text("Cada mes").font(.archivo(13, .extraBold))
                        Image(systemName: "chevron.right").font(.system(size: 13, weight: .heavy))
                    }
                }

                SettingsSection("SONIDOS") {
                    // Solo suenan anotar, pagar, saldar, borrar, un código que no sirve y cerrar un parche.
                    Toggle(isOn: $soundsOn) {
                        Text("Sonidos").font(.archivo(15, .bold))
                    }
                    .toggleStyle(NeoToggleStyle())
                    .frame(minHeight: 52)
                }

                SettingsSection("TUS CRUCES") {
                    SettingsActionRow("Invitar a alguien", systemImage: "person.badge.plus", showsChevron: true) {
                        router.push(.invite)
                    }
                }

                SettingsSection("SESIÓN") {
                    SettingsActionRow("Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right") {
                        // Cruza dos stores: primero se limpia la navegación y luego se cierra la sesión.
                        router.popToRoot()
                        // También se borra lo guardado en el teléfono, para que quien entre después no lo vea.
                        Task {
                            await ledger.reset()
                            await session.signOut()
                        }
                    }
                }

                Text(appVersion)
                    .textStyle(.secondary)
                    .foregroundStyle(CruceColor.textSecondary)
                    .frame(maxWidth: .infinity)
            }
            .foregroundStyle(CruceColor.ink)
            .padding(.horizontal, Spacing.screen)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .screenBackground()
    }

    /// "Cruce 1.0 (1) · testing": fuera de prod dice el ambiente (CRUCE_ENVIRONMENT en el Info.plist).
    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        return AppVersion.line(
            version: info?["CFBundleShortVersionString"] as? String ?? "1.0",
            build: info?["CFBundleVersion"] as? String ?? "1",
            environment: info?["CRUCE_ENVIRONMENT"] as? String
        )
    }
}

#if DEBUG
    #Preview {
        NavigationStack {
            SettingsView().toolbar(.hidden, for: .navigationBar)
        }
        .cruceStores(.sample(withAna: true))
    }
#endif
