import XCTest

/// §4: evaluation order of the states and what each state shows.
final class StateTests: XCTestCase {
    private typealias S = SampleData.State

    func testEveryDesignStateIsRecognised() {
        let expected: [S: WidgetState] = [
            .a: .data(.working, nothingNew: false),
            .b: .data(.workingMany, nothingNew: false),
            .c: .data(.paused, nothingNew: false),
            .d: .data(.idle, nothingNew: false),
            .e: .data(.working, nothingNew: true),
            .f: .data(.offline, nothingNew: false),
            .g: .message(.noAccess),
            .h: .message(.outdated),
            .i: .message(.noResearch),
            .j: .message(.notSelected),
            .k: .data(.stale, nothingNew: false),
        ]
        for state in S.allCases {
            XCTAssertEqual(SampleData.model(state).state, expected[state], "state \(state)")
        }
    }

    private func state(index: FileResult<ResearchIndex>, tree: FileResult<WidgetData>?, key: String? = SampleData.treeKey,
                       now: Date = SampleData.at(14, 35)) -> WidgetState {
        WidgetModelBuilder.state(index: index, tree: tree, selectedKey: key, now: now, findingsInWindow: 1)
    }

    func testOrderFirstMatchWins() {
        let idx = FileResult.ok(SampleData.index())
        var t = SampleData.tree(.a)

        // g before h: no access to the folder beats an old tree file.
        XCTAssertEqual(state(index: .noAccess, tree: .outdated), .message(.noAccess))
        XCTAssertEqual(state(index: idx, tree: .noAccess), .message(.noAccess))
        // h before i: an old index is not „no research“.
        XCTAssertEqual(state(index: .outdated, tree: nil), .message(.outdated))
        // i: index missing, broken or empty.
        XCTAssertEqual(state(index: .missing, tree: nil), .message(.noResearch))
        XCTAssertEqual(state(index: .broken, tree: nil), .message(.noResearch))
        XCTAssertEqual(state(index: .ok(ResearchIndex(trees: [])), tree: .ok(t)), .message(.noResearch))
        // j: nothing chosen, or the chosen tree left the index.
        XCTAssertEqual(state(index: idx, tree: .ok(t), key: nil), .message(.notSelected))
        XCTAssertEqual(state(index: idx, tree: .ok(t), key: "gone"), .message(.notSelected))
        XCTAssertEqual(state(index: idx, tree: .missing), .message(.notSelected))

        // f before k: a properly ended research is „not running“, however old.
        t.running = false
        XCTAssertEqual(state(index: idx, tree: .ok(t), now: SampleData.at(23, 0)), .data(.offline, nothingNew: false))
        // k before d/c/b/a: older than 15 minutes.
        t = SampleData.tree(.d)
        XCTAssertEqual(state(index: idx, tree: .ok(t), now: SampleData.generatedAt + 15 * 60 + 1), .data(.stale, nothingNew: false))
        XCTAssertEqual(state(index: idx, tree: .ok(t), now: SampleData.generatedAt + 15 * 60), .data(.idle, nothingNew: false),
                       "exactly 15 min is still fresh")
        // c only when every line is paused; one paused line among working ones is b.
        XCTAssertEqual(state(index: idx, tree: .ok(SampleData.tree(.c))), .data(.paused, nothingNew: false))
        XCTAssertEqual(state(index: idx, tree: .ok(SampleData.tree(.b))), .data(.workingMany, nothingNew: false))
        t = SampleData.tree(.a)
        t.now?.lines[0].pausedUntil = SampleData.at(14, 50)
        XCTAssertEqual(state(index: idx, tree: .ok(t)), .data(.paused, nothingNew: false))
    }

    func testStaleEntryDate() {
        var t = SampleData.tree(.a)
        let staleAt = SampleData.generatedAt + 15 * 60 + 1
        // Fresh heartbeat: the entry is there although it lies beyond the 5 min reload, so k comes without a reload.
        XCTAssertEqual(WidgetModelBuilder.staleEntryDate(t, now: SampleData.generatedAt), staleAt)
        XCTAssertEqual(WidgetModelBuilder.staleEntryDate(t, now: SampleData.generatedAt + 14 * 60), staleAt)
        // At that entry the state is k.
        let k = WidgetModelBuilder.state(index: .ok(SampleData.index()), tree: .ok(t), selectedKey: SampleData.treeKey,
                                         now: staleAt, findingsInWindow: 1)
        XCTAssertEqual(k, .data(.stale, nothingNew: false))
        // Already stale, or not running: no extra entry.
        XCTAssertNil(WidgetModelBuilder.staleEntryDate(t, now: staleAt))
        t.running = false
        XCTAssertNil(WidgetModelBuilder.staleEntryDate(t, now: SampleData.generatedAt))
    }

