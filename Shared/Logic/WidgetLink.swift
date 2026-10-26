import Foundation

/// Links from the widget go through the host app (§7):
/// `stromwidget://open?tree=<treeKey>&u=<openUrl>&l=<label>` and `stromwidget://app`.
enum WidgetLink: Equatable {
    case app
    case open(tree: String, url: String, label: String?)

    static let scheme = "stromwidget"

    var url: URL {
        switch self {
        case .app:
            return URL(string: "\(Self.scheme)://app")!
        case let .open(tree, target, label):
            var query = "tree=\(Self.encode(tree))&u=\(Self.encode(target))"
            if let label, !label.isEmpty { query += "&l=\(Self.encode(label))" }
            return URL(string: "\(Self.scheme)://open?\(query)") ?? Self.app.url
        }
    }

    init?(url: URL) {
        guard url.scheme == Self.scheme else { return nil }
        switch url.host {
        case "app":
            self = .app
        case "open":
            let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            func value(_ n: String) -> String? { items.first { $0.name == n }?.value }
            guard let target = value("u"), !target.isEmpty else { return nil }
            self = .open(tree: value("tree") ?? "", url: target, label: value("l"))
        default:
            return nil
        }
    }

    private static let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

    private static func encode(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: unreserved) ?? ""
    }

    /// Only web and Strom app addresses are opened; anything else from data is ignored.
    static func isAllowedTarget(_ s: String) -> Bool {
        guard let u = URL(string: s), let scheme = u.scheme?.lowercased() else { return false }
        return ["https", "http", "strom"].contains(scheme)
    }

    /// Link to a target from data, falling back to the tree address, then to the host app.
    static func to(_ target: String?, tree: WidgetData, label: String? = nil) -> WidgetLink {
        for candidate in [target, tree.openUrl] {
            if let c = candidate, isAllowedTarget(c) { return .open(tree: tree.treeKey, url: c, label: label) }
        }
        return .app
    }
}
