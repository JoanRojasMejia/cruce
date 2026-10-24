import SwiftUI

/// Marca de Cruce: dos flechas que se cruzan. Dibujada en una retícula de 24 × 24.
struct CruceMark: Shape {
    func path(in rect: CGRect) -> Path {
        let unit = min(rect.width, rect.height) / 24
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * unit, y: rect.minY + y * unit)
        }
        var path = Path()
        path.move(to: point(4, 4)); path.addLine(to: point(20, 20))
        path.move(to: point(20, 13)); path.addLine(to: point(20, 20)); path.addLine(to: point(13, 20))
        path.move(to: point(4, 20)); path.addLine(to: point(20, 4))
        path.move(to: point(13, 4)); path.addLine(to: point(20, 4)); path.addLine(to: point(20, 11))
        return path
    }
}

/// Ícono de la marca en su cuadro amarillo.
struct CruceLogoMark: View {
    var size: CGFloat = 40
    var fill: Color = CruceColor.yellow
    var stroke: Color = CruceColor.ink

    var body: some View {
        let markSize = size * 0.6
        CruceMark()
            .stroke(stroke, style: StrokeStyle(lineWidth: 2.8 * markSize / 24, lineCap: .round, lineJoin: .round))
            .frame(width: markSize, height: markSize)
            .frame(width: size, height: size)
            .neoSurface(fill: fill, radius: size / 4, shadow: ShadowOffset.s)
            .accessibilityHidden(true)
    }
}

/// Logo con wordmark, como en el encabezado del inicio.
struct CruceLogo: View {
    var body: some View {
        HStack(spacing: 10) {
            CruceLogoMark()
            Text("Cruce")
                .font(.archivo(26, .black, relativeTo: .title))
                .tracking(-0.8)
                .foregroundStyle(CruceColor.ink)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Cruce")
    }
}

#Preview {
    CruceLogo().padding().screenBackground()
}