    /// A pause whose end has passed is over: no „pauza do“ with a past time, and the line counts as working.
    func testPastPauseIsOver() {
        var t = SampleData.tree(.c)
        t.generatedAt = SampleData.at(14, 44) // heartbeat still fresh at 14:51
        let input = (index: FileResult.ok(SampleData.index()), tree: FileResult.ok(t))
        let settings = WidgetSettings(treeKey: SampleData.treeKey, treeName: SampleData.treeName(), hideNames: false, language: .auto)
        func model(_ now: Date) -> WidgetModel {
            WidgetModelBuilder.build(index: input.index, tree: input.tree, settings: settings, now: now, timeZone: SampleData.timeZone)
        }
        let during = model(SampleData.at(14, 45))
        XCTAssertEqual(during.statusText, "Pauza")
        XCTAssertEqual(during.smallSecond, "pokračuje v 14:50")
        let after = model(SampleData.at(14, 51))
        XCTAssertNotEqual(after.statusText, "Pauza")
        XCTAssertFalse(after.smallSecondIsPause)
        for line in after.lines {
            XCTAssertFalse((line.since ?? "").contains("pauza"), line.since ?? "")
            XCTAssertFalse((line.sinceShort ?? "").contains("pauza"), line.sinceShort ?? "")
        }
        XCTAssertEqual(state(index: input.index, tree: input.tree, now: SampleData.at(14, 51)), .data(.workingMany, nothingNew: false))
    }

    /// Timeline entries without new data: just after each pause ends and when the data turns stale.
    func testEntryDates() {
        let t = SampleData.tree(.b)
        let staleAt = SampleData.generatedAt + 15 * 60 + 1
        let pauseOver = SampleData.at(14, 50) + 1
        XCTAssertEqual(WidgetModelBuilder.entryDates(t, now: SampleData.at(14, 35)), [staleAt, pauseOver])
        XCTAssertEqual(WidgetModelBuilder.entryDates(t, now: staleAt), [pauseOver])
        XCTAssertEqual(WidgetModelBuilder.entryDates(t, now: pauseOver), [], "past pause: no entry")
        var stopped = t
        stopped.running = false
        XCTAssertEqual(WidgetModelBuilder.entryDates(stopped, now: SampleData.at(14, 35)), [], "stopped research shows no pause")
    }

    func testStateTexts() {
        let a = SampleData.model(.a)
        XCTAssertEqual(a.asOfHeader, "stav 14:32")
        XCTAssertEqual(a.statusText, "Pracuje se")
        XCTAssertEqual(a.shape, .dot)
        XCTAssertEqual(a.lines.first?.since, "od 9:40")
        XCTAssertNil(a.linesCount)
        XCTAssertEqual(a.pendingHeader, "Čeká · 2")

        let b = SampleData.model(.b)
        XCTAssertEqual(b.linesCount, "3 linie")
        XCTAssertEqual(b.smallSecond, "a 2 další linie")
        XCTAssertEqual(b.lines.last?.since, "pauza · pokračuje v 14:50")
        XCTAssertEqual(b.lines.last?.sinceShort, "pauza do 14:50")
        XCTAssertEqual(b.lines.map(\.glyph), ["↑", "↓", "⌕"])

        let c = SampleData.model(.c)
        XCTAssertEqual(c.shape, .square)
        XCTAssertEqual(c.statusText, "Pauza")
        XCTAssertEqual(c.smallSecond, "pokračuje v 14:50")
        XCTAssertTrue(c.smallSecondIsPause)

        let d = SampleData.model(.d)
        XCTAssertEqual(d.shape, .ring)
        XCTAssertEqual(d.statusText, "Teď se nepracuje")
        XCTAssertEqual(d.statusSentence, "naposledy se pracovalo před 2 h")

        let e = SampleData.model(.e)
        XCTAssertEqual(e.findingsNone, "Za 24 h nic nového")
        XCTAssertTrue(e.rows.isEmpty)
        XCTAssertEqual(e.pendingCount, 0)

        let f = SampleData.model(.f)
        XCTAssertEqual(f.shape, .ring)
        XCTAssertEqual(f.statusText, "Výzkum neběží")
        XCTAssertEqual(f.statusSentence, "naposledy běžel dnes v 11:20")
        XCTAssertEqual(f.asOfHeader, "stav 11:20")
        XCTAssertEqual(f.findingsHeader, "Nálezy do 11:20")
        XCTAssertTrue(f.lines.isEmpty, "Teď is hidden when not running")
        XCTAssertFalse(f.showStats)
        XCTAssertFalse(f.showSmallCounts)
        XCTAssertEqual(f.pendingCount, 2, "Čeká stays")

        let k = SampleData.model(.k)
        XCTAssertEqual(k.shape, .half)
        XCTAssertEqual(k.statusText, "Stav z 14:32")
        XCTAssertEqual(k.asOfHeader, "stav 14:32 · starší než 15 min")
        XCTAssertTrue(k.isStale)
        XCTAssertFalse(k.lines.isEmpty, "content stays")

        for s in [S.g, .h, .i, .j] {
            let m = SampleData.model(s)
            XCTAssertNotNil(m.message, "\(s)")
            XCTAssertNil(m.asOfHeader, "\(s): no time")
            XCTAssertEqual(m.treeLink, .app, "\(s): tap opens the host app")
        }
        XCTAssertEqual(SampleData.model(.h).message?.code, "strom update")
        XCTAssertEqual(SampleData.model(.g).treeTitle, "Lhotákovi ze Lhoty")
        XCTAssertEqual(SampleData.model(.i).treeTitle, "Strom")
    }

