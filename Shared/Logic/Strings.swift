import Foundation

/// Language of the widget and of the host app window: the research language unless overridden (§0 Jazyk).
enum Lang: String, CaseIterable, Codable {
    case cs, en, de

    /// `cs`, `en`, `de` (also `cs-CZ`, `de_AT` …); anything else → `en`.
    init(code: String?) {
        let base = (code ?? "").lowercased().split(whereSeparator: { $0 == "-" || $0 == "_" }).first.map(String.init) ?? ""
        self = Lang(rawValue: base) ?? .en
    }

    var locale: Locale { Locale(identifier: rawValue) }
    var strings: L10n { L10n(lang: self) }
}

/// User choice in the host app: follow the research, or a fixed language (stored in the App Group).
enum LanguageChoice: String, CaseIterable, Codable {
    case auto, cs, en, de

    static let defaultsKey = "language"

    func resolve(researchLang: String?) -> Lang {
        switch self {
        case .auto: return Lang(code: researchLang)
        case .cs: return .cs
        case .en: return .en
        case .de: return .de
        }
    }

    static var stored: LanguageChoice {
        AppGroup.defaults?.string(forKey: defaultsKey).flatMap(LanguageChoice.init(rawValue:)) ?? .auto
    }

    func store() {
        AppGroup.defaults?.set(rawValue, forKey: Self.defaultsKey)
    }
}

/// Texts shown in the research language (ZADANI_DEV „Texty“). Widget gallery and the edit panel
/// follow the system language and live in `Localizable.xcstrings` of the extension instead.
struct L10n {
    let lang: Lang

    private func t(_ cs: String, _ en: String, _ de: String) -> String {
        switch lang {
        case .cs: return cs
        case .en: return en
        case .de: return de
        }
    }

    /// Czech plural: 1 / 2–4 / 5+ (and 0).
    private func csPlural(_ n: Int, _ one: String, _ few: String, _ many: String) -> String {
        n == 1 ? one : (2...4).contains(n) ? few : many
    }

    // MARK: Status and sections

    var statusWorking: String { t("Pracuje se", "Working", "Arbeitet") }
    var statusPaused: String { t("Pauza", "Paused", "Pause") }
    var statusIdle: String { t("Teď se nepracuje", "Not working right now", "Gerade keine Arbeit") }
    var statusIdleShort: String { t("Nepracuje se", "Idle", "Ruht") }
    var statusOffline: String { t("Výzkum neběží", "Research not running", "Forschung läuft nicht") }
    var statusOfflineShort: String { t("Neběží", "Not running", "Läuft nicht") }
    func statusStale(_ time: String) -> String { t("Stav z \(time)", "Status as of \(time)", "Stand von \(time)") }
    func statusStaleShort(_ time: String) -> String { t("Stav z \(time)", "As of \(time)", "Stand \(time)") }

    func subPauseUntil(_ time: String) -> String { t("pokračuje v \(time)", "resumes at \(time)", "geht um \(time) weiter") }
    func subLastWorked(_ ago: String) -> String { t("naposledy se pracovalo před \(ago)", "last worked \(ago) ago", "zuletzt gearbeitet vor \(ago)") }
    /// Variant for more than a day ago, with an absolute time („včera v 21:10“).
    func subLastWorkedAt(_ when: String) -> String { t("naposledy se pracovalo \(when)", "last worked \(when)", "zuletzt gearbeitet \(when)") }
    func subLastRan(_ when: String) -> String { t("naposledy běžel \(when)", "last ran \(when)", "zuletzt gelaufen \(when)") }
    var subStale: String { t("novější údaje zatím nepřišly", "no newer data yet", "noch keine neueren Daten") }

    func lineSince(_ time: String) -> String { t("od \(time)", "since \(time)", "seit \(time)") }
    func linePaused(_ time: String) -> String { t("pauza · pokračuje v \(time)", "paused · resumes at \(time)", "Pause · geht um \(time) weiter") }
    func linePausedShort(_ time: String) -> String { t("pauza do \(time)", "paused until \(time)", "Pause bis \(time)") }
    var linePausedNoTime: String { t("pauza", "paused", "Pause") }

    func linesCount(_ n: Int) -> String {
        switch lang {
        case .cs: return "\(n) " + csPlural(n, "linie", "linie", "linií")
        case .en: return "\(n) " + (n == 1 ? "line" : "lines")
        case .de: return "\(n) " + (n == 1 ? "Linie" : "Linien")
        }
    }

    func linesMore(_ n: Int) -> String {
        switch lang {
        case .cs: return "a \(n) " + csPlural(n, "další linie", "další linie", "dalších linií")
        case .en: return "and \(n) more " + (n == 1 ? "line" : "lines")
        case .de: return "und \(n) weitere " + (n == 1 ? "Linie" : "Linien")
        }
    }

