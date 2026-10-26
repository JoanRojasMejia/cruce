import Foundation

/// Pantallas que se apilan dentro del flujo principal.
public enum Route: Hashable, Sendable {
    case addMovement
    case editMovement(UUID)
    case history
    case detail(UUID)
    case settle
    case settings
    case offline
}
