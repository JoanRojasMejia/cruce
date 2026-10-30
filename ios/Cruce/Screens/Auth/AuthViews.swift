import CruceCore
import SwiftUI
import UIKit

/// Crear cuenta o volver a entrar (pantalla 13), en tres pasos que salen de la sesión:
/// el correo, el código de 6 dígitos que llega a ese correo y, la primera vez, el nombre.
/// Sin contraseña ni enlace mágico: el mismo flujo crea la cuenta y vuelve a entrar.
struct SignUpView: View {
    @Environment(SessionStore.self) private var session

    var body: some View {
        Group {
            if session.userID != nil {
                NameStep()
            } else if let email = session.pendingEmail {
                CodeStep(email: email)
            } else {
                EmailStep()
            }
        }
        .foregroundStyle(CruceColor.ink)
        .padding(.horizontal, Spacing.screen)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .screenBackground()
        .animation(.easeInOut(duration: 0.25), value: session.pendingEmail)
        .animation(.easeInOut(duration: 0.25), value: session.userID)
    }
}

/// Paso 1: el correo al que llega el código.
private struct EmailStep: View {
    @Environment(SessionStore.self) private var session
    @State private var email = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            BackButton { session.phase = .onboarding }

            VStack(alignment: .leading, spacing: 10) {
                Text("Entra con tu correo").textStyle(.title1Compact)
                Text("Te enviamos un código de 6 dígitos. Sirve para crear tu cuenta o para volver a entrar.")
                    .textStyle(.bodyLarge)
                    .foregroundStyle(CruceColor.textBody)
            }

            FolderCard(tab: "TU CORREO", tabColor: CruceColor.yellow) {
                VStack(alignment: .leading, spacing: 12) {
                    NeoTextField(
                        label: "¿Cuál es tu correo?", text: $email, placeholder: "tu@correo.com",
                        fill: CruceColor.cream, focus: $focused
                    )
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.send)
                    .onSubmit(send)
                    if let problem = session.error { ProblemText(problem: problem) }
                }
            }

            Spacer(minLength: 0)

            VStack(spacing: 12) {
                Button(action: send) {
                    Text(session.isWorking ? "Enviando…" : "Enviarme el código")
                }
                .buttonStyle(
                    NeoButtonStyle(kind: .dark, height: 56, shadow: ShadowOffset.m, shadowTint: CruceColor.yellow)
                )
                .disabled(session.isWorking || email.trimmingCharacters(in: .whitespaces).isEmpty)

                TermsText()
            }
        }
        .onAppear { focused = true }
    }

    private func send() {
        Task { await session.sendCode(to: email) }
    }
}

/// Paso 2: el código de 6 dígitos. Se verifica solo al completar los seis.
private struct CodeStep: View {
    @Environment(SessionStore.self) private var session
    let email: String
    @State private var digits = ""
    @State private var resent = false
    @FocusState private var focused: Bool

    init(email: String) {
        self.email = email
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            BackButton { session.cancelCode() }

            VStack(alignment: .leading, spacing: 10) {
                Text("Escribe el código").textStyle(.title1Compact)
                (Text("Te lo enviamos a ") + Text(email).font(.archivo(17, .extraBold)) + Text("."))
                    .textStyle(.bodyLarge)
                    .foregroundStyle(CruceColor.textBody)
            }

            codeField

            if let problem = session.error {
                ProblemText(problem: problem)
            } else if resent {
                Text("Te enviamos un código nuevo.")
                    .textStyle(.secondary)
                    .foregroundStyle(CruceColor.textSecondary)
            }

            // Sin respaldo: mientras il-09 no esté, no se dibuja nada.
            IllustrationView(illustration: .checkEmail, height: 180, minHeight: 100)

            Spacer(minLength: 0)

            VStack(spacing: 8) {
                Button(action: verify) {
                    Text(session.isWorking ? "Revisando…" : "Entrar")
                }
                .buttonStyle(NeoButtonStyle(kind: .primary, height: 58, shadow: ShadowOffset.l))
                .disabled(session.isWorking || digits.count < SessionStore.codeLength)

                Button("Pedir otro código") {
                    digits = ""
                    Task { resent = await session.resendCode() }
                }
                .buttonStyle(.neoLink)
                .disabled(session.isWorking)

                Button("Cambiar el correo") { session.cancelCode() }
                    .buttonStyle(.neoLink)
            }
        }
        .onAppear { focused = true }
    }

    private func verify() {
        resent = false
        Task {
            if !(await session.verify(code: digits)) { digits = "" }
        }
    }

    /// Seis cajas alimentadas por un campo oculto (el teclado ofrece el código del correo).
    private var codeField: some View {
        HStack(spacing: 8) {
            ForEach(0..<SessionStore.codeLength, id: \.self) { index in
                Text(character(at: index))
                    .font(.archivo(28, .black))
                    .frame(maxWidth: .infinity)
                    .frame(height: 64)
                    .neoSurface(
                        fill: index == digits.count && focused ? CruceColor.yellow : CruceColor.surface,
                        radius: Radius.input, shadow: ShadowOffset.s)
            }
        }
        .overlay {
            TextField("", text: $digits)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($focused)
                .foregroundStyle(.clear)
                .tint(.clear)
                .onChange(of: digits) { _, newValue in
                    let clean = String(newValue.filter(\.isNumber).prefix(SessionStore.codeLength))
                    if clean != newValue { digits = clean }
                    if clean.count == SessionStore.codeLength, !session.isWorking { verify() }
                }
                .accessibilityLabel("Código de 6 dígitos")
        }
        .onTapGesture { focused = true }
    }

    private func character(at index: Int) -> String {
        guard index < digits.count else { return "" }
        return String(digits[digits.index(digits.startIndex, offsetBy: index)])
    }
}

