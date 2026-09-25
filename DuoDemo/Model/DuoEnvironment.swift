import Foundation
import Observation

/// Per-window state: this window's latest snapshot plus a few UI toggles.
@Observable
final class DuoEnvironment {
    var snapshot = WindowSnapshot()
    var tab: AppTab = .position
    var showRegions = false
    var lastTapSide: String?
}
