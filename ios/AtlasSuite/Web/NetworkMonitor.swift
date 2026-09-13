import Foundation
import Network
import Observation

/// Tracks reachability so a tab can fall back to its bundled copy instead of
/// showing a blank page when the device is offline.
@Observable
final class NetworkMonitor {
    private(set) var isOnline = true

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in self?.isOnline = online }
        }
        monitor.start(queue: queue)
    }

    deinit { monitor.cancel() }
}
