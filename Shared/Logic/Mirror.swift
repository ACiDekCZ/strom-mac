import Foundation

/// Copies valid research files into the App Group, where the sandboxed widget reads them (§0 Obnova).
struct Mirror {
    var source: URL
    var destination: URL

    struct Result: Equatable {
        /// Trees whose file changed (content other than the heartbeat `generatedAt`).
        var changed: Set<String> = []
        /// Trees whose newest finding changed: reload at once.
        var newFinding: Set<String> = []
        /// Something was written at all (including heartbeats).
        var wrote = false
        var sourceMissing = false
        var sourceNoAccess = false
    }

    func sync() -> Result {
        var result = Result()
        let fm = FileManager.default
        try? fm.createDirectory(at: destination, withIntermediateDirectories: true)

        let store = ResearchStore(directories: [source])
        let index = store.loadIndex()
        var keys: [String] = []
        switch index {
        case .ok(let idx):
            keys = idx.trees.map(\.treeKey).filter(ResearchPaths.isSafeKey)
            if let data = try? Data(contentsOf: source.appendingPathComponent(ResearchPaths.indexFileName)) {
                if write(data, name: ResearchPaths.indexFileName) { result.wrote = true; result.changed.insert("") }
            }
        case .outdated:
            // Keep the old file visible so the widget can say „Výzkum potřebuje aktualizaci“.
            if let data = try? Data(contentsOf: source.appendingPathComponent(ResearchPaths.indexFileName)) {
                if write(data, name: ResearchPaths.indexFileName) { result.wrote = true; result.changed.insert("") }
            }
        case .missing, .broken:
            result.sourceMissing = index.isMissing
            // No research on this Mac: an empty index lets the widget say so (state i) instead of „no access“.
            if write(Self.emptyIndex, name: ResearchPaths.indexFileName) { result.wrote = true; result.changed.insert("") }
        case .noAccess:
            result.sourceNoAccess = true
        }

        for key in keys {
            let name = ResearchPaths.treeFileName(key)
            let src = source.appendingPathComponent(name)
            guard let data = try? Data(contentsOf: src) else { continue }
            let decoded = ResearchStore.decode(WidgetData.self, from: data)
            switch decoded {
            case .ok(let new):
                let old = ResearchStore(directories: [destination]).loadTree(key).value
                if write(data, name: name) {
                    result.wrote = true
                    if old.map({ Self.contentKey($0) }) != Self.contentKey(new) { result.changed.insert(key) }
                    if old?.findings?.items.map(\.at).max() != new.findings?.items.map(\.at).max(), new.findings?.items.isEmpty == false {
                        result.newFinding.insert(key)
                    }
                }
            case .outdated:
                if write(data, name: name) { result.wrote = true; result.changed.insert(key) }
            default:
                continue // half-written or broken: keep the last good copy
            }
        }

        // Trees that left the index disappear from the copy too.
        if case .ok = index, let files = try? fm.contentsOfDirectory(atPath: destination.path) {
            for f in files where f.hasSuffix(".json") && f != ResearchPaths.indexFileName {
                let key = String(f.dropLast(5))
                if !keys.contains(key) {
                    try? fm.removeItem(at: destination.appendingPathComponent(f))
                    result.changed.insert(key)
                }
            }
        }
        return result
    }

    static let emptyIndex = Data(#"{"schemaVersion":1,"trees":[]}"#.utf8)

    /// Everything except the heartbeat times, so a heartbeat alone does not count as a change
    /// (the heartbeat refreshes `generatedAt` and, while running, `lastActiveAt`).
    static func contentKey(_ d: WidgetData) -> WidgetData {
        var d = d
        d.generatedAt = .distantPast
        if d.running { d.lastActiveAt = nil }
        return d
    }

    /// Atomic write; returns false when the destination already has the same bytes.
    @discardableResult
    private func write(_ data: Data, name: String) -> Bool {
        let url = destination.appendingPathComponent(name)
        if let existing = try? Data(contentsOf: url), existing == data { return false }
        do {
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }
}

private extension FileResult {
    var isMissing: Bool {
        if case .missing = self { return true }
        return false
    }
}

/// Decides when to ask WidgetKit for a reload: at once after a new finding, otherwise at most once per 60 s.
struct ReloadThrottle {
    var minimumInterval: TimeInterval = 60
    private(set) var lastReload: Date?
    private(set) var pending = false

    /// Returns true when a reload should happen now; otherwise remembers that one is due.
    mutating func request(now: Date, urgent: Bool) -> Bool {
        if urgent || lastReload.map({ now.timeIntervalSince($0) >= minimumInterval }) ?? true {
            lastReload = now
            pending = false
            return true
        }
        pending = true
        return false
    }

    /// Called from a timer: performs a deferred reload once the interval has passed.
    mutating func flush(now: Date) -> Bool {
        guard pending, let last = lastReload, now.timeIntervalSince(last) >= minimumInterval else { return false }
        lastReload = now
        pending = false
        return true
    }
}
