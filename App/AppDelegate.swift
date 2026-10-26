import AppKit
import ServiceManagement
import SwiftUI
import WidgetKit

@main
enum StromWidgetMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }
}

/// Host app (§7, §8): opens widget links, shows the window with researches and the how-to,
/// registers the helper and uninstalls everything.
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    static let helperIdentifier = "info.stromapp.widget.helper"
    private static let helperRegisteredKey = "helperRegistered"

    private var mainWindow: NSWindow?
    private var failedWindow: NSWindow?
    private var hosting: NSHostingView<HostMainView>?
    private var snapshot = HostSnapshot.build(index: .missing, trees: [:], widgetCounts: [:], choice: .auto, now: Date())
    private var handledURL = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(self, andSelector: #selector(handleURLEvent(_:reply:)),
                                                     forEventClass: AEEventClass(kInternetEventClass),
                                                     andEventID: AEEventID(kAEGetURL))
        NSApp.mainMenu = makeMenu()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        registerHelperOnce()
        let isDefaultLaunch = notification.userInfo?[NSApplication.launchIsDefaultUserInfoKey] as? Bool ?? true
        if isDefaultLaunch && !handledURL { showMainWindow() }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { showMainWindow() }
        return true
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        if mainWindow?.isVisible == true { refresh() }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    // MARK: Links from the widget (§7)

    @objc private func handleURLEvent(_ event: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
        handledURL = true
        guard let text = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: text), let link = WidgetLink(url: url) else {
            showMainWindow()
            return
        }
        switch link {
        case .app:
            showMainWindow()
        case let .open(_, target, label):
            guard WidgetLink.isAllowedTarget(target), let targetURL = URL(string: target) else {
                showMainWindow()
                return
            }
            NSWorkspace.shared.open(targetURL, configuration: NSWorkspace.OpenConfiguration()) { [weak self] _, error in
                DispatchQueue.main.async {
                    if error != nil {
                        self?.showOpenFailed(address: target, what: label)
                    } else if self?.mainWindow?.isVisible != true {
                        NSApp.hide(nil)
                    }
                }
            }
        }
    }

    private func showOpenFailed(address: String, what: String?) {
        failedWindow?.close()
        let lang = currentLang()
        let view = OpenFailedView(lang: lang, what: what, address: address,
                                  onCopy: {
                                      NSPasteboard.general.clearContents()
                                      NSPasteboard.general.setString(address, forType: .string)
                                  },
                                  onClose: { [weak self] in self?.failedWindow?.close() })
        let window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: view)
        window.center()
        failedWindow = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    // MARK: Main window (§8)

    private func showMainWindow() {
        if mainWindow == nil {
            let window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                                  backing: .buffered, defer: false)
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            window.isReleasedWhenClosed = false
            window.delegate = self
            let view = NSHostingView(rootView: HostMainView(snapshot: snapshot, actions: actions))
            view.sizingOptions = [.intrinsicContentSize]
            window.contentView = view
            hosting = view
            mainWindow = window
        }
        refresh()
        mainWindow?.center()
        NSApp.activate(ignoringOtherApps: true)
        mainWindow?.makeKeyAndOrderFront(nil)
    }

    private var actions: HostActions {
        HostActions(
            setLanguage: { [weak self] choice in
                choice.store()
                WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind.research)
                self?.refresh()
            },
            allowAccess: { [weak self] in self?.chooseResearchFolder() },
            uninstall: { [weak self] in self?.uninstall() },
            openHelp: { NSWorkspace.shared.open($0) })
    }

    private func currentLang() -> Lang {
        let index = ResearchStore.standard.loadIndex()
        return LanguageChoice.stored.resolve(researchLang: index.value?.defaultTree?.lang ?? Locale.preferredLanguages.first)
    }

    /// Re-reads the research folder and counts the placed widgets per research.
    private func refresh() {
        let store = ResearchStore.standard
        let index = store.loadIndex()
        var trees: [String: WidgetData] = [:]
        for t in index.value?.trees ?? [] {
            if let d = store.loadTree(t.treeKey).value { trees[t.treeKey] = d }
        }
        let choice = LanguageChoice.stored
        apply(HostSnapshot.build(index: index, trees: trees, widgetCounts: [:], choice: choice, now: Date()))
        WidgetCenter.shared.getCurrentConfigurations { [weak self] result in
            var counts: [String: Int] = [:]
            if case .success(let infos) = result {
                for info in infos where info.kind == WidgetKind.research {
                    let key = info.widgetConfigurationIntent(of: SelectResearchIntent.self)?.research?.id
                        ?? index.value?.defaultTree?.treeKey
                    if let key { counts[key, default: 0] += 1 }
                }
            }
            DispatchQueue.main.async {
                self?.apply(HostSnapshot.build(index: index, trees: trees, widgetCounts: counts, choice: choice, now: Date()))
            }
        }
    }

    private func apply(_ new: HostSnapshot) {
        snapshot = new
        hosting?.rootView = HostMainView(snapshot: new, actions: actions)
    }

    /// 8b: the folder cannot be read; the user points to it, the helper then reads from there.
    private func chooseResearchFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = ResearchPaths.realHome.appendingPathComponent("Library/Application Support/Strom", isDirectory: true)
        guard let window = mainWindow else { return }
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, var url = panel.url else { return }
            // „Strom“ itself or its „widget“ subfolder are both fine.
            let widget = url.appendingPathComponent("widget", isDirectory: true)
            if FileManager.default.fileExists(atPath: widget.appendingPathComponent(ResearchPaths.indexFileName).path) { url = widget }
            if url.standardizedFileURL == ResearchPaths.defaultResearchWidgetDir.standardizedFileURL {
                AppGroup.defaults?.removeObject(forKey: ResearchPaths.chosenDirKey)
            } else {
                AppGroup.defaults?.set(url.path, forKey: ResearchPaths.chosenDirKey)
            }
            WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind.research)
            self?.refresh()
        }
    }

    // MARK: Helper and uninstall

    private func registerHelperOnce() {
        guard #available(macOS 13.0, *) else { return }
        let defaults = AppGroup.defaults
        guard defaults?.bool(forKey: Self.helperRegisteredKey) != true else { return }
        do {
            try SMAppService.loginItem(identifier: Self.helperIdentifier).register()
            defaults?.set(true, forKey: Self.helperRegisteredKey)
        } catch {
            NSLog("Strom Widget: helper registration failed: \(error.localizedDescription)")
        }
    }

    /// 8c: login item off, App Group container removed, app into the Trash, quit.
    private func uninstall() {
        try? SMAppService.loginItem(identifier: Self.helperIdentifier).unregister()
        AppGroup.defaults?.removePersistentDomain(forName: AppGroup.identifier)
        if let container = AppGroup.containerURL {
            let fm = FileManager.default
            for item in (try? fm.contentsOfDirectory(at: container, includingPropertiesForKeys: nil)) ?? [] {
                try? fm.removeItem(at: item)
            }
            try? fm.removeItem(at: container)
        }
        WidgetCenter.shared.reloadAllTimelines()
        NSWorkspace.shared.recycle([Bundle.main.bundleURL]) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }

    // MARK: Menu

    private func makeMenu() -> NSMenu {
        let main = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Hide Strom Widget", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Strom Widget", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        main.addItem(editItem)

        let windowItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowItem.submenu = windowMenu
        main.addItem(windowItem)
        NSApp.windowsMenu = windowMenu
        return main
    }
}
