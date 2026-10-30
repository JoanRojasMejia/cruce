import CruceCore
import SwiftUI

/// Llegada después de "Tengo un código" (pantalla 36).
/// Con `PCH-`: "Entraste a Santa Marta", con los del parche y tu saldo.
/// Con `SOY-`: "Ahora eres Carlos en Santa Marta"; el avatar punteado (sin la app) pasa a sólido y tus gastos y pagos
/// te siguen.
struct ParcheArrivalView: View {
    @Environment(ParcheStore.self) private var parches
    @Environment(Router.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let parcheID: UUID
    private let kind: ParcheArrival.Kind
    /// El avatar del lugar ya es sólido (con la app).
    @State private var solid = false

    init(parcheID: UUID, kind: ParcheArrival.Kind) {
        self.parcheID = parcheID
        self.kind = kind
    }

    var body: some View {
        if let detail = parches.parche(parcheID) {
            FittingScroll {
                VStack(alignment: .leading, spacing: 18) {
                    ScreenHeader(title: "")
                    IllustrationView(
                        illustration: kind == .joined ? .parcheArrival : .placeClaimed, height: 260, minHeight: 140)
                    switch kind {
                    case .joined: joined(detail)
                    case .claimedPlace: claimedPlace(detail)
                    }
                    balanceCard(detail)
                    Spacer(minLength: 0)
                    Button("Ver el parche") {
                        router.pop()
                        router.push(.parche(parcheID))
                    }
                    .buttonStyle(NeoButtonStyle(kind: .primary, height: 58, shadow: ShadowOffset.l))
                }
                .padding(.horizontal, Spacing.screen)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
            .screenBackground()
            .foregroundStyle(CruceColor.ink)
        } else {
            ParcheMissing(parcheID: parcheID)
        }
    }

    // MARK: - PCH

    @ViewBuilder
    private func joined(_ detail: ParcheDetail) -> some View {
        title("Entraste a \(detail.parche.name)")
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: -8) {
                ForEach(detail.participants) { person in
                    ParcheAvatar(participant: person, size: 40)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(detail.participants.map(\.label).joined(separator: ", "))
            Text(peopleText(detail))
                .textStyle(.body)
                .foregroundStyle(CruceColor.textBody)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func peopleText(_ detail: ParcheDetail) -> String {
        let others = detail.participants.filter { $0.id != detail.myParticipantID }.map(\.displayName)
        guard let last = others.last else { return "Por ahora eres la única persona en el parche." }
        if others.count == 1 { return "Estás con \(last)." }
        return "Estás con " + others.dropLast().joined(separator: ", ") + " y \(last)."
    }

    // MARK: - SOY

    @ViewBuilder
    private func claimedPlace(_ detail: ParcheDetail) -> some View {
        title("Ahora eres \(detail.me?.displayName ?? "tú") en \(detail.parche.name)")
        if let me = detail.me {
            HStack(spacing: 14) {
                ZStack {
                    // Antes, sin la app (borde punteado); ahora, con la app (borde sólido).
                    ParcheAvatar(participant: withoutApp(me), size: 56)
                        .opacity(solid ? 0 : 1)
                    ParcheAvatar(participant: me, size: 56)
                        .opacity(solid ? 1 : 0)
                        .scaleEffect(solid ? 1 : 0.8)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(me.displayName), ahora con la app")
                Text("Tus gastos y tus pagos en el parche te siguen: ya son tuyos.")
                    .textStyle(.body)
                    .foregroundStyle(CruceColor.textBody)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .task {
                // Con "Reducir movimiento" el avatar aparece sólido, sin animar.
                guard !reduceMotion else {
                    solid = true
                    return
                }
                try? await Task.sleep(for: .milliseconds(450))
                withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { solid = true }
            }
        }
    }

    /// El mismo lugar como se veía antes de quedarse con él.
    private func withoutApp(_ participant: ParcheParticipant) -> ParcheParticipant {
        var copy = participant
        copy.userID = nil
        return copy
    }

    // MARK: - Comunes

    private func title(_ text: String) -> some View {
        Text(text)
            .font(.archivo(30, .black, relativeTo: .largeTitle))
            .tracking(-1)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Tu saldo en el parche, con la frase y el signo (la dirección no depende del color).
    private func balanceCard(_ detail: ParcheDetail) -> some View {
        let net = detail.myParticipantID.map { detail.balance(of: $0) } ?? 0
        return HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("TU SALDO EN EL PARCHE").textStyle(.label)
                Text(detail.myParticipantID.map { parches.balanceText(net: net, for: $0, in: detail) } ?? "")
                    .font(.archivo(15, .extraBold))
            }
            Spacer(minLength: 8)
            Text(Money.format(net, showsSign: true))
                .font(.archivo(24, .black))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(14)
        .neoSurface(
            fill: net > 0 ? CruceColor.green : net < 0 ? CruceColor.pink : CruceColor.surface, radius: Radius.card,
            shadow: ShadowOffset.s
        )
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
    #Preview("Entraste con PCH") {
        let stores = AppStores.sample()
        return NavigationStack {
            ParcheArrivalView(parcheID: MockParches.santaMartaID, kind: .joined)
                .toolbar(.hidden, for: .navigationBar)
        }
        .cruceStores(stores)
        .task { await stores.parches.load() }
    }

    #Preview("Ahora eres Carlos") {
        let stores = AppStores.sample()
        return NavigationStack {
            ParcheArrivalView(parcheID: MockParches.santaMartaID, kind: .claimedPlace)
                .toolbar(.hidden, for: .navigationBar)
        }
        .cruceStores(stores)
        .task { await stores.parches.load() }
    }
#endif
