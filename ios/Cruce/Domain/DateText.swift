import Foundation

/// Textos de fecha en español de Colombia.
enum DateText {
    private static let locale = Locale(identifier: "es_CO")

    private static let shortDay: DateFormatter = {
        let f = DateFormatter()
        f.locale = locale
        f.setLocalizedDateFormatFromTemplate("d MMM")
        return f
    }()

    private static let weekdayDay: DateFormatter = {
        let f = DateFormatter()
        f.locale = locale
        f.setLocalizedDateFormatFromTemplate("EEE d MMM")
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

    /// "Hoy, vie 23 oct".
    static func long(_ date: Date, now: Date = .now) -> String {
        let day = clean(weekdayDay.string(from: date))
        let rel = relative(date, now: now)
        return rel == "Hoy" || rel == "Ayer" ? "\(rel), \(day)" : day
    }

    /// "1:15 p. m."
    static func hour(_ date: Date) -> String {
        time.string(from: date)
    }

    /// Quita los puntos de abreviatura ("oct." → "oct", "vie.," → "vie").
    private static func clean(_ text: String) -> String {
        text.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: "")
    }
}
