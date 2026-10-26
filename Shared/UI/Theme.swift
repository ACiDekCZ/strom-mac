import SwiftUI
import WidgetKit

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xff) / 255, green: Double((hex >> 8) & 0xff) / 255,
                  blue: Double(hex & 0xff) / 255, opacity: opacity)
    }
}

/// Colour tokens of the widget (§0 Barvy), same as the phone page.
struct Palette {
    var bg, text, muted, faint, rule, label, ok, pause, pauseText, ring, tile, tileText, mark, pill, pillBd, pillText, code: Color

    static let light = Palette(
        bg: Color(hex: 0xfffdf8), text: Color(hex: 0x2b2822), muted: Color(hex: 0x5c5546), faint: Color(hex: 0x746c5c),
        rule: Color(hex: 0xece5d6), label: Color(hex: 0x8a5528), ok: Color(hex: 0x3f6b4f), pause: Color(hex: 0xb5772a),
        pauseText: Color(hex: 0x7f5500), ring: Color(hex: 0xa59d8c), tile: Color(hex: 0xf1ece1), tileText: Color(hex: 0x5c5546),
        mark: Color(hex: 0xb0703c), pill: Color(hex: 0xfbf5e6), pillBd: Color(hex: 0xe8d7ae), pillText: Color(hex: 0x7f5500),
        code: Color(hex: 0xf1ece1))

    static let dark = Palette(
        bg: Color(hex: 0x2c2a24), text: Color(hex: 0xe8e3d6), muted: Color(hex: 0xa89f8d), faint: Color(hex: 0x9a927f),
        rule: Color(hex: 0x35322a), label: Color(hex: 0xc98d59), ok: Color(hex: 0x6f9c7f), pause: Color(hex: 0xd39a52),
        pauseText: Color(hex: 0xe8c47c), ring: Color(hex: 0x9a927f), tile: Color(hex: 0x34302a), tileText: Color(hex: 0xb3aa98),
        mark: Color(hex: 0xc98d59), pill: Color(hex: 0x3a3324), pillBd: Color(hex: 0x5e513f), pillText: Color(hex: 0xe8c47c),
        code: Color(hex: 0x211f1a))

    static func forScheme(_ scheme: ColorScheme) -> Palette { scheme == .dark ? dark : light }
}

/// How the desktop draws the widget. In the widget it comes from `widgetRenderingMode`;
/// snapshots set it directly (`simulatedTint` stands in for the system tint of `.accented`).
enum StromRenderMode: Equatable {
    case fullColor, vibrant, accented
}

private struct RenderModeKey: EnvironmentKey { static let defaultValue: StromRenderMode = .fullColor }
private struct SimulatedTintKey: EnvironmentKey { static let defaultValue: Color? = nil }

extension EnvironmentValues {
    var stromRenderMode: StromRenderMode {
        get { self[RenderModeKey.self] }
        set { self[RenderModeKey.self] = newValue }
    }

    var stromSimulatedTint: Color? {
        get { self[SimulatedTintKey.self] }
        set { self[SimulatedTintKey.self] = newValue }
    }
}

/// Resolved styles for the current scheme and rendering mode. In `.vibrant` and `.accented` the widget
/// uses no colours of its own, only hierarchical foreground styles (§0 Režimy vykreslení).
struct Ink {
    var palette: Palette
    var mode: StromRenderMode
    var tint: Color?

    var plain: Bool { mode != .fullColor }

    var text: AnyShapeStyle { plain ? AnyShapeStyle(.primary) : AnyShapeStyle(palette.text) }
    var muted: AnyShapeStyle { plain ? AnyShapeStyle(.secondary) : AnyShapeStyle(palette.muted) }
    var faint: AnyShapeStyle { plain ? AnyShapeStyle(.secondary) : AnyShapeStyle(palette.faint) }
    var rule: AnyShapeStyle { plain ? AnyShapeStyle(.quaternary) : AnyShapeStyle(palette.rule) }
    var tile: AnyShapeStyle { plain ? AnyShapeStyle(.quaternary) : AnyShapeStyle(palette.tile) }
    var tileText: AnyShapeStyle { plain ? AnyShapeStyle(.primary) : AnyShapeStyle(palette.tileText) }
    var code: AnyShapeStyle { plain ? AnyShapeStyle(.quaternary) : AnyShapeStyle(palette.code) }

    /// Accent group (§0: značka S., tvar stavu, popisky oddílů, tečky a pilulka Čeká).
    private func accent(_ c: Color) -> AnyShapeStyle {
        switch mode {
        case .fullColor: return AnyShapeStyle(c)
        case .vibrant: return AnyShapeStyle(.primary)
        case .accented: return tint.map { AnyShapeStyle($0) } ?? AnyShapeStyle(.primary)
        }
    }

    var label: AnyShapeStyle { accent(palette.label) }
    var mark: AnyShapeStyle { accent(palette.mark) }
    var ok: AnyShapeStyle { accent(palette.ok) }
    var pause: AnyShapeStyle { accent(palette.pause) }
    var ring: AnyShapeStyle { accent(palette.ring) }
    var pillText: AnyShapeStyle { accent(palette.pillText) }
    var pill: AnyShapeStyle { plain ? AnyShapeStyle(.quaternary) : AnyShapeStyle(palette.pill) }
    /// Pause and stale texts: accent colour in full colour, plain text otherwise (the shape carries the meaning).
    var pauseText: AnyShapeStyle { plain ? AnyShapeStyle(.primary) : AnyShapeStyle(palette.pauseText) }
    var pauseShape: AnyShapeStyle { accent(palette.pauseText) }
}

private struct InkReader<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.stromRenderMode) private var mode
    @Environment(\.stromSimulatedTint) private var tint
    var content: (Ink) -> Content
    var body: some View { content(Ink(palette: .forScheme(scheme), mode: mode, tint: tint)) }
}

/// Gives the content the resolved styles of the current environment.
func withInk<Content: View>(@ViewBuilder _ content: @escaping (Ink) -> Content) -> some View {
    InkReader(content: content)
}

extension View {
    /// Marks the accent group for the tinted and clear desktop styles.
    func stromAccentable() -> some View { widgetAccentable() }
}

/// Fonts in points; the widget does not scale with Dynamic Type on macOS (§0 Písmo).
extension Font {
    static func sf(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font { .system(size: size, weight: weight) }
    static func mark(_ size: CGFloat) -> Font { .custom("Georgia-Bold", fixedSize: size) }
}
