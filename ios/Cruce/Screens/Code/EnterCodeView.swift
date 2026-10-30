import CruceCore
import SwiftUI

/// "Tengo un código" (pantalla 36): la única pantalla para entrar con un código. Detecta el tipo por el prefijo
/// mientras se escribe (`CRZ-` une a un cruce, `PCH-` a un parche y `SOY-` se queda con un lugar), muestra a dónde lleva
/// antes de entrar y separa los errores (no existe, venció, ya se usó, es tuyo). La lista de prefijos solo aparece
/// cuando lo escrito no es un código. Se abre también con un enlace `cruce://codigo/<CÓDIGO>` (con el campo lleno).
struct EnterCodeView: View {
    @Environment(SessionStore.self) private var session
    @Environment(ParcheStore.self) private var parches
    @Environment(Router.self) private var router
    @State private var code: String
    @State private var preview: CodePreview?
    /// El error al entrar (por ejemplo, alguien usó el código mientras tanto, o no hay red).
    @State private var problem: String?
    @State private var isChecking = false
    @FocusState private var focused: Bool
    /// Vista previa fija para Debug y las vistas previas: no se consulta mientras el código no cambie.
    private let fixedPreview: (code: String, preview: CodePreview)?

    init(code: String = "", preview: CodePreview? = nil) {
        _code = State(initialValue: code)
        _preview = State(initialValue: preview)
        fixedPreview = preview.map { (EnteredCode.normalize(code), $0) }
    }

    private var shape: EnteredCode.Shape { EnteredCode.shape(of: code) }

    /// El error que se muestra: el de la base, o el de lo escrito si no puede ser un código.
    private var rejection: (title: String, message: String, showsPrefixes: Bool)? {
        switch shape {
        case .unknownPrefix:
            return ("Eso no es un código de Cruce", "Los códigos empiezan con CRZ-, PCH- o SOY-.", true)
        case .malformed:
            return (CodeRejection.invalid.title, CodeRejection.invalid.defaultMessage, true)
        default:
            guard case .rejected(let kind, let message) = preview else { return nil }
            return (kind.title, message, kind.showsPrefixes)
        }
    }

