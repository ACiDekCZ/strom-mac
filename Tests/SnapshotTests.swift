import AppKit
import SwiftUI
import XCTest

/// Renders every size × state (§4) in light/dark and in the three desktop styles, plus the host app
/// windows (§7d, §8). PNGs are written when `STROM_SNAPSHOT_DIR` is set (xcodebuild: `TEST_RUNNER_STROM_SNAPSHOT_DIR`);
/// without it the views are still rendered, so layout crashes fail the test.
///
/// The clear (`vibrant`) and tinted (`accented`) desktop styles are simulated: the system draws them, here the
/// widget gets the same plain foreground styles over a stand-in background.
@MainActor
final class SnapshotTests: XCTestCase {
    enum Mode: String, CaseIterable {
        case color, vibrant, accented
        var render: StromRenderMode {
            switch self {
            case .color: return .fullColor
            case .vibrant: return .vibrant
            case .accented: return .accented
            }
        }
    }

    private static let tint = Color(hex: 0x4f8fd9)
    private var outDir: URL? {
        guard let dir = ProcessInfo.processInfo.environment["STROM_SNAPSHOT_DIR"], !dir.isEmpty else { return nil }
        return URL(fileURLWithPath: dir, isDirectory: true)
    }

    private func name(_ f: StromFamily) -> String {
        switch f {
        case .small: return "1-small"
        case .medium: return "2-medium"
        case .large: return "3-large"
        case .extraLarge: return "3-xl"
        }
    }

    private func widget(_ model: WidgetModel, _ family: StromFamily, _ scheme: ColorScheme, _ mode: Mode) -> some View {
        card(model, family, scheme, mode)
            .padding(18)
            .background(desktop(scheme))
            .environment(\.colorScheme, scheme)
    }

