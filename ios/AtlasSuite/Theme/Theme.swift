import SwiftUI

/// The dashboards are dark-themed (backgrounds around #070a0f–#0a0e12), so the
/// native chrome is matched to them to avoid a bright seam around the web content.
enum Theme {
    /// Close to the darkest of the four page backgrounds.
    static let chrome = Color(red: 0.027, green: 0.039, blue: 0.059)

    static func uiChrome() -> UIColor {
        UIColor(red: 0.027, green: 0.039, blue: 0.059, alpha: 1)
    }
}
