import SwiftUI
import WidgetKit

/// „S.“ in Georgia Bold with the dot in `mark` (§0).
struct MarkView: View {
    var size: CGFloat
    var body: some View {
        withInk { ink in
            HStack(spacing: 0) {
                Text("S").foregroundStyle(ink.text)
                Text(".").foregroundStyle(ink.mark).stromAccentable()
            }
            .font(.mark(size))
            .fixedSize()
        }
    }
}

/// Status shape: ● working, ■ paused, ○ idle / not running, ◐ stale (§0, drawn, not emoji).
struct StatusShapeView: View {
    var shape: StatusShape
    var size: CGFloat
    var body: some View {
        withInk { ink in
            Group {
                switch shape {
                case .dot:
                    Circle().fill(ink.ok)
                case .square:
                    RoundedRectangle(cornerRadius: 1.5).fill(ink.pause)
                case .ring:
                    Circle().strokeBorder(ink.ring, lineWidth: 1.5)
                case .half:
                    HalfCircle(style: ink.pauseShape)
                }
            }
            .frame(width: size, height: size)
            .stromAccentable()
        }
    }
}

struct HalfCircle: View {
    var style: AnyShapeStyle
    var body: some View {
        ZStack {
            Circle().fill(style).mask(HStack(spacing: 0) { Rectangle(); Color.clear })
            Circle().strokeBorder(style, lineWidth: 1.5)
        }
    }
}

/// Small shape before „od 9:40“ / „pauza do 14:30“ in a line.
struct LineMarker: View {
    var paused: Bool
    var body: some View {
        withInk { ink in
            Group {
                if paused {
                    RoundedRectangle(cornerRadius: 1).fill(ink.pause)
                } else {
                    Circle().fill(ink.ok)
                }
            }
            .frame(width: 5, height: 5)
            .stromAccentable()
        }
    }
}

/// Square tile with a direction or kind glyph.
struct GlyphTile: View {
    var glyph: String
    var size: CGFloat
    var corner: CGFloat
    var fontSize: CGFloat
    var weight: Font.Weight = .semibold
    var body: some View {
        withInk { ink in
            Text(glyph)
                .font(.sf(fontSize, weight))
                .foregroundStyle(ink.tileText)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: size, height: size)
                .background(RoundedRectangle(cornerRadius: corner).fill(ink.tile))
        }
    }
}

/// Section label in capitals (9.5 pt, tracking 0.07 em).
struct SectionLabel: View {
    var text: String
    var size: CGFloat = 9.5
    var lang: Lang
    var body: some View {
        withInk { ink in
            Text(text.uppercased(with: lang.locale))
                .font(.sf(size, .semibold))
                .tracking(size * 0.07)
                .foregroundStyle(ink.label)
                .lineLimit(1)
                .stromAccentable()
        }
    }
}

/// Group label of findings (Osoby, Rodiny …): capitals, tracking 0.04 em, `faint`.
struct GroupLabel: View {
    var text: String
    var size: CGFloat
    var lang: Lang
    var body: some View {
        withInk { ink in
            Text(text.uppercased(with: lang.locale))
                .font(.sf(size, .semibold))
                .tracking(size * 0.04)
                .foregroundStyle(ink.faint)
                .lineLimit(1)
                // „VYŘEŠENO“ / „RESOLVED“ are wider than the 52 pt column of the large widget.
                .minimumScaleFactor(0.7)
        }
    }
}

/// „čeká 2“ pill in the medium header.
struct PendingPill: View {
    var text: String
    var body: some View {
        withInk { ink in
            HStack(spacing: 4) {
                Circle().fill(ink.pause).frame(width: 5, height: 5)
                Text(text).font(.sf(10.5, .semibold)).foregroundStyle(ink.pillText).lineLimit(1)
            }
            .padding(.horizontal, 7)
            .frame(height: 17)
            .background(Capsule().fill(ink.pill))
            .overlay(Capsule().strokeBorder(ink.plain ? AnyShapeStyle(Color.clear) : AnyShapeStyle(ink.palette.pillBd), lineWidth: 1))
            .fixedSize()
            .stromAccentable()
        }
    }
}

struct CodeChip: View {
    var text: String
    var size: CGFloat
    var hPad: CGFloat
    var vPad: CGFloat
    var corner: CGFloat
    var body: some View {
        withInk { ink in
            Text(text)
                .font(.system(size: size, design: .monospaced))
                .foregroundStyle(ink.text)
                .padding(.horizontal, hPad)
                .padding(.vertical, vPad)
                .background(RoundedRectangle(cornerRadius: corner).fill(ink.code))
                .fixedSize()
        }
    }
}

struct RuleLine: View {
    var body: some View {
        withInk { ink in
            Rectangle().fill(ink.rule).frame(height: 1)
        }
    }
}

/// Whether the current family allows per-row links (medium and larger).
private struct LinksEnabledKey: EnvironmentKey { static let defaultValue = true }

extension EnvironmentValues {
    var stromLinksEnabled: Bool {
        get { self[LinksEnabledKey.self] }
        set { self[LinksEnabledKey.self] = newValue }
    }
}

/// Wraps content in a `Link` to the host app; plain content in the small widget (it has only `widgetURL`).
struct Linked<Content: View>: View {
    var link: WidgetLink
    @ViewBuilder var content: Content
    @Environment(\.stromLinksEnabled) private var enabled

    var body: some View {
        if enabled {
            Link(destination: link.url) { content.contentShape(Rectangle()) }
                .buttonStyle(.plain)
        } else {
            content
        }
    }
}
