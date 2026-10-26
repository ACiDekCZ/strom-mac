import SwiftUI
import WidgetKit

enum StromFamily: CaseIterable {
    case small, medium, large, extraLarge

    init(_ family: WidgetFamily) {
        switch family {
        case .systemSmall: self = .small
        case .systemMedium: self = .medium
        case .systemLarge: self = .large
        default: self = .extraLarge
        }
    }

    /// Frame sizes of the design (the widget itself takes `context.displaySize`).
    var designSize: CGSize {
        switch self {
        case .small: return CGSize(width: 170, height: 170)
        case .medium: return CGSize(width: 364, height: 170)
        case .large: return CGSize(width: 364, height: 382)
        case .extraLarge: return CGSize(width: 748, height: 382)
        }
    }

    var designPadding: CGFloat { self == .extraLarge ? 16 : 14 }
}

/// The widget content for every size and state. No padding: the system adds content margins.
struct StromWidgetView: View {
    var model: WidgetModel
    var family: StromFamily

    var body: some View {
        Group {
            switch family {
            case .small: SmallView(m: model)
            case .medium: MediumView(m: model)
            case .large: LargeView(m: model)
            case .extraLarge: ExtraLargeView(m: model)
            }
        }
        // `minWidth`/`minHeight` 0: content that does not fit stays at the top left (cut off at the end), not centered across the margins.
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
        .environment(\.stromLinksEnabled, family != .small)
        .environment(\.locale, model.lang.locale)
    }
}

// MARK: Header

private struct Header: View {
    var m: WidgetModel
    var markSize: CGFloat
    var fontSize: CGFloat
    var timeSize: CGFloat
    var spacing: CGFloat = 6
    var showPill = false
    /// Small widget: time only, without „stav“.
    var compactTime = false

    var body: some View {
        withInk { ink in
            HStack(spacing: spacing) {
                MarkView(size: markSize)
                Text(m.treeTitle)
                    .font(.sf(fontSize, .semibold))
                    .foregroundStyle(ink.muted)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if showPill, m.pendingCount > 0, !m.isMessage {
                    Linked(link: m.pendingLink) { PendingPill(text: m.lang.strings.pendingPill(m.pendingCount)) }
                }
                if m.isStale {
                    StatusShapeView(shape: .half, size: 7)
                }
                if let time = compactTime ? m.asOfTime : m.asOfHeader {
                    Text(time)
                        .font(.sf(timeSize).monospacedDigit())
                        .foregroundStyle(m.isStale ? ink.pauseText : ink.faint)
                        .lineLimit(1)
                        .fixedSize()
                }
            }
        }
    }
}

// MARK: States g–j

private struct MessageBlock: View {
    var m: WidgetModel
    var family: StromFamily

