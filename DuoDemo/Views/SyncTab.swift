import SwiftUI

struct SyncTab: View {
    @Environment(DuoEnvironment.self) private var env
    @Environment(SharedStore.self) private var store
    @Environment(\.openWindow) private var openWindow
    @Environment(\.supportsMultipleWindows) private var supportsMultipleWindows

    private var myID: String { env.snapshot.id }
    private var others: [WindowSnapshot] { store.others(than: myID) }

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            Form {
                Section {
                    Picker("Shared segment", selection: $store.segment) {
                        Text("One").tag(0)
                        Text("Two").tag(1)
                        Text("Three").tag(2)
                    }
                    .pickerStyle(.segmented)

                    HStack {
                        Text("Shared colour")
                        Spacer()
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(hue: store.hue, saturation: 0.8, brightness: 0.9))
                            .frame(width: 44, height: 24)
                    }
                    Slider(value: $store.hue, in: 0...1)

                    LabeledContent("Shared level", value: store.level, format: .percent.precision(.fractionLength(0)))
                    Slider(value: $store.level, in: 0...1)
                } header: {
                    Text("Mirrored in every window")
                } footer: {
                    Text("Change any of these here and the other window follows instantly.")
                }

                Section {
                    Toggle("This side's lamp", isOn: Binding(
                        get: { store.lampValue(for: myID) },
                        set: { store.setLamp($0, for: myID) }
                    ))
                    Label(
                        store.lampValue(for: myID) ? "On here, so the other side is off." : "Off here, so the other side is on.",
                        systemImage: store.lampValue(for: myID) ? "lightbulb.fill" : "lightbulb"
                    )
                    .foregroundStyle(.secondary)
                } header: {
                    Text("Always the inverse")
                } footer: {
                    Text("The left / top window holds the real value; every other window shows the opposite.")
                }

                Section {
                    Button {
                        store.ping(from: myID)
                    } label: {
                        Label("Ping the other window", systemImage: "dot.radiowaves.left.and.right")
                    }
                    .disabled(others.isEmpty)

                    Menu {
                        ForEach(AppTab.allCases) { tab in
                            Button(tab.title, systemImage: tab.symbol) { store.send(tab, from: myID) }
                        }
                    } label: {
                        Label("Send the other window to a tab", systemImage: "arrowshape.turn.up.right")
                    }
                    .disabled(others.isEmpty)

                    if supportsMultipleWindows {
                        Button {
                            openWindow(id: "main")
                        } label: {
                            Label("Open another window", systemImage: "plus.rectangle.on.rectangle")
                        }
                    }
                } header: {
                    Text("Talk to the other window")
                } footer: {
                    Text(others.isEmpty
                         ? "Only one window is open. Open a second one and put the two side by side."
                         : "Pings sent from anywhere: \(store.pingsSent).")
                }

                Section("Windows in this process") {
                    ForEach(store.orderedWindows, id: \.id) { w in
                        HStack {
                            Image(systemName: w.id == myID ? "app.badge.checkmark" : "app")
                            VStack(alignment: .leading) {
                                Text(w.id == myID ? "This window" : "Other window").fontWeight(.medium)
                                Text(w.secondaryLine).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(w.primaryWord).font(.caption.weight(.bold)).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Sync")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