/// Paso 3 (solo la primera vez): el nombre con el que te verá tu amigo.
private struct NameStep: View {
    @Environment(SessionStore.self) private var session
    @State private var name = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Crea tu perfil").textStyle(.title1Compact)
                Text("Ya entraste. Falta tu nombre para que tu amigo sepa que eres tú.")
                    .textStyle(.bodyLarge)
                    .foregroundStyle(CruceColor.textBody)
            }

            FolderCard(tab: "TU PERFIL", tabColor: CruceColor.yellow) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 14) {
                        Avatar(member: previewMember, size: 72, shadow: ShadowOffset.s)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Así te verá tu amigo").font(.archivo(16, .extraBold))
                            Text("Puedes cambiar tu nombre después en Ajustes.")
                                .textStyle(.secondary)
                                .foregroundStyle(CruceColor.textSecondary)
                        }
                    }
                    NeoTextField(
                        label: "¿Cómo te llamas?", text: $name, placeholder: "Tu nombre", fill: CruceColor.cream
                    )
                    .textContentType(.givenName)
                    .onChange(of: name) { _, newValue in
                        if newValue.count > SessionStore.maxNameLength {
                            name = String(newValue.prefix(SessionStore.maxNameLength))
                        }
                    }
                    if let problem = session.error { ProblemText(problem: problem) }
                }
            }

            Spacer(minLength: 0)

            Button {
                Task { await session.createProfile(name: name) }
            } label: {
                Text(session.isWorking ? "Guardando…" : "Continuar")
            }
            .buttonStyle(
                NeoButtonStyle(kind: .dark, height: 56, shadow: ShadowOffset.m, shadowTint: CruceColor.yellow)
            )
            .disabled(session.isWorking || name.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private var previewMember: Member {
        var member = session.me
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { member.name = trimmed }
        return member
    }
}

/// El mensaje del problema del último paso, con ícono para que no dependa solo del color.
/// También la usan Ajustes (perfil, reparto y desvincular).
struct ProblemText: View {
    let problem: SessionStore.Problem

    init(problem: SessionStore.Problem) {
        self.problem = problem
    }

    var body: some View {
        Label(problem.message, systemImage: "exclamationmark.triangle.fill")
            .font(.archivo(14, .bold))
            .foregroundStyle(CruceColor.ink)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.updatesFrequently)
    }
}

