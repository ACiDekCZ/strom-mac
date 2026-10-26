import AppKit
import SwiftUI
import XCTest

/// §7d, §8: the host windows get their size from the content (a 0 × 0 window blocked Dock reopen),
/// and the app does not stay in the Dock without a window.
@MainActor
final class HostWindowTests: XCTestCase {
    private func hosting<V: View>(_ view: V) -> NSHostingView<V> {
        let v = NSHostingView(rootView: view)
        v.sizingOptions = [.intrinsicContentSize]
        return v
    }

    private func snapshot(trees count: Int) -> HostSnapshot {
        let trees = (0..<count).map { i in
            var t = SampleData.index(lang: .cs).trees[0]
            t.treeKey = "tree-\(i)"
            return t
        }
        return HostSnapshot.build(index: .ok(ResearchIndex(trees: trees)), trees: [:], widgetCounts: [:], choice: .auto,
                                  now: SampleData.at(14, 35), timeZone: SampleData.timeZone)
    }

    func testMainWindowIsSizedByContent() {
        for snap in [HostSnapshot.sample, snapshot(trees: 0)] {
            let window = HostWindow.make(content: hosting(HostMainView(snapshot: snap)),
                                         styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView])
            XCTAssertEqual(window.contentView?.frame.width ?? 0, 560, accuracy: 0.5)
            XCTAssertGreaterThan(window.frame.height, 300)
            XCTAssertFalse(window.isReleasedWhenClosed)
        }
    }

    func testOpenFailedWindowIsSizedByContent() {
        let view = OpenFailedView(lang: .cs, what: "Narození Bořivoj Lhoták", address: SampleData.base, onCopy: {}, onClose: {})
        let window = HostWindow.make(content: hosting(view), styleMask: [.titled, .closable])
        XCTAssertGreaterThan(window.frame.width, 300)
        XCTAssertGreaterThan(window.frame.height, 100)
    }

    func testCenteredWindowIsOnAScreen() throws {
        let window = HostWindow.make(content: hosting(HostMainView(snapshot: .sample)), styleMask: [.titled, .closable])
        window.center()
        let screen = try XCTUnwrap(window.screen ?? NSScreen.main)
        XCTAssertTrue(screen.frame.intersects(window.frame))
        XCTAssertGreaterThan(window.frame.width, 0)
    }

    /// A longer list after refresh makes the window taller; the top edge stays put.
    func testFitKeepsTopEdgeWhenContentGrows() {
        let view = hosting(HostMainView(snapshot: snapshot(trees: 1)))
        let window = HostWindow.make(content: view, styleMask: [.titled, .closable, .fullSizeContentView])
        window.setFrameTopLeftPoint(NSPoint(x: 100, y: 900))
        let before = window.frame
        view.rootView = HostMainView(snapshot: snapshot(trees: 4))
        HostWindow.fit(window)
        XCTAssertGreaterThan(window.frame.height, before.height)
        XCTAssertEqual(window.frame.maxY, before.maxY, accuracy: 0.5)
        XCTAssertEqual(window.frame.minX, before.minX, accuracy: 0.5)
    }

    /// A zero-sized window (the old bug) gets its size back when it is about to be shown.
    func testPrepareToShowRepairsZeroWindow() {
        let window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = hosting(HostMainView(snapshot: .sample))
        XCTAssertEqual(window.frame.width, 0, "a window does not grow to the hosting view by itself")
        HostWindow.prepareToShow(window)
        XCTAssertEqual(window.contentView?.frame.width ?? 0, 560, accuracy: 0.5)
        XCTAssertGreaterThan(window.frame.height, 300)
    }

    func testQuitsWithoutWindow() {
        XCTAssertTrue(HostLifecycle.quitsAfterLastWindowClosed)
        XCTAssertTrue(HostLifecycle.quitsAfterOpeningLink(windows: [nil, nil]))

        // Off-screen and transparent, so nothing shows while the test runs.
        let window = NSWindow(contentRect: NSRect(x: -20000, y: -20000, width: 40, height: 40), styleMask: .borderless,
                              backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.alphaValue = 0
        XCTAssertTrue(HostLifecycle.quitsAfterOpeningLink(windows: [window, nil]))
        window.orderFrontRegardless()
        XCTAssertFalse(HostLifecycle.quitsAfterOpeningLink(windows: [window, nil]))
        window.close()
        XCTAssertTrue(HostLifecycle.quitsAfterOpeningLink(windows: [window, nil]))
    }
}
