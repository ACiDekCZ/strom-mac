import Foundation

enum AppGroup {
    /// Team-prefixed group (macOS style): works with local signing, no provisioning profile needed.
    static let fallbackIdentifier = "TKYS4BYH6B.info.stromapp.widget"

    static var identifier: String {
        (Bundle.main.object(forInfoDictionaryKey: "StromAppGroup") as? String).flatMap { $0.isEmpty ? nil : $0 }
            ?? fallbackIdentifier
    }

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    /// Copies of the research files made by the helper.
    static var treesURL: URL? { containerURL?.appendingPathComponent("trees", isDirectory: true) }

    static var defaults: UserDefaults? { UserDefaults(suiteName: identifier) }
}

enum ResearchPaths {
    /// The real home folder, also inside the widget's sandbox (where `NSHomeDirectory()` is the container).
    static var realHome: URL {
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: dir), isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }

    /// Folder the research writes to (`~/Library/Application Support/Strom/widget/`).
    /// `STROM_WIDGET_DIR` overrides it (tests, isolated runs).
    static var researchWidgetDir: URL {
        if let override = ProcessInfo.processInfo.environment["STROM_WIDGET_DIR"], !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        if let chosen = AppGroup.defaults?.string(forKey: chosenDirKey), !chosen.isEmpty {
            return URL(fileURLWithPath: chosen, isDirectory: true)
        }
        return defaultResearchWidgetDir
    }

    static var defaultResearchWidgetDir: URL {
        realHome.appendingPathComponent("Library/Application Support/Strom/widget", isDirectory: true)
    }

    /// Folder picked in the host app („Povolit přístup…“) when the default one cannot be read.
    static let chosenDirKey = "researchDir"

    static let indexFileName = "index.json"

    static func treeFileName(_ key: String) -> String { "\(key).json" }

    /// Tree keys come from data; keep them to a safe file name.
    static func isSafeKey(_ key: String) -> Bool {
        !key.isEmpty && key.count <= 200 && !key.hasPrefix(".") &&
            key.unicodeScalars.allSatisfy { CharacterSet.alphanumerics.contains($0) || "-_.".unicodeScalars.contains($0) }
    }
}

/// Outcome of reading one contract file.
enum FileResult<T> {
    case ok(T)
    case missing
    case noAccess
    case outdated
    case broken

    var value: T? {
        if case .ok(let v) = self { return v }
        return nil
    }
}

/// Reads the index and tree files from one or more folders (App Group copy first, research folder second).
struct ResearchStore {
    var directories: [URL]

    static var standard: ResearchStore {
        ResearchStore(directories: [AppGroup.treesURL, ResearchPaths.researchWidgetDir].compactMap { $0 })
    }

    func loadIndex() -> FileResult<ResearchIndex> {
        combine(directories.map { read(ResearchIndex.self, at: $0.appendingPathComponent(ResearchPaths.indexFileName)) }) { a, b in
            // Prefer the folder that knows more trees; the copy may lag behind the source.
            a.trees.count >= b.trees.count ? a : b
        }
    }

    func loadTree(_ key: String) -> FileResult<WidgetData> {
        guard ResearchPaths.isSafeKey(key) else { return .missing }
        return combine(directories.map { read(WidgetData.self, at: $0.appendingPathComponent(ResearchPaths.treeFileName(key))) }) { a, b in
            a.generatedAt >= b.generatedAt ? a : b
        }
    }

    func read<T: Decodable>(_ type: T.Type, at url: URL) -> FileResult<T> {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile {
            return .missing
        } catch let error as CocoaError where error.code == .fileReadNoPermission {
            return .noAccess
        } catch let error as NSError where error.domain == NSPOSIXErrorDomain && (error.code == Int(EPERM) || error.code == Int(EACCES)) {
            return .noAccess
        } catch {
            return FileManager.default.fileExists(atPath: url.path) ? .noAccess : .missing
        }
        return Self.decode(type, from: data)
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) -> FileResult<T> {
        // Not JSON at all (half-written, garbage): broken, not „outdated“.
        guard (try? JSONSerialization.jsonObject(with: data)) != nil else { return .broken }
        let version = ContractCoding.schemaVersion(of: data)
        // The index may be a bare array without a version; tree files must carry one.
        if T.self == WidgetData.self || version != nil {
            guard let v = version, v >= WidgetData.supportedSchemaVersion else { return .outdated }
        }
        do {
            return .ok(try ContractCoding.decoder().decode(T.self, from: data))
        } catch {
            return .broken
        }
    }

    /// Picks the best result across folders: any good value wins, then outdated, then broken,
    /// then no access; missing only when missing everywhere.
    private func combine<T>(_ results: [FileResult<T>], prefer: (T, T) -> T) -> FileResult<T> {
        let values = results.compactMap(\.value)
        if let first = values.first { return .ok(values.dropFirst().reduce(first, prefer)) }
        if results.contains(where: { if case .outdated = $0 { return true } else { return false } }) { return .outdated }
        if results.contains(where: { if case .broken = $0 { return true } else { return false } }) { return .broken }
        if results.contains(where: { if case .noAccess = $0 { return true } else { return false } }) { return .noAccess }
        return .missing
    }
}

enum WidgetKind {
    static let research = "StromResearch"
}