/// "Al continuar aceptas los Términos y la Política de privacidad de Cruce."
private struct TermsText: View {
    var body: some View {
        (Text("Al continuar aceptas los ")
            + Text("Términos").font(.archivo(12, .extraBold)).underline().foregroundColor(CruceColor.ink)
            + Text(" y la ")
            + Text("Política de privacidad").font(.archivo(12, .extraBold)).underline().foregroundColor(
                CruceColor.ink)
            + Text(" de Cruce."))
            .textStyle(.secondary)
            .lineSpacing(4)
            .foregroundStyle(CruceColor.textSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }
}

/// Invitar al amigo con un código (pantalla 14, lo ve quien crea la cuenta).
struct InviteView: View {
    @Environment(SessionStore.self) private var session
    @Environment(LedgerStore.self) private var ledger
    @Environment(Router.self) private var router
    /// El código del cruce pendiente (`create_ledger_with_invite`): pedirlo otra vez devuelve el mismo.
    /// Mientras llega se muestra un marcador con el mismo estilo.
    private var code: String { session.inviteCode ?? "CRZ-····" }
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Con sesión real y sin cruce no hay a dónde volver: el perfil ya existe. Desde el inicio ("Invitar a
            // alguien") se vuelve atrás.
            if session.userID == nil {
                BackButton { session.phase = .signUp }
            } else if session.phase == .main {
                BackButton()
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Invita a tu amigo").textStyle(.title1Compact)
                Text("Cruce funciona entre dos personas. Comparte este código con quien vas a llevar las cuentas.")
                    .textStyle(.bodyLarge)
                    .foregroundStyle(CruceColor.textBody)
            }

            FolderCard(tab: "TU CÓDIGO", tabColor: CruceColor.violet, tabWidth: 130) {
                VStack(spacing: 14) {
                    Text(code)
                        .font(.archivo(48, .black))
                        .tracking(2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .textSelection(.enabled)
                    Text("Vence en 24 horas · sirve para una sola persona")
                        .textStyle(.secondary)
                        .foregroundStyle(CruceColor.textSecondary)
                    HStack(spacing: 10) {
                        ShareLink(item: "Únete a mi cuenta en Cruce con el código \(code)") {
                            Label("Compartir", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(
                            NeoButtonStyle(
                                kind: .primary, height: 50, shadow: ShadowOffset.s, radius: Radius.input,
                                text: .buttonSecondary))
                        Button {
                            UIPasteboard.general.string = code
                            copied = true
                        } label: {
                            Label(copied ? "Copiado" : "Copiar", systemImage: copied ? "checkmark" : "doc.on.doc")
                        }
                        .buttonStyle(
                            NeoButtonStyle(kind: .secondary, height: 50, shadow: ShadowOffset.s, radius: Radius.input))
                    }
                    .labelStyle(NeoLabelStyle())
                }
                .frame(maxWidth: .infinity)
            }

            if session.inviteCode == nil, let problem = session.error {
                ProblemNote(text: problem.message)
            }

            // Con sesión real la pantalla pasa sola a "Conectados" (ver `.task`); el botón solo simula en los datos
            // de ejemplo, sin sesión.
            Button {
                if session.userID == nil { session.phase = .connected }
            } label: {
                HStack(spacing: 12) {
                    HStack(spacing: 0) {
                        Avatar(member: session.me, size: 38)
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: 1.25))
                            path.addLine(to: CGPoint(x: 22, y: 1.25))
                        }
                        .stroke(CruceColor.ink, style: StrokeStyle(lineWidth: 2.5, dash: [4, 3]))
                        .frame(width: 22, height: 2.5)
                        Text("?")
                            .font(.archivo(16, .black))
                            .frame(width: 38, height: 38)
                            .background(Circle().fill(.white))
                            .overlay(
                                Circle().strokeBorder(CruceColor.ink, style: StrokeStyle(lineWidth: 2, dash: [4, 3])))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Esperando a tu amigo…").font(.archivo(14, .extraBold))
                        Text("Te avisamos apenas se una.").textStyle(.secondary).foregroundStyle(
                            CruceColor.textSecondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .neoSurface(fill: .clear, radius: Radius.button, border: BorderWidth.thin, dashed: true)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            // "Tengo un código" acepta el del cruce (va a unirse) y los de parches; los parches no necesitan cruce.
            // Desde el inicio ya están en "Tus cruces" y en el inicio, y cerrar sesión está en Ajustes.
            if session.phase != .main {
                entryButtons
            }
        }
        .foregroundStyle(CruceColor.ink)
        .padding(.horizontal, Spacing.screen)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .screenBackground()
        .task {
            // Trae el código y, mientras la pantalla esté abierta, revisa cada 3 segundos si el otro ya se unió.
            // SwiftUI cancela la tarea al salir. El tiempo real de verdad llega en el CP6.
            guard session.userID != nil else { return }
            await session.loadInviteCode()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                await session.checkForPartner()
            }
        }
    }

    @ViewBuilder
    private var entryButtons: some View {
        HStack(spacing: 12) {
            Button {
                router.push(.enterCode)
            } label: {
                Label("Tengo un código", systemImage: "number")
            }
            Button {
                router.push(.parches)
            } label: {
                Label("Mis parches", systemImage: "person.3")
            }
        }
        .buttonStyle(NeoButtonStyle(kind: .secondary, height: 52))
        .labelStyle(NeoLabelStyle())

        // Mientras no haya cruce, los ajustes no existen: cerrar sesión va aquí.
        if session.userID != nil {
            Button("Cerrar sesión") {
                Task {
                    await ledger.reset()
                    await session.signOut()
                }
            }
            .buttonStyle(.neoLink)
            .frame(maxWidth: .infinity)
        }
    }
}

/// Aviso de un problema bajo un campo: fondo rosa, borde delgado y el mensaje en texto.
private struct ProblemNote: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.archivo(14, .bold))
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .neoSurface(fill: CruceColor.pink, radius: Radius.input, border: BorderWidth.thin)
    }
}

