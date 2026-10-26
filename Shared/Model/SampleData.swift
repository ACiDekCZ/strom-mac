import Foundation

/// Made-up sample research (Lhotákovi ze Lhoty) for the gallery, placeholders, previews and tests.
/// Mirrors the sample data of the design (`Widget.dc.html`: LINES, FIND, PEND). Never real names.
enum SampleData {
    /// Design states a–k (§4).
    enum State: String, CaseIterable {
        case a, b, c, d, e, f, g, h, i, j, k
    }

    static let treeKey = "lhotakovi-lhota"
    static let otherTreeKey = "lhotakovi-morava"
    static let timeZone = TimeZone(identifier: "Europe/Prague")!

    /// 26. 10. 2026 at the given local time (Prague).
    static func at(_ h: Int, _ m: Int, day: Int = 26) -> Date {
        var c = DateComponents()
        c.year = 2026; c.month = 10; c.day = day; c.hour = h; c.minute = m
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        return cal.date(from: c)!
    }

    static let generatedAt = at(14, 32)

    /// „Now“ of a timeline entry for each state (k: 20 min after the data).
    static func now(for state: State) -> Date {
        state == .k ? at(14, 52) : at(14, 35)
    }

    private struct LineText { var dir: WidgetData.Line.Direction; var title, anon, task: String; var since: Date }
    private struct FindText { var kind: String; var fact: String?; var resolved: String?; var text, anon: String; var at: Date }

    private static func lines(_ lang: Lang) -> [LineText] {
        switch lang {
        case .cs: return [
            LineText(dir: .up, title: "Předci Bořivoje Lhotáka", anon: "Předci osoby (1784)", task: "Hledat křest v matrice Lhota 1780–1790", since: at(9, 40)),
            LineText(dir: .down, title: "Potomci Dobromily Lhotákové", anon: "Potomci osoby (1762)", task: "Projít sňatky dětí, Lhota 1805–1830", since: at(11, 15)),
            LineText(dir: .person, title: "Kdo byl otec Dobromily", anon: "Otec osoby (1762)", task: "Porovnat dva zápisy křtu z roku 1762", since: at(12, 2))]
        case .en: return [
            LineText(dir: .up, title: "Ancestors of Bořivoj Lhoták", anon: "Ancestors of a person (1784)", task: "Search baptisms in the Lhota register 1780–1790", since: at(9, 40)),
            LineText(dir: .down, title: "Descendants of Dobromila Lhotáková", anon: "Descendants of a person (1762)", task: "Go through the children’s marriages, Lhota 1805–1830", since: at(11, 15)),
            LineText(dir: .person, title: "Who was Dobromila’s father", anon: "Father of a person (1762)", task: "Compare two baptism entries from 1762", since: at(12, 2))]
        case .de: return [
            LineText(dir: .up, title: "Vorfahren von Bořivoj Lhoták", anon: "Vorfahren einer Person (1784)", task: "Taufe im Matrikenbuch Lhota 1780–1790 suchen", since: at(9, 40)),
            LineText(dir: .down, title: "Nachkommen von Dobromila Lhotáková", anon: "Nachkommen einer Person (1762)", task: "Heiraten der Kinder durchgehen, Lhota 1805–1830", since: at(11, 15)),
            LineText(dir: .person, title: "Wer war Dobromilas Vater", anon: "Vater einer Person (1762)", task: "Zwei Taufeinträge von 1762 vergleichen", since: at(12, 2))]
        }
    }

