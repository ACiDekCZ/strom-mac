import AppKit

/// Where an address from the research opens (K2.3): the Strom app installed from a Chromium browser first,
/// then a tab of a Chromium browser, the default browser last — never Safari ahead of them. The Strom app is
/// a web page that reaches the research's bridge only from Chromium browsers, so the default browser
/// (often Safari) is not where it should open. Same order as `strom app` of the research (`core/chromium.ts`).
enum OpenStep: Equatable {
    /// The installed app in its own window: the browser is asked to launch the app (id, profile) at the address.
    case webApp(browser: URL, browserId: String, appId: String, profile: String?, url: URL)
    /// A tab of that browser.
    case browser(URL, url: URL)
    /// The system's handler of the address (the default browser for web addresses).
    case system(URL)
}

/// A Chromium browser the Strom app can be installed from.
struct ChromiumBrowser: Equatable {
    let name: String
    let bundleId: String
    /// The .app in /Applications or ~/Applications.
    let appName: String
    /// The folders in ~/Applications where it keeps the apps installed from it.
    let appsFolders: [String]
    /// Its profiles, under ~/Library/Application Support.
    let userData: String?

    /// The most common first.
    static let all: [ChromiumBrowser] = [
        .init(name: "Google Chrome", bundleId: "com.google.Chrome", appName: "Google Chrome.app",
              appsFolders: ["Chrome Apps.localized", "Chrome Apps"], userData: "Google/Chrome"),
        .init(name: "Microsoft Edge", bundleId: "com.microsoft.edgemac", appName: "Microsoft Edge.app",
              appsFolders: ["Edge Apps.localized", "Edge Apps"], userData: "Microsoft Edge"),
        .init(name: "Brave", bundleId: "com.brave.Browser", appName: "Brave Browser.app",
              appsFolders: ["Brave Browser Apps.localized", "Brave Browser Apps"], userData: "BraveSoftware/Brave-Browser"),
        .init(name: "Opera", bundleId: "com.operasoftware.Opera", appName: "Opera.app", appsFolders: [], userData: nil),
        .init(name: "Chromium", bundleId: "org.chromium.Chromium", appName: "Chromium.app",
              appsFolders: ["Chromium Apps.localized", "Chromium Apps"], userData: "Chromium"),
        .init(name: "Vivaldi", bundleId: "com.vivaldi.Vivaldi", appName: "Vivaldi.app",
              appsFolders: ["Vivaldi Apps.localized", "Vivaldi Apps"], userData: "Vivaldi"),
        .init(name: "Arc", bundleId: "company.thebrowser.Browser", appName: "Arc.app", appsFolders: [], userData: nil),
    ]
}

/// A web app installed from a Chromium browser (its shim in ~/Applications/<Browser> Apps).
struct InstalledWebApp: Equatable {
    let browser: ChromiumBrowser
    let shortcutURL: String
    let appId: String
}

struct AppOpener {
    /// The user's home (the real one, also when run elsewhere).
    var home: URL
    /// Folders the browsers are looked for in.
    var appDirs: [URL]
    /// The bundle id of the default browser, if known.
    var defaultBrowserId: String?
    /// Where the system has an app of that bundle id, besides `appDirs`.
    var locate: (String) -> URL? = { _ in nil }

