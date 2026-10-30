import Foundation

/// Pantallas que se apilan dentro del flujo principal.
public enum Route: Hashable, Sendable {
    case addMovement
    case editMovement(UUID)
    case history
    case detail(UUID)
    case settle
    /// Ajustes de la cuenta: perfil, notificaciones, recordatorios, invitar, cerrar sesión y versión.
    case settings
    /// Ajustes del cruce abierto: con quién es, moneda, reparto por defecto, exportar y desvincular.
    case cruceSettings
    /// Ajustes → la tarjeta del perfil: cambiar el nombre.
    case profile
    /// Ajustes → "Reparto por defecto" del cruce abierto.
    case defaultSplit
    case offline

    // MARK: Cruces

    /// El inicio de un cruce, desde "Tus cruces": lo abre (`SessionStore.open`) y muestra su saldo.
    case cruce(UUID)
    /// "Invitar a alguien" teniendo ya un cruce: el código del cruce pendiente.
    case invite
    /// Unirse a otro cruce con un código `CRZ-` (arranca con `SessionStore.pendingJoinCode`).
    case join

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

extension Route {
    /// El engrane del encabezado: en "Tus cruces" abre los Ajustes de la cuenta y dentro de un cruce,
    /// los Ajustes de ese cruce.
    public static func gear(inCruce: Bool) -> Route {
        inCruce ? .cruceSettings : .settings
    }
}
