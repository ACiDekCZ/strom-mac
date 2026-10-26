import Foundation
import WidgetKit

/// Reloads asked for through the host app: WidgetKit takes them only from the app that holds the widget,
/// so the helper runs the host app's program with `--reload-widgets` (§0 Obnova).
enum HostReload {
    static let argument = "--reload-widgets"
    static let hostIdentifier = "info.stromapp.widget"

    /// The host app's program: the helper lives in `<host>.app/Contents/Library/LoginItems/`.
    static func hostExecutable(helperBundle: URL) -> URL? {
        let host = helperBundle.deletingLastPathComponent() // LoginItems
            .deletingLastPathComponent() // Library
            .deletingLastPathComponent() // Contents
            .deletingLastPathComponent() // <host>.app
        guard host.pathExtension == "app", let bundle = Bundle(url: host),
              bundle.bundleIdentifier == hostIdentifier else { return nil }
        return bundle.executableURL
    }

    /// In the host app's process: ask for the reload and quit once WidgetKit has taken it (at most 3 s).
    static func run() -> Never {
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind.research)
        // The answer to a later request on the same connection means the reload was delivered.
        var done = false
        WidgetCenter.shared.getCurrentConfigurations { _ in DispatchQueue.main.async { done = true } }
        let deadline = Date().addingTimeInterval(3)
        while !done && Date() < deadline {
            RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.1))
        }
        exit(0)
    }
}
