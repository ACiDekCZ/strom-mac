import Foundation

enum FindingGroup: Int, CaseIterable, Comparable {
    case persons, families, sources, resolved

    static func < (a: FindingGroup, b: FindingGroup) -> Bool { a.rawValue < b.rawValue }
}

/// Kind of a finding row (§5): glyph, group and label key.
enum FindingKind: Equatable {
    case personNew, name
    case birth, baptism, marriage, death, burial, otherFact
    case familyNew, child, sourceNew
    case conflictResolved, hypothesisConfirmed, hypothesisRejected
    case unknown

    init(_ f: WidgetData.Finding) {
        switch f.kind {
        case "person_new": self = .personNew
        case "name": self = .name
        case "fact":
            switch f.fact {
            case "birth": self = .birth
            case "baptism": self = .baptism
            case "marriage": self = .marriage
            case "death": self = .death
            case "burial": self = .burial
            default: self = .otherFact
            }
        case "family_new": self = .familyNew
        case "child": self = .child
        case "source_new": self = .sourceNew
        case "resolved":
            switch f.resolved {
            case "hypothesis_confirmed": self = .hypothesisConfirmed
            case "hypothesis_rejected": self = .hypothesisRejected
            default: self = .conflictResolved
            }
        default: self = .unknown
        }
    }

    /// Text glyph in SF Pro (`↓` doubles as Child; `✓` for two resolved kinds, like the phone page).
    var glyph: String {
        switch self {
        case .personNew: return "+"
        case .name: return "Aa"
        case .birth: return "*"
        case .baptism: return "~"
        case .marriage: return "∞"
        case .death: return "†"
        case .burial: return "□"
        case .otherFact, .unknown: return "•"
        case .familyNew: return "⚭"
        case .child: return "↓"
        case .sourceNew: return "▤"
        case .conflictResolved, .hypothesisConfirmed: return "✓"
        case .hypothesisRejected: return "✕"
        }
    }

    var group: FindingGroup {
        switch self {
        case .personNew, .name, .birth, .baptism, .marriage, .death, .burial, .otherFact, .unknown: return .persons
        case .familyNew, .child: return .families
        case .sourceNew: return .sources
        case .conflictResolved, .hypothesisConfirmed, .hypothesisRejected: return .resolved
        }
    }
}

enum FindingsWindowChoice: String, Codable {
    case last24h, sinceStromOpened
}

enum FindingsLayout {
    /// Large widget: rows of findings by number of lines in Teď (0–1 → 7, 2 → 5, 3 → 4).
    static func largeBudget(lineCount: Int) -> Int {
        switch lineCount {
        case ...1: return 7
        case 2: return 5
        default: return 4
        }
    }

    static let extraLargeBudget = 9
    static let mediumRows = 3
    static let mediumLines = 2
    static let maxLines = 3
    static let extraLargePending = 3

    /// Large widget, Čeká: one item with three lines, else two.
    static func largePending(lineCount: Int) -> Int { lineCount >= 3 ? 1 : 2 }

    /// Takes the newest `limit` findings across groups and groups them in the order Osoby, Rodiny, Prameny, Vyřešeno.
    static func grouped<T>(_ rows: [T], limit: Int, group: (T) -> FindingGroup) -> (groups: [(FindingGroup, [T])], more: Int) {
        let shown = Array(rows.prefix(limit))
        let groups = FindingGroup.allCases.compactMap { g -> (FindingGroup, [T])? in
            let r = shown.filter { group($0) == g }
            return r.isEmpty ? nil : (g, r)
        }
        return (groups, rows.count - shown.count)
    }
}
