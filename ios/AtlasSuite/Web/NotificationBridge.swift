import Foundation
import UserNotifications
import WebKit

/// WKWebView does not implement the Web Notifications API, so CRUCIBLE's
/// liquidation-cascade alerts would silently never fire inside the app — its
/// code guards on `typeof Notification !== "undefined"` and simply goes quiet.
///
/// This bridges the gap: a small shim defines `window.Notification`, and each
/// call is delivered as a real iOS notification. That is the main thing the app
/// gives you over the same page in a Safari tab.
@MainActor
final class NotificationBridge: NSObject {
    static let handlerName = "nativeNotification"

    /// Injected before page scripts run, so the shim is in place by the time the
    /// dashboard first checks for `Notification`.
    static var userScript: WKUserScript {
        let source = """
        (function () {
          if (window.Notification) { return; }
          var bridge = window.webkit && window.webkit.messageHandlers
            && window.webkit.messageHandlers.\(handlerName);
          if (!bridge) { return; }

          var permission = "default";

          function Notification(title, options) {
            options = options || {};
            bridge.postMessage({
              action: "post",
              title: String(title == null ? "" : title),
              body: String(options.body == null ? "" : options.body),
              tag: String(options.tag == null ? "" : options.tag)
            });
          }

          Object.defineProperty(Notification, "permission", {
            get: function () { return permission; }
          });

          Notification.requestPermission = function (callback) {
            return bridge.postMessage({ action: "request" }).then(function (result) {
              permission = result;
              if (typeof callback === "function") { callback(result); }
              return result;
            });
          };

          window.Notification = Notification;

          // Sync the initial value with whatever iOS already decided.
          bridge.postMessage({ action: "query" }).then(function (result) {
            permission = result;
          });
        })();
        """
        return WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: true)
    }

    private let center = UNUserNotificationCenter.current()

    private func currentPermission() async -> String {
        switch await center.notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral: "granted"
        case .denied: "denied"
        default: "default"
        }
    }

    private func requestPermission() async -> String {
        if await currentPermission() != "default" {
            return await currentPermission()
        }
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        return granted ? "granted" : "denied"
    }

    private func post(title: String, body: String, tag: String) async {
        guard await currentPermission() == "granted" else { return }

        let content = UNMutableNotificationContent()
        content.title = title.isEmpty ? "CRUCIBLE" : title
        content.body = body
        content.sound = .default

        // Reusing the page's tag as the identifier means a repeated alert for the
        // same symbol and side replaces the previous one rather than stacking.
        let identifier = tag.isEmpty ? UUID().uuidString : tag
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        try? await center.add(request)
    }
}

extension NotificationBridge: WKScriptMessageHandlerWithReply {
    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) async -> (Any?, String?) {
        guard let payload = message.body as? [String: Any],
              let action = payload["action"] as? String
        else {
            return (nil, "Malformed notification message")
        }

        switch action {
        case "query":
            return (await currentPermission(), nil)
        case "request":
            return (await requestPermission(), nil)
        case "post":
            await post(
                title: payload["title"] as? String ?? "",
                body: payload["body"] as? String ?? "",
                tag: payload["tag"] as? String ?? ""
            )
            return (nil, nil)
        default:
            return (nil, "Unknown notification action: \(action)")
        }
    }
}

/// Without this, a notification posted while the app is open is suppressed —
/// which is exactly when a cascade alert matters most.
final class ForegroundNotificationPresenter: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}
