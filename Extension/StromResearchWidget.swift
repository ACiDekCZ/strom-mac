import SwiftUI
import WidgetKit

struct ResearchEntry: TimelineEntry {
    var date: Date
    var model: WidgetModel
    var redacted = false
}

struct Provider: AppIntentTimelineProvider {
    static let refreshPolicyInterval: TimeInterval = 5 * 60

    func placeholder(in context: Context) -> ResearchEntry {
        ResearchEntry(date: .now, model: Self.sampleModel(), redacted: true)
    }

    func snapshot(for configuration: SelectResearchIntent, in context: Context) async -> ResearchEntry {
        // Gallery: made-up sample data (state a). A placed widget shows its real data.
        if context.isPreview {
            return ResearchEntry(date: .now, model: Self.sampleModel())
        }
        return entry(for: configuration, at: .now)
    }

    func timeline(for configuration: SelectResearchIntent, in context: Context) async -> Timeline<ResearchEntry> {
        let now = Date()
        var entries = [entry(for: configuration, at: now)]
        // End of a pause and „údaje starší než 15 min“ on time even without a reload (§0 Obnova).
        let tree = configuration.research.map { ResearchStore.standard.loadTree($0.id) }
        if let data = tree?.value {
            entries += WidgetModelBuilder.entryDates(data, now: now).map { entry(for: configuration, at: $0) }
        }
        return Timeline(entries: entries, policy: .after(now.addingTimeInterval(Self.refreshPolicyInterval)))
    }

    private func entry(for configuration: SelectResearchIntent, at date: Date) -> ResearchEntry {
        let store = ResearchStore.standard
        let index = store.loadIndex()
        let key = configuration.research?.id
        let tree = key.map { store.loadTree($0) }
        let settings = WidgetSettings(treeKey: key, treeName: configuration.research?.name, hideNames: configuration.hideNames,
                                      findingsWindow: configuration.findings.choice, language: LanguageChoice.stored)
        return ResearchEntry(date: date, model: WidgetModelBuilder.build(index: index, tree: tree, settings: settings, now: date))
    }

    static func sampleModel() -> WidgetModel {
        let lang = Lang(code: Locale.preferredLanguages.first)
        let tree = SampleData.tree(.a, lang: lang)
        let now = Date()
        // Shift the sample so its times read as today.
        let shifted = shift(tree, by: now.timeIntervalSince(SampleData.now(for: .a)))
        return WidgetModelBuilder.build(index: .ok(SampleData.index(lang: lang)), tree: .ok(shifted),
                                        settings: WidgetSettings(treeKey: SampleData.treeKey), now: now)
    }

    private static func shift(_ d: WidgetData, by t: TimeInterval) -> WidgetData {
        var d = d
        d.generatedAt += t
        d.lastActiveAt = d.lastActiveAt.map { $0 + t }
        if var now = d.now {
            now.lastWorkedAt = now.lastWorkedAt.map { $0 + t }
            now.lines = now.lines.map { var l = $0; l.since = l.since.map { $0 + t }; l.pausedUntil = l.pausedUntil.map { $0 + t }; return l }
            d.now = now
        }
        if var findings = d.findings {
            findings.items = findings.items.map { var f = $0; f.at += t; return f }
            findings.sinceStromOpenedAt = findings.sinceStromOpenedAt.map { $0 + t }
            d.findings = findings
        }
        return d
    }
}

struct StromResearchEntryView: View {
    var entry: ResearchEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        StromWidgetView(model: entry.model, family: StromFamily(family))
            .environment(\.stromRenderMode, mode)
            .widgetURL(entry.model.treeLink.url)
            .redacted(reason: entry.redacted ? .placeholder : [])
            .containerBackground(for: .widget) { Palette.forScheme(scheme).bg }
    }

    private var mode: StromRenderMode {
        switch renderingMode {
        case .vibrant: return .vibrant
        case .accented: return .accented
        default: return .fullColor
        }
    }
}

struct StromResearchWidget: Widget {
    let kind = WidgetKind.research

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectResearchIntent.self, provider: Provider()) { entry in
            StromResearchEntryView(entry: entry)
        }
        .configurationDisplayName("widget.name")
        .description("widget.description")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
    }
}

@main
struct StromWidgetBundle: WidgetBundle {
    var body: some Widget {
        StromResearchWidget()
    }
}
