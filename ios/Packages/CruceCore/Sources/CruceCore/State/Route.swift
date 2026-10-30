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
    /// La actividad del parche, desde el encabezado de su detalle; al abrirla queda vista.
    case parcheActivity(parcheID: UUID)
    /// Ticket para compartir: el personal de `participantID` o, sin persona, el del parche.
    case parcheTicket(parcheID: UUID, participantID: UUID?)
    /// "Tengo un código": `CRZ-`, `PCH-` o `SOY-` (también al abrir un enlace `cruce://codigo/…`).
    case enterCode
    /// Llegada después de entrar con un código: "Entraste a…" (`PCH-`) o "Ahora eres… en…" (`SOY-`).
    case parcheArrival(parcheID: UUID, kind: ParcheArrival.Kind)
}

extension Route {
    /// El engrane del encabezado: en "Tus cruces" abre los Ajustes de la cuenta y dentro de un cruce,
    /// los Ajustes de ese cruce.
    public static func gear(inCruce: Bool) -> Route {
        inCruce ? .cruceSettings : .settings
    }
}
