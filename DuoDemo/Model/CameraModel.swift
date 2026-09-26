import AVFoundation
import Observation
import UIKit

/// Owns the capture session off the main actor. One per process, shared by every window and by
/// the outer-display accessory (which is a separate scene in the same process).
nonisolated final class CaptureController: @unchecked Sendable {
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "duo-demo.capture")
    private let photoOutput = AVCapturePhotoOutput()
    private var currentInput: AVCaptureDeviceInput?
    private var inflight: [Int64: PhotoDelegate] = [:]

    /// Configures (or re-configures) inputs for the given camera. Returns whether a camera exists.
    func configure(position: AVCaptureDevice.Position, completion: @escaping @Sendable (Bool) -> Void) {
        queue.async {
            self.session.beginConfiguration()
            defer { self.session.commitConfiguration() }
            if let currentInput = self.currentInput {
                self.session.removeInput(currentInput)
                self.currentInput = nil
            }
            self.session.sessionPreset = .photo
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
                  let input = try? AVCaptureDeviceInput(device: device),
                  self.session.canAddInput(input) else {
                completion(false)
                return
            }
            self.session.addInput(input)
            self.currentInput = input
            if !self.session.outputs.contains(self.photoOutput), self.session.canAddOutput(self.photoOutput) {
                self.session.addOutput(self.photoOutput)
            }
            completion(true)
        }
    }

    func start() { queue.async { if !self.session.isRunning { self.session.startRunning() } } }
    func stop() { queue.async { if self.session.isRunning { self.session.stopRunning() } } }

    func capturePhoto(completion: @escaping @Sendable (UIImage?) -> Void) {
        queue.async {
            guard self.session.outputs.contains(self.photoOutput), self.currentInput != nil else {
                completion(nil)
                return
            }
            let settings = AVCapturePhotoSettings()
            let delegate = PhotoDelegate { [weak self] id, image in
                self?.queue.async { self?.inflight[id] = nil }
                completion(image)
            }
            self.inflight[settings.uniqueID] = delegate
            self.photoOutput.capturePhoto(with: settings, delegate: delegate)
        }
    }
}

nonisolated private final class PhotoDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let done: @Sendable (Int64, UIImage?) -> Void
    init(done: @escaping @Sendable (Int64, UIImage?) -> Void) { self.done = done }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: (any Error)?) {
        let image = photo.fileDataRepresentation().flatMap(UIImage.init(data:))
        done(photo.resolvedSettings.uniqueID, image)
    }
}

/// What the subject on the outer display is told to do.
enum SubjectMessage: String, CaseIterable, Identifiable {
    case smile = "Smile!"
    case lookHere = "Look up here"
    case holdStill = "Hold still…"
    case wave = "Wave!"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .smile: "face.smiling"
        case .lookHere: "arrow.up"
        case .holdStill: "hand.raised"
        case .wave: "hand.wave"
        }
    }
}

/// Main-actor state for the Camera tab and the outer-display accessory.
@Observable
final class CameraModel {
    static let shared = CameraModel()

    let controller = CaptureController()

    var isRunning = false
    var hasCamera = false
    var authorization: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    var position: AVCaptureDevice.Position = .back
    var lastPhoto: UIImage?
    var photosTaken = 0

    /// Whether the system would show our accessory on the outer display right now.
    var accessoryAvailable = false
    /// Our own switch for the accessory (the system may still decide not to show it).
    var accessoryEnabled = true
    var showMirror = true

    var message: SubjectMessage = .smile
    var countdown: Int?
    var flash = false
    /// Shown on the outer display for a moment after each shot.
    var reviewPhoto: UIImage?
    /// The subject can tap the outer display to start the countdown themselves.
    var subjectCanTrigger = true
    var subjectTriggers = 0

    var statusLine: String {
        if authorization == .denied || authorization == .restricted { return "Camera access denied" }
        if !isRunning { return "Capture stopped" }
        return hasCamera ? "Capturing (\(position == .front ? "front" : "back") camera)" : "Session running, but no camera on this device"
    }

    func start() {
        Task {
            if authorization == .notDetermined {
                _ = await AVCaptureDevice.requestAccess(for: .video)
                authorization = AVCaptureDevice.authorizationStatus(for: .video)
            }
            controller.configure(position: position) { found in
                Task { @MainActor in self.hasCamera = found }
            }
            controller.start()
            isRunning = true
        }
    }

    func stop() {
        controller.stop()
        isRunning = false
        countdown = nil
    }

    func flip() {
        position = position == .back ? .front : .back
        controller.configure(position: position) { found in
            Task { @MainActor in self.hasCamera = found }
        }
    }

    func capture() {
        flash = true
        Task {
            try? await Task.sleep(for: .milliseconds(180))
            flash = false
        }
        controller.capturePhoto { image in
            Task { @MainActor in
                self.lastPhoto = image
                if image != nil { self.photosTaken += 1 }
                self.reviewPhoto = image
                try? await Task.sleep(for: .seconds(2.5))
                if self.reviewPhoto === image { self.reviewPhoto = nil }
            }
        }
    }

    /// Called from the outer-display accessory when the subject taps it.
    func subjectTapped() {
        guard subjectCanTrigger, isRunning else { return }
        subjectTriggers += 1
        startCountdown()
    }

    func startCountdown(from seconds: Int = 3) {
        guard countdown == nil else { return }
        Task {
            for n in stride(from: seconds, through: 1, by: -1) {
                countdown = n
                try? await Task.sleep(for: .seconds(1))
            }
            countdown = nil
            capture()
        }
    }
}
