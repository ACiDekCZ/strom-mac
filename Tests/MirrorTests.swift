import XCTest

/// The helper's copy into the App Group and the reload throttle (§0 Obnova).
final class MirrorTests: XCTestCase {
    private var root: URL!
    private var source: URL { root.appendingPathComponent("source") }
    private var dest: URL { root.appendingPathComponent("dest") }
    private let enc = ContractCoding.encoder()

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("strom-mirror-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func write(_ tree: WidgetData) throws {
        try enc.encode(tree).write(to: source.appendingPathComponent("\(tree.treeKey).json"), options: .atomic)
    }

    private func writeIndex(_ idx: ResearchIndex = SampleData.index()) throws {
        try enc.encode(idx).write(to: source.appendingPathComponent("index.json"), options: .atomic)
    }

    func testMissingSourceGivesEmptyIndex() throws {
        try FileManager.default.removeItem(at: source)
        let r = Mirror(source: source, destination: dest).sync()
        XCTAssertTrue(r.sourceMissing)
        let idx = ResearchStore(directories: [dest]).loadIndex()
        XCTAssertEqual(idx.value?.trees.count, 0, "widget says „no research“ (i), not „no access“ (g)")
    }

    func testCopiesAndDetectsChanges() throws {
        var tree = SampleData.tree(.a)
        try writeIndex()
        try write(tree)
        let mirror = Mirror(source: source, destination: dest)

        var r = mirror.sync()
        XCTAssertTrue(r.changed.contains(tree.treeKey))
        XCTAssertTrue(r.newFinding.contains(tree.treeKey))
        XCTAssertEqual(ResearchStore(directories: [dest]).loadTree(tree.treeKey).value, tree)

        // Nothing new: nothing written.
        r = mirror.sync()
        XCTAssertFalse(r.wrote)
        XCTAssertTrue(r.changed.isEmpty)

        // Heartbeat (generatedAt, lastActiveAt and the findings' window move, also in the index): written, not a change.
        tree.generatedAt += 60
        tree.lastActiveAt = tree.generatedAt
        tree.findings?.windowStart = tree.generatedAt - 24 * 3600
        try write(tree)
        var idx = SampleData.index()
        idx.trees[0].generatedAt = tree.generatedAt
        idx.trees[0].lastActiveAt = tree.generatedAt
        try writeIndex(idx)
        r = mirror.sync()
        XCTAssertTrue(r.wrote)
        XCTAssertTrue(r.changed.isEmpty)
        XCTAssertTrue(r.heartbeatOnly)

        // Only the pause moves: a change.
        tree.now?.lines[0].pausedUntil = SampleData.at(15, 10)
        try write(tree)
        r = mirror.sync()
        XCTAssertEqual(r.changed, [tree.treeKey])
        XCTAssertFalse(r.heartbeatOnly)
        tree.now?.lines[0].pausedUntil = nil
        try write(tree)
        XCTAssertEqual(mirror.sync().changed, [tree.treeKey], "the pause ends early")

        // Teď changes: a change, not urgent.
        tree.now?.lines[0].task = "Projít sňatky, Lhota 1805–1830"
        try write(tree)
        r = mirror.sync()
        XCTAssertEqual(r.changed, [tree.treeKey])
        XCTAssertTrue(r.newFinding.isEmpty)

        // New finding: urgent.
        tree.findings?.items.insert(WidgetData.Finding(kind: "child", text: "Božetěch Lhoták", at: SampleData.at(14, 33)), at: 0)
        try write(tree)
        r = mirror.sync()
        XCTAssertEqual(r.newFinding, [tree.treeKey])
    }

    func testBrokenFileKeepsLastGoodCopy() throws {
        let tree = SampleData.tree(.a)
        try writeIndex()
        try write(tree)
        let mirror = Mirror(source: source, destination: dest)
        _ = mirror.sync()
        try Data("{\"schemaVersion\": 1, \"treeKey\":".utf8).write(to: source.appendingPathComponent("\(tree.treeKey).json"))
        _ = mirror.sync()
        XCTAssertEqual(ResearchStore(directories: [dest]).loadTree(tree.treeKey).value, tree)
    }