    var body: some View {
        withInk { ink in
            if let msg = m.message {
                switch family {
                case .small:
                    VStack(alignment: .leading, spacing: 5) {
                        Text(msg.title).font(.sf(14, .semibold)).foregroundStyle(ink.text).lineLimit(3)
                        Text(msg.bodySmall).font(.sf(11.5)).foregroundStyle(ink.muted).lineLimit(3)
                        if let code = msg.code { CodeChip(text: code, size: 11, hPad: 6, vPad: 2, corner: 5) }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
                case .medium:
                    VStack(alignment: .leading, spacing: 6) {
                        Text(msg.title).font(.sf(16, .semibold)).foregroundStyle(ink.text).lineLimit(2)
                        Text(msg.body).font(.sf(12)).foregroundStyle(ink.muted).lineLimit(3)
                        if let code = msg.code { CodeChip(text: code, size: 11.5, hPad: 7, vPad: 2, corner: 5) }
                    }
                    .frame(maxWidth: 290, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
                case .large, .extraLarge:
                    let xl = family == .extraLarge
                    VStack(alignment: .leading, spacing: 8) {
                        Spacer(minLength: 0)
                        MarkView(size: xl ? 28 : 26)
                        Text(msg.title).font(.sf(xl ? 20 : 18, .semibold)).foregroundStyle(ink.text)
                        Text(msg.body).font(.sf(xl ? 13 : 12.5)).foregroundStyle(ink.muted).fixedSize(horizontal: false, vertical: true)
                        if let code = msg.code { CodeChip(text: code, size: xl ? 12.5 : 12, hPad: 8, vPad: 3, corner: 6) }
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: xl ? 420 : .infinity, alignment: .leading)
                    .padding(.leading, xl ? 4 : 2)
                    .padding(.trailing, xl ? 0 : 8)
                    .padding(.bottom, 30)
                }
            }
        }
    }
}

// MARK: Small (§1)

private struct SmallView: View {
    var m: WidgetModel

    var body: some View {
        withInk { ink in
            VStack(alignment: .leading, spacing: 5) {
                Header(m: m, markSize: 12.5, fontSize: 11, timeSize: 10.5, spacing: 5, compactTime: true)
                if m.isMessage {
                    MessageBlock(m: m, family: .small)
                    Spacer(minLength: 0)
                } else {
                    // A line title on two lines while everything fits, if need be a little closer to the header;
                    // otherwise one line ending with „…“.
                    ViewThatFits(in: .vertical) {
                        status(ink, titleLines: 2)
                        status(ink, titleLines: 2, compact: true)
                        status(ink, titleLines: 1)
                    }
                }
            }
        }
    }

    private func status(_ ink: Ink, titleLines: Int, compact: Bool = false) -> some View {
        // The spacer alone keeps the gap above the numbers.
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    StatusShapeView(shape: m.shape, size: 10)
                    Text(m.statusShort).font(.sf(17, .semibold)).foregroundStyle(ink.text).lineLimit(1)
                }
                .padding(.top, compact ? 2 : 5)
                Text(m.lines.first?.title ?? m.statusSentence ?? "")
                    .font(.sf(12.5))
                    .foregroundStyle(ink.text)
                    .lineLimit(titleLines)
                    .fixedSize(horizontal: false, vertical: true)
                if let second = m.smallSecond {
                    Text(second)
                        .font(.sf(11))
                        .foregroundStyle(m.smallSecondIsPause ? ink.pauseText : ink.faint)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: compact ? 2 : 4)
            if m.showSmallCounts {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("\(m.rows.count)").font(.sf(26, .semibold).monospacedDigit()).foregroundStyle(ink.text)
                        Text(m.smallFindingsLabel).font(.sf(10.5)).foregroundStyle(ink.muted).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 5) {
                            Text("\(m.pendingCount)").font(.sf(26, .semibold).monospacedDigit()).foregroundStyle(ink.text)
                            if m.pendingCount > 0 {
                                Circle().fill(ink.pause).frame(width: 7, height: 7).stromAccentable()
                            }
                        }
                        Text(m.lang.strings.smallPending).font(.sf(10.5)).foregroundStyle(ink.muted).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

// MARK: Medium (§2)

private struct MediumView: View {
    var m: WidgetModel

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Header(m: m, markSize: 13, fontSize: 11.5, timeSize: 10.5, showPill: true)
            if m.isMessage {
                MessageBlock(m: m, family: .medium)
                Spacer(minLength: 0)
            } else {
                GeometryReader { geo in
                    let gap: CGFloat = 14
                    let left = (geo.size.width - gap) / 2.08
                    HStack(alignment: .top, spacing: gap) {
                        NowColumn(m: m).frame(width: left, alignment: .topLeading)
                        FindingsColumn(m: m).frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                }
            }
        }
    }

    private struct NowColumn: View {
        var m: WidgetModel
        var body: some View {
            withInk { ink in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        StatusShapeView(shape: m.shape, size: 8)
                        Text(m.statusText).font(.sf(13, .semibold)).foregroundStyle(ink.text).lineLimit(1)
                        if let n = m.linesCount {
                            Text(n).font(.sf(11)).foregroundStyle(ink.faint).lineLimit(1).fixedSize()
                        }
                    }
                    if m.lines.isEmpty, let s = m.statusSentence {
                        Text(s).font(.sf(11.5)).foregroundStyle(ink.muted).lineLimit(3)
                    }
                    ForEach(Array(m.lines.prefix(FindingsLayout.mediumLines).enumerated()), id: \.offset) { _, line in
                        Linked(link: line.link) {
                            HStack(alignment: .top, spacing: 7) {
                                GlyphTile(glyph: line.glyph, size: 18, corner: 5, fontSize: 11, weight: .regular)
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(line.title).font(.sf(12, .semibold)).foregroundStyle(ink.text).lineLimit(1)
                                    if let task = line.task {
                                        Text(task).font(.sf(11.5)).foregroundStyle(ink.text).lineLimit(1)
                                    }
                                    if let since = line.since {
                                        HStack(spacing: 5) {
                                            LineMarker(paused: line.paused)
                                            Text(since).font(.sf(10.5)).foregroundStyle(line.paused ? ink.pauseText : ink.faint).lineLimit(1)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private struct FindingsColumn: View {
        var m: WidgetModel
        var body: some View {
            withInk { ink in
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        SectionLabel(text: m.findingsHeader, lang: m.lang).frame(maxWidth: .infinity, alignment: .leading)
                        if !m.rows.isEmpty {
                            Text("\(m.rows.count)").font(.sf(11).monospacedDigit()).foregroundStyle(ink.text)
                        }
                    }
                    ForEach(Array(m.rows.prefix(FindingsLayout.mediumRows).enumerated()), id: \.offset) { _, row in
                        Linked(link: row.link) {
                            HStack(alignment: .top, spacing: 6) {
                                GlyphTile(glyph: row.glyph, size: 16, corner: 4, fontSize: 9.5).padding(.top, 1)
                                VStack(alignment: .leading, spacing: 0) {
                                    HStack(spacing: 6) {
                                        Text(row.kindLabel).font(.sf(10.5)).foregroundStyle(ink.faint).lineLimit(1)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        Text(row.time).font(.sf(10.5).monospacedDigit()).foregroundStyle(ink.faint).fixedSize()
                                    }
                                    if let text = row.text {
                                        Text(text).font(.sf(11.5)).foregroundStyle(ink.text).lineLimit(1)
                                    }
                                }
                            }
                        }
                    }
                    if let none = m.findingsNone {
                        Text(none).font(.sf(12)).foregroundStyle(ink.muted).lineLimit(2)
                    }
                }
            }
        }
    }
}

// MARK: One-line finding row (large and extra large, §5)

private struct OneLineRow: View {
    var row: WidgetModel.Row
    var xl: Bool

    var body: some View {
        withInk { ink in
            Linked(link: row.link) {
                HStack(spacing: xl ? 7 : 6) {
                    GlyphTile(glyph: row.glyph, size: xl ? 17 : 16, corner: 4, fontSize: xl ? 10 : 9.5)
                    KindTextLayout {
                        Text(row.kindLabel).font(.sf(xl ? 12 : 11.5, .semibold)).foregroundStyle(ink.text)
                            .lineLimit(1).truncationMode(.tail)
                        if let text = row.text {
                            Text(" " + text).font(.sf(xl ? 12 : 11.5)).foregroundStyle(ink.text)
                                .lineLimit(1).truncationMode(.tail)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Text(row.time).font(.sf(xl ? 11 : 10.5).monospacedDigit()).foregroundStyle(ink.faint).fixedSize()
                }
                .frame(height: xl ? 17 : 16)
            }
        }
    }
}

/// Kind word and text of a finding on one line, never wider than offered. The kind word stays whole while it leaves the
/// text at least `1 - kindShare` of the width; a longer kind word (a custom event type) ends with „…“ like the text,
/// which starts right after the kind word as drawn.
struct KindTextLayout: Layout {
    var kindShare: CGFloat = 0.75

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let widths = self.widths(proposal.width, subviews)
        let height = zip(subviews, widths).map { $0.sizeThatFits(ProposedViewSize(width: $1, height: proposal.height)).height }.max() ?? 0
        return CGSize(width: widths.reduce(0, +), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        for (view, width) in zip(subviews, widths(bounds.width, subviews)) {
            view.place(at: CGPoint(x: x, y: bounds.midY), anchor: .leading, proposal: ProposedViewSize(width: width, height: bounds.height))
            x += width
        }
    }

    private func widths(_ available: CGFloat?, _ subviews: Subviews) -> [CGFloat] {
        let ideal = subviews.map { $0.sizeThatFits(.unspecified).width }
        guard let available, ideal.reduce(0, +) > available else { return ideal }
        guard ideal.count > 1 else { return [min(ideal[0], available)] }
        let offered = min(ideal[0], max(available * kindShare, available - ideal[1]))
        // A truncated kind word is narrower than offered; the text takes the rest.
        let kind = min(subviews[0].sizeThatFits(ProposedViewSize(width: offered, height: nil)).width, offered)
        return [kind, max(available - kind, 0)]
    }
}

private struct StatsBlock: View {
    var m: WidgetModel
    var xl: Bool
    var body: some View {
        withInk { ink in
            VStack(alignment: .leading, spacing: xl ? 3 : 2) {
                SectionLabel(text: m.lang.strings.sectionStats, size: xl ? 10 : 9.5, lang: m.lang)
                HStack(alignment: .top, spacing: xl ? 8 : 6) {
                    ForEach(Array(m.stats.enumerated()), id: \.offset) { _, s in
                        VStack(alignment: .leading, spacing: 0) {
                            Text(s.value).font(.sf(xl ? 20 : 16, .semibold).monospacedDigit()).foregroundStyle(ink.text)
                            Text(s.label).font(.sf(xl ? 11 : 10)).foregroundStyle(ink.muted).lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }
}

private struct PendingRows: View {
    var items: [String]
    var xl: Bool
    var body: some View {
        withInk { ink in
            ForEach(Array(items.enumerated()), id: \.offset) { _, text in
                HStack(spacing: xl ? 7 : 6) {
                    Circle().fill(ink.pause).frame(width: 6, height: 6).stromAccentable()
                    Text(text).font(.sf(xl ? 12 : 11.5)).foregroundStyle(ink.text).lineLimit(1)
                }
            }
        }
    }
}

// MARK: Large (§3)

private struct LargeView: View {
    var m: WidgetModel

    var body: some View {
        withInk { ink in
            VStack(alignment: .leading, spacing: 9) {
                Header(m: m, markSize: 13, fontSize: 11.5, timeSize: 10.5)
                if m.isMessage {
                    MessageBlock(m: m, family: .large)
                } else {
                    nowBlock(ink)
                    RuleLine()
                    findingsBlock(ink).frame(maxHeight: .infinity, alignment: .top).clipped()
                    RuleLine()
                    GeometryReader { geo in
                        let gap: CGFloat = 14
                        let left = (geo.size.width - gap) * 1.15 / 2.15
                        HStack(alignment: .top, spacing: gap) {
                            Linked(link: m.pendingLink) {
                                VStack(alignment: .leading, spacing: 3) {
                                    SectionLabel(text: m.pendingHeader, lang: m.lang)
                                    if m.pendingItems.isEmpty {
                                        Text(m.pendingCount > 0 ? "" : m.lang.strings.pendingNone)
                                            .font(.sf(11.5)).foregroundStyle(ink.muted).lineLimit(1)
                                    } else {
                                        PendingRows(items: Array(m.pendingItems.prefix(FindingsLayout.largePending(lineCount: m.lines.count))), xl: false)
                                    }
                                }
                                .frame(width: left, alignment: .topLeading)
                            }
                            if m.showStats {
                                StatsBlock(m: m, xl: false).frame(maxWidth: .infinity, alignment: .topLeading)
                            }
                        }
                    }
                    .frame(height: 50)
                }
            }
        }
    }

    @ViewBuilder private func nowBlock(_ ink: Ink) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                SectionLabel(text: m.lang.strings.sectionNow, lang: m.lang)
                StatusShapeView(shape: m.shape, size: 8)
                Text(m.statusText).font(.sf(12, .semibold)).foregroundStyle(ink.text).lineLimit(1)
                if let n = m.linesCount {
                    Text(n).font(.sf(11)).foregroundStyle(ink.faint).lineLimit(1).fixedSize()
                }
            }
            if m.lines.isEmpty, let s = m.statusSentence {
                Text(s).font(.sf(11.5)).foregroundStyle(ink.muted).lineLimit(2)
            }
            ForEach(Array(m.lines.enumerated()), id: \.offset) { _, line in
                Linked(link: line.link) {
                    HStack(alignment: .top, spacing: 7) {
                        GlyphTile(glyph: line.glyph, size: 18, corner: 5, fontSize: 11, weight: .regular)
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(line.title).font(.sf(12, .semibold)).foregroundStyle(ink.text).lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                if let since = line.sinceShort {
                                    HStack(spacing: 4) {
                                        LineMarker(paused: line.paused)
                                        Text(since).font(.sf(10.5)).foregroundStyle(line.paused ? ink.pauseText : ink.faint).lineLimit(1)
                                    }
                                    .fixedSize()
                                }
                            }
                            if let task = line.task {
                                Text(task).font(.sf(11.5)).foregroundStyle(ink.text).lineLimit(1)
                            }
                        }
                    }
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private func findingsBlock(_ ink: Ink) -> some View {
        let grouped = FindingsLayout.grouped(m.rows, limit: FindingsLayout.largeBudget(lineCount: m.lines.count)) { $0.group }
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                SectionLabel(text: m.findingsHeader, lang: m.lang).frame(maxWidth: .infinity, alignment: .leading)
                if !m.rows.isEmpty {
                    Text("\(m.rows.count)").font(.sf(11).monospacedDigit()).foregroundStyle(ink.text)
                }
            }
            ForEach(Array(grouped.groups.enumerated()), id: \.offset) { _, g in
                HStack(alignment: .top, spacing: 6) {
                    GroupLabel(text: m.lang.strings.group(g.0), size: 9.5, lang: m.lang)
                        .frame(width: 52, height: 16, alignment: .leading)
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(Array(g.1.enumerated()), id: \.offset) { _, row in OneLineRow(row: row, xl: false) }
                    }
                }
                .padding(.top, 2)
            }
            if grouped.more > 0 {
                Text(m.lang.strings.findingsMore(grouped.more)).font(.sf(10.5)).foregroundStyle(ink.faint).padding(.leading, 58)
            }
            if let none = m.findingsNone {
                Text(none).font(.sf(12)).foregroundStyle(ink.muted)
            }
        }
    }
}

// MARK: Extra large (§3)

private struct ExtraLargeView: View {
    var m: WidgetModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Header(m: m, markSize: 14, fontSize: 12, timeSize: 11)
            if m.isMessage {
                MessageBlock(m: m, family: .extraLarge)
            } else {
                GeometryReader { geo in
                    let gap: CGFloat = 20
                    let left = (geo.size.width - gap) / 2.12
                    HStack(alignment: .top, spacing: gap) {
                        leftColumn.frame(width: left, alignment: .topLeading)
                        rightColumn.frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                }
            }
        }
    }

    private var leftColumn: some View {
        withInk { ink in
            VStack(alignment: .leading, spacing: 9) {
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 6) {
                        SectionLabel(text: m.lang.strings.sectionNow, size: 10, lang: m.lang)
                        StatusShapeView(shape: m.shape, size: 8)
                        Text(m.statusText).font(.sf(12.5, .semibold)).foregroundStyle(ink.text).lineLimit(1)
                        if let n = m.linesCount {
                            Text(n).font(.sf(11.5)).foregroundStyle(ink.faint).lineLimit(1).fixedSize()
                        }
                    }
                    if m.lines.isEmpty, let s = m.statusSentence {
                        Text(s).font(.sf(12)).foregroundStyle(ink.muted).lineLimit(2)
                    }
                    ForEach(Array(m.lines.enumerated()), id: \.offset) { _, line in
                        Linked(link: line.link) {
                            HStack(alignment: .top, spacing: 8) {
                                GlyphTile(glyph: line.glyph, size: 20, corner: 6, fontSize: 12, weight: .regular)
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(line.title).font(.sf(12.5, .semibold)).foregroundStyle(ink.text).lineLimit(1)
                                    if let task = line.task {
                                        Text(task).font(.sf(12)).foregroundStyle(ink.text).lineLimit(1)
                                    }
                                    if let since = line.since {
                                        HStack(spacing: 5) {
                                            LineMarker(paused: line.paused)
                                            Text(since).font(.sf(11)).foregroundStyle(line.paused ? ink.pauseText : ink.faint).lineLimit(1)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                RuleLine()
                Linked(link: m.pendingLink) {
                    VStack(alignment: .leading, spacing: 4) {
                        SectionLabel(text: m.pendingHeader, size: 10, lang: m.lang)
                        if m.pendingItems.isEmpty && m.pendingCount == 0 {
                            Text(m.lang.strings.pendingNone).font(.sf(12)).foregroundStyle(ink.muted)
                        } else {
                            PendingRows(items: Array(m.pendingItems.prefix(FindingsLayout.extraLargePending)), xl: true)
                            Text(m.lang.strings.pendingNote).font(.sf(11)).foregroundStyle(ink.faint).lineLimit(2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                Spacer(minLength: 0)
                if m.showStats {
                    StatsBlock(m: m, xl: true)
                }
            }
        }
    }

    private var rightColumn: some View {
        withInk { ink in
            let grouped = FindingsLayout.grouped(m.rows, limit: FindingsLayout.extraLargeBudget) { $0.group }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    SectionLabel(text: m.findingsHeader, size: 10, lang: m.lang).frame(maxWidth: .infinity, alignment: .leading)
                    if !m.rows.isEmpty {
                        Text("\(m.rows.count)").font(.sf(11.5).monospacedDigit()).foregroundStyle(ink.text)
                    }
                }
                ForEach(Array(grouped.groups.enumerated()), id: \.offset) { _, g in
                    VStack(alignment: .leading, spacing: 3) {
                        GroupLabel(text: m.lang.strings.group(g.0), size: 10, lang: m.lang)
                        ForEach(Array(g.1.enumerated()), id: \.offset) { _, row in OneLineRow(row: row, xl: true) }
                    }
                    .padding(.top, 4)
                }
                if grouped.more > 0 {
                    Text(m.lang.strings.findingsMore(grouped.more)).font(.sf(10.5)).foregroundStyle(ink.faint).padding(.leading, 24)
                }
                if let none = m.findingsNone {
                    Text(none).font(.sf(12.5)).foregroundStyle(ink.muted)
                }
            }
        }
    }
}
