import AVFoundation
import SwiftUI
import UserNotifications

@main
struct AtlasSuiteApp: App {
    @State private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    private static let notificationPresenter = ForegroundNotificationPresenter()

    init() {
        // Alerts must show even while the dashboard is on screen.
        UNUserNotificationCenter.current().delegate = Self.notificationPresenter

        // The live board's tones are opt-in (its sound toggle starts off), so
        // honour them past the ringer switch — but mix, never interrupt.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)

        // Match the tab bar to the dashboards' near-black background so the web
        // content does not sit inside a lighter frame.
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = Theme.uiChrome()
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(appState)
                .preferredColorScheme(.dark)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background: appState.appDidEnterBackground()
            case .active: appState.appWillEnterForeground()
            default: break
            }
        }
    }
}
