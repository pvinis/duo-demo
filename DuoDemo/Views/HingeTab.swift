import SwiftUI

struct HingeTab: View {
    @Environment(DuoEnvironment.self) private var env
    /// The same hinge as seen through SwiftUI's own modifier, for comparison with the UIKit probe.
    @State private var swiftUIHinge: DeviceHinge?

    private var snapshot: WindowSnapshot { env.snapshot }
    private var angle: Double { snapshot.hingeAngleDegrees ?? 0 }

    /// Laptop mode: hinge partially open and the crease runs horizontally through this window.
    private var laptopCrease: RegionInfo? {
        guard snapshot.hinge == .partiallyOpen, let d = snapshot.activeDivision, d.isHorizontal else { return nil }
        return d
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let local = proxy.frame(in: .global)
                if let crease = laptopCrease {
                    // Split the content on the crease: gauge above, controls below.
                    let top = max(0, crease.frame.minY - local.minY)
                    let bottom = max(0, local.maxY - crease.frame.maxY)
                    VStack(spacing: 0) {
                        gauge.frame(height: top)
                        Rectangle().fill(.orange.opacity(0.3)).frame(height: crease.frame.height)
                            .overlay { Text("crease").font(.caption2).foregroundStyle(.secondary) }
                        readout.frame(height: bottom)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            gauge.frame(height: min(320, proxy.size.height * 0.5))
                            readout
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Hinge")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onHingeChange { _, context in
            swiftUIHinge = context.hinge
        }
    }

    private var swiftUIHingeLabel: String {
        guard let h = swiftUIHinge else { return "nil (no hinge)" }
        let status: String = switch h.status {
        case .closed: "closed"
        case .partiallyOpen: "partiallyOpen"
        case .fullyOpen: "fullyOpen"
        default: "unknown"
        }
        return "\(status), \(Int(h.angle.degrees.rounded()))°"
    }

    private var gauge: some View {
        Canvas { context, size in
            let length = min(size.width, size.height) * 0.42
            let pivot = CGPoint(x: size.width / 2, y: size.height * 0.62)
            let radians = angle * .pi / 180
            // Panel A points left; panel B swings from A by the hinge angle.
            let a = CGPoint(x: pivot.x - length, y: pivot.y)
            let b = CGPoint(x: pivot.x - length * cos(radians), y: pivot.y - length * sin(radians))

            var arc = Path()
            arc.move(to: pivot)
            arc.addArc(center: pivot, radius: length * 0.45, startAngle: .degrees(180), endAngle: .degrees(180 - angle), clockwise: true)
            arc.closeSubpath()
            context.fill(arc, with: .color(.orange.opacity(0.25)))

            var panels = Path()
            panels.move(to: a)
            panels.addLine(to: pivot)
            panels.addLine(to: b)
            context.stroke(panels, with: .color(.primary), style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))
            context.fill(Path(ellipseIn: CGRect(x: pivot.x - 9, y: pivot.y - 9, width: 18, height: 18)), with: .color(.orange))
        }
        .overlay(alignment: .top) {
            VStack(spacing: 4) {
                Text(snapshot.hingeAngleDegrees.map { "\(Int($0.rounded()))°" } ?? "—")
                    .font(.system(size: 64, weight: .black, design: .rounded))
                    .contentTransition(.numericText())
                    .animation(.snappy, value: Int(angle))
                Text(snapshot.hinge.rawValue)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)
        }
    }

    private var readout: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What the app sees").font(.headline)
            Text(explanation).foregroundStyle(.secondary)
            Divider()
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow { Text("Status").foregroundStyle(.secondary); Text(snapshot.hinge.rawValue) }
                GridRow { Text("Angle").foregroundStyle(.secondary); Text(snapshot.hingeAngleDegrees.map { String(format: "%.1f°", $0) } ?? "n/a") }
                GridRow { Text("Panel").foregroundStyle(.secondary); Text(snapshot.panel.name.capitalized) }
                GridRow { Text("Crease").foregroundStyle(.secondary); Text(snapshot.creaseRelation ?? "none reported") }
                GridRow { Text("SwiftUI").foregroundStyle(.secondary); Text("onHingeChange → \(swiftUIHingeLabel)") }
            }
            .font(.callout.monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.background.secondary, in: .rect(cornerRadius: 16))
        .padding(.horizontal)
    }

    private var explanation: String {
        switch snapshot.hinge {
        case .none:
            "No hinge here. This is a regular single-screen iPhone, or the view isn't in a hierarchy that reports hinge updates."
        case .unknown:
            "There is a hinge but its state hasn't been reported yet."
        case .closed:
            "Closed: you're looking at the cover display. Fold the phone open to move to the inner display."
        case .partiallyOpen:
            "Partially open. If the crease runs horizontally this tab lays itself out laptop-style, gauge above the crease and controls below it."
        case .fullyOpen:
            "Fully open: the inner display is flat. Nothing to avoid except the crease region shown on the Layout tab."
        }
    }
}
