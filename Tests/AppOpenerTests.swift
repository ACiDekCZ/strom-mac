import XCTest

/// K2.3: where an address opens — the installed Strom app, a Chromium browser, the default browser. Only made-up
/// folders in a scratch directory; nothing is opened.
final class AppOpenerTests: XCTestCase {
    private var root: URL!
    private let prodId = "aaaabbbbccccddddeeeeffffgggghhhh"
    private let betaId = "iiiijjjjkkkkllllmmmmnnnnoooopppp"
    private let prod = URL(string: "https://stromapp.info/run/?tree=dvorakovi-trebon")!
    private let beta = URL(string: "https://beta.stromapp.info/run/?tree=dvorakovi-trebon&person=I12")!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("AppOpenerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private var home: URL { root.appendingPathComponent("home", isDirectory: true) }
    private var system: URL { root.appendingPathComponent("Applications", isDirectory: true) }

    private func opener(defaultBrowser: String? = "com.apple.Safari") -> AppOpener {
        AppOpener(home: home, appDirs: [system, home.appendingPathComponent("Applications")], defaultBrowserId: defaultBrowser)
    }

    private func mkdir(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    private func browser(_ appName: String) throws {
        try mkdir(system.appendingPathComponent(appName))
    }

    /// A web app shim as Chrome writes it: ~/Applications/Chrome Apps.localized/<name>.app/Contents/Info.plist.
    private func webApp(_ name: String, folder: String = "Chrome Apps.localized", url: String, id: String,
                        binary: Bool = false) throws {
        let contents = home.appendingPathComponent("Applications/\(folder)/\(name).app/Contents")
        try mkdir(contents)
        let info: [String: Any] = ["CFBundleName": name, "CrAppModeShortcutURL": url, "CrAppModeShortcutID": id,
                                   "CrAppModeShortcutName": name]
        let data = try PropertyListSerialization.data(fromPropertyList: info, format: binary ? .binary : .xml, options: 0)
        try data.write(to: contents.appendingPathComponent("Info.plist"))
    }

    private func profile(_ name: String, has id: String, data: String = "Google/Chrome") throws {
        try mkdir(home.appendingPathComponent("Library/Application Support/\(data)/\(name)/Web Applications/Manifest Resources/\(id)"))
    }

    private func installBoth() throws {
        try browser("Google Chrome.app")
        try webApp("Strom - Family Tree", url: "https://stromapp.info/run/", id: prodId)
        try webApp("Strom Beta", url: "https://beta.stromapp.info/run/", id: betaId, binary: true)
        try profile("Default", has: "otherotherotherotherotherotherot")
        try profile("Profile 2", has: prodId)
        try profile("Profile 2", has: betaId)
    }

    private var chrome: URL { system.appendingPathComponent("Google Chrome.app", isDirectory: true) }

    func testProductionAddressOpensTheProductionApp() throws {
        try installBoth()
        let steps = opener().steps(for: prod)
        XCTAssertEqual(steps.first, .webApp(browser: chrome, browserId: "com.google.Chrome", appId: prodId, profile: "Profile 2", url: prod))
        XCTAssertEqual(steps.dropFirst().first, .browser(chrome, url: prod))
        XCTAssertEqual(steps.last, .system(prod))
        XCTAssertEqual(steps.count, 3)
    }

    func testBetaAddressOpensTheBetaApp() throws {
        try installBoth()
        let steps = opener().steps(for: beta)
        XCTAssertEqual(steps.first, .webApp(browser: chrome, browserId: "com.google.Chrome", appId: betaId, profile: "Profile 2", url: beta))
        XCTAssertFalse(steps.contains { if case let .webApp(_, _, id, _, _) = $0 { return id == prodId } else { return false } },
                       "the production app does not take a beta address")
    }

    func testArgumentsLaunchTheAppAtTheAddress() {
        XCTAssertEqual(AppOpener.webAppArguments(appId: prodId, profile: "Profile 2", url: prod),
                       ["--profile-directory=Profile 2", "--app-id=\(prodId)",
                        "--app-launch-url-for-shortcuts-menu-item=https://stromapp.info/run/?tree=dvorakovi-trebon"])
        XCTAssertEqual(AppOpener.webAppArguments(appId: prodId, profile: nil, url: prod).first, "--app-id=\(prodId)")
    }

    func testWithoutProfileTheAppStillOpens() throws {
        try browser("Google Chrome.app")
        try webApp("Strom - Family Tree", url: "https://stromapp.info/run/", id: prodId)
        XCTAssertEqual(opener().steps(for: prod).first,
                       .webApp(browser: chrome, browserId: "com.google.Chrome", appId: prodId, profile: nil, url: prod))
    }

    func testAppOfAnotherBrowserOpensInItsBrowser() throws {
        try browser("Google Chrome.app")
        try browser("Microsoft Edge.app")
        try webApp("Strom", folder: "Edge Apps.localized", url: "https://stromapp.info/run/", id: prodId)
        try profile("Default", has: prodId, data: "Microsoft Edge")
        let edge = system.appendingPathComponent("Microsoft Edge.app", isDirectory: true)
        let steps = opener().steps(for: prod)
        XCTAssertEqual(steps.first, .webApp(browser: edge, browserId: "com.microsoft.edgemac", appId: prodId, profile: "Default", url: prod))
        // a tab: the browser the app is from before Chrome
        XCTAssertEqual(Array(steps.dropFirst()), [.browser(edge, url: prod), .browser(chrome, url: prod), .system(prod)])
    }

    func testNoMatchingAppOpensATabOfTheBrowserTheAppIsFrom() throws {
        try browser("Google Chrome.app")
        try browser("Brave Browser.app")
        try webApp("Strom", folder: "Brave Browser Apps.localized", url: "https://stromapp.info/run/", id: prodId)
        let brave = system.appendingPathComponent("Brave Browser.app", isDirectory: true)
        // only the production app is installed; a beta address goes to a tab of its browser
        XCTAssertEqual(opener().steps(for: beta), [.browser(brave, url: beta), .browser(chrome, url: beta), .system(beta)])
    }

    func testNoAppOpensChromeBeforeTheDefaultBrowser() throws {
        try browser("Google Chrome.app")
        try browser("Safari.app")
        XCTAssertEqual(opener().steps(for: prod), [.browser(chrome, url: prod), .system(prod)])
    }

    func testDefaultChromiumBrowserGoesBeforeChrome() throws {
        try browser("Google Chrome.app")
        try browser("Vivaldi.app")
        let vivaldi = system.appendingPathComponent("Vivaldi.app", isDirectory: true)
        XCTAssertEqual(opener(defaultBrowser: "com.vivaldi.Vivaldi").steps(for: prod),
                       [.browser(vivaldi, url: prod), .browser(chrome, url: prod), .system(prod)])
    }

    func testNoChromiumBrowserOpensTheDefaultOne() throws {
        try browser("Safari.app")
        try webApp("Strom", url: "https://stromapp.info/run/", id: prodId) // Chrome itself was removed
        XCTAssertEqual(opener().steps(for: prod), [.system(prod)])
    }

    func testOtherSchemesGoToTheSystem() throws {
        try installBoth()
        let strom = URL(string: "strom://open?tree=dvorakovi-trebon")!
        XCTAssertEqual(opener().steps(for: strom), [.system(strom)])
    }

    func testBrokenShimsAreSkipped() throws {
        try browser("Google Chrome.app")
        try webApp("Strom", url: "https://stromapp.info/run/", id: "not-an-id")
        let broken = home.appendingPathComponent("Applications/Chrome Apps.localized/Broken.app/Contents")
        try mkdir(broken)
        try Data("not a plist".utf8).write(to: broken.appendingPathComponent("Info.plist"))
        XCTAssertEqual(opener().steps(for: prod), [.browser(chrome, url: prod), .system(prod)])
    }

    func testAddressWithinTheApp() {
        let app = "https://stromapp.info/run/"
        XCTAssertTrue(AppOpener.isWithin("https://stromapp.info/run/?tree=x", app: app))
        XCTAssertTrue(AppOpener.isWithin("https://stromapp.info/run", app: app))
        XCTAssertTrue(AppOpener.isWithin("https://stromapp.info/run?tree=x", app: app))
        XCTAssertTrue(AppOpener.isWithin("https://StromApp.info/run/#p", app: app))
        XCTAssertFalse(AppOpener.isWithin("https://beta.stromapp.info/run/?tree=x", app: app))
        XCTAssertFalse(AppOpener.isWithin("https://stromapp.info/help/", app: app))
        XCTAssertFalse(AppOpener.isWithin("https://stromapp.info/runner", app: app))
        XCTAssertFalse(AppOpener.isWithin("https://stromapp.info/run/", app: ""))
    }
}
