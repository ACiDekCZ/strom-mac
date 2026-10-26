import Foundation

/// Snapshot of one research tree as written by `strom` to
/// `~/Library/Application Support/Strom/widget/<treeKey>.json` (contract §0, schemaVersion 1).
/// Decoding is tolerant: optional fields may be missing, unknown kinds are kept as `.other`.
struct WidgetData: Codable, Equatable {
    static let supportedSchemaVersion = 1

    var schemaVersion: Int?
    var treeKey: String
    var treeName: String
    var lang: String?
    var generatedAt: Date
    var running: Bool
    var lastActiveAt: Date?
    var openUrl: String?
    var now: NowSection?
    var findings: FindingsSection?
    var pending: PendingSection?
    var stats24h: Stats?

    struct NowSection: Codable, Equatable {
        var lines: [Line]
        var lastWorkedAt: Date?

        init(lines: [Line] = [], lastWorkedAt: Date? = nil) {
            self.lines = lines
            self.lastWorkedAt = lastWorkedAt
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            lines = try c.decodeIfPresent([Line].self, forKey: .lines) ?? []
            lastWorkedAt = try c.decodeIfPresent(Date.self, forKey: .lastWorkedAt)
        }
    }

    struct Line: Codable, Equatable {
        /// `up` ancestors, `down` descendants; `other` (person or question, as the research writes it)
        /// and anything unknown read as `.person`.
        enum Direction: String, Codable, Equatable {
            case up, down, person
            init(from decoder: Decoder) throws {
                let raw = try decoder.singleValueContainer().decode(String.self)
                self = Direction(rawValue: raw) ?? .person
            }
        }
        var dir: Direction
        var title: String
        var titleNoNames: String?
        var task: String?
        var taskNoNames: String?
        var since: Date?
        var pausedUntil: Date?
        var openUrl: String?

        init(dir: Direction, title: String, titleNoNames: String? = nil, task: String? = nil, taskNoNames: String? = nil,
             since: Date? = nil, pausedUntil: Date? = nil, openUrl: String? = nil) {
            self.dir = dir
            self.title = title
            self.titleNoNames = titleNoNames
            self.task = task
            self.taskNoNames = taskNoNames
            self.since = since
            self.pausedUntil = pausedUntil
            self.openUrl = openUrl
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            dir = (try? c.decodeIfPresent(Direction.self, forKey: .dir)) ?? .person
            title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
            titleNoNames = try c.decodeIfPresent(String.self, forKey: .titleNoNames)
            task = try c.decodeIfPresent(String.self, forKey: .task)
            taskNoNames = try c.decodeIfPresent(String.self, forKey: .taskNoNames)
            since = try c.decodeIfPresent(Date.self, forKey: .since)
            pausedUntil = try c.decodeIfPresent(Date.self, forKey: .pausedUntil)
            openUrl = try c.decodeIfPresent(String.self, forKey: .openUrl)
        }
    }

    struct FindingsSection: Codable, Equatable {
        var windowStart: Date?
        var sinceStromOpenedAt: Date?
        var items: [Finding]

        init(windowStart: Date? = nil, sinceStromOpenedAt: Date? = nil, items: [Finding] = []) {
            self.windowStart = windowStart
            self.sinceStromOpenedAt = sinceStromOpenedAt
            self.items = items
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            windowStart = try c.decodeIfPresent(Date.self, forKey: .windowStart)
            sinceStromOpenedAt = try c.decodeIfPresent(Date.self, forKey: .sinceStromOpenedAt)
            // A single malformed item must not hide the whole widget.
            items = (try c.decodeIfPresent([Lossy<Finding>].self, forKey: .items) ?? []).compactMap(\.value)
        }
    }

    struct Finding: Codable, Equatable {
        var kind: String
        var fact: String?
        var resolved: String?
        var label: String?
        var text: String?
        var textNoNames: String?
        var at: Date
        var openUrl: String?

