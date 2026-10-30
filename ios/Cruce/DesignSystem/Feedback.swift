import AVFoundation
import SwiftUI
import UIKit

/// Los únicos momentos con sonido y vibración. El resto de la app no suena ni vibra (decisión del 30 oct 2026).
/// Los sonidos están en `Resources/Sounds/` y salen de `scripts/sonidos.py`.
enum FeedbackMoment: String, CaseIterable {
    /// Anotar o editar un gasto, en el cruce o en un parche.
    case expenseSaved = "gasto-guardado"
    /// Un pago que no deja el cruce en $0, o un pago en un parche.
    case paymentRecorded = "pago-anotado"
    /// Saldar todo: "¡A paz y salvo!".
    case settled = "paz-y-salvo"
    case expenseDeleted = "gasto-borrado"
    /// Un código que no sirve ("Tengo un código" o el del correo).
    case error = "error"
    case parcheClosed = "parche-cerrado"
}

/// Suena y vibra en un momento de `FeedbackMoment`. Es imperativo (con UIKit para la vibración) porque casi todos
/// pasan al tocar un botón que además cierra la pantalla: un `.sensoryFeedback` en esa vista ya no alcanzaría a sonar.
@MainActor
enum Feedback {
    /// Clave de `UserDefaults` del interruptor "Sonidos" de Ajustes. Apagado, solo queda la vibración.
    static let soundsKey = "sonidos"

    static var soundsEnabled: Bool {
        UserDefaults.standard.object(forKey: soundsKey) as? Bool ?? true
    }

    private static var players: [FeedbackMoment: AVAudioPlayer] = [:]
    private static var isSessionReady = false

    static func play(_ moment: FeedbackMoment) {
        vibrate(for: moment)
        guard soundsEnabled, let player = player(for: moment) else { return }
        player.currentTime = 0
        player.play()
    }

    private static func vibrate(for moment: FeedbackMoment) {
        switch moment {
        case .expenseSaved, .paymentRecorded, .settled:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .error:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        case .expenseDeleted:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .parcheClosed:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }

    private static func player(for moment: FeedbackMoment) -> AVAudioPlayer? {
        if let player = players[moment] { return player }
        prepareSession()
        guard
            let url = Bundle.main.url(forResource: moment.rawValue, withExtension: "caf"),
            let player = try? AVAudioPlayer(contentsOf: url)
        else { return nil }
        player.prepareToPlay()
        players[moment] = player
        return player
    }

    /// `.ambient`: respeta el modo silencio y suena encima de la música sin pausarla.
    private static func prepareSession() {
        guard !isSessionReady else { return }
        isSessionReady = true
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: .mixWithOthers)
    }
}
