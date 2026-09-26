import SwiftUI

struct CameraTab: View {
    @Environment(DuoEnvironment.self) private var env
    private let camera = CameraModel.shared

    var body: some View {
        @Bindable var camera = camera
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    viewfinder
                    controls
                    accessorySection
                    outerPreview
                }
                .padding()
            }
            .navigationTitle("Camera")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var viewfinder: some View {
        ZStack {
            if camera.isRunning, camera.hasCamera {
                CameraPreview(session: camera.controller.session, mirrored: camera.position == .front)
            } else {
                ContentUnavailableView(
                    camera.isRunning ? "No camera here" : "Capture stopped",
                    systemImage: camera.isRunning ? "camera.slash" : "camera",
                    description: Text(camera.isRunning
                                      ? "The simulator has no camera, so this stays blank. The session is still running, which is what the outer-display accessory keys off."
                                      : "Start capture to get a live preview and to make the outer-display accessory available.")
                )
            }
            if let n = camera.countdown {
                Text("\(n)").font(.system(size: 120, weight: .black, design: .rounded))
                    .foregroundStyle(.white).shadow(radius: 10)
                    .contentTransition(.numericText(countsDown: true)).animation(.snappy, value: n)
            }
            if camera.flash { Color.white }
            if let photo = camera.lastPhoto {
                Image(uiImage: photo).resizable().scaledToFill()
                    .frame(width: 72, height: 96).clipShape(.rect(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white, lineWidth: 2))
                    .padding(12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
        }
        .frame(height: 280)
        .background(.black.opacity(0.85), in: .rect(cornerRadius: 20))
        .clipShape(.rect(cornerRadius: 20))
    }

    private var controls: some View {
        @Bindable var camera = camera
        return VStack(spacing: 14) {
            HStack(spacing: 12) {
                Button(camera.isRunning ? "Stop" : "Start capture", systemImage: camera.isRunning ? "stop.fill" : "play.fill") {
                    camera.isRunning ? camera.stop() : camera.start()
                }
                .buttonStyle(.borderedProminent)
                Button("Flip", systemImage: "arrow.trianglehead.2.clockwise.rotate.90.camera") { camera.flip() }
                    .buttonStyle(.bordered)
                    .disabled(!camera.isRunning)
                Spacer()
                Button {
                    camera.startCountdown()
                } label: {
                    Label("3-2-1", systemImage: "timer")
                }
                .buttonStyle(.bordered)
                .disabled(!camera.isRunning || camera.countdown != nil)
                Button {
                    camera.capture()
                } label: {
                    Image(systemName: "circle.inset.filled").font(.system(size: 44))
                }
                .buttonStyle(.plain)
                .disabled(!camera.isRunning)
            }
            Picker("Tell the subject", selection: $camera.message) {
                ForEach(SubjectMessage.allCases) { m in Text(m.rawValue).tag(m) }
            }
            .pickerStyle(.segmented)
            Text(camera.statusLine).font(.footnote).foregroundStyle(.secondary)
        }
    }

    private var accessorySection: some View {
        @Bindable var camera = camera
        return VStack(alignment: .leading, spacing: 10) {
            Text("Outer display while you shoot").font(.headline)
            Text("A camera-capture scene accessory puts a second scene on the cover display while this app is full screen on the inner display with an active capture session. The subject sees themselves, a countdown, a message, the shot they just took, and can tap to trigger the shutter.")
                .font(.callout).foregroundStyle(.secondary)
            Toggle("Show the accessory when available", isOn: $camera.accessoryEnabled)
            Toggle("Mirror the camera on the outside", isOn: $camera.showMirror)
            Toggle("Let the subject tap the outside to shoot", isOn: $camera.subjectCanTrigger)
            LabeledContent("Shots started from the outside", value: "\(camera.subjectTriggers)")
            LabeledContent("System says the accessory is") {
                Text(camera.accessoryAvailable ? "available" : "not available")
                    .foregroundStyle(camera.accessoryAvailable ? .green : .secondary)
            }
            LabeledContent("This window") {
                Text(env.snapshot.secondaryLine).multilineTextAlignment(.trailing)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.background.secondary, in: .rect(cornerRadius: 16))
    }

    /// The accessory can only be seen on hardware, so render the same view here at cover-display proportions.
    private var outerPreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What the outside will show").font(.headline)
            Text("Same view the accessory uses, at the cover display's 466 × 678 proportions. On the real thing this window reports OUTSIDE with the inside open.")
                .font(.callout).foregroundStyle(.secondary)
            OuterAccessoryView()
                .frame(width: 466, height: 678)
                .clipShape(.rect(cornerRadius: 40))
                .scaleEffect(0.55, anchor: .top)
                .frame(width: 466 * 0.55, height: 678 * 0.55)
                .frame(maxWidth: .infinity)
                .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.background.secondary, in: .rect(cornerRadius: 16))
    }
}