    func headerAsOf(_ time: String) -> String { t("stav \(time)", "as of \(time)", "Stand \(time)") }
    var headerOld: String { t(" · starší než 15 min", " · over 15 min old", " · älter als 15 Min.") }

    var sectionNow: String { t("Teď", "Now", "Jetzt") }
    var sectionFindings: String { t("Nálezy · 24 h", "Findings · 24 h", "Funde · 24 Std.") }
    func sectionFindingsSince(_ time: String) -> String { t("Nálezy · od \(time)", "Findings · since \(time)", "Funde · seit \(time)") }
    func sectionFindingsUntil(_ time: String) -> String { t("Nálezy do \(time)", "Findings until \(time)", "Funde bis \(time)") }
    var findingsNone: String { t("Za 24 h nic nového", "Nothing new in 24 h", "Nichts Neues in 24 Std.") }
    var findingsNoneSince: String { t("Od otevření Stromu nic nového", "Nothing new since Strom was opened", "Nichts Neues seit dem Öffnen von Strom") }

    func findingsMore(_ n: Int) -> String {
        switch lang {
        case .cs: return "a \(n) " + csPlural(n, "další", "další", "dalších")
        case .en: return "and \(n) more"
        case .de: return "und \(n) weitere"
        }
    }

    var sectionPending: String { t("Čeká", "Waiting", "Wartet") }
    func pendingPill(_ n: Int) -> String { t("čeká \(n)", "\(n) waiting", "\(n) wartet") }
    var pendingNone: String { t("Nic nečeká", "Nothing waiting", "Nichts wartet") }
    var pendingNote: String { t("Vyřizuje se v aplikaci Strom nebo v terminálu.", "Handled in the Strom app or in Terminal.", "Erledigt wird es in der Strom-App oder im Terminal.") }
    /// Pending item whose text has names and no name-free variant was supplied.
    /// Stand-in for a pending item without a name-free text: says nothing about what it waits for.
    var pendingAnon: String { t("Položka", "Item", "Eintrag") }

    var sectionStats: String { t("Za 24 h", "Last 24 h", "Letzte 24 Std.") }
    var statsPersons: String { t("osoby", "people", "Personen") }
    var statsSources: String { t("pramenů", "sources", "Quellen") }
    var statsSaves: String { t("zápisů", "entries", "Einträge") }

    var smallFindings: String { t("nálezy · 24 h", "found · 24 h", "Funde · 24 h") }
    func smallFindingsSince(_ time: String) -> String { t("nálezy · od \(time)", "found · since \(time)", "Funde · seit \(time)") }
    var smallPending: String { t("čeká", "waiting", "wartet") }

    var treeAnon: String { t("Výzkum", "Research", "Forschung") }
    var treeGeneric: String { "Strom" }
    var yesterday: String { t("včera", "yesterday", "gestern") }

    // MARK: Lines without names (fallback when the research gave no `titleNoNames`)

    func directionWord(_ dir: WidgetData.Line.Direction) -> String {
        switch dir {
        case .up: return t("Předci", "Ancestors", "Vorfahren")
        case .down: return t("Potomci", "Descendants", "Nachkommen")
        case .person: return t("Osoba nebo otázka", "Person or question", "Person oder Frage")
        }
    }

    // MARK: Groups and kinds (§5)

    func group(_ g: FindingGroup) -> String {
        switch g {
        case .persons: return t("Osoby", "People", "Personen")
        case .families: return t("Rodiny", "Families", "Familien")
        case .sources: return t("Prameny", "Sources", "Quellen")
        case .resolved: return t("Vyřešeno", "Resolved", "Gelöst")
        }
    }

    func kind(_ k: FindingKind) -> String {
        switch k {
        case .personNew: return t("Nově v rodokmenu", "New in tree", "Neu im Stammbaum")
        case .name: return t("Jméno", "Name", "Name")
        case .birth: return t("Narození", "Birth", "Geburt")
        case .baptism: return t("Křest", "Baptism", "Taufe")
        case .marriage: return t("Sňatek", "Marriage", "Heirat")
        case .death: return t("Úmrtí", "Death", "Tod")
        case .burial: return t("Pohřeb", "Burial", "Begräbnis")
        case .otherFact, .unknown: return t("Jiný údaj", "Other fact", "Andere Angabe")
        case .familyNew: return t("Nová rodina", "New family", "Neue Familie")
        case .child: return t("Dítě", "Child", "Kind")
        case .sourceNew: return t("Nový pramen", "New source", "Neue Quelle")
        case .conflictResolved: return t("Vyřešen rozpor", "Conflict resolved", "Widerspruch gelöst")
        case .hypothesisConfirmed: return t("Hypotéza potvrzena", "Hypothesis confirmed", "Hypothese bestätigt")
        case .hypothesisRejected: return t("Hypotéza vyvrácena", "Hypothesis rejected", "Hypothese verworfen")
        }
    }

