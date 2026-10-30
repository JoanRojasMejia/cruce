import CruceCore
import SwiftUI

/// Ticket para compartir: el personal de una persona o el del parche. Se dibuja como un recibo de Tike, se convierte
/// en imagen en el teléfono (`ImageRenderer`) y se comparte con el menú de iOS.
struct ParcheTicketView: View {
    @Environment(ParcheStore.self) private var parches

    private let parcheID: UUID
    private let participantID: UUID?
    /// Fecha y hora del corte: el momento en que se abrió el ticket.
    @State private var cutAt = Date.now
    @State private var image: Image?

    init(parcheID: UUID, participantID: UUID?) {
        self.parcheID = parcheID
        self.participantID = participantID
    }

    var body: some View {
        if let detail = parches.parche(parcheID), let ticket = ticket(for: detail) {
            content(ticket)
        } else {
            ParcheMissing(parcheID: parcheID)
        }
    }

    private func content(_ ticket: ParcheTicket) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ScreenHeader(title: ticket.personName.map { "Ticket de \($0)" } ?? "Ticket del parche")
                Text(
                    ticket.personName == nil
                        ? "Mándalo al chat del parche: dice cuánto se gastó y quién le paga a quién."
                        : "Mándaselo para que sepa cuánto es y por qué."
                )
                .textStyle(.body)
                .foregroundStyle(CruceColor.textBody)
                TicketCard(ticket: ticket)
                    .padding(.horizontal, 4)
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) {
            Group {
                if let image {
                    ShareLink(
                        item: image, message: Text(shareText(ticket)),
                        preview: SharePreview(shareTitle(ticket), image: image)
                    ) {
                        Label("Compartir el ticket", systemImage: "square.and.arrow.up")
                    }
                } else {
                    Button {
                    } label: {
                        Label("Preparando el ticket…", systemImage: "hourglass")
                    }
                    .disabled(true)
                }
            }
            .buttonStyle(NeoButtonStyle(kind: .primary, height: 56, shadow: ShadowOffset.l))
            .labelStyle(NeoLabelStyle())
            .padding(.horizontal, Spacing.screen)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(CruceColor.cream)
        }
        .screenBackground()
        .foregroundStyle(CruceColor.ink)
        .task(id: ticket) { render(ticket) }
    }

    private func ticket(for detail: ParcheDetail) -> ParcheTicket? {
        guard let participantID else { return ParcheTicket.parche(detail, at: cutAt) }
        return ParcheTicket.personal(for: participantID, in: detail, at: cutAt)
    }

    /// Dibuja el ticket a 3x para que se lea bien en el chat.
    private func render(_ ticket: ParcheTicket) {
        let renderer = ImageRenderer(
            content: TicketCard(ticket: ticket)
                .frame(width: 360)
                .padding(20)
                .background(CruceColor.cream)
        )
        renderer.scale = 3
        if let uiImage = renderer.uiImage {
            image = Image(uiImage: uiImage)
        }
    }

    private func shareTitle(_ ticket: ParcheTicket) -> String {
        "Cruce · Parche \(ticket.parcheName)"
    }

    /// El texto corto que acompaña la imagen.
    private func shareText(_ ticket: ParcheTicket) -> String {
        var text = "\(shareTitle(ticket)): \(ticket.headline)"
        if ticket.personName == nil { text += " \(Money.format(ticket.amount))" }
        if let claim = ticket.claimPhrase { text += ". \(claim)." }
        return text
    }
}

