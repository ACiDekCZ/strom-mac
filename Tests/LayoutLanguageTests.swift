import XCTest

/// Row budgets and grouping (§3, §5), language choice (§0 Jazyk) and times taken from the data.
final class LayoutTests: XCTestCase {
    func testLargeBudgetByLines() {
        XCTAssertEqual(FindingsLayout.largeBudget(lineCount: 0), 7)
        XCTAssertEqual(FindingsLayout.largeBudget(lineCount: 1), 7)
        XCTAssertEqual(FindingsLayout.largeBudget(lineCount: 2), 5)
        XCTAssertEqual(FindingsLayout.largeBudget(lineCount: 3), 4)
        XCTAssertEqual(FindingsLayout.largePending(lineCount: 3), 1)
        XCTAssertEqual(FindingsLayout.largePending(lineCount: 2), 2)
        XCTAssertEqual(FindingsLayout.extraLargeBudget, 9)
        XCTAssertEqual(FindingsLayout.mediumRows, 3)
    }

    func testNewestAcrossGroupsThenGrouped() {
        // Newest first: source, person, resolved, family, person, person, child, source.
        let rows: [FindingGroup] = [.sources, .persons, .resolved, .families, .persons, .persons, .families, .sources]
        let (groups, more) = FindingsLayout.grouped(rows, limit: 5) { $0 }
        XCTAssertEqual(groups.map(\.0), [.persons, .families, .sources, .resolved])
        XCTAssertEqual(groups.map(\.1.count), [2, 1, 1, 1])
        XCTAssertEqual(more, 3, "„a 3 další“")

        let all = FindingsLayout.grouped(rows, limit: 20) { $0 }
        XCTAssertEqual(all.more, 0)
    }

    func testMoreLabel() {
        XCTAssertEqual(L10n(lang: .cs).findingsMore(1), "a 1 další")
        XCTAssertEqual(L10n(lang: .cs).findingsMore(3), "a 3 další")
        XCTAssertEqual(L10n(lang: .cs).findingsMore(7), "a 7 dalších")
        XCTAssertEqual(L10n(lang: .en).findingsMore(7), "and 7 more")
        XCTAssertEqual(L10n(lang: .de).findingsMore(7), "und 7 weitere")
    }

    /// The widget never cuts texts itself: the view truncates the end of the line (§5, 5c),
    /// so the full text reaches the view and kind word and time stay separate fields.
    func testRowKeepsFullTextForTailTruncation() {
        var t = SampleData.tree(.a)
        let long = "Bořivoj Lhoták, 3. 5. 1784, Lhota, farnost Lhota, matrika N 1780–1790, folio 112, zápis č. 14"
        t.findings?.items.insert(WidgetData.Finding(kind: "fact", fact: "birth", text: long, at: SampleData.at(14, 31)), at: 0)
        let m = WidgetModelBuilder.build(index: .ok(SampleData.index()), tree: .ok(t), settings: WidgetSettings(treeKey: SampleData.treeKey),
                                         now: SampleData.at(14, 35), timeZone: SampleData.timeZone)
        XCTAssertEqual(m.rows.first?.text, long)
        XCTAssertEqual(m.rows.first?.kindLabel, "Narození")
        XCTAssertEqual(m.rows.first?.time, "14:31")
    }
}

final class LanguageTests: XCTestCase {
    func testLanguageCodes() {
        XCTAssertEqual(Lang(code: "cs"), .cs)
        XCTAssertEqual(Lang(code: "cs-CZ"), .cs)
        XCTAssertEqual(Lang(code: "de_AT"), .de)
        XCTAssertEqual(Lang(code: "EN"), .en)
        XCTAssertEqual(Lang(code: "sk"), .en, "other languages → English")
        XCTAssertEqual(Lang(code: nil), .en)
    }

    func testChoiceOverridesResearch() {
        XCTAssertEqual(LanguageChoice.auto.resolve(researchLang: "de"), .de)
        XCTAssertEqual(LanguageChoice.cs.resolve(researchLang: "de"), .cs)
        XCTAssertEqual(LanguageChoice.en.resolve(researchLang: "cs"), .en)
        XCTAssertEqual(LanguageChoice.de.resolve(researchLang: nil), .de)
    }

    func testWidgetFollowsResearchLanguage() {
        let en = SampleData.model(.a, lang: .en)
        XCTAssertEqual(en.lang, .en)
        XCTAssertEqual(en.statusText, "Working")
        XCTAssertEqual(en.asOfHeader, "as of 14:32")
        XCTAssertEqual(en.lines.first?.since, "since 9:40")
        let de = SampleData.model(.f, lang: .de)
        XCTAssertEqual(de.statusText, "Forschung läuft nicht")
        XCTAssertEqual(de.statusSentence, "zuletzt gelaufen heute um 11:20")
        XCTAssertEqual(de.findingsHeader, "Funde bis 11:20")

        // The host app choice wins over the research language.
        let input = SampleData.inputs(.a, lang: .cs)
        let forced = WidgetModelBuilder.build(index: input.index, tree: input.tree,
                                              settings: WidgetSettings(treeKey: SampleData.treeKey, language: .de),
                                              now: SampleData.at(14, 35), timeZone: SampleData.timeZone)
        XCTAssertEqual(forced.statusText, "Arbeitet")
        XCTAssertEqual(forced.asOfHeader, "Stand 14:32")
    }

