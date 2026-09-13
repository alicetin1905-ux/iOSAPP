import SwiftUI
import Observation

@MainActor
@Observable
final class AppState {
    /// The live board is the main tab, so the app opens on it.
    var selectedModule: Module = .liveBoard

    /// The live board is meant to be left running and glanced at, so the screen
    /// is held awake while it is on screen. The other tabs are read and then put
    /// away, and holding the screen awake there would just drain the battery.
    var keepScreenAwake = true

    let network = NetworkMonitor()

    @ObservationIgnored private var sessions: [Module: WebSession] = [:]

    /// Sessions are created lazily — the first time a tab is shown — so launching
    /// the app opens one set of sockets, not four.
    func session(for module: Module) -> WebSession {
        if let existing = sessions[module] { return existing }
        let session = WebSession(module: module)
        sessions[module] = session
        return session
    }

    func appDidEnterBackground() {
        sessions.values.forEach { $0.appDidEnterBackground() }
        UIApplication.shared.isIdleTimerDisabled = false
    }

    func appWillEnterForeground() {
        sessions.values.forEach { $0.appWillEnterForeground() }
        applyIdleTimer()
    }

    /// Driven from the view layer rather than a `didSet`: `@Observable` rewrites
    /// stored properties into computed ones, which cannot carry property observers.
    func applyIdleTimer() {
        UIApplication.shared.isIdleTimerDisabled = keepScreenAwake && selectedModule == .liveBoard
    }
}