    private static func finds(_ lang: Lang) -> [FindText] {
        let t: [(String, String?, String?, Date)] = [
            ("person_new", nil, nil, at(13, 5)), ("fact", "birth", nil, at(12, 40)), ("source_new", nil, nil, at(12, 38)),
            ("fact", "death", nil, at(11, 52)), ("source_new", nil, nil, at(11, 50)), ("name", nil, nil, at(11, 2)),
            ("child", nil, nil, at(10, 31)), ("family_new", nil, nil, at(10, 30)), ("resolved", nil, "conflict", at(9, 58))]
        let texts: [(String, String)]
        switch lang {
        case .cs: texts = [
            ("Dobromila Lhotáková (1762–1820)", "osoba (1762–1820)"), ("Bořivoj Lhoták, 3. 5. 1784, Lhota", "osoba, 3. 5. 1784, Lhota"),
            ("Matrika N 1780–1795, Lhota", "Matrika N 1780–1795, Lhota"), ("Božetěch Lhoták, 14. 2. 1811, Lhota", "osoba, 14. 2. 1811, Lhota"),
            ("Matrika Z 1800–1830, Lhota", "Matrika Z 1800–1830, Lhota"), ("Bořivoj Lhoták, též Borziwoj Lhotak", "osoba, jiný tvar jména"),
            ("Anna Lhotáková (1787), dcera Božetěcha a Dobromily", "osoba (1787), dítě v rodině"), ("Božetěch Lhoták a Dobromila Lhotáková", "rodina, sňatek 1783"),
            ("datum sňatku Božetěcha a Dobromily", "datum sňatku v rodině")]
        case .en: texts = [
            ("Dobromila Lhotáková (1762–1820)", "person (1762–1820)"), ("Bořivoj Lhoták, 3 May 1784, Lhota", "person, 3 May 1784, Lhota"),
            ("Birth register 1780–1795, Lhota", "Birth register 1780–1795, Lhota"), ("Božetěch Lhoták, 14 Feb 1811, Lhota", "person, 14 Feb 1811, Lhota"),
            ("Death register 1800–1830, Lhota", "Death register 1800–1830, Lhota"), ("Bořivoj Lhoták, also Borziwoj Lhotak", "person, another form of the name"),
            ("Anna Lhotáková (1787), daughter of Božetěch and Dobromila", "person (1787), child in a family"), ("Božetěch Lhoták and Dobromila Lhotáková", "family, marriage 1783"),
            ("marriage date of Božetěch and Dobromila", "marriage date in a family")]
        case .de: texts = [
            ("Dobromila Lhotáková (1762–1820)", "Person (1762–1820)"), ("Bořivoj Lhoták, 3. 5. 1784, Lhota", "Person, 3. 5. 1784, Lhota"),
            ("Geburtsmatrik 1780–1795, Lhota", "Geburtsmatrik 1780–1795, Lhota"), ("Božetěch Lhoták, 14. 2. 1811, Lhota", "Person, 14. 2. 1811, Lhota"),
            ("Sterbematrik 1800–1830, Lhota", "Sterbematrik 1800–1830, Lhota"), ("Bořivoj Lhoták, auch Borziwoj Lhotak", "Person, andere Namensform"),
            ("Anna Lhotáková (1787), Tochter von Božetěch und Dobromila", "Person (1787), Kind in einer Familie"), ("Božetěch Lhoták und Dobromila Lhotáková", "Familie, Heirat 1783"),
            ("Heiratsdatum von Božetěch und Dobromila", "Heiratsdatum in einer Familie")]
        }
        return zip(t, texts).map { FindText(kind: $0.0, fact: $0.1, resolved: $0.2, text: $1.0, anon: $1.1, at: $0.3) }
    }

    private static func pendingTexts(_ lang: Lang) -> [WidgetData.PendingItem] {
        switch lang {
        case .cs: return [WidgetData.PendingItem(text: "Rozhodnout rozpor: dvě data narození", textNoNames: "Rozhodnout rozpor: dvě data narození"),
                          WidgetData.PendingItem(text: "Vybrat pramen: dva zápisy křtu Dobromily (1762)", textNoNames: "Vybrat pramen: dva zápisy křtu osoby (1762)")]
        case .en: return [WidgetData.PendingItem(text: "Decide conflict: two birth dates", textNoNames: "Decide conflict: two birth dates"),
                          WidgetData.PendingItem(text: "Choose source: two baptism entries for Dobromila (1762)", textNoNames: "Choose source: two baptism entries for a person (1762)")]
        case .de: return [WidgetData.PendingItem(text: "Widerspruch entscheiden: zwei Geburtsdaten", textNoNames: "Widerspruch entscheiden: zwei Geburtsdaten"),
                          WidgetData.PendingItem(text: "Quelle wählen: zwei Taufeinträge für Dobromila (1762)", textNoNames: "Quelle wählen: zwei Taufeinträge für eine Person (1762)")]
        }
    }