/// El recibo: bordes dentados, frase, monto, transferencias, gastos, fecha del corte y sello.
/// No lee el `Environment` de los stores, así `ImageRenderer` lo puede dibujar solo.
struct TicketCard: View {
    let ticket: ParcheTicket

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CRUCE · PARCHE \(ticket.parcheName.uppercased())")
                        .textStyle(.label)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 6) {
                        // La persona del ticket, con el mismo color que en el parche.
                        if let person = ticket.person { ParcheAvatar(participant: person, size: 24) }
                        Text(ticket.personName.map { "Cuentas de \($0)" } ?? "Cuentas del parche")
                            .font(.archivo(14, .bold))
                            .foregroundStyle(CruceColor.textSecondary)
                    }
                }
                Spacer(minLength: 8)
                IllustrationView(illustration: illustration, height: 72)
                    .frame(width: 72)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(ticket.headline).textStyle(.balancePhrase).fixedSize(horizontal: false, vertical: true)
                Text(Money.format(ticket.amount, showsSign: ticket.personName != nil))
                    .font(.archivo(44, .black))
                    .tracking(-1.8)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if let favor = ticket.favor {
                    Text(favor).font(.archivo(14, .extraBold))
                }
                if ticket.personName == nil {
                    Text(ticket.expenseCount == 1 ? "en 1 gasto" : "en \(ticket.expenseCount) gastos")
                        .font(.archivo(14, .extraBold))
                }
            }

            dashed
            section("PARA SALDAR") {
                if ticket.transfers.isEmpty {
                    Text("No hay nada por pagar.").font(.archivo(14, .bold))
                } else {
                    ForEach(ticket.transfers, id: \.self) { line in
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Image(systemName: "arrow.right").font(.system(size: 11, weight: .black))
                            Text(line).font(.archivo(14, .extraBold)).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            if !ticket.lines.isEmpty {
                dashed
                section("GASTOS") {
                    ForEach(ticket.lines, id: \.self) { line in
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(line.concept).font(.archivo(14, .bold))
                                // En un gasto por consumo, lo que consumió (los ítems con nombre).
                                if !line.items.isEmpty {
                                    Text(line.items.joined(separator: ", "))
                                        .textStyle(.secondary)
                                        .foregroundStyle(CruceColor.textSecondary)
                                }
                                if line.paid > 0 {
                                    Text("Pagó \(Money.format(line.paid))")
                                        .textStyle(.secondary)
                                        .foregroundStyle(CruceColor.textSecondary)
                                }
                            }
                            Spacer(minLength: 8)
                            Text(Money.format(line.share)).font(.archivo(14, .black))
                        }
                    }
                    Text("A la derecha, lo que le tocó en cada gasto.")
                        .textStyle(.secondary)
                        .foregroundStyle(CruceColor.textSecondary)
                }
            }

            dashed
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("CORTE").textStyle(.label)
                    // Espacios que no se parten: la hora ("5:25 a. m.") no se corta en dos líneas.
                    Text(
                        "\(DateText.day(ticket.cutAt)) · \(DateText.hour(ticket.cutAt))".replacingOccurrences(
                            of: " ", with: "\u{00A0}")
                    )
                    .font(.archivo(13, .bold))
                    .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                stamp
            }

            if let code = ticket.claimCode {
                HStack(alignment: .center, spacing: 10) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("¿Ya tienes Cruce? Entra con el código").font(.archivo(13, .bold))
                        Text(code).font(.archivo(26, .black)).tracking(1.5)
                        Text("y tus cuentas te siguen.").font(.archivo(13, .bold))
                    }
                    Spacer(minLength: 0)
                    if Illustration.placeClaimedMini.isAvailable {
                        IllustrationView(illustration: .placeClaimedMini, height: 64).frame(width: 64)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .neoSurface(fill: CruceColor.yellow, radius: Radius.input, border: BorderWidth.thin)
                .accessibilityElement(children: .combine)
            }
        }
        .foregroundStyle(CruceColor.ink)
        .padding(.horizontal, 20)
        .padding(.vertical, 26)
        .background(ReceiptShape().fill(CruceColor.surface))
        .overlay(ReceiptShape().stroke(CruceColor.ink, lineWidth: BorderWidth.regular))
        .background(ReceiptShape().fill(CruceColor.ink).offset(x: ShadowOffset.l, y: ShadowOffset.l))
    }

    /// Neutral, sin rosa ni verde: a paz y salvo sigue con il-07; pendiente (individual o de grupo), il-15.
    private var illustration: Illustration {
        ticket.stamp == .settled ? .allClear : .ticketPending
    }

    private var stamp: some View {
        let settled = ticket.stamp == .settled
        return Text(ticket.stamp.rawValue.uppercased())
            .font(.archivo(15, .black))
            .tracking(1)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 6).fill(settled ? CruceColor.green : CruceColor.pink))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(CruceColor.ink, lineWidth: BorderWidth.thick))
            .rotationEffect(.degrees(-8))
            .accessibilityLabel("Sello: \(ticket.stamp.rawValue)")
    }

    private var dashed: some View {
        Line()
            .stroke(CruceColor.ink, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            .frame(height: 1.5)
            .accessibilityHidden(true)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).textStyle(.label)
            content()
        }
    }
}

/// Línea horizontal para el separador punteado del recibo.
private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        }
    }
}

/// Recibo con los bordes de arriba y abajo dentados.
struct ReceiptShape: Shape {
    var tooth: CGFloat = 12

    func path(in rect: CGRect) -> Path {
        let count = max(Int(rect.width / tooth), 1)
        let step = rect.width / CGFloat(count)
        let depth = tooth / 2
        return Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.minY + depth))
            for index in 0..<count {
                let x = rect.minX + CGFloat(index) * step
                path.addLine(to: CGPoint(x: x + step / 2, y: rect.minY))
                path.addLine(to: CGPoint(x: x + step, y: rect.minY + depth))
            }
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - depth))
            for index in 0..<count {
                let x = rect.maxX - CGFloat(index) * step
                path.addLine(to: CGPoint(x: x - step / 2, y: rect.maxY))
                path.addLine(to: CGPoint(x: x - step, y: rect.maxY - depth))
            }
            path.closeSubpath()
        }
    }
}

#if DEBUG
    #Preview("Ticket de Carlos") {
        let stores = AppStores.sample()
        return NavigationStack {
            ParcheTicketView(parcheID: MockParches.santaMartaID, participantID: MockParches.carlos)
                .toolbar(.hidden, for: .navigationBar)
        }
        .cruceStores(stores)
        .task { await stores.parches.load() }
    }

    #Preview("Ticket del parche") {
        let stores = AppStores.sample()
        return NavigationStack {
            ParcheTicketView(parcheID: MockParches.santaMartaID, participantID: nil)
                .toolbar(.hidden, for: .navigationBar)
        }
        .cruceStores(stores)
        .task { await stores.parches.load() }
    }
#endif
