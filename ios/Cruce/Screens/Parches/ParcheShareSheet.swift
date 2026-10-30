import CruceCore
import SwiftUI

/// Hoja del botón de compartir del detalle: el código del parche, el ticket del parche y los del parche
/// (con el código `SOY-` de quien está sin la app y para agregar a alguien más).
struct ParcheShareSheet: View {
    @Environment(ParcheStore.self) private var parches

    private let parcheID: UUID
    /// Cierra la hoja y abre el ticket del parche.
    private let onShareTicket: () -> Void
    @State private var newPerson = ""
    @State private var copied = false

    init(parcheID: UUID, onShareTicket: @escaping () -> Void) {
        self.parcheID = parcheID
        self.onShareTicket = onShareTicket
    }

    var body: some View {
        ScrollView {
            if let detail = parches.parche(parcheID) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Compartir el parche").font(.archivo(22, .black))
                    codeCard(detail)
                    Button(action: onShareTicket) {
                        Label("Compartir el ticket del parche", systemImage: "doc.text")
                    }
                    .buttonStyle(.neoSecondary)
                    .labelStyle(NeoLabelStyle())
                    if let error = parches.error {
                        ParcheProblem(text: error.message)
                    }
                    people(detail)
                }
                .foregroundStyle(CruceColor.ink)
                .padding(.horizontal, Spacing.screen)
                .padding(.top, 24)
                .padding(.bottom, 16)
            }
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
    }

    private func codeCard(_ detail: ParcheDetail) -> some View {
        let code = detail.parche.code
        return FolderCard(tab: "CÓDIGO DEL PARCHE", tabColor: CruceColor.violet, tabWidth: 180, shadow: ShadowOffset.m)
        {
            VStack(alignment: .leading, spacing: 12) {
                Text(code)
                    .font(.archivo(34, .black))
                    .tracking(1.5)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .textSelection(.enabled)
                Text("Compártelo con los del parche para que entren desde su app.")
                    .textStyle(.secondary)
                    .foregroundStyle(CruceColor.textSecondary)
                HStack(spacing: 10) {
                    ShareLink(item: "Únete al parche \(detail.parche.name) en Cruce con el código \(code)") {
                        Label("Compartir", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.dialog(.primary))
                    Button {
                        UIPasteboard.general.string = code
                        copied = true
                    } label: {
                        Label(copied ? "Copiado" : "Copiar", systemImage: copied ? "checkmark" : "doc.on.doc")
                    }
                    .buttonStyle(.dialog(.secondary))
                }
                .labelStyle(NeoLabelStyle())
            }
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private func people(_ detail: ParcheDetail) -> some View {
        SectionTitle("Los del parche")
        ParcheCard {
            ForEach(Array(detail.participants.enumerated()), id: \.element.id) { index, person in
                if index > 0 { CardDivider() }
                HStack(spacing: 10) {
                    ParcheAvatar(participant: person, size: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(person.id == detail.myParticipantID ? "\(person.displayName) (tú)" : person.label)
                            .textStyle(.rowTitle)
                        if let code = person.claimCode, !person.hasApp {
                            Text("Su código para quedarse con su lugar: \(code)")
                                .textStyle(.secondary)
                                .foregroundStyle(CruceColor.textSecondary)
                                .textSelection(.enabled)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            if detail.parche.isOpen {
                CardDivider()
                HStack(spacing: 10) {
                    TextField("Nombre de alguien sin la app", text: $newPerson)
                        .font(.archivo(14, .bold))
                        .padding(.horizontal, 12)
                        .frame(height: 40)
                        .neoSurface(radius: Radius.input, border: BorderWidth.thin)
                        .accessibilityLabel("Nombre de alguien sin la app")
                        .submitLabel(.done)
                        .onSubmit { Task { await addPerson() } }
                    Button("Agregar") { Task { await addPerson() } }
                        .buttonStyle(
                            NeoButtonStyle(
                                kind: .primary, height: 40, shadow: ShadowOffset.xs, radius: Radius.chip,
                                text: .fieldLabel)
                        )
                        .frame(width: 96)
                        .disabled(newPerson.trimmingCharacters(in: .whitespaces).isEmpty || parches.isWorking)
                }
                .padding(14)
            }
        }
    }

    private func addPerson() async {
        let name = newPerson
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        if await parches.addParticipant(name: name, to: parcheID) != nil {
            newPerson = ""
        }
    }
}

#if DEBUG
    #Preview("Compartir el parche") {
        let stores = AppStores.sample()
        return ParcheShareSheet(parcheID: MockParches.santaMartaID) {}
            .screenBackground()
            .cruceStores(stores)
            .task { await stores.parches.load() }
    }
#endif