    func testCzechPlurals() {
        let L = L10n(lang: .cs)
        XCTAssertEqual(L.linesCount(2), "2 linie")
        XCTAssertEqual(L.linesCount(5), "5 linií")
        XCTAssertEqual(L.appRowWidgets(0), "bez widgetu")
        XCTAssertEqual(L.appRowWidgets(1), "1 widget")
        XCTAssertEqual(L.appRowWidgets(2), "2 widgety")
        XCTAssertEqual(L.appRowWidgets(5), "5 widgetů")
    }

    func testEveryStateHasTextsInAllLanguages() {
        for lang in Lang.allCases {
            for s in SampleData.State.allCases {
                let m = SampleData.model(s, lang: lang)
                if let msg = m.message {
                    XCTAssertFalse(msg.title.isEmpty)
                    XCTAssertFalse(msg.body.isEmpty)
                } else {
                    XCTAssertFalse(m.statusText.isEmpty, "\(lang) \(s)")
                    XCTAssertFalse(m.findingsHeader.isEmpty, "\(lang) \(s)")
                }
            }
        }
    }

    /// Gallery and edit panel texts follow the system language from the string catalog (§6, 6b).
    func testPanelCatalogHasAllLanguages() throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "Localizable", withExtension: "xcstrings")
            ?? Bundle(for: Self.self).url(forResource: "Localizable", withExtension: "strings", subdirectory: nil, localization: "cs"),
            "string catalog in the bundle")
        if url.pathExtension == "xcstrings" {
            let json = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
            let strings = try XCTUnwrap(json?["strings"] as? [String: [String: Any]])
            for key in ["widget.name", "widget.description", "intent.research", "intent.hideNames", "intent.findings",
                        "findings.last24h", "findings.sinceOpened", "research.notRunning"] {
                let locs = try XCTUnwrap(strings[key]?["localizations"] as? [String: Any], key)
                XCTAssertEqual(Set(locs.keys), ["cs", "en", "de"], key)
            }
        } else {
            let cs = Bundle(for: Self.self).localizedString(forKey: "widget.name", value: nil, table: nil)
            XCTAssertFalse(cs.isEmpty)
        }
    }
}

final class TimeTests: XCTestCase {
    private func tt(_ lang: Lang = .cs, now: Date = SampleData.at(14, 35)) -> TimeText {
        TimeText(lang: lang, now: now, timeZone: SampleData.timeZone)
    }

    func testAbsoluteTimesComeFromData() {
        // The header shows the data time whatever the clock says.
        for minute in [33, 40, 46] {
            let input = SampleData.inputs(.a)
            let m = WidgetModelBuilder.build(index: input.index, tree: input.tree, settings: WidgetSettings(treeKey: SampleData.treeKey),
                                             now: SampleData.at(14, minute), timeZone: SampleData.timeZone)
            XCTAssertEqual(m.asOfHeader, "stav 14:32")
            XCTAssertEqual(m.lines.first?.since, "od 9:40")
        }
    }

    func testRowTimes() {
        XCTAssertEqual(tt().rowTime(SampleData.at(9, 5)), "9:05")
        XCTAssertEqual(tt().rowTime(SampleData.at(21, 10, day: 25)), "včera")
        XCTAssertEqual(tt(.en).rowTime(SampleData.at(21, 10, day: 25)), "yesterday")
        XCTAssertEqual(tt(.de).rowTime(SampleData.at(21, 10, day: 25)), "gestern")
        XCTAssertEqual(tt().rowTime(SampleData.at(10, 0, day: 24)), "24. 10.")
        XCTAssertEqual(tt(.en).rowTime(SampleData.at(10, 0, day: 24)), "24 Oct")
        XCTAssertEqual(tt(.de).rowTime(SampleData.at(10, 0, day: 24)), "24.10.")
    }

    func testDayAndTime() {
        XCTAssertEqual(tt().dayAndTime(SampleData.at(11, 20)), "dnes v 11:20")
        XCTAssertEqual(tt(.en).dayAndTime(SampleData.at(21, 10, day: 25)), "yesterday at 21:10")
        XCTAssertEqual(tt().dayAndTimeShort(SampleData.at(21, 10, day: 25)), "včera 21:10")
        XCTAssertEqual(tt().clockOrDate(SampleData.at(9, 40, day: 24)), "24. 10. 9:40")
    }

