import Foundation
import Network
import Observation

/// Passive connectivity observation for the privacy-proof surfaces: NWPathMonitor
/// only watches interface state and creates no traffic of its own, so the proof
/// screen can say "you're offline" without contradicting itself. One instance
/// per surface; start on appear, cancel on disappear.
@MainActor
@Observable
final class ConnectivityMonitor {
    private(set) var isOffline = false
    private var monitor: NWPathMonitor?

    func start() {
        guard monitor == nil else { return }
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            let offline = path.status != .satisfied
            Task { @MainActor in self?.isOffline = offline }
        }
        monitor.start(queue: DispatchQueue(label: "app.inward.connectivity"))
        self.monitor = monitor
    }

    func stop() {
        monitor?.cancel()
        monitor = nil
    }
}
