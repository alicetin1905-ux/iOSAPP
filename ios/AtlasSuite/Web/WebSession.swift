import Foundation
import Observation
import WebKit

/// Which copy of a dashboard a tab is showing.
enum ContentSource: String {
    case live      // GitHub Pages
    case bundled   // copy shipped inside the app
}

/// Owns one long-lived `WKWebView` — one per tab.
///
/// The web views are created once and kept for the lifetime of the app rather
/// than rebuilt when SwiftUI re-renders. That matters here: CRUCIBLE holds open
/// WebSockets to four exchanges, and tearing the view down on every tab switch
/// would drop those feeds and restart the liquidation tape from empty.
@MainActor
@Observable
final class WebSession {
    let module: Module

    private(set) var isLoading = false
    private(set) var didLoadOnce = false
    private(set) var errorMessage: String?
    private(set) var source: ContentSource = .live

    let webView: WKWebView
    @ObservationIgnored private var navigationHandler: NavigationHandler!
    @ObservationIgnored private var notificationBridge: NotificationBridge!

    /// When the app was last backgrounded, used to decide whether feeds went stale.
    private var backgroundedAt: Date?

    init(module: Module) {
        self.module = module

        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(BundledSchemeHandler(), forURLScheme: BundledSchemeHandler.scheme)
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        // The shared store matches the browser: all three pages are served from
        // the same github.io origin, so they already share localStorage there.
        // Their keys are namespaced ("atlas-desk-v1", "crucible.*"), so nothing collides.
        config.websiteDataStore = .default()

        // Give the page a working Notification API (see NotificationBridge).
        notificationBridge = NotificationBridge()
        config.userContentController.addUserScript(NotificationBridge.userScript)
        config.userContentController.addScriptMessageHandler(
            notificationBridge,
            contentWorld: .page,
            name: NotificationBridge.handlerName
        )

        webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = Theme.uiChrome()
        webView.scrollView.backgroundColor = Theme.uiChrome()
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.allowsBackForwardNavigationGestures = false
        // Lets Safari's Web Inspector attach to a debug build on a connected Mac.
        #if DEBUG
        webView.isInspectable = true
        #endif

        navigationHandler = NavigationHandler(session: self)
        webView.navigationDelegate = navigationHandler
        webView.uiDelegate = navigationHandler
    }

    // MARK: - Loading

    func loadIfNeeded(isOnline: Bool) {
        guard !didLoadOnce else { return }
        load(source: isOnline ? .live : .bundled)
    }

    func load(source: ContentSource) {
        self.source = source
        errorMessage = nil
        isLoading = true
        didLoadOnce = true

        switch source {
        case .live:
            var request = URLRequest(url: module.remoteURL)
            // GitHub Pages serves these with `cache-control: max-age=600`, so the
            // default policy would keep showing a stale page for ten minutes after
            // a push. Note `.reloadRevalidatingCacheData` is documented as
            // unimplemented and quietly falls back to the default — this one is
            // the policy that actually goes to the origin.
            request.cachePolicy = .reloadIgnoringLocalCacheData
            webView.load(request)
        case .bundled:
            webView.load(URLRequest(url: module.bundledURL))
        }
    }

    func reload() {
        // An explicit reload almost always means "I just pushed, show me that",
        // so bypass the cache for subresources too, not just the page itself.
        if didLoadOnce, webView.url != nil {
            isLoading = true
            errorMessage = nil
            webView.reloadFromOrigin()
            return
        }
        load(source: source)
    }

    // MARK: - Lifecycle

    func appDidEnterBackground() {
        backgroundedAt = .now
    }

    /// iOS suspends WebSocket traffic for backgrounded web views, so a tab that
    /// was away for a while is showing a frozen tape. Reload it rather than let
    /// stale prices look live.
    func appWillEnterForeground() {
        defer { backgroundedAt = nil }
        guard didLoadOnce, let backgroundedAt else { return }
        if Date.now.timeIntervalSince(backgroundedAt) > 30 {
            reload()
        }
    }

    // MARK: - Delegate callbacks

    fileprivate func navigationFinished() {
        isLoading = false
        errorMessage = nil
    }

    fileprivate func navigationFailed(_ error: any Error) {
        isLoading = false

        // Cancelled navigations are routine (a reload landing on a slower one).
        let nsError = error as NSError
        guard !(nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled) else { return }

        // If the live copy is unreachable, fall back to the one in the bundle.
        if source == .live {
            load(source: .bundled)
            errorMessage = nil
            return
        }

        errorMessage = error.localizedDescription
    }

    fileprivate func navigationStarted() {
        isLoading = true
    }
}

/// Kept separate from `WebSession` so the observable model does not have to be
/// an `NSObject` to satisfy WebKit's delegate protocols.
@MainActor
private final class NavigationHandler: NSObject, WKNavigationDelegate, WKUIDelegate {
    private weak var session: WebSession?

    init(session: WebSession) {
        self.session = session
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        session?.navigationStarted()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        session?.navigationFinished()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
        session?.navigationFailed(error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
        session?.navigationFailed(error)
    }

    /// Keep the dashboards in the app; send anything else to Safari.
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }

        let isDashboard = url.host?.hasSuffix("github.io") == true
            || url.scheme == BundledSchemeHandler.scheme
            || url.scheme == "about"

        if navigationAction.navigationType == .linkActivated && !isDashboard {
            decisionHandler(.cancel)
            UIApplication.shared.open(url)
            return
        }
        decisionHandler(.allow)
    }

    /// `target="_blank"` links have no window to open into; route them to Safari.
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if let url = navigationAction.request.url {
            UIApplication.shared.open(url)
        }
        return nil
    }
}
