import SwiftUI

/// Onboarding de 3 pasos (pantallas 01, 11 y 12).
struct OnboardingView: View {
    @Environment(AppState.self) private var app
    @State private var page: Int

    init(page: Int = 0) {
        _page = State(initialValue: page)
    }

    var body: some View {
        FittingScroll { content }
            .foregroundStyle(CruceColor.ink)
            .background(alignment: .topLeading) { decorations }
            .screenBackground()
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                CruceLogo()
                Spacer()
                Badge(text: "\(page + 1) de 3")
            }

            Group {
                switch page {
                case 0: WelcomePage()
                case 1: CrossingPage()
                default: SettlePage()
                }
            }
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            .id(page)

            PageDots(count: 3, current: page)

            Spacer(minLength: 0)

            VStack(spacing: 8) {
                Button {
                    if page < 2 {
                        withAnimation(.easeInOut(duration: 0.25)) { page += 1 }
                    } else {
                        app.phase = .signUp
                    }
                } label: {
                    Label(primaryTitle, systemImage: "arrow.right")
                        .labelStyle(TrailingIconLabelStyle())
                }
                .buttonStyle(NeoButtonStyle(kind: .primary, height: 58, shadow: ShadowOffset.l))

                Button(secondaryTitle) {
                    switch page {
                    case 0: app.phase = .signUp
                    case 1: app.phase = .signUp
                    default: withAnimation { page = 1 }
                    }
                }
                .buttonStyle(.neoLink)
            }
        }
        .padding(.horizontal, Spacing.screen)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    private var primaryTitle: String {
        switch page {
        case 0: return "Empezar"
        case 1: return "Siguiente"
        default: return "Crear mi cuenta"
        }
    }

    private var secondaryTitle: String {
        switch page {
        case 0: return "Ya tengo una cuenta"
        case 1: return "Saltar"
        default: return "Atrás"
        }
    }

    /// Formas de color detrás de la ilustración, como en el canvas.
    @ViewBuilder
    private var decorations: some View {
        GeometryReader { proxy in
            switch page {
            case 0:
                Circle().fill(CruceColor.pink).frame(width: 220, height: 220).position(x: 40, y: 265)
                Rectangle().fill(CruceColor.violet).frame(width: 190, height: 170)
                    .rotationEffect(.degrees(-12)).position(x: proxy.size.width + 10, y: 330)
            case 2:
                Circle().fill(CruceColor.green).frame(width: 240, height: 240).position(x: proxy.size.width - 40, y: 250)
                Rectangle().fill(CruceColor.pink).frame(width: 150, height: 120)
                    .rotationEffect(.degrees(14)).position(x: 35, y: 380)
            default:
                EmptyView()
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// Texto con el ícono a la derecha ("Empezar →").
struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            configuration.title
            configuration.icon.font(.system(size: 17, weight: .heavy))
        }
    }
}

private struct WelcomePage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            IllustrationView(illustration: .welcome, height: 320, minHeight: 160)
            Text("Cuentas claras\nentre dos.").textStyle(.title1).fixedSize(horizontal: false, vertical: true)
            Text("Anoten lo que paga cada uno. Cruce cruza los gastos y les muestra un solo saldo: quién le debe a quién.")
                .textStyle(.bodyLarge)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(CruceColor.textBody)
        }
    }
}

/// Ejemplo de cómo dos gastos se cruzan en un solo saldo.
private struct CrossingPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 8) {
                exampleRow(category: .comida, title: "Joan pagó la cena", detail: "$60.000 a medias", who: "Jesús debe", amount: "$30.000")
                    .rotationEffect(.degrees(-1.5))
                exampleRow(category: .mercado, title: "Jesús pagó el mercado", detail: "$100.000 a medias", who: "Joan debe", amount: "$50.000")
                    .rotationEffect(.degrees(1.5))
                VStack(spacing: 0) {
                    Rectangle().fill(CruceColor.ink).frame(width: 2.5, height: 10)
                    CruceLogoMark(size: 52).rotationEffect(.degrees(-6))
                    Rectangle().fill(CruceColor.ink).frame(width: 2.5, height: 10)
                }
                FolderCard(tab: "UN SOLO SALDO", tabColor: CruceColor.lime, tabWidth: 130,
                           padding: EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)) {
                    HStack {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Joan le debe a Jesús").font(.archivo(16, .extraBold))
                            Text("$20.000").font(.archivo(40, .black)).tracking(-1.5)
                        }
                        Spacer()
                        HStack(spacing: 4) {
                            Avatar(member: MockData.joan, size: 34)
                            Image(systemName: "arrow.right").font(.system(size: 14, weight: .black))
                            Avatar(member: MockData.jesus, size: 34)
                        }
                    }
                }
            }
            .accessibilityElement(children: .combine)

            Text("Cada gasto se\ncruza solo.").textStyle(.title1Compact).fixedSize(horizontal: false, vertical: true)
            Text("Nada de dos listas. Cruce compensa lo que se deben y deja una sola cifra.")
                .textStyle(.bodyLarge)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(CruceColor.textBody)
        }
    }

    private func exampleRow(category: MovementCategory, title: String, detail: String, who: String, amount: String) -> some View {
        HStack(spacing: 12) {
            CategoryIcon(category: category)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).textStyle(.rowTitle)
                Text(detail).textStyle(.secondary).foregroundStyle(CruceColor.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(who).font(.archivo(11, .bold)).foregroundStyle(CruceColor.textSecondary)
                Text(amount).font(.archivo(16, .black))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .neoSurface(radius: Radius.button, shadow: ShadowOffset.s)
    }
}

private struct SettlePage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            IllustrationView(illustration: .allClear, height: 320, minHeight: 160)
            Text("Salden cuando\nquieran.").textStyle(.title1).fixedSize(horizontal: false, vertical: true)
            Text("Cuando uno le paga al otro, lo registran con un toque y el saldo vuelve a $0. Sin cuentas pendientes ni malentendidos.")
                .textStyle(.bodyLarge)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(CruceColor.textBody)
        }
    }
}

#Preview {
    OnboardingView().environment(AppState.preview(phase: .onboarding))
}
