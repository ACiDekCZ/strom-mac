import Foundation

/// What the host window shows (§8), built from the research folder and the placed widgets.
struct HostSnapshot: Equatable {
    enum Access: Equatable { case ok, noResearch, noAccess }

    struct Row: Equatable, Identifiable {
        var id: String
        var name: String
        var running: Bool
        var detail: String
        var widgets: String
    }

    var lang: Lang
    var access: Access
    var rows: [Row]
    var languageChoice: LanguageChoice
    /// Language the „Podle výzkumu“ option resolves to, for its label.
    var autoLanguage: Lang
    /// Help page of the widget; hidden while there is none (ZADANI_VYZKUM, question 7).
    var helpURL: URL?

    static func build(index: FileResult<ResearchIndex>, trees: [String: WidgetData], widgetCounts: [String: Int],
                      choice: LanguageChoice, now: Date, timeZone: TimeZone = .current,
                      systemLanguage: String? = Locale.preferredLanguages.first) -> HostSnapshot {
        let list = index.value?.trees ?? []
        let newest = index.value?.defaultTree
        let autoLang = Lang(code: newest?.lang ?? systemLanguage)
        let lang = choice.resolve(researchLang: newest?.lang ?? systemLanguage)
        let L = lang.strings
        let tt = TimeText(lang: lang, now: now, timeZone: timeZone)

        let access: Access
        switch index {
        case .noAccess: access = .noAccess
        case .ok where !list.isEmpty: access = .ok
        case .outdated: access = .ok
        default: access = .noResearch
        }

        let rows = list.map { t -> Row in
            let data = trees[t.treeKey]
            let running = data?.running ?? t.running ?? false
            let treeLang = L.languageName(Lang(code: data?.lang ?? t.lang))
            let detail: String
            if running, let at = data?.generatedAt ?? t.generatedAt {
                detail = L.appRowRunning(tt.clockOrDate(at), treeLang)
            } else if let at = data?.lastActiveAt ?? t.lastActiveAt ?? data?.generatedAt ?? t.generatedAt {
                detail = running ? L.appRowRunning(tt.clockOrDate(at), treeLang) : L.appRowStopped(tt.dayAndTimeShort(at), treeLang)
            } else {
                detail = treeLang
            }
            return Row(id: t.treeKey, name: t.treeName, running: running, detail: detail,
                       widgets: L.appRowWidgets(widgetCounts[t.treeKey] ?? 0))
        }
        return HostSnapshot(lang: lang, access: access, rows: access == .ok ? rows : [], languageChoice: choice,
                            autoLanguage: autoLang, helpURL: nil)
    }

    static var sample: HostSnapshot {
        let idx = SampleData.index()
        let a = SampleData.tree(.a)
        var b = SampleData.tree(.f)
        b.treeKey = SampleData.otherTreeKey
        b.treeName = SampleData.treeName(SampleData.otherTreeKey)
        b.lastActiveAt = SampleData.at(21, 10, day: 25)
        return build(index: .ok(idx), trees: [a.treeKey: a, b.treeKey: b], widgetCounts: [SampleData.treeKey: 2],
                     choice: .auto, now: SampleData.now(for: .a), timeZone: SampleData.timeZone)
    }
}
