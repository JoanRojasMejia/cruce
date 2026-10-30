import CruceCore
import SwiftUI

/// Avatar de una persona del parche, con su color fijo (el de su perfil, o el que recibió al entrar sin la app). Quien no
/// tiene la app lleva el borde punteado (además del texto "(sin la app)", nunca solo por el estilo).
struct ParcheAvatar: View {
    let participant: ParcheParticipant
    var size: CGFloat = 36

    var body: some View {
        Text(participant.initials)
            .font(.archivo(size * 0.36, .black))
            .foregroundStyle(CruceColor.ink)
            .frame(width: size, height: size)
            .background(Circle().fill(participant.avatarColor.color))
            .overlay(
                Circle().strokeBorder(
                    CruceColor.ink,
                    style: StrokeStyle(lineWidth: BorderWidth.thin, dash: participant.hasApp ? [] : [4, 3]))
            )
            .accessibilityLabel(participant.label)
    }
}

extension ParcheDetail {
    /// "Ana" o "ti" para quien usa la app (para "Anotado por ti").
    func recorderName(_ participantID: UUID) -> String {
        participantID == myParticipantID ? "ti" : participant(participantID)?.displayName ?? "alguien"
    }
}

/// Encabezado de una sección dentro de una pantalla de parches, con un texto opcional a la derecha.
struct SectionTitle<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).textStyle(.sectionTitle)
            Spacer(minLength: 8)
            trailing
        }
        .foregroundStyle(CruceColor.ink)
        .padding(.top, 6)
    }
}

extension SectionTitle where Trailing == EmptyView {
    init(_ title: String) {
        self.init(title: title) { EmptyView() }
    }
}

/// Tarjeta blanca con borde para listas (personas, gastos, saldos).
struct ParcheCard<Content: View>: View {
    var fill: Color = CruceColor.surface
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .neoSurface(fill: fill, radius: Radius.card, shadow: ShadowOffset.s)
            .foregroundStyle(CruceColor.ink)
    }
}

/// Separador entre filas de una `ParcheCard`.
struct CardDivider: View {
    var body: some View {
        Rectangle().fill(CruceColor.line).frame(height: 1.5).padding(.horizontal, 14)
    }
}

/// Campo de monto en pesos: se escribe con el teclado numérico y se ve como `$30.000`.
struct MoneyField: View {
    let label: String?
    @Binding var amount: Int
    var height: CGFloat = 44
    var accessibilityName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let label { Text(label).textStyle(.fieldLabel) }
            TextField(
                "$0",
                text: Binding(
                    get: { amount == 0 ? "" : Money.format(amount) },
                    set: { amount = Money.parse(digits: $0) })
            )
            .keyboardType(.numberPad)
            .font(.archivo(15, .bold))
            .padding(.horizontal, 12)
            .frame(height: height)
            .neoSurface(radius: Radius.input, border: BorderWidth.thin)
            .accessibilityLabel(accessibilityName ?? label ?? "Monto")
        }
        .foregroundStyle(CruceColor.ink)
    }
}

/// Campo de un número entero pequeño (porcentajes, partes) con su sufijo ("%").
struct NumberField: View {
    @Binding var value: Int
    var suffix: String = ""
    var range: ClosedRange<Int> = 0...100
    var accessibilityName: String

    var body: some View {
        HStack(spacing: 4) {
            TextField(
                "0",
                text: Binding(
                    get: { value == 0 ? "" : String(value) },
                    set: {
                        value = min(range.upperBound, max(range.lowerBound, Int($0.filter(\.isNumber).prefix(6)) ?? 0))
                    })
            )
            .keyboardType(.numberPad)
            .multilineTextAlignment(.trailing)
            if !suffix.isEmpty { Text(suffix) }
        }
        .font(.archivo(15, .bold))
        .foregroundStyle(CruceColor.ink)
        .padding(.horizontal, 12)
        .frame(width: 92, height: 40)
        .neoSurface(radius: Radius.input, border: BorderWidth.thin)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityName)
    }
}

/// Mensaje de error o de ayuda en rosa, con ícono (el texto dice el problema, no solo el color).
struct ParcheProblem: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 13, weight: .bold))
            Text(text).font(.archivo(13, .bold)).fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(CruceColor.ink)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .neoSurface(fill: CruceColor.pink.opacity(0.35), radius: Radius.input, border: BorderWidth.thin)
    }
}

