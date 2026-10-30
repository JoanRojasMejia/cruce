import CruceCore
import SwiftUI

/// Ajustes del cruce abierto (pantalla 25): con quién es y desde cuándo, moneda, reparto por defecto,
/// exportar el historial y desvincular. Se abre con el engrane de un cruce.
/// Cuando el cruce es el inicio (un solo cruce), termina con "Tu cuenta", que abre los Ajustes de la cuenta.
struct CruceSettingsView: View {
    @Environment(SessionStore.self) private var session
    @Environment(LedgerStore.self) private var ledger
    @Environment(Router.self) private var router
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
                ScreenHeader(title: "Ajustes del cruce")

                SettingsSection("TU CRUCE") {
                    SettingsRow {
                        Avatar(member: session.partner, size: 24)
                        Text("Con \(session.partner.name)").font(.archivo(15, .bold))
                        Spacer()
                        if let first = ledger.visibleMovements.last?.date {
                            Text("desde \(DateText.relative(first))").textStyle(.secondary).foregroundStyle(
                                CruceColor.textSecondary)
                        }
                    }
                    SettingsDivider()
                    SettingsRow {
                        Text("Moneda").font(.archivo(15, .bold))
                        Spacer()
                        Text("Peso colombiano (COP)").font(.archivo(13, .bold)).foregroundStyle(
                            CruceColor.textSecondary)
                    }
                    // Un cruce cerrado (desvinculado) es de solo lectura: no cambia de reparto.
                    if !session.isOpenCruceClosed {
                        SettingsDivider()
                        Button {
                            router.push(.defaultSplit)
                        } label: {
                            SettingsRow {
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

                SettingsSection("DATOS") {
                    if let exportURL {
                        ShareLink(item: exportURL) {
                            SettingsActionLabel(title: "Exportar historial (CSV)", systemImage: "arrow.down.to.line")
                        }
                        .buttonStyle(.plain)
                    } else {
                        SettingsActionLabel(title: "Exportar historial (CSV)", systemImage: "arrow.down.to.line")
                            .opacity(0.4)
                    }
                    if !session.isOpenCruceClosed {
                        SettingsDivider()
                        SettingsActionRow(
                            "Desvincular a \(session.partner.name)", systemImage: "xmark", tint: CruceColor.pink
                        ) {
                            confirmingUnlink = true
                        }
                    }
                }

                // Con un solo cruce no hay "Tus cruces" con su engrane: la cuenta se abre desde aquí.
                if !session.showsCruceList {
                    SettingsSection("CUENTA") {
                        SettingsActionRow("Tu cuenta", systemImage: "person.crop.circle", showsChevron: true) {
                            router.push(.settings)
                        }
                    }
                }
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
}

#if DEBUG
    #Preview("Un solo cruce") {
        NavigationStack {
            CruceSettingsView().toolbar(.hidden, for: .navigationBar)
        }
        .cruceStores(.sample())
    }

    #Preview("Desde Tus cruces") {
        NavigationStack {
            CruceSettingsView().toolbar(.hidden, for: .navigationBar)
        }
        .cruceStores(.sample(withAna: true))
    }
#endif