    var body: some View {
        FittingScroll {
            VStack(alignment: .leading, spacing: 20) {
                ScreenHeader(title: "Tengo un código")
                Text("Escribe el código que te mandaron. Por cómo empieza sabemos si es de un cruce o de un parche.")
                    .textStyle(.bodyLarge)
                    .foregroundStyle(CruceColor.textBody)
                    .fixedSize(horizontal: false, vertical: true)
                codeField
                if let rejection {
                    errorCard(rejection)
                } else if let preview {
                    previewCard(preview)
                }
                if let problem {
                    ParcheProblem(text: problem)
                }
                Spacer(minLength: 0)
                Button(buttonTitle) { Task { await enter() } }
                    .buttonStyle(NeoButtonStyle(kind: .primary, height: 58, shadow: ShadowOffset.l))
                    .disabled(!canEnter || session.isWorking || parches.isWorking)
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .screenBackground()
        .foregroundStyle(CruceColor.ink)
        .animation(.easeOut(duration: 0.2), value: preview)
        .onAppear {
            focused = true
            takePendingCode()
        }
        // Un enlace que llega con la pantalla ya abierta llena el campo otra vez.
        .onChange(of: session.pendingCode) { takePendingCode() }
        .onChange(of: code) { problem = nil }
        .task(id: EnteredCode.normalize(code)) { await check() }
    }

    // MARK: - Campo

    private var codeField: some View {
        HStack(spacing: 10) {
            TextField("CRZ-4821", text: $code)
                .font(.archivo(28, .black))
                .tracking(1.5)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .focused($focused)
                .submitLabel(.go)
                .onSubmit { Task { await enter() } }
                .accessibilityLabel("Código")
            if let kind = EnteredCode.kind(of: code) {
                Badge(text: Self.kindName(kind), fill: Self.kindColor(kind))
                    .accessibilityLabel("Código de \(Self.kindName(kind).lowercased())")
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 64)
        .neoSurface(
            fill: focused ? CruceColor.yellow : CruceColor.surface, radius: Radius.input, shadow: ShadowOffset.s
        )
        .animation(.easeOut(duration: 0.15), value: EnteredCode.kind(of: code))
    }

    private static func kindName(_ kind: ParcheCode.Kind) -> String {
        switch kind {
        case .cruce: "Cruce"
        case .parche: "Parche"
        case .place: "Tu lugar"
        }
    }

    private static func kindColor(_ kind: ParcheCode.Kind) -> Color {
        switch kind {
        case .cruce: CruceColor.green
        case .parche: CruceColor.violet
        case .place: CruceColor.peach
        }
    }

    // MARK: - A dónde lleva

    @ViewBuilder
    private func previewCard(_ preview: CodePreview) -> some View {
        switch preview {
        case .cruce(let name):
            FolderCard(tab: "CÓDIGO VÁLIDO", tabColor: CruceColor.green, tabWidth: 160) {
                HStack(spacing: 14) {
                    // Quien invita creó el cruce: su color no viene en la vista previa.
                    Avatar(member: Member(name: name, avatarColor: .yellow, tikeVariant: .rosa), size: 56)
                    previewText(title: "Cuenta de \(name)", detail: "Vas a llevar las cuentas con \(name).")
                }
            }
        case .parche(let name, let alreadyMember):
            FolderCard(tab: "PARCHE", tabColor: CruceColor.violet, tabWidth: 120) {
                previewText(
                    title: name,
                    detail: alreadyMember ? "Ya estás en este parche." : "Vas a entrar a \(name) con tu nombre.")
            }
        case .place(let parcheName, let personName):
            FolderCard(tab: "TU LUGAR", tabColor: CruceColor.peach, tabWidth: 130) {
                previewText(
                    title: "Eres \(personName) en \(parcheName)",
                    detail: "Te quedas con su lugar: sus gastos y pagos pasan a ser tuyos.")
            }
        case .rejected:
            EmptyView()
        }
    }

    private func previewText(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.archivo(18, .extraBold)).fixedSize(horizontal: false, vertical: true)
            Text(detail)
                .textStyle(.secondary)
                .foregroundStyle(CruceColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Errores

    private func errorCard(_ rejection: (title: String, message: String, showsPrefixes: Bool)) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                IllustrationView(illustration: .invalidCode, height: 120)
                    .frame(width: 120)
                VStack(alignment: .leading, spacing: 4) {
                    Text(rejection.title).font(.archivo(18, .extraBold)).fixedSize(horizontal: false, vertical: true)
                    Text(rejection.message)
                        .textStyle(.secondary)
                        .foregroundStyle(CruceColor.textBody)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if rejection.showsPrefixes {
                VStack(alignment: .leading, spacing: 10) {
                    hint(prefix: "CRZ-", text: "para unirte al cruce de tu amigo")
                    hint(prefix: "PCH-", text: "para entrar a un parche")
                    hint(prefix: "SOY-", text: "para quedarte con tu lugar en un parche donde te anotaron sin la app")
                }
            }
        }
        .transition(.opacity)
    }

    private func hint(prefix: String, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(prefix)
                .font(.archivo(12, .black))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 6).fill(CruceColor.ink))
            Text(text).textStyle(.body).foregroundStyle(CruceColor.textBody)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Entrar

    private var canEnter: Bool {
        switch preview {
        case .cruce, .parche, .place: rejection == nil && !isChecking
        default: false
        }
    }

    private var buttonTitle: String {
        switch preview {
        case .cruce(let name): "Unirme a la cuenta de \(name)"
        case .parche(_, let alreadyMember): alreadyMember ? "Ver el parche" : "Entrar al parche"
        case .place: "Quedarme con el lugar"
        default: "Entrar"
        }
    }

    private func takePendingCode() {
        guard let pending = session.pendingCode else { return }
        code = pending
        session.pendingCode = nil
    }

    /// Con el código completo, pregunta a dónde lleva; con menos, borra la respuesta anterior.
    private func check() async {
        let normalized = EnteredCode.normalize(code)
        if let fixedPreview, fixedPreview.code == normalized {
            preview = fixedPreview.preview
            return
        }
        preview = nil
        guard case .complete(let kind, let full) = shape else { return }
        isChecking = true
        defer { isChecking = false }
        // Si el código cambió mientras se revisaba, `.task(id:)` cancela este chequeo: su respuesta ya no se muestra
        // (ni un error de conexión falso encima de la del código nuevo).
        switch kind {
        case .cruce:
            await session.checkCode(full)
            guard !Task.isCancelled else { return }
            preview = session.invitePreview.map(CodePreview.init)
            if preview == nil { problem = session.error?.message }
        case .parche, .place:
            let answer = await parches.previewCode(full)
            guard !Task.isCancelled else { return }
            preview = answer
            if preview == nil { problem = parches.error?.message }
        }
    }

    private func enter() async {
        guard canEnter, case .complete(let kind, let full) = shape else { return }
        switch kind {
        case .cruce:
            if await session.join(code: full) {
                // Sin cruces se pasa a "Conectados" (otra raíz): la pila de invitar se vacía. En el inicio,
                // "Conectados" sale encima y al cerrarlo vuelve al inicio.
                if session.phase != .main { router.popToRoot() }
            } else {
                problem = session.error?.message
            }
        case .parche, .place:
            guard let arrival = await parches.enter(code: full) else {
                problem = parches.error?.message ?? CodeRejection.invalid.defaultMessage
                return
            }
            // "Tengo un código" se reemplaza por la llegada (o por el parche, si ya estaba en él).
            router.pop()
            if case .parche(_, true) = preview {
                router.push(.parche(arrival.detail.id))
            } else {
                router.push(.parcheArrival(parcheID: arrival.detail.id, kind: arrival.kind))
            }
        }
    }
}

#if DEBUG
    #Preview("Tengo un código") {
        NavigationStack { EnterCodeView().toolbar(.hidden, for: .navigationBar) }
            .cruceStores(.sample())
    }

    #Preview("Código de cruce") {
        NavigationStack {
            EnterCodeView(code: "CRZ-4821", preview: .cruce(inviterName: "Joan")).toolbar(.hidden, for: .navigationBar)
        }
        .cruceStores(.sample(phase: .invite, viewer: MockData.jesus))
    }

    #Preview("Código vencido") {
        NavigationStack {
            EnterCodeView(
                code: "CRZ-4821", preview: .rejected(.expired, message: CodeRejection.expired.defaultMessage)
            )
            .toolbar(.hidden, for: .navigationBar)
        }
        .cruceStores(.sample())
    }

    #Preview("Código que no existe") {
        NavigationStack {
            EnterCodeView(
                code: "PCH-ZZZZZZ", preview: .rejected(.invalid, message: CodeRejection.invalid.defaultMessage)
            )
            .toolbar(.hidden, for: .navigationBar)
        }
        .cruceStores(.sample())
    }
#endif
