import AppKit

/// Windows of the host app (§7d, §8), apart from AppDelegate so tests can build them.
///
/// A window does not grow to its hosting view's intrinsic size by itself (those constraints are weaker than the
/// window's own size), so a window made with `.zero` stays 0 × 0 on screen: invisible, yet counted as visible,
/// and a click in the Dock then does nothing. The size is therefore always set from the content.
enum HostWindow {
    static func make(content: NSView, styleMask: NSWindow.StyleMask) -> NSWindow {
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: content.fittingSize), styleMask: styleMask,
                              backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = content
        fit(window)
        return window
    }

    /// Sizes the window to its content (fixed width, height by content), keeping the top-left corner
    /// so the window grows downwards when the content changes.
    static func fit(_ window: NSWindow) {
        guard let content = window.contentView else { return }
        content.layoutSubtreeIfNeeded()
        let size = content.fittingSize
        guard size.width > 0, size.height > 0, size != content.frame.size else { return }
        let topLeft = NSPoint(x: window.frame.minX, y: window.frame.maxY)
        window.setContentSize(size)
        window.setFrameTopLeftPoint(topLeft)
    }

    /// Restores a minimised window and sizes it; a window not yet on screen is centred after sizing.
    static func prepareToShow(_ window: NSWindow) {
        if window.isMiniaturized { window.deminiaturize(nil) }
        fit(window)
        if !window.isVisible { window.center() }
    }
}

/// When the host app quits (§7, §8): it has nothing to show without a window, so it does not stay in the Dock.
/// The helper is a separate login item and keeps running.
enum HostLifecycle {
    static let quitsAfterLastWindowClosed = true

    /// After a widget link was opened in the Strom app: quit unless a window of this app is open.
    static func quitsAfterOpeningLink(windows: [NSWindow?]) -> Bool {
        !windows.contains { $0?.isVisible == true || $0?.isMiniaturized == true }
    }
}
