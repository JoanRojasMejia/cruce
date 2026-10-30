import CruceCore
import SwiftUI

// El monto principal se escribe con el teclado de Cruce; los montos secundarios, con el del sistema. Estas piezas las
// comparten "Nuevo movimiento", "Anotar un gasto" y "Anotar un pago" del parche.

/// Pantalla con un monto principal: el contenido se desplaza y abajo quedan los botones y, cuando el monto está activo,
/// el teclado de Cruce acoplado como un teclado. Tocar el espacio vacío cierra los dos teclados y abrir el del sistema
/// (otro campo) cierra el de Cruce.
struct AmountEntryScreen<Content: View, Actions: View>: View {
    @Binding private var focus: AmountEntryFocus
    @Binding private var amount: Int
    private let content: Content
    private let actions: Actions

    init(
        focus: Binding<AmountEntryFocus>, amount: Binding<Int>, @ViewBuilder content: () -> Content,
        @ViewBuilder actions: () -> Actions
    ) {
        _focus = focus
        _amount = amount
        self.content = content()
        self.actions = actions()
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                content
                    // Ocupa al menos el alto visible, para que tocar el espacio vacío de abajo también cierre los teclados.
                    .frame(minHeight: proxy.size.height, alignment: .top)
                    // Va en el fondo, no en el contenedor, para que tocar un campo no le quite el foco.
                    .background {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { closeKeyboards() }
                    }
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        // Los botones quedan fijos y el teclado de Cruce va debajo de ellos, como el del sistema, que también los sube.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                actions
                    .padding(.horizontal, Spacing.screen)
                    .padding(.top, 10)
                    .padding(.bottom, 8)
                if focus.showsKeypad {
                    AmountKeypadDock(amount: $amount) { focus = .none }
                        .transition(.move(edge: .bottom))
                }
            }
            .background(CruceColor.cream)
        }
        // Tocar otro campo abre el teclado del sistema: se cierra el de Cruce. Se escucha que el campo empieza a
        // editarse (y no que aparece el teclado) para que también funcione con un teclado físico.
        .task { await follow(UITextField.textDidBeginEditingNotification) { $0.afterSystemKeyboardShows } }
        .task { await follow(UITextView.textDidBeginEditingNotification) { $0.afterSystemKeyboardShows } }
        .task { await follow(UITextField.textDidEndEditingNotification) { $0.afterSystemKeyboardHides } }
        .task { await follow(UITextView.textDidEndEditingNotification) { $0.afterSystemKeyboardHides } }
        .animation(.easeOut(duration: 0.2), value: focus)
    }

    private func closeKeyboards() {
        focus = .none
        hideSystemKeyboard()
    }

    /// Cambia el teclado abierto cada vez que llega el aviso `name`, mientras la pantalla está a la vista.
    private func follow(_ name: Notification.Name, _ next: (AmountEntryFocus) -> AmountEntryFocus) async {
        for await _ in NotificationCenter.default.notifications(named: name) {
            focus = next(focus)
        }
    }
}

/// La tarjeta amarilla del monto principal. Tocarla abre el teclado de Cruce y cierra el del sistema; mientras está
/// activa muestra el cursor.
struct MainAmountCard: View {
    private let title: String
    private let amount: Int
    @Binding private var focus: AmountEntryFocus
    private let accessibilityName: String

    /// `title`: el rótulo en mayúsculas ("MONTO"); `accessibilityName`: cómo lo nombra VoiceOver ("Monto").
    init(title: String = "MONTO", amount: Int, focus: Binding<AmountEntryFocus>, accessibilityName: String = "Monto") {
        self.title = title
        self.amount = amount
        _focus = focus
        self.accessibilityName = accessibilityName
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).textStyle(.label)
            HStack(spacing: 4) {
                Text(Money.format(amount))
                    .font(.archivo(46, .black, relativeTo: .largeTitle))
                    .tracking(-2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                // El cursor: solo con el teclado de Cruce abierto (guarda su lugar para que el monto no salte).
                Rectangle().fill(CruceColor.ink).frame(width: 3, height: 40)
                    .opacity(focus.showsKeypad ? 1 : 0)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .neoSurface(fill: CruceColor.yellow, radius: Radius.card, shadow: ShadowOffset.m)
        .contentShape(Rectangle())
        .onTapGesture { open() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityName)
        .accessibilityValue(AmountEntry.spokenValue(amount))
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(focus.showsKeypad ? "" : "Abre el teclado del monto")
        .accessibilityAction { open() }
    }

    private func open() {
        focus = .amount
        hideSystemKeyboard()
    }
}

/// El teclado de Cruce acoplado abajo, con "Listo" para cerrarlo.
struct AmountKeypadDock: View {
    @Binding private var amount: Int
    private let onDone: () -> Void

    init(amount: Binding<Int>, onDone: @escaping () -> Void) {
        _amount = amount
        self.onDone = onDone
    }

    var body: some View {
        VStack(spacing: 2) {
            HStack {
                Spacer()
                Button("Listo", action: onDone)
                    .font(.archivo(16, .extraBold))
                    .foregroundStyle(CruceColor.ink)
                    .frame(minWidth: Spacing.minTouch, minHeight: Spacing.minTouch)
                    .contentShape(Rectangle())
                    .buttonStyle(.plain)
                    .accessibilityHint("Cierra el teclado del monto")
            }
            AmountKeypad(amount: $amount)
        }
        .padding(.horizontal, Spacing.m)
        .padding(.bottom, Spacing.xs)
        .background {
            // La bandeja llega hasta el borde de abajo, también debajo de la barra de inicio.
            CruceColor.line
                .overlay(alignment: .top) {
                    Rectangle().fill(CruceColor.ink).frame(height: BorderWidth.regular)
                }
                .ignoresSafeArea(edges: .bottom)
        }
    }
}

/// Baja el teclado del sistema, sea cual sea el campo que lo abrió.
@MainActor
func hideSystemKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

#if DEBUG
    #Preview("Teclado acoplado") {
        struct Wrapper: View {
            @State var focus = AmountEntryFocus.amount
            @State var amount = 60_000
            @State var concept = ""
            var body: some View {
                AmountEntryScreen(focus: $focus, amount: $amount) {
                    VStack(alignment: .leading, spacing: 12) {
                        MainAmountCard(amount: amount, focus: $focus)
                        NeoTextField(label: "Concepto", text: $concept, placeholder: "Ej. Cena viernes")
                    }
                    .padding(.horizontal, Spacing.screen)
                } actions: {
                    Button("Guardar") {}
                        .buttonStyle(NeoButtonStyle(kind: .primary, height: 54))
                }
                .screenBackground()
            }
        }
        return Wrapper()
    }
#endif
