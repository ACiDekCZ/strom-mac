import Foundation

/// States without data (§4 g–j).
enum MessageKind: Equatable {
    case noAccess, outdated, noResearch, notSelected
}

/// Status of a tree with data (§4 f, k, d, c, b, a).
enum DataStatus: Equatable {
    case offline, stale, idle, paused, workingMany, working
}

enum WidgetState: Equatable {
    case message(MessageKind)
    /// `nothingNew` is state e, which combines with any data status.
    case data(DataStatus, nothingNew: Bool)
}

/// Shape that tells the status apart without colour (§0).
enum StatusShape: Equatable {
    case dot, square, ring, half
}

struct WidgetSettings: Equatable {
    var treeKey: String?
    /// Name stored with the widget configuration; shown in states g and h when the files can't tell.
    var treeName: String?
    var hideNames = false
    var findingsWindow: FindingsWindowChoice = .last24h
    var language: LanguageChoice = .auto
}

/// What a timeline entry shows: the state plus every text, already in the right language.
/// Views only lay this out; all decisions live here so they can be tested.
struct WidgetModel: Equatable {
    struct Line: Equatable {
        var glyph: String
        var title: String
        var task: String?
        var paused: Bool
        /// Medium and extra large: „od 9:40“ / „pauza · pokračuje v 14:30“.
        var since: String?
        /// Large: „od 9:40“ / „pauza do 14:30“.
        var sinceShort: String?
        var link: WidgetLink
    }

    struct Row: Equatable {
        var kind: FindingKind
        var glyph: String
        var kindLabel: String
        /// nil when names are hidden and the research gave no name-free text: the row shows kind and time only.
        var text: String?
        var time: String
        var group: FindingGroup
        var link: WidgetLink
    }

    struct Stat: Equatable {
        var value: String
        var label: String
    }

    var lang: Lang
    var state: WidgetState
    var treeTitle: String
    var treeLink: WidgetLink

    // Header
    var asOfTime: String?
    var asOfHeader: String?
    var isStale = false

    // States g–j
    var message: L10n.Message?

    // Status
    var shape: StatusShape = .dot
    var statusText = ""
    var statusShort = ""
    /// Sentence under the status when there is no line to show („naposledy se pracovalo před 2 h“).
    var statusSentence: String?
    /// „3 linie“ next to the status (only when > 1).
    var linesCount: String?
    var lines: [Line] = []
    /// Small widget, second line: „a 2 další linie“ or „pokračuje v 14:30“.
    var smallSecond: String?
    var smallSecondIsPause = false

    // Findings
    var findingsHeader = ""
    var smallFindingsLabel = ""
    var rows: [Row] = []
    var findingsNone: String?

    // Pending
    var pendingCount = 0
    var pendingItems: [String] = []
    var pendingHeader = ""
    var pendingLink: WidgetLink = .app

    // Stats
    var showStats = false
    var stats: [Stat] = []
    var showSmallCounts = false

    var isMessage: Bool { message != nil }
}

enum WidgetModelBuilder {
    static let staleAfter: TimeInterval = 15 * 60

    /// Extra timeline date at which a running tree turns stale (§4 k), so the state changes on time even when
    /// WidgetKit delays the next reload. `nil` when the data is not running or already stale.
    static func staleEntryDate(_ data: WidgetData, now: Date) -> Date? {
        guard data.running else { return nil }
        let staleAt = data.generatedAt.addingTimeInterval(staleAfter + 1)
        return staleAt > now ? staleAt : nil
    }

    /// A pause still running at `now`; one whose end has passed is over (no „pauza do“ with a past time).
    static func activePause(_ line: WidgetData.Line, now: Date) -> Date? {
        line.pausedUntil.flatMap { $0 > now ? $0 : nil }
    }

    /// The later dates at which the widget shows something else without new data: a pause ends, the data turns
    /// stale. Extra timeline entries, so it changes on time even when WidgetKit delays the next reload.
    static func entryDates(_ data: WidgetData, now: Date) -> [Date] {
        var dates = Set<Date>()
        if data.running {
            for line in data.now?.lines ?? [] {
                if let until = activePause(line, now: now) { dates.insert(until.addingTimeInterval(1)) }
            }
        }
        if let staleAt = staleEntryDate(data, now: now) { dates.insert(staleAt) }
        let horizon = now.addingTimeInterval(24 * 3600)
        return dates.filter { $0 > now && $0 <= horizon }.sorted()
    }