    func testNoStateSaysError() {
        for lang in Lang.allCases {
            for s in S.allCases {
                let m = SampleData.model(s, lang: lang)
                let all = [m.statusText, m.statusShort, m.statusSentence ?? "", m.message?.title ?? "", m.message?.body ?? ""].joined(separator: " ").lowercased()
                for word in ["chyba", "error", "fehler"] { XCTAssertFalse(all.contains(word), "\(lang) \(s)") }
            }
        }
    }

    func testFindingsWindow() {
        var t = SampleData.tree(.a)
        let old = WidgetData.Finding(kind: "person_new", text: "Božetěch Lhoták", at: SampleData.at(14, 0, day: 25))
        t.findings?.items.append(old)
        let in24h = WidgetModelBuilder.findingsInWindow(t, window: .last24h, now: SampleData.at(14, 35))
        XCTAssertFalse(in24h.contains(old))
        XCTAssertEqual(in24h, in24h.sorted { $0.at > $1.at }, "newest first")

        let sinceOpened = WidgetModelBuilder.findingsInWindow(t, window: .sinceStromOpened, now: SampleData.at(14, 35))
        XCTAssertTrue(sinceOpened.allSatisfy { $0.at >= SampleData.at(8, 55) })

        // Without sinceStromOpenedAt (the research does not know it yet) the widget keeps 24 h.
        t.findings?.sinceStromOpenedAt = nil
        XCTAssertEqual(WidgetModelBuilder.findingsInWindow(t, window: .sinceStromOpened, now: SampleData.at(14, 35)), in24h)
        let m = WidgetModelBuilder.build(index: .ok(SampleData.index()), tree: .ok(t),
                                         settings: WidgetSettings(treeKey: SampleData.treeKey, findingsWindow: .sinceStromOpened),
                                         now: SampleData.at(14, 35), timeZone: SampleData.timeZone)
        XCTAssertEqual(m.findingsHeader, "Nálezy · 24 h")

        // Stale data: the window is anchored at the data time, not at the clock.
        let stale = WidgetModelBuilder.findingsInWindow(SampleData.tree(.a), window: .last24h, now: SampleData.at(14, 30, day: 27))
        XCTAssertFalse(stale.isEmpty)

        // At most 50 items.
        var many = SampleData.tree(.a)
        many.findings?.items = (0..<80).map { WidgetData.Finding(kind: "source_new", text: "Matrika \($0)", at: SampleData.at(14, 0) - Double($0) * 60) }
        XCTAssertEqual(WidgetModelBuilder.findingsInWindow(many, window: .last24h, now: SampleData.at(14, 35)).count, 50)

        let since = WidgetModelBuilder.build(index: .ok(SampleData.index()), tree: .ok(SampleData.tree(.a)),
                                             settings: WidgetSettings(treeKey: SampleData.treeKey, findingsWindow: .sinceStromOpened),
                                             now: SampleData.at(14, 35), timeZone: SampleData.timeZone)
        XCTAssertEqual(since.findingsHeader, "Nálezy · od 8:55")
        XCTAssertEqual(since.smallFindingsLabel, "nálezy · od 8:55")
    }

    func testHideNames() {
        let m = SampleData.model(.b, hideNames: true)
        XCTAssertEqual(m.treeTitle, "Výzkum")
        XCTAssertEqual(m.lines.first?.title, "Předci osoby (1784)")
        let names = ["Bořivoj", "Dobromila", "Lhoták"]
        let texts = m.lines.map(\.title) + m.rows.compactMap(\.text) + m.pendingItems
        for n in names { XCTAssertFalse(texts.joined(separator: " ").contains(n), n) }

        // Missing name-free variants: kind and time only; the line falls back to its direction; no task with names.
        var t = SampleData.tree(.a)
        t.now?.lines[0].titleNoNames = nil
        let items = t.findings!.items.map { var f = $0; f.textNoNames = nil; return f }
        t.findings?.items = items
        let pending = t.pending!.items.map { var p = $0; p.textNoNames = nil; return p }
        t.pending?.items = pending
        let h = WidgetModelBuilder.build(index: .ok(SampleData.index()), tree: .ok(t),
                                         settings: WidgetSettings(treeKey: SampleData.treeKey, hideNames: true),
                                         now: SampleData.at(14, 35), timeZone: SampleData.timeZone)
        XCTAssertEqual(h.lines.first?.title, "Předci")
        XCTAssertNil(h.lines.first?.task)
        XCTAssertTrue(h.rows.allSatisfy { $0.text == nil && !$0.kindLabel.isEmpty && !$0.time.isEmpty })
        XCTAssertEqual(h.pendingItems, Array(repeating: "Položka", count: pending.count))
    }
}
