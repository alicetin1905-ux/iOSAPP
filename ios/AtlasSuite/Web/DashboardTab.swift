import SwiftUI

/// One tab: the dashboard itself plus the native chrome around it.
struct DashboardTab: View {
    let module: Module

    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState
        let session = appState.session(for: module)

        NavigationStack {
            ZStack {
                Theme.chrome.ignoresSafeArea()

                DashboardWebView(session: session)
                    .opacity(session.errorMessage == nil ? 1 : 0)

                if let error = session.errorMessage {
                    FailureView(module: module, message: error) {
                        session.load(source: .live)
                    }
                }

                if session.isLoading && !session.didLoadOnce {
                    ProgressView().controlSize(.large).tint(module.tint)
                }
            }
            .navigationTitle(module.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.chrome, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if session.isLoading && session.didLoadOnce {
                        ProgressView().controlSize(.small).tint(module.tint)
                    } else if session.source == .bundled {
                        Label("Offline copy", systemImage: "arrow.down.circle")
                            .labelStyle(.iconOnly)
                            .foregroundStyle(.orange)
                            .accessibilityLabel("Showing the copy bundled in the app")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Reload", systemImage: "arrow.clockwise") { session.reload() }

                        Picker("Source", selection: sourceBinding(for: session)) {
                            Label("Live (GitHub Pages)", systemImage: "antenna.radiowaves.left.and.right")
                                .tag(ContentSource.live)
                            Label("Bundled copy", systemImage: "internaldrive")
                                .tag(ContentSource.bundled)
                        }

                        Divider()

                        // The idle timer is only held on the live board, so the
                        // toggle would be a no-op anywhere else.
                        if module == .liveBoard {
                            Toggle("Keep screen awake", systemImage: "sun.max", isOn: $appState.keepScreenAwake)
                            Divider()
                        }

                        Button("Open in Safari", systemImage: "safari") {
                            UIApplication.shared.open(module.remoteURL)
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .tint(module.tint)
                }
            }
        }
        .onAppear { session.loadIfNeeded(isOnline: appState.network.isOnline) }
    }

    private func sourceBinding(for session: WebSession) -> Binding<ContentSource> {
        Binding(
            get: { session.source },
            set: { session.load(source: $0) }
        )
    }
}

/// Shown only when both the live page and the bundled copy failed.
private struct FailureView: View {
    let module: Module
    let message: String
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("\(module.title) didn't load", systemImage: "wifi.exclamationmark")
        } description: {
            Text(message)
        } actions: {
            Button("Try again", action: retry)
                .buttonStyle(.borderedProminent)
                .tint(module.tint)
        }
    }
}
