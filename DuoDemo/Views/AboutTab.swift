import SwiftUI

struct AboutTab: View {
    private struct Item: Identifiable {
        let id = UUID()
        let title: String
        let api: String
        let text: String
    }

    private let items: [Item] = [
        Item(title: "Outside vs inside",
             api: "UIHingeInteraction · UIHinge.status",
             text: "A hinge interaction on any view reports closed / partially open / fully open. Closed means you're on the cover display; open means the inner one. The screen's point size is used as a fallback."),
        Item(title: "Left vs right (or top vs bottom)",
             api: "UIView.convert(_:to: UIScreen.coordinateSpace)",
             text: "The window's bounds converted into screen space tell you if it is narrower than the screen and on which side its centre falls. Apple gives you the geometry, not the label."),
        Item(title: "Hinge angle",
             api: "UIHinge.angle",
             text: "Radians, delivered at a rate the system chooses. Good for a gauge or a 'laptop mode' layout, not for precision work."),
        Item(title: "The crease",
             api: "UIView.reservedRegions(kind: .division)",
             text: "The crease is a reserved region with a frame and margins in the view's coordinates. Inactive regions (crease outside this window) are included when you ask for them, which is how the app knows which side of the crease it sits on."),
        Item(title: "Camera cut-outs",
             api: "UIView.reservedRegions(kind: .occlusion)",
             text: "Same API, different kind: parts of the screen something sits in front of."),
        Item(title: "Vertical tab bar",
             api: "UITraitCollection.verticalBarEdge",
             text: "New in iOS 27.1. When the system moves the tab bar and status bar to a vertical edge, this trait says which one. Register for systemTraitsAffectingVerticalBarEdge to be told when it changes."),
        Item(title: "Outside while the inside is open",
             api: "sceneAccessory · CameraCaptureAccessory · onAvailabilityChange",
             text: "While the app is full screen on the inner display with an active capture session, the system can show a second scene of ours on the cover display. It is a separate scene in the same process, so it shares the camera session and the store, and its own probe reports OUTSIDE with the inside open."),
        Item(title: "Two windows talking",
             api: "UIApplicationSupportsMultipleScenes · @Observable",
             text: "Two copies of the app side by side are two window scenes in one process, so a shared observable object is all the communication you need. The 'inverse toggle' just keys one value off which window is the left / top one."),
    ]

    var body: some View {
        NavigationStack {
            List(items) { item in
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title).font(.headline)
                    Text(item.api).font(.caption.monospaced()).foregroundStyle(.orange)
                    Text(item.text).font(.callout).foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
