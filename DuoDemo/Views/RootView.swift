import SwiftUI

struct RootView: View {
    @State private var env = DuoEnvironment()
    private let store = SharedStore.shared

    var body: some View {
        TabView(selection: $env.tab) {
            Tab(AppTab.position.title, systemImage: AppTab.position.symbol, value: .position) { PositionTab() }
            Tab(AppTab.sync.title, systemImage: AppTab.sync.symbol, value: .sync) { SyncTab() }
            Tab(AppTab.hinge.title, systemImage: AppTab.hinge.symbol, value: .hinge) { HingeTab() }
            Tab(AppTab.layout.title, systemImage: AppTab.layout.symbol, value: .layout) { LayoutTab() }
            Tab(AppTab.about.title, systemImage: AppTab.about.symbol, value: .about) { AboutTab() }
        }
        .background { WindowProbe(env: env, store: store).ignoresSafeArea() }
        .overlay { RegionsOverlay() }
        .overlay { PingFlash() }
        .environment(env)
        .environment(store)
        .onChange(of: store.tabRequests[env.snapshot.id]) { _, requested in
            guard let requested else { return }
            withAnimation { env.tab = requested }
            store.tabRequests[env.snapshot.id] = nil
        }
    }
}

/// Draws the reserved regions (crease, camera cut-outs) on top of the whole window.
struct RegionsOverlay: View {
    @Environment(DuoEnvironment.self) private var env

    var body: some View {
        if env.showRegions {
            GeometryReader { proxy in
                let origin = proxy.frame(in: .global).origin
                ForEach(env.snapshot.divisions + env.snapshot.occlusions) { region in
                    Rectangle()
                        .fill(color(for: region))
                        .overlay {
                            Rectangle().strokeBorder(color(for: region).opacity(1), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                        }
                        .frame(width: region.frame.width, height: region.frame.height)
                        .position(x: region.frame.midX - origin.x, y: region.frame.midY - origin.y)
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }

    private func color(for region: RegionInfo) -> Color {
        let base: Color = region.kind == "division" ? .orange : .pink
        return base.opacity(region.isActive ? 0.45 : 0.2)
    }
}

/// Flashes the whole window when the other window pings us.
struct PingFlash: View {
    @Environment(DuoEnvironment.self) private var env
    @Environment(SharedStore.self) private var store
    @State private var visible = false

    var body: some View {
        Rectangle()
            .fill(.tint)
            .opacity(visible ? 0.55 : 0)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .onChange(of: store.pings[env.snapshot.id]) { _, new in
                guard new != nil else { return }
                withAnimation(.easeOut(duration: 0.15)) { visible = true }
                withAnimation(.easeIn(duration: 0.6).delay(0.15)) { visible = false }
            }
    }
}
