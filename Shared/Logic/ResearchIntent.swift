import AppIntents
import WidgetKit

/// A research tree on this Mac, offered in the widget's edit panel (§6).
struct ResearchEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = TypeDisplayRepresentation(name: "intent.research")
    static var defaultQuery = ResearchQuery()

    var id: String
    var name: String
    var running: Bool

    var displayRepresentation: DisplayRepresentation {
        running
            ? DisplayRepresentation(title: "\(name)")
            : DisplayRepresentation(title: "\(name)", subtitle: "research.notRunning")
    }

    init(_ tree: ResearchIndex.Tree) {
        id = tree.treeKey
        name = tree.treeName
        running = tree.running ?? true
    }
}

struct ResearchQuery: EntityQuery {
    private func trees() -> [ResearchIndex.Tree] {
        ResearchStore.standard.loadIndex().value?.trees ?? []
    }

    func entities(for identifiers: [ResearchEntity.ID]) async throws -> [ResearchEntity] {
        let all = trees()
        return identifiers.compactMap { id in all.first { $0.treeKey == id }.map(ResearchEntity.init) }
    }

    func suggestedEntities() async throws -> [ResearchEntity] {
        trees().map(ResearchEntity.init)
    }

    /// Only tree, otherwise the most recently active one.
    func defaultResult() async -> ResearchEntity? {
        ResearchStore.standard.loadIndex().value?.defaultTree.map(ResearchEntity.init)
    }
}

enum FindingsWindow: String, AppEnum {
    case last24h, sinceStromOpened

    static var typeDisplayRepresentation: TypeDisplayRepresentation = TypeDisplayRepresentation(name: "intent.findings")
    static var caseDisplayRepresentations: [FindingsWindow: DisplayRepresentation] = [
        .last24h: DisplayRepresentation(title: "findings.last24h"),
        .sinceStromOpened: DisplayRepresentation(title: "findings.sinceOpened"),
    ]

    var choice: FindingsWindowChoice { self == .last24h ? .last24h : .sinceStromOpened }
}

/// Widget configuration: three rows in the system edit panel, nothing custom (§6).
struct SelectResearchIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "widget.name"
    static var description = IntentDescription("widget.description")

    @Parameter(title: "intent.research")
    var research: ResearchEntity?

    @Parameter(title: "intent.hideNames", default: false)
    var hideNames: Bool

    @Parameter(title: "intent.findings", default: .last24h)
    var findings: FindingsWindow

    init() {}

    init(research: ResearchEntity?, hideNames: Bool = false, findings: FindingsWindow = .last24h) {
        self.research = research
        self.hideNames = hideNames
        self.findings = findings
    }
}
