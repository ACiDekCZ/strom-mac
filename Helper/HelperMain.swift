import AppKit

/// Login item without a window or menu bar icon: watches the research folder, mirrors it into the
/// App Group and asks WidgetKit for reloads (§0 Obnova, §8 Pomocník).
final class HelperDelegate: NSObject, NSApplicationDelegate {
    private var mirror: Mirror?
    private var throttle = ReloadThrottle()
    private var source: DispatchSourceFileSystemObject?
    private var watchedFD: Int32 = -1
    private var timer: Timer?
    private var debounce: DispatchWorkItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let dest = AppGroup.treesURL else {
            NSLog("Strom Widget Helper: App Group container unavailable")
            return
        }
        mirror = Mirror(source: ResearchPaths.researchWidgetDir, destination: dest)
        sync()
        // Heartbeat: the research writes every 60 s; the timer also re-attaches the watcher
        // when the folder appears later and flushes deferred reloads.
        timer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in self?.tick() }
    }

    private func tick() {
        if source == nil { watch() }
        sync()
        if throttle.flush(now: Date()) { reload() }
    }

    private func watch() {
        let dir = ResearchPaths.researchWidgetDir
        let fd = open(dir.path, O_EVTONLY)
        guard fd >= 0 else { return }
        watchedFD = fd
        let s = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .rename, .delete, .extend], queue: .main)
        s.setEventHandler { [weak self] in
            guard let self else { return }
            if s.data.contains(.delete) || s.data.contains(.rename) {
                self.stopWatching()
            }
            self.scheduleSync()
        }
        s.setCancelHandler { close(fd) }
        s.resume()
        source = s
    }

    private func stopWatching() {
        source?.cancel()
        source = nil
        watchedFD = -1
    }

    /// Writes come in bursts (`.tmp` + rename); wait a moment before reading.
    private func scheduleSync() {
        debounce?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.sync() }
        debounce = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    private func sync() {
        guard let mirror else { return }
        let result = mirror.sync()
        if result.heartbeatOnly {
            if throttle.heartbeat(now: Date()) { reload() }
            return
        }
        guard !result.changed.isEmpty || !result.newFinding.isEmpty else { return }
        if throttle.request(now: Date(), urgent: !result.newFinding.isEmpty) { reload() }
    }

    /// WidgetKit takes reloads only from the app that holds the widget, not from this helper (chronod: „Ignoring
    /// restricted or unknown extension info.stromapp.widget.helper“). The host app's program is run without a
    /// window to ask for it (`HostReload`).
    private func reload() {
        guard let exe = HostReload.hostExecutable(helperBundle: Bundle.main.bundleURL) else {
            NSLog("Strom Widget Helper: host app not found")
            return
        }
        let p = Process()
        p.executableURL = exe
        p.arguments = [HostReload.argument]
        p.standardInput = FileHandle.nullDevice
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        do {
            try p.run()
        } catch {
            NSLog("Strom Widget Helper: reload failed: \(error.localizedDescription)")
        }
    }
}

@main
enum HelperMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = HelperDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.prohibited)
        app.run()
    }
}
