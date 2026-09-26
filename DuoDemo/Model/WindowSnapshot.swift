import UIKit

/// Which physical panel the window is on.
enum Panel {
    case cover
    /// The cover display while the phone is open: only a camera-capture accessory scene lives here.
    case coverWhileOpen
    case inner
    case single
    case unknown

    /// The big word.
    var word: String {
        switch self {
        case .cover, .coverWhileOpen: "OUTSIDE"
        case .inner: "INSIDE"
        case .single: "SINGLE"
        case .unknown: "UNKNOWN"
        }
    }

    /// A short lowercase description.
    var name: String {
        switch self {
        case .cover: "outside"
        case .coverWhileOpen: "outside (inside open)"
        case .inner: "inside"
        case .single: "single screen"
        case .unknown: "unknown"
        }
    }
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
    /// Which signal decided `placement`.
    var placementSource: String = "screen frame"
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
        placement.isHalf ? placement.rawValue : panel.word
    }

    /// The smaller line under it.
    var secondaryLine: String {
        var parts: [String] = []
        switch panel {
        case .cover: parts.append("outside (cover display)")
        case .coverWhileOpen: parts.append("outside, while the inside is open")
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
    ///
    /// The crease is reported even when it is *inactive* for this window (it then sits on one of
    /// the window's edges), which is what tells a half-width window which half it is.
    var creaseRelation: String? {
        guard let side = creaseSide else { return nil }
        switch side {
        case .full: return "spans the crease"
        case .left: return "left of the crease"
        case .right: return "right of the crease"
        case .top: return "above the crease"
        case .bottom: return "below the crease"
        }
    }

    /// `.full` when the crease runs through the window, otherwise the half this window occupies.
    var creaseSide: Placement? {
        guard let d = divisions.first else { return nil }
        let w = windowFrame.width, h = windowFrame.height
        let inside = CGRect(x: 0, y: 0, width: w, height: h).insetBy(dx: 8, dy: 8)
        if d.isActive || inside.contains(CGPoint(x: d.frame.midX, y: d.frame.midY)) { return .full }
        if d.isHorizontal {
            return d.frame.midY > h / 2 ? .top : .bottom
        } else {
            return d.frame.midX > w / 2 ? .left : .right
        }
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