/// En lugar del botón "Cerrar el parche", a quien no lo creó: "Pídele a Jesús que lo cierre".
struct CloseParcheHint: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock").font(.system(size: 14, weight: .bold)).accessibilityHidden(true)
            Text(text).font(.archivo(15, .extraBold)).fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(CruceColor.ink)
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .neoSurface(fill: CruceColor.neutral, radius: Radius.button, border: BorderWidth.thin)
        .accessibilityElement(children: .combine)
    }
}

/// Aviso de que hay cosas sin enviar (sin conexión), con el botón para reintentar.
struct ParcheSyncBanner: View {
    @Environment(ParcheStore.self) private var parches

    var body: some View {
        if parches.isOffline || parches.pendingSyncCount > 0 {
            HStack(spacing: 10) {
                Image(systemName: "wifi.slash").font(.system(size: 15, weight: .bold)).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(parches.isOffline ? "Sin conexión" : "Enviando…").font(.archivo(14, .extraBold))
                    Text(pendingText).textStyle(.secondary).foregroundStyle(CruceColor.textSecondary)
                }
                Spacer(minLength: 8)
                Button("Reintentar") { Task { await parches.retryPending() } }
                    .buttonStyle(
                        NeoButtonStyle(
                            kind: .secondary, height: 36, shadow: ShadowOffset.xs, radius: Radius.chip,
                            text: .fieldLabel)
                    )
                    .frame(width: 112)
            }
            .foregroundStyle(CruceColor.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .neoSurface(fill: CruceColor.peach, radius: Radius.button, border: BorderWidth.thin)
        }
    }

    private var pendingText: String {
        switch parches.pendingSyncCount {
        case 0: return "Lo que anotes se envía cuando vuelva la señal."
        case 1: return "1 cambio guardado en el teléfono, sin enviar."
        default: return "\(parches.pendingSyncCount) cambios guardados en el teléfono, sin enviar."
        }
    }
}

/// Diálogo neobrutalista sobre la pantalla (confirmar, avisos). Los botones los pone quien lo usa.
struct NeoDialog<Actions: View>: View {
    let systemImage: String
    var iconFill: Color = CruceColor.yellow
    let title: String
    var message: String?
    let onDismiss: () -> Void
    @ViewBuilder var actions: Actions

    var body: some View {
        ZStack {
            CruceColor.scrim.ignoresSafeArea().onTapGesture(perform: onDismiss)

            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 24, weight: .bold))
                    .frame(width: 56, height: 56)
                    .neoSurface(fill: iconFill, radius: 16, shadow: ShadowOffset.s)
                    .rotationEffect(.degrees(-6))
                    .accessibilityHidden(true)
                Text(title)
                    .font(.archivo(24, .black, relativeTo: .title))
                    .tracking(-0.6)
                    .fixedSize(horizontal: false, vertical: true)
                if let message {
                    Text(message)
                        .textStyle(.body)
                        .foregroundStyle(CruceColor.textBody)
                        .fixedSize(horizontal: false, vertical: true)
                }
                VStack(spacing: 12) { actions }
                    .padding(.top, 4)
            }
            .foregroundStyle(CruceColor.ink)
            .padding(.horizontal, 20)
            .padding(.vertical, 22)
            .neoSurface(
                fill: CruceColor.cream, radius: Radius.dialog, border: BorderWidth.thick, shadow: ShadowOffset.xxl
            )
            .padding(.horizontal, 24)
            .accessibilityAddTraits(.isModal)
        }
    }
}

/// Botón de diálogo, del alto de los de eliminar.
extension ButtonStyle where Self == NeoButtonStyle {
    static func dialog(_ kind: NeoButtonStyle.Kind) -> NeoButtonStyle {
        NeoButtonStyle(kind: kind, height: 50, shadow: ShadowOffset.s, radius: Radius.input)
    }
}

/// Lo que muestran las pantallas de parches mientras su parche no está cargado; lo pide al repositorio.
struct ParcheMissing: View {
    @Environment(ParcheStore.self) private var parches
    let parcheID: UUID

    var body: some View {
        VStack(spacing: 14) {
            ScreenHeader(title: "Parche")
            Spacer()
            ProgressView().tint(CruceColor.ink)
            Text("Buscando el parche…").textStyle(.body).foregroundStyle(CruceColor.textBody)
            Spacer()
        }
        .padding(.horizontal, Spacing.screen)
        .padding(.top, 8)
        .screenBackground()
        .task { await parches.refresh(parcheID) }
    }
}
