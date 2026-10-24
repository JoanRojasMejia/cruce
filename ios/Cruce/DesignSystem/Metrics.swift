import CoreGraphics

/// Radios de esquina.
enum Radius {
    static let chip: CGFloat = 10
    static let input: CGFloat = 12
    static let button: CGFloat = 14
    static let card: CGFloat = 16
    static let dialog: CGFloat = 20
    static let sheet: CGFloat = 28
}

/// Grosor de bordes.
enum BorderWidth {
    static let thin: CGFloat = 2
    static let regular: CGFloat = 2.5
    static let thick: CGFloat = 3
}

/// Desplazamiento de las sombras sólidas (x = y, sin blur).
enum ShadowOffset {
    static let xs: CGFloat = 2
    static let s: CGFloat = 3
    static let m: CGFloat = 4
    static let l: CGFloat = 5
    static let xl: CGFloat = 6
    static let xxl: CGFloat = 8
}

/// Espaciados (base 2).
enum Spacing {
    static let xxs: CGFloat = 6
    static let xs: CGFloat = 8
    static let s: CGFloat = 10
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    /// Margen lateral de todas las pantallas.
    static let screen: CGFloat = 20
    /// Área táctil mínima.
    static let minTouch: CGFloat = 44
}
