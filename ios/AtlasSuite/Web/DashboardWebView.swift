import SwiftUI
import WebKit

/// Hosts a `WebSession`'s long-lived web view. The view is never rebuilt — only
/// re-parented — so the page keeps running across tab switches.
struct DashboardWebView: UIViewRepresentable {
    let session: WebSession

    func makeUIView(context: Context) -> WKWebView {
        session.webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Deliberately empty: the session owns all loading.
    }
}