    func testOutdatedFileIsCopiedSoTheWidgetCanSaySo() throws {
        try writeIndex()
        try Data(#"{"treeKey":"lhotakovi-lhota","treeName":"Lhotákovi","generatedAt":"2026-10-26T13:00:00Z","running":true}"#.utf8)
            .write(to: source.appendingPathComponent("lhotakovi-lhota.json"))
        _ = Mirror(source: source, destination: dest).sync()
        if case .outdated = ResearchStore(directories: [dest]).loadTree("lhotakovi-lhota") {} else { XCTFail() }
    }

    func testTreesLeavingTheIndexDisappear() throws {
        let a = SampleData.tree(.a)
        var b = SampleData.tree(.f)
        b.treeKey = SampleData.otherTreeKey
        try writeIndex()
        try write(a)
        try write(b)
        let mirror = Mirror(source: source, destination: dest)
        _ = mirror.sync()
        XCTAssertNotNil(ResearchStore(directories: [dest]).loadTree(b.treeKey).value)

        var idx = SampleData.index()
        idx.trees.removeAll { $0.treeKey == b.treeKey }
        try writeIndex(idx)
        try FileManager.default.removeItem(at: source.appendingPathComponent("\(b.treeKey).json"))
        let r = mirror.sync()
        XCTAssertTrue(r.changed.contains(b.treeKey))
        if case .missing = ResearchStore(directories: [dest]).loadTree(b.treeKey) {} else { XCTFail() }
    }

    func testIgnoresTemporaryAndUnsafeFiles() throws {
        var idx = SampleData.index()
        idx.trees.append(.init(treeKey: "../escape", treeName: "x"))
        try writeIndex(idx)
        try write(SampleData.tree(.a))
        try Data("{".utf8).write(to: source.appendingPathComponent(".lhotakovi-lhota.json.123.abc.tmp"))
        _ = Mirror(source: source, destination: dest).sync()
        let files = try FileManager.default.contentsOfDirectory(atPath: dest.path).sorted()
        XCTAssertEqual(files, ["index.json", "lhotakovi-lhota.json"])
    }

    func testThrottle() {
        var t = ReloadThrottle()
        let t0 = SampleData.at(14, 0)
        XCTAssertTrue(t.request(now: t0, urgent: false), "first change reloads")
        XCTAssertFalse(t.request(now: t0 + 10, urgent: false), "merged")
        XCTAssertFalse(t.flush(now: t0 + 30))
        XCTAssertTrue(t.flush(now: t0 + 60), "deferred reload after 60 s")
        XCTAssertFalse(t.flush(now: t0 + 120), "nothing pending")
        XCTAssertTrue(t.request(now: t0 + 61, urgent: true), "a new finding reloads at once")
        XCTAssertTrue(t.request(now: t0 + 130, urgent: false))
    }

    /// Heartbeats alone keep the widget fresh once per 10 min, not once per heartbeat.
    func testThrottleHeartbeat() {
        var t = ReloadThrottle()
        let t0 = SampleData.at(14, 0)
        XCTAssertTrue(t.heartbeat(now: t0), "first sync after start reloads")
        var reloads = 0
        for minute in 1...60 where t.heartbeat(now: t0 + Double(minute) * 60) { reloads += 1 }
        XCTAssertEqual(reloads, 6, "heartbeat every 60 s: 6 reloads an hour")
        XCTAssertTrue(t.request(now: t0 + 3700, urgent: false), "a visible change still reloads")
        XCTAssertFalse(t.heartbeat(now: t0 + 3760), "the change counts as the fresh reload")
    }

    /// The helper reloads through the host app: its program, found from the helper's place in the bundle.
    func testHostExecutable() throws {
        let host = root.appendingPathComponent("Strom Widget.app/Contents")
        let helper = host.appendingPathComponent("Library/LoginItems/StromWidgetHelper.app")
        try FileManager.default.createDirectory(at: host.appendingPathComponent("MacOS"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: helper, withIntermediateDirectories: true)
        func info(_ id: String) throws {
            let plist: [String: Any] = ["CFBundleIdentifier": id, "CFBundleExecutable": "Strom Widget", "CFBundlePackageType": "APPL"]
            try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
                .write(to: host.appendingPathComponent("Info.plist"))
        }
        try info(HostReload.hostIdentifier)
        try Data().write(to: host.appendingPathComponent("MacOS/Strom Widget"))
        XCTAssertEqual(HostReload.hostExecutable(helperBundle: helper)?.resolvingSymlinksInPath().path,
                       host.appendingPathComponent("MacOS/Strom Widget").resolvingSymlinksInPath().path)
        XCTAssertNil(HostReload.hostExecutable(helperBundle: root.appendingPathComponent("StromWidgetHelper.app")),
                     "a helper outside the host app has no host")
    }

    func testOtherHostIsNotRun() throws {
        let host = root.appendingPathComponent("Other.app/Contents")
        let helper = host.appendingPathComponent("Library/LoginItems/StromWidgetHelper.app")
        try FileManager.default.createDirectory(at: host.appendingPathComponent("MacOS"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: helper, withIntermediateDirectories: true)
        let plist: [String: Any] = ["CFBundleIdentifier": "devcheck.other", "CFBundleExecutable": "Other", "CFBundlePackageType": "APPL"]
        try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0).write(to: host.appendingPathComponent("Info.plist"))
        try Data().write(to: host.appendingPathComponent("MacOS/Other"))
        XCTAssertNil(HostReload.hostExecutable(helperBundle: helper))
    }
}