/// Unirse con un código (pantalla 15, lo ve quien recibe la invitación).
struct JoinView: View {
    /// Con los 4 dígitos, la base dice de quién es el código (`preview_invite`); unirse lo canjea (`redeem_invite`).
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var digits = ""
    @FocusState private var focused: Bool

    /// Nombre de quien invitó si el código sirve.
    private var inviterName: String? {
        if case .valid(let name) = session.invitePreview { return name }
        return nil
    }

    /// Lo que se muestra si el código no sirve: el rechazo de la vista previa o el error al unirse.
    private var problem: String? {
        if case .rejected(_, let message) = session.invitePreview { return message }
        return digits.count == SessionStore.inviteDigits ? session.error?.message : nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            BackButton {
                session.pendingJoinCode = nil
                session.invitePreview = nil
                // Desde el inicio ("Tengo un código") se vuelve atrás; sin cruce, a invitar.
                if session.phase == .main { dismiss() } else { session.phase = .invite }
            }

            VStack(alignment: .leading, spacing: 10) {
                // Salto explícito: iOS 17 reparte las líneas distinto ("Únete con / un código").
                // fixedSize: con el teclado abierto y la tarjeta del código, los textos no se cortan ("Únete con un…").
                Text("Únete con un\ncódigo").textStyle(.title1Compact).fixedSize(horizontal: false, vertical: true)
                Text("Pídele el código a tu amigo. Lo encuentra en su app, en la pantalla para invitar.")
                    .textStyle(.bodyLarge)
                    .foregroundStyle(CruceColor.textBody)
                    .fixedSize(horizontal: false, vertical: true)
            }

            codeField

            if let name = inviterName {
                FolderCard(tab: "CÓDIGO VÁLIDO", tabColor: CruceColor.green, tabWidth: 160) {
                    HStack(spacing: 14) {
                        // Quien invita creó el cruce: amarillo y rosa.
                        Avatar(member: Member(name: name, avatarColor: .yellow, tikeVariant: .rosa), size: 56)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Cuenta de \(name)").font(.archivo(18, .extraBold))
                            Text("Vas a llevar las cuentas con \(name).")
                                .textStyle(.secondary)
                                .foregroundStyle(CruceColor.textSecondary)
                        }
                    }
                }
                .transition(.opacity)
            } else if let problem {
                ProblemNote(text: problem)
                    .transition(.opacity)
            }

            Spacer(minLength: 0)

            Button(inviterName.map { "Unirme a la cuenta de \($0)" } ?? "Unirme") {
                Task { await session.join(code: digits) }
            }
            .buttonStyle(NeoButtonStyle(kind: .primary, height: 58, shadow: ShadowOffset.l))
            .disabled(inviterName == nil || session.isWorking)
        }
        .foregroundStyle(CruceColor.ink)
        .padding(.horizontal, Spacing.screen)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .screenBackground()
        .animation(.easeOut(duration: 0.2), value: session.invitePreview)
        .onAppear {
            focused = true
            if let pending = session.pendingJoinCode {
                digits = String(pending.dropFirst(4))
            }
        }
        .task(id: digits) {
            // Con los 4 dígitos pregunta de quién es; con menos, borra la respuesta anterior.
            await session.checkCode(digits)
        }
    }

    /// "CRZ – 4 8 2 1": un campo oculto alimenta las cuatro cajas.
    private var codeField: some View {
        HStack(spacing: 8) {
            Text("CRZ")
                .font(.archivo(22, .black))
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .frame(height: 64)
                .neoSurface(fill: CruceColor.ink, radius: Radius.input)
            Text("–").font(.archivo(26, .black))
            ForEach(0..<4, id: \.self) { index in
                Text(character(at: index))
                    .font(.archivo(28, .black))
                    .frame(width: 52, height: 64)
                    .neoSurface(
                        fill: index == digits.count && focused ? CruceColor.yellow : CruceColor.surface,
                        radius: Radius.input, shadow: ShadowOffset.s)
            }
        }
        .overlay {
            TextField("", text: $digits)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($focused)
                .foregroundStyle(.clear)
                .tint(.clear)
                .onChange(of: digits) { _, newValue in
                    digits = String(newValue.filter(\.isNumber).prefix(4))
                }
                .accessibilityLabel("Código de invitación")
        }
        .onTapGesture { focused = true }
    }

    private func character(at index: Int) -> String {
        guard index < digits.count else { return "" }
        return String(digits[digits.index(digits.startIndex, offsetBy: index)])
    }
}

