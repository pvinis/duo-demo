import SwiftUI
import UIKit

/// An invisible UIKit view that sits behind the SwiftUI root and turns what UIKit knows about
/// the window (hinge, reserved regions, traits, frame on screen) into a `WindowSnapshot`.
struct WindowProbe: UIViewRepresentable {
    let env: DuoEnvironment
    let store: SharedStore

    func makeUIView(context: Context) -> ProbeView {
        let view = ProbeView()
        view.env = env
        view.store = store
        return view
    }

    func updateUIView(_ uiView: ProbeView, context: Context) {}

    static func dismantleUIView(_ uiView: ProbeView, coordinator: ()) {
        uiView.tearDown()
    }
}

final class ProbeView: UIView {
    weak var env: DuoEnvironment?
    weak var store: SharedStore?

    private var hinge: UIHinge?
    private var hingeSeen = false
    private var lastPanel: Panel = .unknown
    private var foldTransitions = 0
    private var disconnectObserver: (any NSObjectProtocol)?
    private var lastPublished: WindowSnapshot?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear

        // Live hinge state. The handler fires with the initial state and on every change.
        let interaction = UIHingeInteraction { [weak self] _, update in
            guard let self else { return }
            self.hinge = update.hinge
            if update.hinge != nil { self.hingeSeen = true }
            self.recompute()
        }
        addInteraction(interaction)

        // The system tells us which traits can move the tab bar to a vertical edge.
        registerForTraitChanges(UITraitCollection.systemTraitsAffectingVerticalBarEdge) { (self: ProbeView, _) in
            self.recompute()
        }
        registerForTraitChanges([UITraitHorizontalSizeClass.self, UITraitVerticalSizeClass.self]) { (self: ProbeView, _) in
            self.recompute()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if let scene = window?.windowScene, disconnectObserver == nil {
            disconnectObserver = NotificationCenter.default.addObserver(
                forName: UIScene.didDisconnectNotification, object: scene, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.tearDown() }
            }
        }
        recompute()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        recompute()
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        recompute()
    }

    func tearDown() {
        if let id = lastPublished?.id { store?.unregister(id) }
        if let disconnectObserver { NotificationCenter.default.removeObserver(disconnectObserver) }
        disconnectObserver = nil
    }

    // MARK: - Snapshot

    func recompute() {
        guard let window, let scene = window.windowScene else { return }
        let screen = window.screen

        var s = WindowSnapshot()
        s.id = scene.session.persistentIdentifier
        s.screenSize = screen.bounds.size
        s.windowFrame = window.convert(window.bounds, to: screen.coordinateSpace)
        s.safeArea = window.safeAreaInsets

        let orientation = scene.effectiveGeometry.interfaceOrientation
        s.orientation = Self.name(orientation)
        s.isLandscape = orientation.isLandscape

        if let hinge {
            s.hinge = Self.state(hinge.status)
            s.hingeAngleDegrees = Double(hinge.angle) * 180 / .pi
        } else {
            s.hinge = hingeSeen ? .unknown : .none
        }

        s.panel = panel(hinge: s.hinge, screenSize: s.screenSize)

        s.verticalBarEdge = Self.name(traitCollection.verticalBarEdge)
        s.horizontalSizeClass = Self.name(traitCollection.horizontalSizeClass)
        s.verticalSizeClass = Self.name(traitCollection.verticalSizeClass)

        s.divisions = window.reservedRegions(kind: .division, options: [.includeInactive]).map { Self.info($0, kind: "division") }
        s.occlusions = window.reservedRegions(kind: .occlusion, options: [.includeInactive]).map { Self.info($0, kind: "occlusion") }

        (s.placement, s.placementSource) = placement(for: s, screen: screen.bounds)

        if s.panel == .cover || s.panel == .inner {
            if lastPanel != .unknown, lastPanel != s.panel { foldTransitions += 1 }
            lastPanel = s.panel
        }
        s.foldTransitions = foldTransitions

        guard s != lastPublished else { return }
        lastPublished = s
        env?.snapshot = s
        store?.register(s)
    }

    private func panel(hinge: HingeState, screenSize: CGSize) -> Panel {
        // The inner display has roughly twice the area of the cover display.
        let onSmallPanel = screenSize.width * screenSize.height < 500_000
        switch hinge {
        case .closed: return .cover
        case .fullyOpen, .partiallyOpen:
            // Open, yet our screen is the small one: we are the camera-capture accessory on the cover.
            return onSmallPanel ? .coverWhileOpen : .inner
        case .none: return .single
        case .unknown: return onSmallPanel ? .cover : .inner
        }
    }

    /// A scene's window is always at (0, 0) in its own coordinate space, so the frame alone only
    /// says *whether* we are a half, not which one. For that we use, in order of preference:
    /// 1. the crease: UIKit reports the (inactive) division region on the edge that faces it;
    /// 2. the vertical bar edge: the system puts the tab bar on the edge away from the crease;
    /// 3. the frame's centre, which works if a future OS ever reports real screen positions.
    private func placement(for s: WindowSnapshot, screen: CGRect) -> (Placement, String) {
        let tolerance: CGFloat = 4
        let window = s.windowFrame
        let horizontalSplit = window.width < screen.width - tolerance
        let verticalSplit = !horizontalSplit && window.height < screen.height - tolerance
        guard horizontalSplit || verticalSplit else { return (.full, "full-size window") }

        if let side = s.creaseSide, side != .full {
            return (side, "crease region")
        }
        if horizontalSplit {
            let rtl = traitCollection.layoutDirection == .rightToLeft
            switch traitCollection.verticalBarEdge {
            case .leading: return (rtl ? .right : .left, "vertical bar edge")
            case .trailing: return (rtl ? .left : .right, "vertical bar edge")
            default: break
            }
            return (window.midX < screen.midX ? .left : .right, "screen frame")
        }
        return (window.midY < screen.midY ? .top : .bottom, "screen frame")
    }

    // MARK: - Naming helpers

    private static func info(_ r: UIView.ReservedRegion, kind: String) -> RegionInfo {
        RegionInfo(id: "\(kind)-\(r.id)", kind: kind, frame: r.frame, margins: r.margins, isActive: r.isActive)
    }

    private static func state(_ status: UIHinge.Status) -> HingeState {
        switch status {
        case .closed: .closed
        case .partiallyOpen: .partiallyOpen
        case .fullyOpen: .fullyOpen
        case .unknown: .unknown
        @unknown default: .unknown
        }
    }

    private static func name(_ o: UIInterfaceOrientation) -> String {
        switch o {
        case .portrait: "portrait"
        case .portraitUpsideDown: "portrait (upside down)"
        case .landscapeLeft: "landscape left"
        case .landscapeRight: "landscape right"
        default: "unknown"
        }
    }

    private static func name(_ e: UIVerticalBarEdge) -> String {
        switch e {
        case .leading: "leading"
        case .trailing: "trailing"
        case .unspecified: "unspecified"
        @unknown default: "unknown"
        }
    }

    private static func name(_ c: UIUserInterfaceSizeClass) -> String {
        switch c {
        case .compact: "compact"
        case .regular: "regular"
        default: "unspecified"
        }
    }
}
