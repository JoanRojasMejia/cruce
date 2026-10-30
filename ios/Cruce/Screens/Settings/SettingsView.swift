import CruceCore
import SwiftUI

/// Ajustes (pantalla 19).
struct SettingsView: View {
    @Environment(SessionStore.self) private var session
    @Environment(LedgerStore.self) private var ledger
    @Environment(Router.self) private var router
    @State private var notifyNewExpense = true
    @State private var confirmingUnlink: Bool
    @State private var unlinkFailed = false
    /// El historial del cruce abierto ya escrito como CSV, listo para compartir.
    @State private var exportURL: URL?

    init(confirmingUnlink: Bool = false) {
        _confirmingUnlink = State(initialValue: confirmingUnlink)
    }

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
                .accessibilityHint("Cambiar tu nombre")

                section("CUENTA COMPARTIDA") {
                    row {
                        Avatar(member: session.partner, size: 24)
                        Text("Con \(session.partner.name)").font(.archivo(15, .bold))
                        Spacer()
                        if let first = ledger.visibleMovements.last?.date {
                            Text("desde \(DateText.relative(first))").textStyle(.secondary).foregroundStyle(
                                CruceColor.textSecondary)
                        }
                    }
                    divider
                    actionRow("Invitar a alguien", systemImage: "person.badge.plus") {
                        router.push(.invite)
                    }
                    divider
                    row {
                        Text("Moneda").font(.archivo(15, .bold))
                        Spacer()
                        Text("Peso colombiano (COP)").font(.archivo(13, .bold)).foregroundStyle(
                            CruceColor.textSecondary)
                    }
                    // Un cruce cerrado (desvinculado) es de solo lectura: no cambia de reparto.
                    if !session.isOpenCruceClosed {
                        divider
                        Button {
                            router.push(.defaultSplit)
                        } label: {
                            row {
                                Text("Reparto por defecto").font(.archivo(15, .bold))
                                Spacer()
                                Text(defaultSplit.defaultTitle).font(.archivo(13, .extraBold))
                                Image(systemName: "chevron.right").font(.system(size: 13, weight: .heavy))
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                section("NOTIFICACIONES") {
                    Toggle(isOn: $notifyNewExpense) {
                        Text("Cuando \(session.partner.name) anote un gasto").font(.archivo(15, .bold))
                    }
                    .toggleStyle(NeoToggleStyle())
                    .frame(minHeight: 52)
                    divider
                    row {
                        Text("Recordarme saldar").font(.archivo(15, .bold))
                        Spacer()
                        Text("Cada mes").font(.archivo(13, .extraBold))
                        Image(systemName: "chevron.right").font(.system(size: 13, weight: .heavy))
                    }
                }

                section("DATOS") {
                    if let exportURL {
                        ShareLink(item: exportURL) {
                            actionLabel("Exportar historial (CSV)", systemImage: "arrow.down.to.line")
                        }
                        .buttonStyle(.plain)
                    } else {
                        actionLabel("Exportar historial (CSV)", systemImage: "arrow.down.to.line")
                            .opacity(0.4)
                    }
                    divider
                    if !session.isOpenCruceClosed {
                        actionRow("Desvincular a \(session.partner.name)", systemImage: "xmark", tint: CruceColor.pink)
                        {
                            confirmingUnlink = true
                        }
                        divider
                    }
                    actionRow("Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right") {
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
        .overlay {
            if confirmingUnlink {
                UnlinkConfirmation(
                    failed: unlinkFailed,
                    onCancel: {
                        confirmingUnlink = false
                        unlinkFailed = false
                    },
                    onUnlink: {
                        Task {
                            // Al cerrarse, el inicio pasa a "Tus cruces": se vuelve a la raíz.
                            if await session.closeOpenCruce() {
                                confirmingUnlink = false
                                router.popToRoot()
                            } else {
                                unlinkFailed = true
                            }
                        }
                    },
                    onSettleFirst: {
                        confirmingUnlink = false
                        unlinkFailed = false
                        router.push(.settle)
                    }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: confirmingUnlink)
        // El archivo se vuelve a escribir cuando cambian los movimientos o la otra persona.
        .task(id: ExportKey(movements: ledger.movements, me: session.me, partner: session.partner)) {
            exportURL = try? HistoryExport.write(
                movements: ledger.movements, me: session.me, partner: session.partner)
        }
    }

    private var defaultSplit: SplitRule {
        SplitRule(otherPercent: session.openCruce?.defaultOtherPercent ?? CruceLink.standardOtherPercent)
    }

    /// Lo que cambia el archivo exportado.
    private struct ExportKey: Equatable {
        let movements: [Movement]
        let me: Member
        let partner: Member
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

    private var divider: some View {
        Rectangle().fill(CruceColor.line).frame(height: 1.5)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).textStyle(.label).padding(.leading, 4)
            VStack(spacing: 0, content: content)
                .padding(.horizontal, 14)
                .neoSurface(radius: Radius.button)
        }
    }

    private func row<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 10, content: content).frame(minHeight: 48)
    }

    private func actionRow(
        _ title: String, systemImage: String, tint: Color = CruceColor.ink, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            actionLabel(title, systemImage: systemImage, tint: tint)
        }
        .buttonStyle(.plain)
    }

    private func actionLabel(_ title: String, systemImage: String, tint: Color = CruceColor.ink) -> some View {
        HStack(spacing: 10) {
            Group {
                if tint == CruceColor.ink {
                    Image(systemName: systemImage).font(.system(size: 16, weight: .bold))
                } else {
                    // Acción delicada: cuadro de color con borde y símbolo en tinta, como en el diseño.
                    Image(systemName: systemImage)
                        .font(.system(size: 10, weight: .black))
                        .frame(width: 20, height: 20)
                        .background(RoundedRectangle(cornerRadius: 5).fill(tint))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5).strokeBorder(
                                CruceColor.ink, lineWidth: BorderWidth.thin))
                }
            }
            // Ancho fijo para que los textos de las filas queden alineados.
            .frame(width: 24)
            Text(title).font(.archivo(15, tint == CruceColor.ink ? .bold : .extraBold))
            Spacer()
        }
        .foregroundStyle(CruceColor.ink)
        .frame(minHeight: 48)
        .contentShape(Rectangle())
    }
}

#if DEBUG
    #Preview {
        NavigationStack {
            SettingsView().toolbar(.hidden, for: .navigationBar)
        }
        .cruceStores(.sample())
    }
#endif
