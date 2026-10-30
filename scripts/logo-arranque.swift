// Genera LaunchLogo (@2x y @3x), la imagen de la pantalla de arranque de iOS.
// Es el mismo dibujo que `SplashTile` (ios/Cruce/Components/LaunchSplash.swift): si cambias uno, cambia el otro.
// Uso, desde la raíz del repo: swift scripts/logo-arranque.swift
import AppKit
import SwiftUI

let tileSize: CGFloat = 96
let tileShadow: CGFloat = 5
let tileBorder: CGFloat = 3
let yellow = Color(red: 0xFF / 255, green: 0xD1 / 255, blue: 0x2E / 255)
let ink = Color(red: 0x11 / 255, green: 0x11 / 255, blue: 0x11 / 255)

struct Arrows: Shape {
    func path(in rect: CGRect) -> Path {
        let unit = min(rect.width, rect.height) / 24
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * unit, y: y * unit) }
        var path = Path()
        path.move(to: point(4, 4))
        path.addLine(to: point(20, 20))
        path.move(to: point(20, 13))
        path.addLine(to: point(20, 20))
        path.addLine(to: point(13, 20))
        path.move(to: point(4, 20))
        path.addLine(to: point(20, 4))
        path.move(to: point(13, 4))
        path.addLine(to: point(20, 4))
        path.addLine(to: point(20, 11))
        return path
    }
}

struct Tile: View {
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: tileSize / 4, style: .circular)
        let mark = tileSize * 0.6
        ZStack(alignment: .topLeading) {
            shape.fill(ink).frame(width: tileSize, height: tileSize).offset(x: tileShadow, y: tileShadow)
            shape.fill(yellow)
                .overlay(shape.strokeBorder(ink, lineWidth: tileBorder))
                .frame(width: tileSize, height: tileSize)
                .overlay {
                    Arrows()
                        .stroke(ink, style: StrokeStyle(lineWidth: 2.8 * mark / 24, lineCap: .round, lineJoin: .round))
                        .frame(width: mark, height: mark)
                }
        }
        .frame(width: tileSize + tileShadow, height: tileSize + tileShadow, alignment: .topLeading)
    }
}

let folder = URL(fileURLWithPath: "ios/Cruce/Resources/Assets.xcassets/LaunchLogo.imageset")
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
MainActor.assumeIsolated {
    for scale in [2, 3] {
        let renderer = ImageRenderer(content: Tile())
        renderer.scale = CGFloat(scale)
        guard let image = renderer.cgImage else { fatalError("No se pudo dibujar el logo") }
        let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!
        try! data.write(to: folder.appendingPathComponent("launch-logo@\(scale)x.png"))
    }
}
let contents = """
    {
      "images" : [
        { "idiom" : "universal", "scale" : "1x" },
        { "filename" : "launch-logo@2x.png", "idiom" : "universal", "scale" : "2x" },
        { "filename" : "launch-logo@3x.png", "idiom" : "universal", "scale" : "3x" }
      ],
      "info" : { "author" : "xcode", "version" : 1 }
    }

    """
try contents.write(to: folder.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
print("LaunchLogo listo en \(folder.path)")