/// Conectados (pantalla 16).
struct ConnectedView: View {
    @Environment(SessionStore.self) private var session
    @Environment(Router.self) private var router

    var body: some View {
        ZStack {
            CruceColor.yellow.ignoresSafeArea()
            ZStack {
                Circle().fill(CruceColor.violet).frame(width: 240).offset(x: 170, y: -260)
                Rectangle().fill(CruceColor.green).frame(width: 280, height: 260).rotationEffect(.degrees(16)).offset(
                    x: -150, y: 330)
                RoundedRectangle(cornerRadius: 2).fill(CruceColor.pink).frame(width: 16, height: 16)
                    .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(CruceColor.ink, lineWidth: 2.5))
                    .rotationEffect(.degrees(-20)).offset(x: -160, y: -330)
            }
            .accessibilityHidden(true)

            FittingScroll {
                VStack(spacing: 24) {
                    VStack(spacing: 14) {
                        IllustrationView(illustration: .welcome, height: 250, minHeight: 160)
                        HStack(spacing: 6) {
                            Avatar(member: session.me, size: 40)
                            CruceLogoMark(size: 30, fill: CruceColor.ink, stroke: CruceColor.yellow)
                            Avatar(member: session.partner, size: 40)
                        }
                        Text("¡\(session.me.name) y \(session.partner.name) ya están conectados!")
                            .font(.archivo(32, .black, relativeTo: .largeTitle))
                            .tracking(-1.2)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Todo lo que anoten aparece en los dos celulares al instante.")
                            .textStyle(.body)
                            .foregroundStyle(CruceColor.textBody)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 20)
                    .padding(.bottom, 24)
                    .neoSurface(radius: Radius.dialog, border: BorderWidth.thick, shadow: ShadowOffset.xxl)

                    Spacer(minLength: 0)

                    Button {
                        if let linked = session.lastLinked {
                            // Desde el inicio: se cierra "Conectados" y se abre el cruce nuevo.
                            session.lastLinked = nil
                            router.popToRoot()
                            if session.cruces.count >= 2 { router.push(.cruce(linked.id)) }
                        } else {
                            session.phase = .main
                        }
                    } label: {
                        Label("Ir al inicio", systemImage: "arrow.right").labelStyle(TrailingIconLabelStyle())
                    }
                    .buttonStyle(.neoDark)
                }
                .foregroundStyle(CruceColor.ink)
                .padding(.horizontal, 24)
                .padding(.top, 40)
                .padding(.bottom, 16)
            }
        }
    }
}

#if DEBUG
    #Preview("Entrar: correo") { SignUpView().cruceStores(.sample(phase: .signUp)) }
    #Preview("Entrar: código") {
        SignUpView().cruceStores(.sample(phase: .signUp, pendingEmail: "joan@correo.com"))
    }
    #Preview("Entrar: nombre") { SignUpView().cruceStores(.sample(phase: .signUp, userID: MockData.joan.id)) }
    #Preview("Invitar") { InviteView().cruceStores(.sample(phase: .invite)) }
    #Preview("Unirse") { JoinView().cruceStores(.sample(phase: .join, viewer: MockData.jesus, joinCode: "CRZ-4821")) }
    #Preview("Unirse: código inválido") {
        JoinView().cruceStores(.sample(phase: .join, viewer: MockData.jesus, joinCode: "CRZ-0000"))
    }
    #Preview("Conectados") { ConnectedView().cruceStores(.sample(phase: .connected)) }
#endif
