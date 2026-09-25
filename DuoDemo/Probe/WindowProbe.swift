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
        s.placement = placement(window: s.windowFrame, screen: screen.bounds)

        s.verticalBarEdge = Self.name(traitCollection.verticalBarEdge)
        s.horizontalSizeClass = Self.name(traitCollection.horizontalSizeClass)
        s.verticalSizeClass = Self.name(traitCollection.verticalSizeClass)

        s.divisions = window.reservedRegions(kind: .division, options: [.includeInactive]).map { Self.info($0, kind: "division") }
        s.occlusions = window.reservedRegions(kind: .occlusion, options: [.includeInactive]).map { Self.info($0, kind: "occlusion") }

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
        switch hinge {
        case .closed: return .cover
        case .fullyOpen, .partiallyOpen: return .inner
        case .none: return .single
        case .unknown:
            // Fall back to the panel's size: the inner display has roughly twice the area.
            let area = screenSize.width * screenSize.height
            return area > 500_000 ? .inner : .cover
        }
    }

    private func placement(window: CGRect, screen: CGRect) -> Placement {
        let tolerance: CGFloat = 4
        if window.width < screen.width - tolerance {
            return window.midX < screen.midX ? .left : .right
        }
        if window.height < screen.height - tolerance {
            return window.midY < screen.midY ? .top : .bottom
        }
        return .full
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