    // MARK: States without data (§4 g–j)

    struct Message: Equatable {
        var title: String
        var body: String
        var bodySmall: String
        var code: String?
    }

    func message(_ m: MessageKind) -> Message {
        switch m {
        case .noAccess:
            return Message(title: t("Bez přístupu k výzkumu", "No access to research", "Kein Zugriff auf die Forschung"),
                           body: t("Widget nevidí složku výzkumu na tomto Macu. Přístup se nastavuje v aplikaci Strom Widget.",
                                   "The widget can’t see the research folder on this Mac. Access is set up in the Strom Widget app.",
                                   "Das Widget sieht den Forschungsordner auf diesem Mac nicht. Der Zugriff wird in der App Strom Widget eingerichtet."),
                           bodySmall: t("Přístup se nastavuje v aplikaci Strom Widget.", "Access is set up in Strom Widget.", "Zugriff in Strom Widget einrichten."))
        case .outdated:
            return Message(title: t("Výzkum potřebuje aktualizaci", "Research needs an update", "Forschung braucht ein Update"),
                           body: t("Tato verze výzkumu widgetu údaje nedává. Aktualizace v terminálu:",
                                   "This research version doesn’t provide widget data. Update in Terminal:",
                                   "Diese Version der Forschung liefert keine Widget-Daten. Update im Terminal:"),
                           bodySmall: t("Aktualizace v terminálu:", "Update in Terminal:", "Update im Terminal:"),
                           code: "strom update")
        case .noResearch:
            return Message(title: t("Na tomto Macu není výzkum", "No research on this Mac", "Keine Forschung auf diesem Mac"),
                           body: t("Widget ukáže výzkum, který na tomto Macu běží v terminálu.",
                                   "The widget shows research running in Terminal on this Mac.",
                                   "Das Widget zeigt die Forschung, die auf diesem Mac im Terminal läuft."),
                           bodySmall: t("Widget ukáže výzkum z terminálu tohoto Macu.", "Shows research running in Terminal.", "Zeigt die Forschung aus dem Terminal."))
        case .notSelected:
            return Message(title: t("Výzkum není vybraný", "No research selected", "Keine Forschung ausgewählt"),
                           body: t("Výběr výzkumu: pravý klik na widget → Upravit widget.",
                                   "Choosing research: right-click the widget → Edit Widget.",
                                   "Auswahl der Forschung: Rechtsklick auf das Widget → Widget bearbeiten."),
                           bodySmall: t("Pravý klik → Upravit widget.", "Right-click → Edit Widget.", "Rechtsklick → Widget bearbeiten."))
        }
    }

    // MARK: Host app (§8) and open failure (§7)

    var appName: String { "Strom Widget" }
    var appTagline: String { t("Výzkum Stromu na ploše Macu: na čem se pracuje a co se našlo.",
                               "Strom research on the Mac desktop: what is being worked on and what was found.",
                               "Strom-Forschung auf dem Mac-Schreibtisch: woran gearbeitet wird und was gefunden wurde.") }
    var appResearches: String { t("Výzkumy na tomto Macu", "Research on this Mac", "Forschung auf diesem Mac") }
    func appRowRunning(_ time: String, _ language: String) -> String { t("běží · stav \(time) · \(language)", "running · as of \(time) · \(language)", "läuft · Stand \(time) · \(language)") }
    func appRowStopped(_ when: String, _ language: String) -> String { t("neběží · naposledy \(when) · \(language)", "not running · last \(when) · \(language)", "läuft nicht · zuletzt \(when) · \(language)") }

    func appRowWidgets(_ n: Int) -> String {
        if n == 0 { return t("bez widgetu", "no widget", "kein Widget") }
        switch lang {
        case .cs: return "\(n) " + csPlural(n, "widget", "widgety", "widgetů")
        case .en: return "\(n) " + (n == 1 ? "widget" : "widgets")
        case .de: return "\(n) " + (n == 1 ? "Widget" : "Widgets")
        }
    }

