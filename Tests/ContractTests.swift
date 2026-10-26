import XCTest

/// Decoding of the research files (contract §0 and the research's answer in ZADANI_VYZKUM).
final class ContractTests: XCTestCase {
    private func fixture(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: name, withExtension: "json"))
        return try Data(contentsOf: url)
    }

    func testDecodesContractExample() throws {
        let result = ResearchStore.decode(WidgetData.self, from: try fixture("contract-example"))
        let d = try XCTUnwrap(result.value)
        XCTAssertEqual(d.schemaVersion, 1)
        XCTAssertEqual(d.treeKey, "lhotakovi-lhota")
        XCTAssertEqual(d.treeName, "Lhotákovi ze Lhoty")
        XCTAssertTrue(d.running)
        XCTAssertEqual(d.now?.lines.count, 1)
        XCTAssertEqual(d.now?.lines.first?.dir, .up)
        XCTAssertNil(d.now?.lines.first?.pausedUntil)
        XCTAssertEqual(d.findings?.items.count, 2)
        XCTAssertEqual(FindingKind(d.findings!.items[1]), .birth)
        XCTAssertEqual(d.pending?.count, 2)
        XCTAssertEqual(d.stats24h, WidgetData.Stats(persons: 3, sources: 5, saves: 12))
        // 14:32:05 +01:00 is 13:32:05 UTC.
        XCTAssertEqual(d.generatedAt, ContractCoding.parseDate("2026-10-26T13:32:05Z"))
    }

    /// The sample the research delivered (`docs/podklady/widget-vzor.json`, made-up tree).
    func testDecodesResearchSample() throws {
        let d = try XCTUnwrap(ResearchStore.decode(WidgetData.self, from: try fixture("research-sample")).value)
        XCTAssertEqual(d.treeKey, "8766d005-3a27-4dc9-a3c5-a62d70726cf5")
        XCTAssertTrue(ResearchPaths.isSafeKey(d.treeKey))
        XCTAssertEqual(d.now?.lines.first?.taskNoNames, "Hledat křest … v matrice Lhota")
        XCTAssertNil(d.now?.lastWorkedAt)
        XCTAssertNil(d.findings?.sinceStromOpenedAt)
        XCTAssertEqual(d.findings?.items.count, 11)
        let kinds = d.findings!.items.map(FindingKind.init)
        XCTAssertEqual(kinds.first, .conflictResolved)
        XCTAssertTrue(kinds.contains(.otherFact))
        XCTAssertEqual(d.findings!.items.first { FindingKind($0) == .otherFact }?.label, "Povolání")
        XCTAssertEqual(d.pending?.items.first?.textNoNames, "Opis zápisu …")
        XCTAssertEqual(d.stats24h?.saves, 19)

        let idx = try XCTUnwrap(ResearchStore.decode(ResearchIndex.self, from: try fixture("research-sample-index")).value)
        XCTAssertEqual(idx.trees.map(\.treeKey), [d.treeKey])
        XCTAssertEqual(idx.defaultTree?.treeName, "Lhotákovi ze Lhoty")
    }

    func testResearchSampleBuildsAModel() throws {
        let d = try XCTUnwrap(ResearchStore.decode(WidgetData.self, from: try fixture("research-sample")).value)
        let idx = try XCTUnwrap(ResearchStore.decode(ResearchIndex.self, from: try fixture("research-sample-index")).value)
        let now = d.generatedAt.addingTimeInterval(60)
        let m = WidgetModelBuilder.build(index: .ok(idx), tree: .ok(d), settings: WidgetSettings(treeKey: d.treeKey), now: now,
                                         timeZone: SampleData.timeZone)
        XCTAssertEqual(m.state, .data(.working, nothingNew: false))
        XCTAssertEqual(m.asOfHeader, "stav 9:19")
        XCTAssertEqual(m.lines.first?.since, "od 8:19")
        XCTAssertEqual(m.rows.count, 11)
        XCTAssertEqual(m.rows.first { $0.kind == .otherFact }?.kindLabel, "Povolání")
        XCTAssertEqual(m.stats.map(\.value), ["+3", "+1", "19"])

        let hidden = WidgetModelBuilder.build(index: .ok(idx), tree: .ok(d),
                                              settings: WidgetSettings(treeKey: d.treeKey, hideNames: true), now: now,
                                              timeZone: SampleData.timeZone)
        XCTAssertEqual(hidden.treeTitle, "Výzkum")
        XCTAssertEqual(hidden.lines.first?.title, "Předci osoby (*1784)")
        XCTAssertEqual(hidden.lines.first?.task, "Hledat křest … v matrice Lhota")
        XCTAssertFalse(hidden.rows.compactMap(\.text).joined().contains("Lhoták"))
        XCTAssertEqual(hidden.pendingItems, ["Opis zápisu …"])
    }

    func testDateFormats() {
        let z = ContractCoding.parseDate("2026-10-26T08:19:43Z")
        XCTAssertNotNil(z)
        XCTAssertEqual(ContractCoding.parseDate("2026-10-26T09:19:43+01:00"), z)
        XCTAssertEqual(ContractCoding.parseDate("2026-10-26T08:19:43.000Z"), z)
        XCTAssertNil(ContractCoding.parseDate("26. 10. 2026"))
    }

    func testToleratesMissingAndUnknownFields() throws {
        let json = """
        {"schemaVersion": 1, "treeKey": "t", "treeName": "Lhotákovi", "generatedAt": "2026-10-26T13:00:00Z", "running": true,
         "somethingNew": {"x": 1},
         "now": {"lines": [{"dir": "other", "title": "Kdo byl otec Dobromily"}, {"dir": "sideways", "title": "x"}]},
         "findings": {"items": [
            {"kind": "comet", "label": "Kometa", "text": "nad Lhotou", "at": "2026-10-26T12:00:00Z"},
            {"kind": "fact", "text": "chybí čas"},
            {"kind": "fact", "fact": "burial", "text": "Dobromila Lhotáková", "at": "not a date"},
            {"kind": "fact", "fact": "baptism", "text": "Bořivoj Lhoták", "at": "2026-10-26T11:00:00Z"}]},
         "pending": {"items": [{"text": "a"}, {"text": "b"}]}}
        """
        let d = try XCTUnwrap(ResearchStore.decode(WidgetData.self, from: Data(json.utf8)).value)
        XCTAssertEqual(d.now?.lines.map(\.dir), [.person, .person])
        XCTAssertNil(d.now?.lastWorkedAt)
        XCTAssertNil(d.stats24h)
        // Items without a time or with a broken one are dropped, the rest stays.
        XCTAssertEqual(d.findings?.items.count, 2)
        XCTAssertEqual(FindingKind(d.findings!.items[0]), .unknown)
        XCTAssertEqual(FindingKind(d.findings!.items[1]), .baptism)
        XCTAssertEqual(d.pending?.count, 2)

        let m = WidgetModelBuilder.build(index: .ok(ResearchIndex(trees: [.init(treeKey: "t", treeName: "Lhotákovi")])), tree: .ok(d),
                                         settings: WidgetSettings(treeKey: "t"), now: d.generatedAt, timeZone: SampleData.timeZone)
        XCTAssertEqual(m.rows.first?.kindLabel, "Kometa")
        XCTAssertEqual(m.rows.first?.glyph, "•")
        XCTAssertEqual(m.lines.first?.glyph, "⌕")
        // Without stats24h the numbers are not invented.
        XCTAssertEqual(m.stats.map(\.value), ["–", "–", "–"])
    }

    func testSchemaVersion() {
        let base = #""treeKey":"t","treeName":"x","generatedAt":"2026-10-26T13:00:00Z","running":true"#
        if case .outdated = ResearchStore.decode(WidgetData.self, from: Data("{\(base)}".utf8)) {} else { XCTFail("missing version") }
        if case .outdated = ResearchStore.decode(WidgetData.self, from: Data(#"{"schemaVersion":0,\#(base)}"#.utf8)) {} else { XCTFail("old version") }
        XCTAssertNotNil(ResearchStore.decode(WidgetData.self, from: Data(#"{"schemaVersion":2,\#(base)}"#.utf8)).value, "newer minor additions still read")
        if case .broken = ResearchStore.decode(WidgetData.self, from: Data(#"{"schemaVersion":1,"treeKey":"t"}"#.utf8)) {} else { XCTFail("required fields") }
        if case .broken = ResearchStore.decode(WidgetData.self, from: Data("{\"schemaVer".utf8)) {} else { XCTFail("half-written file is broken, not old") }
    }

    func testIndexShapes() throws {
        let object = #"{"schemaVersion":1,"generatedAt":"2026-10-26T08:19:48Z","trees":[{"treeKey":"a","treeName":"A","lastActiveAt":"2026-10-25T10:00:00Z"},{"treeKey":"b","treeName":"B","lastActiveAt":"2026-10-26T10:00:00Z"},{"bad":1}]}"#
        let idx = try XCTUnwrap(ResearchStore.decode(ResearchIndex.self, from: Data(object.utf8)).value)
        XCTAssertEqual(idx.trees.map(\.treeKey), ["a", "b"])
        XCTAssertEqual(idx.defaultTree?.treeKey, "b", "most recently active")

        let array = #"[{"treeKey":"a","treeName":"A"}]"#
        let bare = try XCTUnwrap(ResearchStore.decode(ResearchIndex.self, from: Data(array.utf8)).value)
        XCTAssertEqual(bare.defaultTree?.treeKey, "a", "the only tree")

        if case .outdated = ResearchStore.decode(ResearchIndex.self, from: Data(#"{"schemaVersion":0,"trees":[]}"#.utf8)) {} else { XCTFail() }
    }

    func testSafeKeys() {
        XCTAssertTrue(ResearchPaths.isSafeKey("lhotakovi-lhota"))
        XCTAssertTrue(ResearchPaths.isSafeKey("8766d005-3a27-4dc9-a3c5-a62d70726cf5"))
        XCTAssertFalse(ResearchPaths.isSafeKey("../secret"))
        XCTAssertFalse(ResearchPaths.isSafeKey(".hidden"))
        XCTAssertFalse(ResearchPaths.isSafeKey("a/b"))
        XCTAssertFalse(ResearchPaths.isSafeKey(""))
    }

    func testStoreReadsFromFolders() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("strom-widget-tests-\(UUID().uuidString)")
        defer { try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: root.appendingPathComponent("locked").path)
                try? fm.removeItem(at: root) }
        let copy = root.appendingPathComponent("copy"), source = root.appendingPathComponent("source")
        try fm.createDirectory(at: copy, withIntermediateDirectories: true)
        try fm.createDirectory(at: source, withIntermediateDirectories: true)
        let store = ResearchStore(directories: [copy, source])

        if case .missing = store.loadIndex() {} else { XCTFail("nothing yet") }

        var tree = SampleData.tree(.a)
        let enc = ContractCoding.encoder()
        try enc.encode(SampleData.index()).write(to: source.appendingPathComponent("index.json"))
        try enc.encode(tree).write(to: copy.appendingPathComponent("\(tree.treeKey).json"))
        tree.generatedAt += 60
        try enc.encode(tree).write(to: source.appendingPathComponent("\(tree.treeKey).json"))

        XCTAssertEqual(store.loadIndex().value?.trees.count, 2)
        XCTAssertEqual(store.loadTree(tree.treeKey).value?.generatedAt, tree.generatedAt, "the newer copy wins")
        if case .missing = store.loadTree("../index") {} else { XCTFail("unsafe key") }

        let locked = root.appendingPathComponent("locked")
        try fm.createDirectory(at: locked, withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: locked.appendingPathComponent("index.json"))
        try fm.setAttributes([.posixPermissions: 0o000], ofItemAtPath: locked.path)
        if case .noAccess = ResearchStore(directories: [locked]).loadIndex() {} else { XCTFail("no access") }
    }
}
