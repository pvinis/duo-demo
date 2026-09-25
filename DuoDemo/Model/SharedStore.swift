import Foundation
import Observation

/// State shared by every window of this process. Two side-by-side copies of the app are two
/// `UIWindowScene`s in one process, so a plain singleton is all the "communication" we need.
@Observable
final class SharedStore {
    static let shared = SharedStore()

    // Values that are simply mirrored in every window.
    var segment = 0
    var hue = 0.58
    var level = 0.5

    /// The lamp toggle as seen from the *primary* window (left / top / first). Every other
    /// window shows the inverse, so the two sides are always opposite.
    var primaryLampOn = true

    /// Every live window, keyed by its scene session id.
    private(set) var windows: [String: WindowSnapshot] = [:]
    private(set) var registrationOrder: [String] = []

    /// Window id → time of the last ping it received.
    var pings: [String: Date] = [:]
    var pingsSent = 0

    /// Window id → tab it has been asked to switch to.
    var tabRequests: [String: AppTab] = [:]

    // MARK: Registry

    func register(_ snapshot: WindowSnapshot) {
        guard snapshot.isReady else { return }
        if !registrationOrder.contains(snapshot.id) { registrationOrder.append(snapshot.id) }
        windows[snapshot.id] = snapshot
    }

    func unregister(_ id: String) {
        windows[id] = nil
        registrationOrder.removeAll { $0 == id }
        pings[id] = nil
        tabRequests[id] = nil
    }

    /// Windows ordered left→right / top→bottom, falling back to creation order.
    var orderedWindows: [WindowSnapshot] {
        registrationOrder.compactMap { windows[$0] }.sorted { a, b in
            rank(a.placement) != rank(b.placement)
                ? rank(a.placement) < rank(b.placement)
                : (registrationOrder.firstIndex(of: a.id) ?? 0) < (registrationOrder.firstIndex(of: b.id) ?? 0)
        }
    }

    private func rank(_ p: Placement) -> Int {
        switch p {
        case .left, .top: 0
        case .full: 1
        case .right, .bottom: 2
        }
    }

    func isPrimary(_ id: String) -> Bool { orderedWindows.first?.id == id }

    func others(than id: String) -> [WindowSnapshot] { orderedWindows.filter { $0.id != id } }

    // MARK: Inverse toggle

    func lampValue(for id: String) -> Bool {
        isPrimary(id) ? primaryLampOn : !primaryLampOn
    }

    func setLamp(_ on: Bool, for id: String) {
        primaryLampOn = isPrimary(id) ? on : !on
    }

    // MARK: Messages

    func ping(from id: String) {
        let now = Date()
        for other in others(than: id) { pings[other.id] = now }
        pingsSent += 1
    }

    func send(_ tab: AppTab, from id: String) {
        for other in others(than: id) { tabRequests[other.id] = tab }
    }
}