    var appStartPrefix: String { t("Výzkum se spouští v terminálu příkazem", "Research is started in Terminal with", "Die Forschung startet im Terminal mit") }
    var appStartSuffix: String { t(". Data zůstávají na tomto Macu.", ". Data stays on this Mac.", ". Die Daten bleiben auf diesem Mac.") }
    var appNoneTitle: String { t("Na tomto Macu zatím není žádný výzkum", "No research on this Mac yet", "Noch keine Forschung auf diesem Mac") }
    var appNoneBodyPrefix: String { t("Widget se napojí sám, jakmile výzkum v terminálu poprvé poběží (příkaz", "The widget connects by itself once research first runs in Terminal (", "Das Widget verbindet sich selbst, sobald die Forschung zum ersten Mal im Terminal läuft (") }
    var appAccessTitle: String { t("Bez přístupu ke složce výzkumu", "No access to the research folder", "Kein Zugriff auf den Forschungsordner") }
    var appAccessBody: String { t("Strom Widget potřebuje číst složku, do které výzkum zapisuje stav.",
                                  "Strom Widget needs to read the folder where the research writes its status.",
                                  "Strom Widget muss den Ordner lesen, in den die Forschung ihren Stand schreibt.") }
    var appAccessButton: String { t("Povolit přístup…", "Allow Access…", "Zugriff erlauben …") }
    var appHowTo: String { t("Přidat widget na plochu", "Add the widget to the desktop", "Widget zum Schreibtisch hinzufügen") }
    var appSteps: [String] {
        [t("Pravý klik na prázdné místo plochy → **Upravit widgety…**", "Right-click an empty spot on the desktop → **Edit Widgets…**", "Rechtsklick auf eine freie Stelle des Schreibtischs → **Widgets bearbeiten …**"),
         t("V galerii vyhledat **Strom** a vybrat velikost.", "Search the gallery for **Strom** and pick a size.", "In der Galerie nach **Strom** suchen und eine Größe wählen."),
         t("Přetáhnout widget na plochu.", "Drag the widget onto the desktop.", "Das Widget auf den Schreibtisch ziehen."),
         t("Jiný výzkum: pravý klik na widget → **Upravit widget**.", "Other research: right-click the widget → **Edit Widget**.", "Andere Forschung: Rechtsklick auf das Widget → **Widget bearbeiten**.")]
    }
    /// Labels inside the stylised desktop picture of the how-to.
    var howToMenu: [String] { [t("Nová složka", "New Folder", "Neuer Ordner"), t("Upravit widgety…", "Edit Widgets…", "Widgets bearbeiten …"), t("Změnit pozadí…", "Change Wallpaper…", "Hintergrund ändern …")] }
    var howToSearch: String { t("Hledat:", "Search:", "Suchen:") }
    var appLanguage: String { t("Jazyk", "Language", "Sprache") }
    func appLanguageAuto(_ language: String) -> String { t("Podle výzkumu (\(language))", "Same as research (\(language))", "Wie die Forschung (\(language))") }
    var appHelp: String { t("Nápověda", "Help", "Hilfe") }
    var appUninstall: String { t("Odinstalovat…", "Uninstall…", "Deinstallieren …") }
    var uninstallTitle: String { t("Odinstalovat Strom Widget?", "Uninstall Strom Widget?", "Strom Widget deinstallieren?") }
    var uninstallBody: String { t("Widgety Stromu zmizí z plochy. Výzkum ani rodokmen se nemění. Aplikace se přesune do koše.",
                                  "Strom widgets disappear from the desktop. The research and the family tree stay unchanged. The app moves to the Trash.",
                                  "Die Strom-Widgets verschwinden vom Schreibtisch. Forschung und Stammbaum bleiben unverändert. Die App wird in den Papierkorb gelegt.") }
    var uninstallCancel: String { t("Zrušit", "Cancel", "Abbrechen") }
    var uninstallConfirm: String { t("Odinstalovat", "Uninstall", "Deinstallieren") }
    var openFailedTitle: String { t("Aplikaci Strom se nepodařilo otevřít", "The Strom app couldn’t be opened", "Die Strom-App ließ sich nicht öffnen") }
    func openFailedBody(_ what: String) -> String { t("\(what) jde otevřít i ručně, adresou v prohlížeči:", "\(what) can also be opened manually in a browser:", "\(what) lässt sich auch manuell im Browser öffnen:") }
    var openFailedWhatDefault: String { t("Výzkum", "The research", "Die Forschung") }
    var openFailedCopy: String { t("Kopírovat adresu", "Copy Address", "Adresse kopieren") }
    var openFailedClose: String { t("Zavřít", "Close", "Schließen") }

    /// Name of a language in the current language („čeština“, „Czech“, „Tschechisch“).
    func languageName(_ l: Lang) -> String {
        switch l {
        case .cs: return t("čeština", "Czech", "Tschechisch")
        case .en: return t("angličtina", "English", "Englisch")
        case .de: return t("němčina", "German", "Deutsch")
        }
    }

    /// Fixed language names in the picker (each in its own language).
    static func nativeName(_ l: Lang) -> String {
        switch l {
        case .cs: return "Čeština"
        case .en: return "English"
        case .de: return "Deutsch"
        }
    }
}
