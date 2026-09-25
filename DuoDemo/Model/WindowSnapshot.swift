import UIKit

/// Which physical panel the window is on.
enum Panel: String {
    case cover = "OUTSIDE"
    case inner = "INSIDE"
    case single = "SINGLE"
    case unknown = "UNKNOWN"
}

/// Where the window sits on that panel.
enum Placement: String {
    case full = "FULL"
    case left = "LEFT"
    case right = "RIGHT"
    case top = "TOP"
    case bottom = "BOTTOM"

    var isHalf: Bool { self != .full }
}

enum HingeState: String {
    case none = "No hinge"
    case unknown = "Unknown"
    case closed = "Closed"
    case partiallyOpen = "Partially open"
    case fullyOpen = "Fully open"
}

/// A reserved region reported by UIKit: the crease (`division`) or a camera cut-out (`occlusion`).
struct RegionInfo: Identifiable, Equatable {
    let id: String
    let kind: String
    let frame: CGRect
    let margins: UIEdgeInsets
    let isActive: Bool

    /// True when the region is a horizontal band (a crease you'd fold like a laptop).
    var isHorizontal: Bool { frame.width > frame.height }
}

/// Everything one window knows about itself. Recomputed by `WindowProbe`.
struct WindowSnapshot: Equatable {
    var id: String = ""
    var panel: Panel = .unknown
    var placement: Placement = .full
    var hinge: HingeState = .none
    var hingeAngleDegrees: Double? = nil
    var orientation: String = "unknown"
    var isLandscape = false
    var screenSize: CGSize = .zero
    var windowFrame: CGRect = .zero
    var safeArea: UIEdgeInsets = .zero
    var verticalBarEdge: String = "unspecified"
    var horizontalSizeClass: String = "?"
    var verticalSizeClass: String = "?"
    var divisions: [RegionInfo] = []
    var occlusions: [RegionInfo] = []
    var foldTransitions = 0

    var isReady: Bool { !id.isEmpty }

    /// The word shown in huge letters on the Position tab.
    var primaryWord: String {
        placement.isHalf ? placement.rawValue : panel.rawValue
    }

    /// The smaller line under it.
    var secondaryLine: String {
        var parts: [String] = []
        switch panel {
        case .cover: parts.append("outside (cover display)")
        case .inner: parts.append("inside (inner display)")
        case .single: parts.append("single screen")
        case .unknown: parts.append("panel unknown")
        }
        parts.append(placement.isHalf ? "\(placement.rawValue.lowercased()) half" : "full width")
        parts.append(isLandscape ? "landscape" : "portrait")
        return parts.joined(separator: " · ")
    }

    /// The active crease, if there is one inside this window.
    var activeDivision: RegionInfo? { divisions.first { $0.isActive } }

    /// Where this window sits relative to the crease: "spans", "left of", "right of", "above", "below" or nil.
    var creaseRelation: String? {
        guard let d = divisions.first else { return nil }
        let w = windowFrame.width, h = windowFrame.height
        if d.isActive, d.frame.intersects(CGRect(x: 0, y: 0, width: w, height: h)) { return "spans the crease" }
        if d.isHorizontal {
            if d.frame.midY >= h { return "above the crease" }
            if d.frame.midY <= 0 { return "below the crease" }
        } else {
            if d.frame.midX >= w { return "left of the crease" }
            if d.frame.midX <= 0 { return "right of the crease" }
        }
        return "crease inactive"
    }
}

extension CGSize {
    var pointsLabel: String { "\(Int(width.rounded())) × \(Int(height.rounded()))" }
}

extension CGRect {
    var pointsLabel: String {
        "(\(Int(minX.rounded())), \(Int(minY.rounded()))) \(size.pointsLabel)"
    }
}

extension UIEdgeInsets {
    var pointsLabel: String {
        "T \(Int(top.rounded()))  L \(Int(left.rounded()))  B \(Int(bottom.rounded()))  R \(Int(right.rounded()))"
    }
}
