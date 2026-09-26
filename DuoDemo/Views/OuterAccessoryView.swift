import SwiftUI

/// What the person being photographed sees on the cover display while the photographer uses
/// the inner display. This is a separate scene in the same process, so it reads the shared
/// singletons directly and runs its own `WindowProbe` (which reports OUTSIDE, inside open).
struct OuterAccessoryView: View {
    @State private var env = DuoEnvironment()
    private let store = SharedStore.shared
    private let camera = CameraModel.shared

    var body: some View {
        ZStack {
            if camera.showMirror {
                CameraPreview(session: camera.controller.session, mirrored: camera.position == .front)
                    .ignoresSafeArea()
                if !camera.hasCamera {
                    Color(hue: store.hue, saturation: 0.5, brightness: 0.35).ignoresSafeArea()
                }
            } else {
                Color(hue: store.hue, saturation: 0.5, brightness: 0.35).ignoresSafeArea()
            }

            VStack(spacing: 12) {
                Text(env.snapshot.primaryWord)
                    .font(.system(size: 72, weight: .black, design: .rounded))
                    .minimumScaleFactor(0.3)
                    .lineLimit(1)
                Text(env.snapshot.secondaryLine)
                    .font(.headline)
                    .opacity(0.85)
                Spacer()
                if let n = camera.countdown {
                    Text("\(n)")
                        .font(.system(size: 200, weight: .black, design: .rounded))
                        .contentTransition(.numericText(countsDown: true))
                        .animation(.snappy, value: n)
                } else {
                    Label(camera.message.rawValue, systemImage: camera.message.symbol)
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .symbolEffect(.bounce, value: camera.message)
                    if camera.subjectCanTrigger {
                        Text("Tap here to take the photo yourself")
                            .font(.subheadline.weight(.semibold)).opacity(0.8)
                    }
                }
                Spacer()
                HStack {
                    Label(hingeLabel, systemImage: "book.pages")
                    Spacer()
                    Label("\(camera.photosTaken)", systemImage: "photo.stack")
                }
                .font(.subheadline.weight(.semibold))
                .opacity(0.85)
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.5), radius: 8)
            .padding(24)

            if let review = camera.reviewPhoto {
                Image(uiImage: review).resizable().scaledToFill().ignoresSafeArea()
                    .overlay(alignment: .bottom) {
                        Text("Looking good").font(.title.weight(.bold)).foregroundStyle(.white)
                            .padding(.bottom, 40).shadow(radius: 8)
                    }
                    .transition(.opacity)
            }
            if camera.flash { Color.white.ignoresSafeArea() }
        }
        .animation(.easeInOut, value: camera.reviewPhoto == nil)
        .contentShape(.rect)
        .onTapGesture { camera.subjectTapped() }
        .background { WindowProbe(env: env, store: store).ignoresSafeArea() }
        .environment(env)
        .environment(store)
    }

    private var hingeLabel: String {
        if let angle = env.snapshot.hingeAngleDegrees { return "\(env.snapshot.hinge.rawValue) · \(Int(angle.rounded()))°" }
        return env.snapshot.hinge.rawValue
    }
}