    /// Evaluation order of §4: first match wins (g, h, i, j, f, k, d, c, b, a; e combines with f–a).
    static func state(index: FileResult<ResearchIndex>, tree: FileResult<WidgetData>?, selectedKey: String?,
                      now: Date, findingsInWindow: Int) -> WidgetState {
        if case .noAccess = index { return .message(.noAccess) }
        if case .noAccess? = tree { return .message(.noAccess) }
        if case .outdated = index { return .message(.outdated) }
        if case .outdated? = tree { return .message(.outdated) }
        guard let idx = index.value, !idx.trees.isEmpty else { return .message(.noResearch) }
        guard let key = selectedKey, idx.trees.contains(where: { $0.treeKey == key }), let data = tree?.value else {
            return .message(.notSelected)
        }
        let nothingNew = findingsInWindow == 0
        let status: DataStatus
        let lines = data.now?.lines ?? []
        if !data.running {
            status = .offline
        } else if now.timeIntervalSince(data.generatedAt) > staleAfter {
            status = .stale
        } else if lines.isEmpty {
            status = .idle
        } else if lines.allSatisfy({ activePause($0, now: now) != nil }) {
            status = .paused
        } else if lines.count >= 2 {
            status = .workingMany
        } else {
            status = .working
        }
        return .data(status, nothingNew: nothingNew)
    }

    /// Findings inside the chosen window, newest first.
    static func findingsInWindow(_ data: WidgetData, window: FindingsWindowChoice, now: Date) -> [WidgetData.Finding] {
        let items = (data.findings?.items ?? []).sorted { $0.at > $1.at }
        let reference: Date
        if !data.running {
            reference = data.lastActiveAt ?? data.generatedAt
        } else if now.timeIntervalSince(data.generatedAt) > staleAfter {
            // Stale: content stays as it was when the data was written (§4 k).
            reference = data.generatedAt
        } else {
            reference = now
        }
        let start: Date
        if window == .sinceStromOpened, let opened = data.findings?.sinceStromOpenedAt {
            start = opened
        } else {
            start = reference.addingTimeInterval(-24 * 3600)
        }
        return Array(items.filter { $0.at >= start && $0.at <= reference.addingTimeInterval(5 * 60) }.prefix(50))
    }

