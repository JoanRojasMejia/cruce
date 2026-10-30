import SwiftUI

/// Cuadro del logo de la entrada. La pantalla de arranque de iOS muestra la misma figura como imagen
/// (`LaunchLogo`, generada con `scripts/logo-arranque.swift`): si cambias las medidas, vuelve a generarla.
struct SplashTile: View {
    enum Arrows { case both, first, second }

    static let size: CGFloat = 96
    static let shadow: CGFloat = ShadowOffset.l
    /// Lado de la imagen completa (cuadro + sombra), centrada en la pantalla igual que en el arranque.
    static let frame: CGFloat = size + shadow

    var fill: Color = CruceColor.yellow
    var arrows: Arrows = .both

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Self.size / 4, style: .circular)
        let mark = Self.size * 0.6
        ZStack(alignment: .topLeading) {
            shape.fill(CruceColor.ink)
                .frame(width: Self.size, height: Self.size)
                .offset(x: Self.shadow, y: Self.shadow)
            shape.fill(fill)
                .overlay(shape.strokeBorder(CruceColor.ink, lineWidth: BorderWidth.thick))
                .frame(width: Self.size, height: Self.size)
                .overlay {
                    ArrowsShape(arrows: arrows)
                        .stroke(
                            CruceColor.ink,
                            style: StrokeStyle(lineWidth: 2.8 * mark / 24, lineCap: .round, lineJoin: .round)
                        )
                        .frame(width: mark, height: mark)
                }
        }
        .frame(width: Self.frame, height: Self.frame, alignment: .topLeading)
    }

    /// Las flechas de `CruceMark`, juntas o una sola (la que baja o la que sube).
    private struct ArrowsShape: Shape {
        let arrows: Arrows

        func path(in rect: CGRect) -> Path {
            let unit = min(rect.width, rect.height) / 24
            func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: rect.minX + x * unit, y: rect.minY + y * unit)
            }
            var path = Path()
            if arrows != .second {
                path.move(to: point(4, 4))
                path.addLine(to: point(20, 20))
                path.move(to: point(20, 13))
                path.addLine(to: point(20, 20))
                path.addLine(to: point(13, 20))
            }
            if arrows != .first {
                path.move(to: point(4, 20))
                path.addLine(to: point(20, 4))
                path.move(to: point(13, 4))
                path.addLine(to: point(20, 4))
                path.addLine(to: point(20, 11))
            }
            return path
        }
    }
}

/// Entrada "Choque" (decisión del 30 oct 2026): el logo se parte en sus dos flechas, que se alejan y chocan de frente;
/// vuelve el logo con un golpe y la pantalla se abre en dos como una puerta. Empieza igual que la pantalla de arranque
/// y espera quieta hasta que `isReady`, para no revelar una pantalla vacía. Con "Reducir movimiento" solo se desvanece.
struct LaunchSplash: View {
    let isReady: Bool
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var started = false
    @State private var fadedOut = false

    /// Lo que dura desde que arranca hasta que la puerta termina de abrirse.
    static let duration: Double = 1.6

    var body: some View {
        GeometryReader { proxy in
            KeyframeAnimator(initialValue: Frame(), trigger: started && !reduceMotion) { frame in
                scene(frame, width: proxy.size.width)
            } keyframes: { _ in
                Self.keyframes
            }
        }
        .ignoresSafeArea()
        .opacity(fadedOut ? 0 : 1)
        .accessibilityHidden(true)
        .task(id: isReady) {
            guard isReady, !started else { return }
            // Un instante quieto: el primer cuadro es idéntico a la pantalla de arranque. Si la tarea se cancela
            // (`isReady` cambió mientras tanto), no se arranca: lo hará la tarea siguiente.
            do { try await Task.sleep(for: .milliseconds(150)) } catch { return }
            started = true
        }
        // Aparte de la de arriba: `started` cambia una sola vez, así que esta tarea no se cancela a mitad de camino
        // (si se cancelara, la entrada se quitaría antes de terminar).
        .task(id: started) {
            guard started else { return }
            if reduceMotion {
                withAnimation(.easeOut(duration: 0.3)) { fadedOut = true }
                do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
            } else {
                do { try await Task.sleep(for: .seconds(Self.duration)) } catch { return }
            }
            onFinish()
        }
    }

    private func scene(_ frame: Frame, width: CGFloat) -> some View {
        ZStack {
            // La puerta: dos mitades crema que se abren hacia los lados con su canto de tinta.
            HStack(spacing: 0) {
                door(edge: .trailing, frame: frame)
                    .offset(x: -frame.door * (width / 2 + BorderWidth.thick))
                door(edge: .leading, frame: frame)
                    .offset(x: frame.door * (width / 2 + BorderWidth.thick))
            }
            Circle()
                .strokeBorder(CruceColor.ink, lineWidth: BorderWidth.thick)
                .frame(width: 120, height: 120)
                .scaleEffect(frame.ringScale)
                .opacity(frame.ringOpacity)
                .offset(x: -SplashTile.shadow / 2, y: -SplashTile.shadow / 2)
            Group {
                SplashTile(fill: CruceColor.violet, arrows: .first)
                    .rotationEffect(.degrees(-frame.halfRotation))
                    .offset(x: -frame.halfOffset)
                SplashTile(fill: CruceColor.lime, arrows: .second)
                    .rotationEffect(.degrees(frame.halfRotation))
                    .offset(x: frame.halfOffset)
            }
            .opacity(frame.halvesOpacity)
            SplashTile()
                .scaleEffect(x: frame.logoScaleX, y: frame.logoScaleY)
                .rotationEffect(.degrees(frame.logoRotation))
                .opacity(frame.logoOpacity)
        }
        .offset(x: frame.shake.width, y: frame.shake.height)
    }

