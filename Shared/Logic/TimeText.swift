import Foundation

/// Times shown in the widget. Absolute times always come from the data, relative ones are
/// computed against the timeline entry date (`now`), never against a live clock (§0 Obnova).
struct TimeText {
    var lang: Lang
    var now: Date
    var calendar: Calendar

    init(lang: Lang, now: Date, timeZone: TimeZone = .current) {
        self.lang = lang
        self.now = now
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        cal.locale = lang.locale
        self.calendar = cal
    }

    /// `9:40`, `14:32` (24 h in every language, like the design).
    func clock(_ date: Date) -> String {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%d:%02d", c.hour ?? 0, c.minute ?? 0)
    }

    /// `24. 10.` / `24 Oct` / `24.10.`
    func shortDate(_ date: Date) -> String {
        let c = calendar.dateComponents([.day, .month], from: date)
        let d = c.day ?? 0, m = c.month ?? 0
        switch lang {
        case .cs: return "\(d). \(m)."
        case .de: return "\(d).\(m)."
        case .en:
            let f = DateFormatter()
            f.calendar = calendar
            f.timeZone = calendar.timeZone
            f.locale = Locale(identifier: "en_GB")
            f.dateFormat = "d MMM"
            return f.string(from: date)
        }
    }

    private func dayDistance(_ date: Date) -> Int {
        let a = calendar.startOfDay(for: date), b = calendar.startOfDay(for: now)
        return calendar.dateComponents([.day], from: a, to: b).day ?? 0
    }

    /// Finding row time: today `H:MM`, yesterday `včera`, otherwise a date (§5).
    func rowTime(_ date: Date) -> String {
        switch dayDistance(date) {
        case ...0: return clock(date)
        case 1: return lang.strings.yesterday
        default: return shortDate(date)
        }
    }

    /// Header time and „od 9:40“: the clock for today, otherwise date and clock.
    func clockOrDate(_ date: Date) -> String {
        switch dayDistance(date) {
        case ...0: return clock(date)
        case 1: return "\(lang.strings.yesterday) \(clock(date))"
        default: return "\(shortDate(date)) \(clock(date))"
        }
    }

    /// `dnes v 11:20` / `včera v 21:10` / `24. 10. v 11:20` (sub.lastRan, host app rows).
    func dayAndTime(_ date: Date) -> String {
        let time = clock(date)
        switch dayDistance(date) {
        case ...0:
            switch lang {
            case .cs: return "dnes v \(time)"
            case .en: return "today at \(time)"
            case .de: return "heute um \(time)"
            }
        case 1:
            switch lang {
            case .cs: return "včera v \(time)"
            case .en: return "yesterday at \(time)"
            case .de: return "gestern um \(time)"
            }
        default:
            let d = shortDate(date)
            switch lang {
            case .cs: return "\(d) v \(time)"
            case .en: return "\(d) at \(time)"
            case .de: return "\(d) um \(time)"
            }
        }
    }

    /// Host app row: `včera 21:10` (no preposition, as in the design 8a).
    func dayAndTimeShort(_ date: Date) -> String {
        switch dayDistance(date) {
        case ...0:
            switch lang {
            case .cs: return "dnes \(clock(date))"
            case .en: return "today \(clock(date))"
            case .de: return "heute \(clock(date))"
            }
        default: return clockOrDate(date)
        }
    }

    /// Short duration for „před 2 h“: `5 min` / `2 h`; nil when it is a day or more (then an absolute time is used).
    func ago(_ date: Date) -> String? {
        let seconds = max(0, now.timeIntervalSince(date))
        let minutes = Int(seconds / 60)
        if minutes < 60 {
            let m = max(1, minutes)
            return lang == .de ? "\(m) Min." : "\(m) min"
        }
        let hours = minutes / 60
        if hours < 24 {
            return lang == .de ? "\(hours) Std." : "\(hours) h"
        }
        return nil
    }

    /// „naposledy se pracovalo před 2 h“ / „… včera v 21:10“.
    func lastWorked(_ date: Date) -> String {
        if let a = ago(date) { return lang.strings.subLastWorked(a) }
        return lang.strings.subLastWorkedAt(dayAndTime(date))
    }
}