    static func build(index: FileResult<ResearchIndex>, tree: FileResult<WidgetData>?, settings: WidgetSettings,
                      now: Date, timeZone: TimeZone = .current) -> WidgetModel {
        let data = tree?.value
        let langCode = data?.lang ?? index.value?.trees.first(where: { $0.treeKey == settings.treeKey })?.lang
            ?? index.value?.defaultTree?.lang ?? Locale.preferredLanguages.first
        let lang = settings.language.resolve(researchLang: langCode)
        let L = lang.strings
        let tt = TimeText(lang: lang, now: now, timeZone: timeZone)
        let window = data.map { findingsInWindow($0, window: settings.findingsWindow, now: now) } ?? []
        let state = state(index: index, tree: tree, selectedKey: settings.treeKey, now: now, findingsInWindow: window.count)

        guard case let .data(status, nothingNew) = state, let data else {
            guard case let .message(kind) = state else { fatalError("unreachable") }
            var title = L.treeGeneric
            if kind == .noAccess || kind == .outdated, let key = settings.treeKey,
               let name = index.value?.trees.first(where: { $0.treeKey == key })?.treeName ?? settings.treeName {
                title = settings.hideNames ? L.treeAnon : name
            }
            var m = WidgetModel(lang: lang, state: state, treeTitle: title, treeLink: .app)
            m.message = L.message(kind)
            return m
        }

        let hide = settings.hideNames
        let treeLink = WidgetLink.to(data.openUrl, tree: data)
        var m = WidgetModel(lang: lang, state: state, treeTitle: hide ? L.treeAnon : data.treeName, treeLink: treeLink)

        // Header: time the data was made (f: last activity).
        let headerDate = status == .offline ? (data.lastActiveAt ?? data.generatedAt) : data.generatedAt
        let headerTime = tt.clockOrDate(headerDate)
        m.asOfTime = headerTime
        m.isStale = status == .stale
        m.asOfHeader = L.headerAsOf(headerTime) + (m.isStale ? L.headerOld : "")

        // Status
        let allLines = data.now?.lines ?? []
        switch status {
        case .offline:
            m.shape = .ring
            m.statusText = L.statusOffline
            m.statusShort = L.statusOfflineShort
            m.statusSentence = L.subLastRan(tt.dayAndTime(data.lastActiveAt ?? data.generatedAt))
        case .stale:
            m.shape = .half
            m.statusText = L.statusStale(tt.clock(data.generatedAt))
            m.statusShort = L.statusStaleShort(tt.clock(data.generatedAt))
            m.statusSentence = allLines.isEmpty ? L.subStale : nil
        case .idle:
            m.shape = .ring
            m.statusText = L.statusIdle
            m.statusShort = L.statusIdleShort
            // Only `lastWorkedAt`: the heartbeat keeps `lastActiveAt` at „now“ while the research runs.
            if let last = data.now?.lastWorkedAt {
                m.statusSentence = tt.lastWorked(last)
            }
        case .paused:
            m.shape = .square
            m.statusText = L.statusPaused
            m.statusShort = L.statusPaused
        case .working, .workingMany:
            m.shape = .dot
            m.statusText = L.statusWorking
            m.statusShort = L.statusWorking
        }

        // Lines (hidden when research is not running: they would not be true, §4 f).
        if status != .offline {
            m.lines = allLines.prefix(FindingsLayout.maxLines).map { line in
                let title: String
                if hide {
                    title = line.titleNoNames ?? L.directionWord(line.dir)
                } else {
                    title = line.title
                }
                // Without a name-free variant the task is left out rather than shown with names.
                let task = hide ? line.taskNoNames : line.task
                let pause = activePause(line, now: now)
                let paused = pause != nil
                var since: String?, sinceShort: String?
                if let until = pause {
                    since = L.linePaused(tt.clock(until))
                    sinceShort = L.linePausedShort(tt.clock(until))
                } else if let s = line.since {
                    since = L.lineSince(tt.clockOrDate(s))
                    sinceShort = since
                }
                let glyph: String
                switch line.dir {
                case .up: glyph = "↑"
                case .down: glyph = "↓"
                case .person: glyph = "⌕"
                }
                return WidgetModel.Line(glyph: glyph, title: title, task: task, paused: paused, since: since, sinceShort: sinceShort,
                                        link: WidgetLink.to(line.openUrl, tree: data, label: title))
            }
            if allLines.count > 1 { m.linesCount = L.linesCount(allLines.count) }
            if status == .paused, let until = allLines.compactMap({ activePause($0, now: now) }).min() {
                m.smallSecond = L.subPauseUntil(tt.clock(until))
                m.smallSecondIsPause = true
            } else if allLines.count > 1 {
                m.smallSecond = L.linesMore(allLines.count - 1)
            }
        }

        // Findings
        let sinceOpened = settings.findingsWindow == .sinceStromOpened ? data.findings?.sinceStromOpenedAt : nil
        if status == .offline {
            m.findingsHeader = L.sectionFindingsUntil(tt.clock(data.lastActiveAt ?? data.generatedAt))
        } else if let s = sinceOpened {
            m.findingsHeader = L.sectionFindingsSince(tt.clockOrDate(s))
        } else {
            m.findingsHeader = L.sectionFindings
        }
        m.smallFindingsLabel = sinceOpened.map { L.smallFindingsSince(tt.clockOrDate($0)) } ?? L.smallFindings
        m.rows = window.map { f in
            let kind = FindingKind(f)
            var label = L.kind(kind)
            if kind == .otherFact || kind == .unknown, let l = f.label, !l.isEmpty { label = l }
            let text = hide ? f.textNoNames : f.text
            return WidgetModel.Row(kind: kind, glyph: kind.glyph, kindLabel: label, text: text, time: tt.rowTime(f.at),
                                   group: kind.group, link: WidgetLink.to(f.openUrl, tree: data, label: [label, text].compactMap { $0 }.joined(separator: " ")))
        }
        if nothingNew { m.findingsNone = sinceOpened == nil ? L.findingsNone : L.findingsNoneSince }

        // Pending (stays in every data state, „čeká stále“).
        let pending = data.pending
        m.pendingCount = max(pending?.count ?? 0, pending?.items.count ?? 0)
        m.pendingItems = (pending?.items ?? []).map { hide ? ($0.textNoNames ?? L.pendingAnon) : $0.text }
        m.pendingHeader = m.pendingCount > 0 ? "\(L.sectionPending) · \(m.pendingCount)" : L.sectionPending
        m.pendingLink = WidgetLink.to(pending?.openUrl, tree: data, label: L.sectionPending)

        // Stats and small counts are hidden when research is not running (they held only until then).
        m.showStats = status != .offline
        m.showSmallCounts = status != .offline
        // `stats24h` comes only once the day summary is computed; until then the numbers read „–“, not 0.
        let s = data.stats24h
        func plus(_ n: Int?) -> String { n.map { $0 > 0 ? "+\($0)" : "0" } ?? "–" }
        m.stats = [WidgetModel.Stat(value: plus(s?.persons), label: L.statsPersons),
                   WidgetModel.Stat(value: plus(s?.sources), label: L.statsSources),
                   WidgetModel.Stat(value: s.map { "\($0.saves)" } ?? "–", label: L.statsSaves)]
        return m
    }
}