    static var standard: AppOpener {
        let home = ResearchPaths.realHome
        let probe = URL(string: "https://stromapp.info/")!
        let defaultApp = NSWorkspace.shared.urlForApplication(toOpen: probe)
        return AppOpener(home: home,
                         appDirs: [URL(fileURLWithPath: "/Applications", isDirectory: true),
                                   home.appendingPathComponent("Applications", isDirectory: true)],
                         defaultBrowserId: defaultApp.flatMap { Bundle(url: $0)?.bundleIdentifier },
                         locate: { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) })
    }

    // MARK: Choosing

    /// What is tried for the address, in order; the first that opens wins.
    func steps(for url: URL) -> [OpenStep] {
        guard let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http" else { return [.system(url)] }
        var steps: [OpenStep] = []
        let apps = installedWebApps()
        let target = url.absoluteString
        // The app whose address the target lies within (beta → Strom Beta, production → Strom); the longest one wins.
        let matching = apps.filter { Self.isWithin(target, app: $0.shortcutURL) }
            .sorted { $0.shortcutURL.count > $1.shortcutURL.count }
        for app in matching {
            guard let browser = browserURL(app.browser) else { continue }
            steps.append(.webApp(browser: browser, browserId: app.browser.bundleId, appId: app.appId,
                                 profile: profile(of: app), url: url))
        }
        // A tab: the browser the app is installed from, the default one when it is Chromium, Chrome, the others.
        var order = apps.map(\.browser)
        if let id = defaultBrowserId, let b = ChromiumBrowser.all.first(where: { $0.bundleId.lowercased() == id.lowercased() }) {
            order.append(b)
        }
        order += ChromiumBrowser.all
        var seen = Set<String>()
        for b in order where seen.insert(b.bundleId).inserted {
            if let at = browserURL(b) { steps.append(.browser(at, url: url)) }
        }
        steps.append(.system(url))
        return steps
    }

    /// The app's address is a prefix of the target (`https://beta.stromapp.info/run/` takes `…/run/?tree=x`).
    static func isWithin(_ target: String, app: String) -> Bool {
        guard !app.isEmpty else { return false }
        let t = target.lowercased(), a = app.lowercased()
        if t.hasPrefix(a) { return true }
        // `…/run/` also takes `…/run` and `…/run?tree=x`
        guard a.hasSuffix("/") else { return false }
        let bare = String(a.dropLast())
        return t == bare || t.hasPrefix(bare + "?") || t.hasPrefix(bare + "#")
    }

    /// Every web app installed from a Chromium browser here that says its address and id.
    func installedWebApps() -> [InstalledWebApp] {
        let fm = FileManager.default
        let apps = home.appendingPathComponent("Applications", isDirectory: true)
        var found: [InstalledWebApp] = []
        for browser in ChromiumBrowser.all {
            for folder in browser.appsFolders {
                let dir = apps.appendingPathComponent(folder, isDirectory: true)
                let names = ((try? fm.contentsOfDirectory(atPath: dir.path)) ?? []).filter { $0.hasSuffix(".app") }.sorted()
                for name in names {
                    let plist = dir.appendingPathComponent(name).appendingPathComponent("Contents/Info.plist")
                    guard let info = Self.plist(at: plist),
                          let address = info["CrAppModeShortcutURL"] as? String,
                          let id = info["CrAppModeShortcutID"] as? String, Self.isAppId(id) else { continue }
                    found.append(InstalledWebApp(browser: browser, shortcutURL: address, appId: id))
                }
            }
        }
        return found
    }

    /// The profile that holds the app's files (only folder names are looked at).
    func profile(of app: InstalledWebApp) -> String? {
        guard let data = app.browser.userData else { return nil }
        let root = home.appendingPathComponent("Library/Application Support", isDirectory: true)
            .appendingPathComponent(data, isDirectory: true)
        let fm = FileManager.default
        let dirs = ((try? fm.contentsOfDirectory(atPath: root.path)) ?? []).sorted()
        return dirs.first { p in
            fm.fileExists(atPath: root.appendingPathComponent(p).appendingPathComponent("Web Applications/Manifest Resources/\(app.appId)").path)
        }
    }

    func browserURL(_ b: ChromiumBrowser) -> URL? {
        let fm = FileManager.default
        for dir in appDirs {
            let at = dir.appendingPathComponent(b.appName, isDirectory: true)
            if fm.fileExists(atPath: at.path) { return at }
        }
        return locate(b.bundleId)
    }

    static func isAppId(_ s: String) -> Bool {
        s.count == 32 && s.unicodeScalars.allSatisfy { ("a"..."p").contains($0) }
    }

    private static func plist(at url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any]
    }

    /// The arguments that launch the app at the address (the browser hands them to its running copy).
    static func webAppArguments(appId: String, profile: String?, url: URL) -> [String] {
        (profile.map { ["--profile-directory=\($0)"] } ?? [])
            + ["--app-id=\(appId)", "--app-launch-url-for-shortcuts-menu-item=\(url.absoluteString)"]
    }

    // MARK: Opening

    /// Tries the steps in order; `done` gets whether one of them opened the address.
    func open(_ url: URL, done: @escaping (Bool) -> Void) {
        Self.run(steps(for: url)[...], done: done)
    }

    private static func run(_ steps: ArraySlice<OpenStep>, done: @escaping (Bool) -> Void) {
        guard let step = steps.first else { return done(false) }
        let next = { (ok: Bool) in
            DispatchQueue.main.async { ok ? done(true) : run(steps.dropFirst(), done: done) }
        }
        let config = NSWorkspace.OpenConfiguration()
        switch step {
        case let .webApp(browser, browserId, appId, profile, url):
            let args = webAppArguments(appId: appId, profile: profile, url: url)
            if NSRunningApplication.runningApplications(withBundleIdentifier: browserId).isEmpty {
                // Not running: Launch Services starts it with the arguments.
                config.arguments = args
                NSWorkspace.shared.openApplication(at: browser, configuration: config) { app, error in next(app != nil && error == nil) }
            } else {
                // Running: Launch Services would only bring it forward; its own program hands the request to it.
                next(launchProgram(of: browser, arguments: args))
            }
        case let .browser(browser, url):
            NSWorkspace.shared.open([url], withApplicationAt: browser, configuration: config) { app, error in next(app != nil && error == nil) }
        case let .system(url):
            NSWorkspace.shared.open(url, configuration: config) { app, error in next(app != nil && error == nil) }
        }
    }

    private static func launchProgram(of app: URL, arguments: [String]) -> Bool {
        guard let exe = Bundle(url: app)?.executableURL else { return false }
        let p = Process()
        p.executableURL = exe
        p.arguments = arguments
        p.standardInput = FileHandle.nullDevice
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        do {
            try p.run()
            return true
        } catch {
            return false
        }
    }
}
