import Foundation

/// Cómo se llegó a un parche con "Tengo un código": decide qué pantalla de llegada se muestra.
public struct ParcheArrival: Equatable, Sendable {
    public enum Kind: Hashable, Sendable {
        /// Con un código `PCH-`: "Entraste a Santa Marta".
        case joined
        /// Con un código `SOY-`: "Ahora eres Carlos en Santa Marta".
        case claimedPlace
    }

    public let kind: Kind
    /// El parche ya con quien llegó adentro.
    public let detail: ParcheDetail

    public init(kind: Kind, detail: ParcheDetail) {
        self.kind = kind
        self.detail = detail
    }

    /// El nombre con el que quedó quien llegó: el suyo con `PCH-` o el del lugar con `SOY-`.
    public var name: String { detail.me?.displayName ?? "" }
}
