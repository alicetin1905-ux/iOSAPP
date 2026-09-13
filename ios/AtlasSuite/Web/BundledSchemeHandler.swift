import Foundation
import WebKit

/// Serves the bundled copies of the dashboards under a custom scheme.
///
/// A custom scheme is used rather than `file://` on purpose: pages loaded from
/// `file://` get the opaque "null" origin, which WKWebView blocks from making
/// cross-origin requests unless private preference keys are flipped. A custom
/// scheme gives the page a real origin, so its normal `fetch` calls to the
/// exchange APIs succeed against their `Access-Control-Allow-Origin: *` headers.
final class BundledSchemeHandler: NSObject, WKURLSchemeHandler {
    static let scheme = "bundled"

    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        guard
            let url = urlSchemeTask.request.url,
            let host = url.host,
            let module = Module(rawValue: normalizedModuleID(host)),
            let path = Bundle.main.path(forResource: module.bundledResource, ofType: "html"),
            let data = FileManager.default.contents(atPath: path)
        else {
            urlSchemeTask.didFailWithError(
                NSError(
                    domain: "BundledSchemeHandler",
                    code: 404,
                    userInfo: [NSLocalizedDescriptionKey: "No bundled copy for \(urlSchemeTask.request.url?.absoluteString ?? "?")"]
                )
            )
            return
        }

        let response = URLResponse(
            url: url,
            mimeType: "text/html",
            expectedContentLength: data.count,
            textEncodingName: "utf-8"
        )
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {
        // Nothing to cancel: responses are served synchronously from the bundle.
    }

    /// URL hosts are lowercased by the loader, so map back to the enum's casing.
    private func normalizedModuleID(_ host: String) -> String {
        Module.allCases.first { $0.rawValue.lowercased() == host }?.rawValue ?? host
    }
}
