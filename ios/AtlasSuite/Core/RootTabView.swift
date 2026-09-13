import SwiftUI

struct RootTabView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        TabView(selection: $appState.selectedModule) {
            ForEach(Module.allCases) { module in
                DashboardTab(module: module)
                    .tabItem { Label(module.tabLabel, systemImage: module.systemImage) }
                    .tag(module)
            }
        }
        .tint(appState.selectedModule.tint)
        .onAppear { appState.applyIdleTimer() }
        .onChange(of: appState.selectedModule) { _, _ in appState.applyIdleTimer() }
        .onChange(of: appState.keepScreenAwake) { _, _ in appState.applyIdleTimer() }
    }
}
