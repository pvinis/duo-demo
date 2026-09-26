import SwiftUI

struct PositionTab: View {
    @Environment(DuoEnvironment.self) private var env

    private var snapshot: WindowSnapshot { env.snapshot }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headline
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)

                    details
                        .padding(.horizontal)
                }
                .padding(.bottom, 24)
            }
            .background(tint.opacity(0.12).gradient)
            .navigationTitle("Position")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var headline: some View {
        VStack(spacing: 8) {
            Text(snapshot.primaryWord)
                .font(.system(size: 140, weight: .black, design: .rounded))
                .minimumScaleFactor(0.2)
                .lineLimit(1)
                .foregroundStyle(tint)
                .contentTransition(.numericText())
                .animation(.snappy, value: snapshot.primaryWord)
            Text(snapshot.secondaryLine)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal)
    }

    private var details: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
            row("Panel", snapshot.panel.name.capitalized)
            row("Placement", "\(snapshot.placement.rawValue.capitalized) (via \(snapshot.placementSource))")
            row("Hinge", hingeLabel)
            row("Orientation", snapshot.orientation)
            row("Window", snapshot.windowFrame.pointsLabel)
            row("Screen", snapshot.screenSize.pointsLabel)
            row("Size classes", "\(snapshot.horizontalSizeClass) × \(snapshot.verticalSizeClass)")
            row("Vertical bar", snapshot.verticalBarEdge)
            row("Fold transitions", "\(snapshot.foldTransitions)")
        }
        .font(.callout.monospacedDigit())
        .padding()
        .background(.background.secondary, in: .rect(cornerRadius: 16))
    }

    private var hingeLabel: String {
        if let angle = snapshot.hingeAngleDegrees {
            return "\(snapshot.hinge.rawValue) (\(Int(angle.rounded()))°)"
        }
        return snapshot.hinge.rawValue
    }

    private func row(_ title: String, _ value: String) -> some View {
        GridRow {
            Text(title).foregroundStyle(.secondary).gridColumnAlignment(.trailing)
            Text(value).fontWeight(.medium)
        }
    }

    private var tint: Color {
        switch snapshot.placement {
        case .left, .top: .blue
        case .right, .bottom: .orange
        case .full:
            switch snapshot.panel {
            case .cover: .green
            case .coverWhileOpen: .teal
            default: .purple
            }
        }
    }
}