    private func door(edge: Edge, frame: Frame) -> some View {
        CruceColor.cream
            .overlay(alignment: edge == .leading ? .leading : .trailing) {
                CruceColor.ink.frame(width: BorderWidth.thick).opacity(frame.door > 0 ? 1 : 0)
            }
    }

    /// Lo que cambia en cada cuadro de la animación.
    struct Frame {
        var halfOffset: CGFloat = 0
        var halfRotation: Double = 0
        var halvesOpacity: Double = 0
        var logoOpacity: Double = 1
        var logoScaleX: CGFloat = 1
        var logoScaleY: CGFloat = 1
        var logoRotation: Double = 0
        var ringScale: CGFloat = 0.6
        var ringOpacity: Double = 0
        var shake: CGSize = .zero
        /// 0: cerrada; 1: abierta del todo.
        var door: CGFloat = 0
    }

    /// El choque es a los 0,665 s y la puerta se abre de 1,2 s a 1,6 s.
    private static let impact = 0.665

    @KeyframesBuilder<Frame>
    private static var keyframes: some Keyframes<Frame> {
        KeyframeTrack(\.halvesOpacity) {
            MoveKeyframe(1)
            LinearKeyframe(1, duration: impact)
            MoveKeyframe(0)
        }
        // Se alejan girando y vuelven acelerando hasta chocar.
        KeyframeTrack(\.halfOffset) {
            LinearKeyframe(96, duration: 0.315, timingCurve: .easeOut)
            LinearKeyframe(0, duration: impact - 0.315, timingCurve: .easeIn)
        }
        KeyframeTrack(\.halfRotation) {
            LinearKeyframe(16, duration: 0.315, timingCurve: .easeOut)
            LinearKeyframe(0, duration: impact - 0.315, timingCurve: .easeIn)
        }
        KeyframeTrack(\.logoOpacity) {
            MoveKeyframe(0)
            LinearKeyframe(0, duration: impact)
            LinearKeyframe(1, duration: 0.075)
        }
        // Vuelve el logo aplastado por el golpe, rebota y al final se encoge girando.
        KeyframeTrack(\.logoScaleX) {
            MoveKeyframe(0.4)
            LinearKeyframe(0.4, duration: impact)
            LinearKeyframe(1.32, duration: 0.075)
            LinearKeyframe(0.9, duration: 0.12)
            LinearKeyframe(1, duration: 0.14)
            LinearKeyframe(1, duration: 0.13)
            LinearKeyframe(0, duration: 0.22, timingCurve: .easeIn)
        }
        KeyframeTrack(\.logoScaleY) {
            MoveKeyframe(0.4)
            LinearKeyframe(0.4, duration: impact)
            LinearKeyframe(0.78, duration: 0.075)
            LinearKeyframe(1.1, duration: 0.12)
            LinearKeyframe(1, duration: 0.14)
            LinearKeyframe(1, duration: 0.13)
            LinearKeyframe(0, duration: 0.22, timingCurve: .easeIn)
        }
        KeyframeTrack(\.logoRotation) {
            LinearKeyframe(0, duration: 1.13)
            LinearKeyframe(90, duration: 0.22, timingCurve: .easeIn)
        }
        KeyframeTrack(\.ringOpacity) {
            LinearKeyframe(0, duration: impact)
            MoveKeyframe(1)
            LinearKeyframe(0, duration: 0.38, timingCurve: .easeOut)
        }
        KeyframeTrack(\.ringScale) {
            LinearKeyframe(0.6, duration: impact)
            LinearKeyframe(2.6, duration: 0.38, timingCurve: .easeOut)
        }
        KeyframeTrack(\.shake) {
            LinearKeyframe(.zero, duration: impact)
            LinearKeyframe(CGSize(width: -6, height: 3), duration: 0.05)
            LinearKeyframe(CGSize(width: 6, height: -3), duration: 0.05)
            LinearKeyframe(CGSize(width: -3, height: 1.5), duration: 0.05)
            LinearKeyframe(.zero, duration: 0.05)
        }
        KeyframeTrack(\.door) {
            LinearKeyframe(0, duration: 1.2)
            LinearKeyframe(
                1, duration: 0.4,
                timingCurve: .bezier(
                    startControlPoint: UnitPoint(x: 0.7, y: 0), endControlPoint: UnitPoint(x: 0.3, y: 1)))
        }
    }
}

#if DEBUG
    #Preview {
        ZStack {
            CruceColor.yellow.ignoresSafeArea()
            Text("El inicio").font(.archivo(30, .black))
            LaunchSplash(isReady: true) {}
        }
    }
#endif
