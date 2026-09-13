import SwiftUI

/// The four dashboards the app combines, one per tab.
/// Declaration order is tab order, and `liveBoard` leads: it is the main tab.
enum Module: String, CaseIterable, Identifiable, Hashable {
    case liveBoard, atlas, crucible, goldenRatio

    var id: String { rawValue }

    var title: String {
        switch self {
        case .liveBoard: "BTC Live Board"
        case .atlas: "ATLAS"
        case .crucible: "CRUCIBLE"
        case .goldenRatio: "Golden Ratio"
        }
    }

    /// Short label for the tab bar, where horizontal space is tight.
    var tabLabel: String {
        switch self {
        case .liveBoard: "LIVE"
        case .atlas: "ATLAS"
        case .crucible: "CRUCIBLE"
        case .goldenRatio: "FIBO"
        }
    }

    var subtitle: String {
        switch self {
        case .liveBoard: "Full-screen live price"
        case .atlas: "BTCUSDT.P signals & desk"
        case .crucible: "Liquidations, all exchanges"
        case .goldenRatio: "Auto Fibonacci retracement"
        }
    }

    var systemImage: String {
        switch self {
        case .liveBoard: "bitcoinsign.circle"
        case .atlas: "chart.bar.doc.horizontal"
        case .crucible: "flame"
        case .goldenRatio: "chart.xyaxis.line"
        }
    }

    var tint: Color {
        switch self {
        case .liveBoard: Color(red: 0.16, green: 0.85, blue: 0.60)
        case .atlas: Color(red: 0.30, green: 0.62, blue: 1.00)
        case .crucible: Color(red: 0.98, green: 0.40, blue: 0.34)
        case .goldenRatio: Color(red: 0.94, green: 0.73, blue: 0.04)
        }
    }

    /// Published copy on GitHub Pages. Loading this means the app runs the exact
    /// same origin the dashboards were built and tested against, and picks up
    /// pushes to the repo without an App Store release.
    var remoteURL: URL {
        switch self {
        case .liveBoard: URL(string: "https://alicetin1905-ux.github.io/BTCLiveBoard/")!
        case .atlas: URL(string: "https://alicetin1905-ux.github.io/ATLAS/")!
        case .crucible: URL(string: "https://alicetin1905-ux.github.io/CRUCIBLE/")!
        case .goldenRatio: URL(string: "https://alicetin1905-ux.github.io/GoldenRatio/")!
        }
    }

    /// Name of the copy bundled in the app, used when the network is unreachable.
    var bundledResource: String {
        switch self {
        case .liveBoard: "btcliveboard"
        case .atlas: "atlas"
        case .crucible: "crucible"
        case .goldenRatio: "goldenratio"
        }
    }

    /// Served by BundledSchemeHandler out of the app bundle.
    var bundledURL: URL {
        URL(string: "\(BundledSchemeHandler.scheme)://\(rawValue.lowercased())/index.html")!
    }
}
