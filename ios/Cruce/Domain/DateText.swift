import Foundation

/// Textos de fecha en español de Colombia.
enum DateText {
    private static let locale = Locale(identifier: "es_CO")

    // Formatos fijos: la plantilla localizada de es_CO agrega "de" ("14 de oct") y el diseño usa "14 oct".
    private static let shortDay: DateFormatter = {
        let f = DateFormatter()
        f.locale = locale
        f.dateFormat = "d MMM"
        return f
    }()

    private static let weekdayDay: DateFormatter = {
        let f = DateFormatter()
        f.locale = locale
        f.dateFormat = "EEE d MMM"
        return f
    }()

    private static let time: DateFormatter = {
        let f = DateFormatter()
        f.locale = locale
        f.dateFormat = "h:mm a"
        f.amSymbol = "a. m."
        f.pmSymbol = "p. m."
        return f
    }()

    /// "Hoy", "Ayer" o "21 oct".
    static func relative(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "Hoy" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) { return "Ayer" }
        return clean(shortDay.string(from: date))
    }

    /// Encabezado de grupo en el historial: "HOY · VIE 23 OCT", "MIÉ 21 OCT".
    static func groupHeader(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        let day = clean(weekdayDay.string(from: date)).uppercased(with: locale)
        let rel = relative(date, now: now, calendar: calendar)
        if rel == "Hoy" || rel == "Ayer" { return "\(rel.uppercased(with: locale)) · \(day)" }
        return day
    }

    /// "vie 23 oct", sin "Hoy" ni "Ayer". Para frases como "el vie 23 oct".
    static func day(_ date: Date) -> String {
        clean(weekdayDay.string(from: date))
    }

    /// "Hoy, vie 23 oct".
    static func long(_ date: Date, now: Date = .now) -> String {
        let day = day(date)
        let rel = relative(date, now: now)
        return rel == "Hoy" || rel == "Ayer" ? "\(rel), \(day)" : day
    }

    /// "1:15 p. m."
    static func hour(_ date: Date) -> String {
        time.string(from: date)
    }

    /// "hoy a la 1:16 p. m.", "ayer a las 8:00 p. m." o "el 21 oct a las 8:00 p. m.".
    static func moment(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        let rel = relative(date, now: now, calendar: calendar)
        let day = (rel == "Hoy" || rel == "Ayer") ? rel.lowercased() : "el \(rel)"
        // En español la 1 lleva "la"; las demás horas, "las".
        let article = calendar.component(.hour, from: date) % 12 == 1 ? "la" : "las"
        return "\(day) a \(article) \(hour(date))"
    }

    /// Quita los puntos de abreviatura ("oct." → "oct", "vie.," → "vie").
    private static func clean(_ text: String) -> String {
        text.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: "")
    }
}