    static let base = "https://stromapp.info/?tree=lhotakovi-lhota"

    static func treeName(_ key: String = treeKey) -> String {
        key == otherTreeKey ? "Lhotákovi (Morava)" : "Lhotákovi ze Lhoty"
    }

    /// Tree file for a design state (data states a–f, k; for g–j the data of state a).
    static func tree(_ state: State, lang: Lang = .cs) -> WidgetData {
        let L = lines(lang)
        func line(_ i: Int, paused: Bool = false) -> WidgetData.Line {
            WidgetData.Line(dir: L[i].dir, title: L[i].title, titleNoNames: L[i].anon, task: L[i].task, since: L[i].since,
                            pausedUntil: paused ? at(14, 30) : nil, openUrl: base)
        }
        var lineList: [WidgetData.Line] = [line(0)]
        var running = true
        var lastActive = generatedAt
        var withFinds = true
        var withPending = true
        switch state {
        case .b: lineList = [line(0), line(1), line(2, paused: true)]
        case .c: lineList = [line(0, paused: true), line(1, paused: true)]
        case .d: lineList = []
        case .e: withFinds = false; withPending = false
        case .f: lineList = []; running = false; lastActive = at(11, 20)
        default: break
        }
        let items = withFinds ? finds(lang).map {
            WidgetData.Finding(kind: $0.kind, fact: $0.fact, resolved: $0.resolved, text: $0.text, textNoNames: $0.anon,
                               at: $0.at, openUrl: base)
        }.filter { $0.at <= lastActive } : []
        return WidgetData(
            schemaVersion: 1, treeKey: treeKey, treeName: treeName(), lang: lang.rawValue,
            generatedAt: state == .f ? lastActive : generatedAt, running: running, lastActiveAt: lastActive, openUrl: base,
            now: .init(lines: lineList, lastWorkedAt: at(12, 30)),
            findings: .init(windowStart: generatedAt.addingTimeInterval(-24 * 3600), sinceStromOpenedAt: at(8, 55), items: items),
            pending: withPending ? .init(count: 2, items: pendingTexts(lang), openUrl: base + "#ceka") : .init(count: 0, items: [], openUrl: base + "#ceka"),
            stats24h: withFinds ? .init(persons: 3, sources: 5, saves: 12) : .init(persons: 0, sources: 0, saves: 0))
    }

    static func index(lang: Lang = .cs) -> ResearchIndex {
        ResearchIndex(trees: [
            .init(treeKey: treeKey, treeName: treeName(), lang: lang.rawValue, running: true, lastActiveAt: generatedAt, generatedAt: generatedAt),
            .init(treeKey: otherTreeKey, treeName: treeName(otherTreeKey), lang: lang.rawValue, running: false,
                  lastActiveAt: at(21, 10, day: 25), generatedAt: at(21, 10, day: 25))])
    }

    /// Store results for a design state, as the widget would read them.
    static func inputs(_ state: State, lang: Lang = .cs) -> (index: FileResult<ResearchIndex>, tree: FileResult<WidgetData>?, key: String?) {
        switch state {
        case .g: return (.noAccess, nil, treeKey)
        case .h: return (.ok(index(lang: lang)), .outdated, treeKey)
        case .i: return (.ok(ResearchIndex(trees: [])), nil, nil)
        case .j: return (.ok(index(lang: lang)), nil, nil)
        default: return (.ok(index(lang: lang)), .ok(tree(state, lang: lang)), treeKey)
        }
    }

    static func model(_ state: State, lang: Lang = .cs, hideNames: Bool = false) -> WidgetModel {
        let input = inputs(state, lang: lang)
        // States g–j carry no research language; the design shows them in the language of the frame.
        let choice: LanguageChoice = [.g, .h, .i, .j].contains(state) ? LanguageChoice(rawValue: lang.rawValue)! : .auto
        return WidgetModelBuilder.build(index: input.index, tree: input.tree,
                                        settings: WidgetSettings(treeKey: input.key, treeName: input.key.map { treeName($0) }, hideNames: hideNames, language: choice),
                                        now: now(for: state), timeZone: timeZone)
    }
}
