import SwiftUI

struct LayoutTab: View {
    @Environment(DuoEnvironment.self) private var env

    private var snapshot: WindowSnapshot { env.snapshot }

    var body: some View {
        @Bindable var env = env
        NavigationStack {
            Form {
                Section {
                    Toggle("Overlay reserved regions on the window", isOn: $env.showRegions)
                    LabeledContent("This window is", value: snapshot.creaseRelation ?? "no crease reported")
                } header: {
                    Text("Crease & cut-outs")
                } footer: {
                    Text("Orange = division (the crease). Pink = occlusion (camera). Faded = reported but inactive.")
                }

                Section("Tap test") {
                    tapPad
                }

                Section("Reserved regions") {
                    let regions = snapshot.divisions + snapshot.occlusions
                    if regions.isEmpty {
                        Text("None reported for this window.").foregroundStyle(.secondary)
                    }
                    ForEach(regions) { r in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(r.kind.capitalized).fontWeight(.medium)
                                Spacer()
                                Text(r.isActive ? "active" : "inactive")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(r.isActive ? .orange : .secondary)
                            }
                            Text("frame \(r.frame.pointsLabel)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                            Text("margins \(r.margins.pointsLabel)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Traits & insets") {
                    LabeledContent("Vertical bar edge", value: snapshot.verticalBarEdge)
                    LabeledContent("Horizontal size class", value: snapshot.horizontalSizeClass)
                    LabeledContent("Vertical size class", value: snapshot.verticalSizeClass)
                    LabeledContent("Safe area", value: snapshot.safeArea.pointsLabel)
                    LabeledContent("Orientation", value: snapshot.orientation)
                    LabeledContent("Window on screen", value: snapshot.windowFrame.pointsLabel)
                    LabeledContent("Screen", value: snapshot.screenSize.pointsLabel)
                }
            }
            .navigationTitle("Layout")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var tapPad: some View {
        GeometryReader { proxy in
            let local = proxy.frame(in: .global)
            RoundedRectangle(cornerRadius: 12)
                .fill(.blue.opacity(0.12))
                .overlay {
                    Text(env.lastTapSide ?? "Tap anywhere in here")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                }
                .contentShape(.rect)
                .onTapGesture { point in
                    let global = CGPoint(x: point.x + local.minX, y: point.y + local.minY)
                    env.lastTapSide = side(of: global)
                }
        }
        .frame(height: 120)
        .listRowInsets(EdgeInsets())
    }

    /// Which side of the crease a point (in window coordinates) is on.
    private func side(of p: CGPoint) -> String {
        guard let d = snapshot.divisions.first else { return "No crease to compare with" }
        let f = d.frame
        if d.isHorizontal {
            if p.y < f.minY { return "Above the crease" }
            if p.y > f.maxY { return "Below the crease" }
            return "On the crease"
        } else {
            if p.x < f.minX { return "Left of the crease" }
            if p.x > f.maxX { return "Right of the crease" }
            return "On the crease"
        }
    }
}
