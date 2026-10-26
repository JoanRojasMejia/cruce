import CruceCore
import SwiftUI
import UIKit

/// Crear cuenta (pantalla 13).
/// TODO punto 2: reemplazar el botón por `SignInWithAppleButton` y conectar con Supabase Auth.
/// Apple exige su botón oficial; este solo simula el paso.
struct SignUpView: View {
    @Environment(AppState.self) private var app
    @State private var name = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            BackButton { app.phase = .onboarding }

            VStack(alignment: .leading, spacing: 10) {
                Text("Crea tu cuenta").textStyle(.title1Compact)
                Text("Entras con tu cuenta de Apple, así no tienes que recordar otra contraseña.")
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
                        label: "¿Cómo te llamas?", text: $name, placeholder: "Tu nombre", fill: CruceColor.cream)
                }
            }

            Spacer(minLength: 0)

            VStack(spacing: 12) {
                Button {
                    let trimmed = name.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty { app.me.name = trimmed }
                    app.phase = .invite
                } label: {
                    Text("Continuar con Apple")
                }
                .buttonStyle(
                    NeoButtonStyle(kind: .dark, height: 56, shadow: ShadowOffset.m, shadowTint: CruceColor.yellow))

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
        .foregroundStyle(CruceColor.ink)
        .padding(.horizontal, Spacing.screen)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .screenBackground()
        .onAppear { if name.isEmpty { name = app.me.name } }
    }

    private var previewMember: Member {
        var member = app.me
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { member.name = trimmed }
        return member
    }
}

/// Invitar al amigo con un código (pantalla 14, lo ve quien crea la cuenta).
struct InviteView: View {
    @Environment(AppState.self) private var app
    /// TODO punto 2: el código lo genera la función `create_ledger_with_invite` de Supabase.
    private let code = "CRZ-4821"
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            BackButton { app.phase = .signUp }

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

            // Simulación: en la app real esto cambia solo cuando el amigo canjea el código.
            Button {
                app.phase = .connected
            } label: {
                HStack(spacing: 12) {
                    HStack(spacing: 0) {
                        Avatar(member: app.me, size: 38)
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

            Button("¿Te invitaron a ti? Ingresa un código") { app.phase = .join }
                .buttonStyle(NeoButtonStyle(kind: .secondary, height: 52))
        }
        .foregroundStyle(CruceColor.ink)
        .padding(.horizontal, Spacing.screen)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .screenBackground()
    }
}

/// Unirse con un código (pantalla 15, lo ve quien recibe la invitación).
struct JoinView: View {
    @Environment(AppState.self) private var app
    @State private var digits = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            BackButton { app.phase = .invite }

            VStack(alignment: .leading, spacing: 10) {
                // Salto explícito: iOS 17 reparte las líneas distinto ("Únete con / un código").
                Text("Únete con un\ncódigo").textStyle(.title1Compact)
                Text("Pídele el código a tu amigo. Lo encuentra en su app, en la pantalla para invitar.")
                    .textStyle(.bodyLarge)
                    .foregroundStyle(CruceColor.textBody)
            }

            codeField

            if digits.count == 4 {
                // TODO punto 2: validar con `redeem_invite` antes de mostrar la cuenta.
                FolderCard(tab: "CÓDIGO VÁLIDO", tabColor: CruceColor.green, tabWidth: 160) {
                    HStack(spacing: 14) {
                        Avatar(member: MockData.joan, size: 56)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Cuenta de \(MockData.joan.name)").font(.archivo(18, .extraBold))
                            Text("Vas a llevar las cuentas con \(MockData.joan.name).")
                                .textStyle(.secondary)
                                .foregroundStyle(CruceColor.textSecondary)
                        }
                    }
                }
                .transition(.opacity)
            }

            Spacer(minLength: 0)

            Button("Unirme a la cuenta de \(MockData.joan.name)") { app.phase = .connected }
                .buttonStyle(NeoButtonStyle(kind: .primary, height: 58, shadow: ShadowOffset.l))
                .disabled(digits.count < 4)
        }
        .foregroundStyle(CruceColor.ink)
        .padding(.horizontal, Spacing.screen)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .screenBackground()
        .animation(.easeOut(duration: 0.2), value: digits.count == 4)
        .onAppear { focused = true }
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
    @Environment(AppState.self) private var app

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
                            Avatar(member: app.me, size: 40)
                            CruceLogoMark(size: 30, fill: CruceColor.ink, stroke: CruceColor.yellow)
                            Avatar(member: app.partner, size: 40)
                        }
                        Text("¡\(app.me.name) y \(app.partner.name) ya están conectados!")
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
                        app.phase = .main
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

#Preview("Crear cuenta") { SignUpView().environment(AppState.preview(phase: .signUp)) }
#Preview("Invitar") { InviteView().environment(AppState.preview(phase: .invite)) }
#Preview("Unirse") { JoinView().environment(AppState.preview(phase: .join, viewer: MockData.jesus)) }
#Preview("Conectados") { ConnectedView().environment(AppState.preview(phase: .connected)) }