    /// One widget without the desktop around it.
    private func card(_ model: WidgetModel, _ family: StromFamily, _ scheme: ColorScheme, _ mode: Mode = .color) -> some View {
        let size = family.designSize
        let palette = Palette.forScheme(scheme)
        return StromWidgetView(model: model, family: family)
            .environment(\.stromRenderMode, mode.render)
            .environment(\.stromSimulatedTint, mode == .accented ? Self.tint : nil)
            .padding(family.designPadding)
            .frame(width: size.width, height: size.height)
            .background {
                switch mode {
                case .color: palette.bg
                case .vibrant: (scheme == .dark ? Color.black.opacity(0.28) : Color.white.opacity(0.38))
                case .accented: Self.tint.opacity(scheme == .dark ? 0.22 : 0.16)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .environment(\.colorScheme, scheme)
    }

    private func desktop(_ scheme: ColorScheme) -> LinearGradient {
        scheme == .dark
            ? LinearGradient(colors: [Color(hex: 0x2d3540), Color(hex: 0x1b1f26)], startPoint: .topLeading, endPoint: .bottomTrailing)
            : LinearGradient(colors: [Color(hex: 0x9fb4c4), Color(hex: 0x6f8798)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    @discardableResult
    private func render<V: View>(_ view: V, _ file: String, to dir: URL? = nil) throws -> NSImage {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        let image = try XCTUnwrap(renderer.cgImage, file)
        XCTAssertGreaterThan(image.width, 100, file)
        if let dir = dir ?? outDir {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let rep = NSBitmapImageRep(cgImage: image)
            let png = try XCTUnwrap(rep.representation(using: .png, properties: [:]))
            try png.write(to: dir.appendingPathComponent(file + ".png"))
        }
        return NSImage(cgImage: image, size: .zero)
    }

    func testAllSizesStatesAndStyles() throws {
        for family in StromFamily.allCases {
            for state in SampleData.State.allCases {
                let model = SampleData.model(state)
                for scheme in [ColorScheme.light, .dark] {
                    for mode in Mode.allCases {
                        try render(widget(model, family, scheme, mode),
                                   "\(name(family))-\(state.rawValue)-\(scheme == .dark ? "dark" : "light")-\(mode.rawValue)")
                    }
                }
            }
        }
    }

    /// Language variants (Ja–Ji) and hidden names (6d) for the working and not-running states.
    func testLanguagesAndHiddenNames() throws {
        for family in StromFamily.allCases {
            for lang in [Lang.en, .de] {
                for state in [SampleData.State.a, .b, .f, .h] {
                    try render(widget(SampleData.model(state, lang: lang), family, .light, .color),
                               "lang-\(lang.rawValue)-\(name(family))-\(state.rawValue)")
                }
            }
            for state in [SampleData.State.a, .b] {
                try render(widget(SampleData.model(state, hideNames: true), family, .light, .color),
                           "hidenames-\(name(family))-\(state.rawValue)")
            }
        }
    }

    /// 5c: very long texts and names; the end of a text gives way, kind word and time stay.
    func testTruncation() throws {
        var t = SampleData.tree(.b)
        t.treeName = "Lhotákovi ze Lhoty, jejich sousedé, kmotři a celé široké příbuzenstvo z okolních vesnic"
        t.now?.lines[0].title = "Předci Bořivoje Lhotáka, sládka ze Lhoty a jeho manželky Dobromily"
        t.now?.lines[0].task = "Hledat křest v matrice Lhota 1780–1790, farnost Lhota, svazek N a indexy"
        t.findings?.items.insert(WidgetData.Finding(kind: "fact", fact: "birth",
                                                    text: "Bořivoj Lhoták, 3. 5. 1784, Lhota, farnost Lhota, matrika N 1780–1790",
                                                    at: SampleData.at(14, 31)), at: 0)
        t.findings?.items.insert(WidgetData.Finding(kind: "fact", fact: "other", label: "Povolání a postavení v obci",
                                                    text: "Bořivoj Lhoták, sládek v panském pivovaru", at: SampleData.at(14, 30)), at: 0)
        t.pending?.items[0].text = "Rozhodnout rozpor: dvě různá data narození Dobromily Lhotákové v matrice a v indexu"
        let m = WidgetModelBuilder.build(index: .ok(SampleData.index()), tree: .ok(t), settings: WidgetSettings(treeKey: SampleData.treeKey),
                                         now: SampleData.at(14, 35), timeZone: SampleData.timeZone)
        for family in StromFamily.allCases {
            try render(widget(m, family, .light, .color), "long-\(name(family))")
        }
    }

    /// The research's own sample (`widget-vzor.json`).
    func testResearchSample() throws {
        let bundle = Bundle(for: Self.self)
        let data = try Data(contentsOf: try XCTUnwrap(bundle.url(forResource: "research-sample", withExtension: "json")))
        let index = try Data(contentsOf: try XCTUnwrap(bundle.url(forResource: "research-sample-index", withExtension: "json")))
        let tree = try XCTUnwrap(ResearchStore.decode(WidgetData.self, from: data).value)
        let idx = try XCTUnwrap(ResearchStore.decode(ResearchIndex.self, from: index).value)
        let m = WidgetModelBuilder.build(index: .ok(idx), tree: .ok(tree), settings: WidgetSettings(treeKey: tree.treeKey),
                                         now: tree.generatedAt.addingTimeInterval(120), timeZone: SampleData.timeZone)
        for family in StromFamily.allCases {
            try render(widget(m, family, .light, .color), "vzor-\(name(family))")
            try render(widget(m, family, .dark, .color), "vzor-\(name(family))-dark")
        }
    }

    func testHostWindows() throws {
        for scheme in [ColorScheme.light, .dark] {
            let suffix = scheme == .dark ? "dark" : "light"
            for lang in Lang.allCases {
                var s = HostSnapshot.sample
                s.lang = lang
                s = HostSnapshot.build(index: .ok(SampleData.index(lang: lang)), trees: [SampleData.treeKey: SampleData.tree(.a, lang: lang)],
                                       widgetCounts: [SampleData.treeKey: 2], choice: .auto, now: SampleData.at(14, 35),
                                       timeZone: SampleData.timeZone)
                try render(HostMainView(snapshot: s).environment(\.colorScheme, scheme), "8a-window-\(lang.rawValue)-\(suffix)")
            }
            let none = HostSnapshot.build(index: .ok(ResearchIndex(trees: [])), trees: [:], widgetCounts: [:], choice: .auto,
                                          now: SampleData.at(14, 35), systemLanguage: "cs")
            try render(HostMainView(snapshot: none).environment(\.colorScheme, scheme), "8b-none-\(suffix)")
            let locked = HostSnapshot.build(index: .noAccess, trees: [:], widgetCounts: [:], choice: .auto,
                                            now: SampleData.at(14, 35), systemLanguage: "cs")
            try render(HostMainView(snapshot: locked).environment(\.colorScheme, scheme), "8b-noaccess-\(suffix)")
            try render(UninstallSheet(lang: .cs, onCancel: {}, onConfirm: {}).environment(\.colorScheme, scheme), "8c-uninstall-\(suffix)")
            try render(OpenFailedView(lang: .cs, what: "Narození Bořivoj Lhoták", address: SampleData.base, onCopy: {}, onClose: {})
                .environment(\.colorScheme, scheme), "7d-open-failed-\(suffix)")
            try render(IconTile(size: 128).padding(20).background(desktop(scheme)).environment(\.colorScheme, scheme), "8d-icon-\(suffix)")
        }
    }

    /// The pictures of the README (`.github/images/`), in English. Written when `STROM_README_DIR` is set
    /// (xcodebuild: `TEST_RUNNER_STROM_README_DIR`).
    func testReadmeImages() throws {
        let env = ProcessInfo.processInfo.environment["STROM_README_DIR"]
        let dir = env.flatMap { $0.isEmpty ? nil : URL(fileURLWithPath: $0, isDirectory: true) }
        let working = SampleData.model(.b, lang: .en)
        for scheme in [ColorScheme.light, .dark] {
            let suffix = scheme == .dark ? "-dark" : ""
            // Several sizes side by side, as on a desktop.
            let hero = HStack(alignment: .top, spacing: 18) {
                card(working, .large, scheme)
                VStack(spacing: 18) {
                    card(working, .medium, scheme)
                    HStack(spacing: 24) {
                        card(SampleData.model(.a, lang: .en), .small, scheme)
                        card(SampleData.model(.c, lang: .en), .small, scheme)
                    }
                }
            }
            .padding(28)
            .background(desktop(scheme))
            .environment(\.colorScheme, scheme)
            try render(hero, "hero\(suffix)", to: dir)
            for family in StromFamily.allCases {
                try render(widget(working, family, scheme, .color), "\(readmeName(family))\(suffix)", to: dir)
            }
            try render(widget(SampleData.model(.c, lang: .en), .medium, scheme, .color), "state-paused\(suffix)", to: dir)
            try render(widget(SampleData.model(.d, lang: .en), .medium, scheme, .color), "state-idle\(suffix)", to: dir)
            try render(widget(SampleData.model(.f, lang: .en), .medium, scheme, .color), "state-not-running\(suffix)", to: dir)
            try render(widget(SampleData.model(.b, lang: .en, hideNames: true), .large, scheme, .color), "hidden-names\(suffix)", to: dir)
            let window = HostSnapshot.build(index: .ok(SampleData.index(lang: .en)), trees: [SampleData.treeKey: SampleData.tree(.a, lang: .en)],
                                            widgetCounts: [SampleData.treeKey: 2], choice: .auto, now: SampleData.at(14, 35),
                                            timeZone: SampleData.timeZone)
            try render(HostMainView(snapshot: window).environment(\.colorScheme, scheme), "app-window\(suffix)", to: dir)
        }
    }

    private func readmeName(_ f: StromFamily) -> String {
        switch f {
        case .small: return "widget-small"
        case .medium: return "widget-medium"
        case .large: return "widget-large"
        case .extraLarge: return "widget-extra-large"
        }
    }
}