        init(kind: String, fact: String? = nil, resolved: String? = nil, label: String? = nil, text: String?,
             textNoNames: String? = nil, at: Date, openUrl: String? = nil) {
            self.kind = kind
            self.fact = fact
            self.resolved = resolved
            self.label = label
            self.text = text
            self.textNoNames = textNoNames
            self.at = at
            self.openUrl = openUrl
        }
    }

    struct PendingSection: Codable, Equatable {
        var count: Int
        var items: [PendingItem]
        var openUrl: String?

        init(count: Int, items: [PendingItem] = [], openUrl: String? = nil) {
            self.count = count
            self.items = items
            self.openUrl = openUrl
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            items = try c.decodeIfPresent([PendingItem].self, forKey: .items) ?? []
            count = try c.decodeIfPresent(Int.self, forKey: .count) ?? items.count
            openUrl = try c.decodeIfPresent(String.self, forKey: .openUrl)
        }
    }

    struct PendingItem: Codable, Equatable {
        var text: String
        var textNoNames: String?
    }

    struct Stats: Codable, Equatable {
        var persons: Int
        var sources: Int
        var saves: Int

        init(persons: Int, sources: Int, saves: Int) {
            self.persons = persons
            self.sources = sources
            self.saves = saves
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            persons = try c.decodeIfPresent(Int.self, forKey: .persons) ?? 0
            sources = try c.decodeIfPresent(Int.self, forKey: .sources) ?? 0
            saves = try c.decodeIfPresent(Int.self, forKey: .saves) ?? 0
        }
    }
}

/// Wraps a decodable so that a broken array element decodes to nil instead of failing the array.
struct Lossy<T: Decodable>: Decodable {
    let value: T?
    init(from decoder: Decoder) throws {
        value = try? T(from: decoder)
    }
}

/// `index.json` next to the tree files: the list of research trees on this Mac.
/// Accepted shapes: `{ "schemaVersion": 1, "trees": [ … ] }` or a bare array of trees.
struct ResearchIndex: Codable, Equatable {
    var schemaVersion: Int?
    var trees: [Tree]

    struct Tree: Codable, Equatable, Identifiable {
        var treeKey: String
        var treeName: String
        var lang: String?
        var running: Bool?
        var lastActiveAt: Date?
        var generatedAt: Date?
        var id: String { treeKey }
    }

    init(schemaVersion: Int? = WidgetData.supportedSchemaVersion, trees: [Tree]) {
        self.schemaVersion = schemaVersion
        self.trees = trees
    }

    init(from decoder: Decoder) throws {
        if let array = try? decoder.singleValueContainer().decode([Lossy<Tree>].self) {
            schemaVersion = nil
            trees = array.compactMap(\.value)
            return
        }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion)
        trees = (try c.decodeIfPresent([Lossy<Tree>].self, forKey: .trees) ?? []).compactMap(\.value)
    }

    /// Default research for a new widget: the only tree, otherwise the most recently active one.
    var defaultTree: Tree? {
        if trees.count == 1 { return trees[0] }
        return trees.max { ($0.lastActiveAt ?? $0.generatedAt ?? .distantPast) < ($1.lastActiveAt ?? $1.generatedAt ?? .distantPast) }
    }
}

enum ContractCoding {
    /// ISO 8601 with or without fractional seconds, with offset or `Z`.
    static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let c = try decoder.singleValueContainer()
            let s = try c.decode(String.self)
            if let date = parseDate(s) { return date }
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Not an ISO 8601 date: \(s)")
        }
        return d
    }

    static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        e.dateEncodingStrategy = .custom { date, encoder in
            var c = encoder.singleValueContainer()
            try c.encode(plain.string(from: date))
        }
        return e
    }

    static func parseDate(_ s: String) -> Date? {
        fractional.date(from: s) ?? plain.date(from: s)
    }

    private static let plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let fractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    /// Reads just `schemaVersion` so that an outdated file is told apart from a broken one.
    static func schemaVersion(of data: Data) -> Int? {
        struct Probe: Decodable { var schemaVersion: Int? }
        if let probe = try? JSONDecoder().decode(Probe.self, from: data) { return probe.schemaVersion }
        return nil
    }
}