    func testRelativeTimesFollowTheEntryTime() {
        XCTAssertEqual(tt().ago(SampleData.at(14, 30)), "5 min")
        XCTAssertEqual(tt(now: SampleData.at(16, 35)).ago(SampleData.at(14, 30)), "2 h")
        XCTAssertEqual(tt(.de).ago(SampleData.at(14, 30)), "5 Min.")
        XCTAssertNil(tt(now: SampleData.at(15, 0, day: 27)).ago(SampleData.at(14, 30)))
        XCTAssertEqual(tt(now: SampleData.at(15, 0, day: 27)).lastWorked(SampleData.at(14, 30)), "naposledy se pracovalo včera v 14:30")
        XCTAssertEqual(tt(now: SampleData.at(15, 0, day: 28)).lastWorked(SampleData.at(14, 30)), "naposledy se pracovalo 26. 10. v 14:30")
    }

    func testTimeZoneOfTheMac() {
        // Data is in UTC (`Z`); it reads in the Mac's zone.
        let utc = ContractCoding.parseDate("2026-10-26T08:19:43Z")!
        XCTAssertEqual(tt().clock(utc), "9:19")
        XCTAssertEqual(TimeText(lang: .en, now: utc, timeZone: TimeZone(identifier: "America/New_York")!).clock(utc), "4:19")
    }
}

final class LinkTests: XCTestCase {
    func testRoundTrip() {
        let target = "https://stromapp.info/run/?tree=lhotakovi-ze-lhoty&x=a b#ceka"
        let link = WidgetLink.open(tree: "8766d005-3a27", url: target, label: "Narození Bořivoj Lhoták")
        XCTAssertTrue(link.url.absoluteString.hasPrefix("stromwidget://open?tree=8766d005-3a27&u=https%3A%2F%2F"))
        XCTAssertEqual(WidgetLink(url: link.url), link)
        XCTAssertEqual(WidgetLink(url: WidgetLink.app.url), .app)
        XCTAssertNil(WidgetLink(url: URL(string: "https://stromapp.info")!))
        XCTAssertNil(WidgetLink(url: URL(string: "stromwidget://open?tree=x")!), "no target")
    }

    func testOnlyWebAndStromTargets() {
        XCTAssertTrue(WidgetLink.isAllowedTarget("https://stromapp.info/run/?tree=x"))
        XCTAssertTrue(WidgetLink.isAllowedTarget("strom://tree/x"))
        XCTAssertFalse(WidgetLink.isAllowedTarget("file:///etc/passwd"))
        XCTAssertFalse(WidgetLink.isAllowedTarget("javascript:alert(1)"))
        XCTAssertFalse(WidgetLink.isAllowedTarget(""))
    }

    func testFallbacks() {
        var t = SampleData.tree(.a)
        XCTAssertEqual(WidgetLink.to("https://stromapp.info/osoba", tree: t), .open(tree: t.treeKey, url: "https://stromapp.info/osoba", label: nil))
        XCTAssertEqual(WidgetLink.to("file:///x", tree: t), .open(tree: t.treeKey, url: SampleData.base, label: nil), "tree address")
        XCTAssertEqual(WidgetLink.to(nil, tree: t), .open(tree: t.treeKey, url: SampleData.base, label: nil))
        t.openUrl = nil
        XCTAssertEqual(WidgetLink.to(nil, tree: t), .app)
    }

    func testTapTargetsInModel() {
        let m = SampleData.model(.a)
        XCTAssertEqual(m.treeLink, .open(tree: SampleData.treeKey, url: SampleData.base, label: nil))
        XCTAssertEqual(m.pendingLink, .open(tree: SampleData.treeKey, url: SampleData.base + "#ceka", label: "Čeká"))
        if case let .open(_, _, label)? = m.rows.first?.link { XCTAssertNotNil(label) } else { XCTFail("finding link") }
    }
}

final class HostModelTests: XCTestCase {
    func testRows() {
        let s = HostSnapshot.sample
        XCTAssertEqual(s.access, .ok)
        XCTAssertEqual(s.rows.count, 2)
        XCTAssertEqual(s.rows[0].running, true)
        XCTAssertEqual(s.rows[0].detail, "běží · stav 14:32 · čeština")
        XCTAssertEqual(s.rows[0].widgets, "2 widgety")
        XCTAssertEqual(s.rows[1].running, false)
        XCTAssertEqual(s.rows[1].detail, "neběží · naposledy včera 21:10 · čeština")
        XCTAssertEqual(s.rows[1].widgets, "bez widgetu")
        XCTAssertNil(s.helpURL, "no help page yet")
    }

    func testAccessStates() {
        let none = HostSnapshot.build(index: .missing, trees: [:], widgetCounts: [:], choice: .auto, now: Date(), systemLanguage: "de")
        XCTAssertEqual(none.access, .noResearch)
        XCTAssertEqual(none.lang, .de, "no research: system language")
        let empty = HostSnapshot.build(index: .ok(ResearchIndex(trees: [])), trees: [:], widgetCounts: [:], choice: .cs, now: Date())
        XCTAssertEqual(empty.access, .noResearch)
        XCTAssertEqual(empty.lang, .cs)
        let locked = HostSnapshot.build(index: .noAccess, trees: [:], widgetCounts: [:], choice: .auto, now: Date())
        XCTAssertEqual(locked.access, .noAccess)
        XCTAssertTrue(locked.rows.isEmpty)
    }
}
