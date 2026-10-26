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

    // MARK: Parches

    /// "Tus parches": la lista completa.
    case parches
    /// Detalle de un parche.
    case parche(UUID)
    case newParche
    case addParcheExpense(parcheID: UUID)
    case editParcheExpense(parcheID: UUID, expenseID: UUID)
    case parchePayment(parcheID: UUID)
    case closeParche(parcheID: UUID)
    /// Ticket para compartir: el personal de `participantID` o, sin persona, el del parche.
    case parcheTicket(parcheID: UUID, participantID: UUID?)
    /// "Tengo un código": `CRZ-`, `PCH-` o `SOY-`.
    case enterCode
}
