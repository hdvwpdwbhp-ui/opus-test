import SwiftUI
import Combine
import AVFoundation
import Photos

@MainActor
final class MusicVideoRecorderManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var isPreparing = false
    @Published var errorMessage: String?
    @Published var isSaved = false

    let session = AVCaptureSession()
    private let output = AVCaptureMovieFileOutput()
    private var currentFileURL: URL?

    func prepareSession() async {
        guard !session.isRunning else { return }
        isPreparing = true
        errorMessage = nil
        isSaved = false

        let cameraGranted = await requestCameraPermission()
        let micGranted = await requestMicrophonePermission()
        let photoGranted = await requestPhotoAddPermission()

        guard cameraGranted, micGranted, photoGranted else {
            errorMessage = "Kamera/Mikrofon/Fotozugriff benötigt"
            isPreparing = false
            return
        }

        do {
            try configureAudioSessionForRecording()
        } catch {
            errorMessage = "Audio konnte nicht konfiguriert werden"
            isPreparing = false
            return
        }

        session.beginConfiguration()
        session.sessionPreset = .high

        if session.inputs.isEmpty {
            if let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
               let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
               session.canAddInput(videoInput) {
                session.addInput(videoInput)
            }

            if let audioDevice = AVCaptureDevice.default(for: .audio),
               let audioInput = try? AVCaptureDeviceInput(device: audioDevice),
               session.canAddInput(audioInput) {
                session.addInput(audioInput)
            }
        }

        if session.canAddOutput(output), !session.outputs.contains(output) {
            session.addOutput(output)
        }

        session.commitConfiguration()
        session.startRunning()
        isPreparing = false
    }

    func startRecording() {
        guard !isRecording else { return }
        isSaved = false
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")
        currentFileURL = tempURL
        output.startRecording(to: tempURL, recordingDelegate: self)
        isRecording = true
    }

    func stopRecording() {
        guard isRecording else { return }
        output.stopRecording()
        isRecording = false
    }

    func cleanup() {
        if session.isRunning {
            session.stopRunning()
        }
        currentFileURL = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    private func requestCameraPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default: return false
        }
    }

    private func requestMicrophonePermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        default: return false
        }
    }

    private func requestPhotoAddPermission() async -> Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        switch status {
        case .authorized, .limited: return true
        case .notDetermined:
            let newStatus = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            return newStatus == .authorized || newStatus == .limited
        default: return false
        }
    }

    private func configureAudioSessionForRecording() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .videoRecording, options: [.mixWithOthers, .defaultToSpeaker])
        try session.setActive(true)
    }

    private func saveToPhotos(url: URL) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
        }) { [weak self] success, _ in
            Task { @MainActor [weak self] in
                self?.isSaved = success
                if success {
                    try? FileManager.default.removeItem(at: url)
                } else {
                    self?.errorMessage = "Speichern in Galerie fehlgeschlagen"
                }
            }
        }
    }
}

extension MusicVideoRecorderManager: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            Task { @MainActor in
                self.errorMessage = error.localizedDescription
            }
            return
        }
        saveToPhotos(url: outputFileURL)
    }
}

struct MusicVideoRecorderView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var recorder = MusicVideoRecorderManager()

    var body: some View {
        ZStack {
            CameraPreview(session: recorder.session)
                .ignoresSafeArea()

            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .semibold))
                            .padding(10)
                            .background(Circle().fill(.ultraThinMaterial))
                    }
                    Spacer()
                }
                .padding()

                Spacer()

                if recorder.isSaved {
                    Text(T("✅ In Galerie gespeichert"))
                        .font(TDTypography.caption1)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.black.opacity(0.6)))
                }

                if let error = recorder.errorMessage {
                    Text(error)
                        .font(TDTypography.caption1)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.red.opacity(0.7)))
                }

                Button {
                    recorder.isRecording ? recorder.stopRecording() : recorder.startRecording()
                } label: {
                    ZStack {
                        Circle()
                            .fill(recorder.isRecording ? Color.red : Color.white)
                            .frame(width: 72, height: 72)
                        if recorder.isRecording {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.white)
                                .frame(width: 26, height: 26)
                        }
                    }
                }
                .padding(.bottom, 32)
            }
        }
        .task {
            await recorder.prepareSession()
        }
        .onDisappear {
            recorder.cleanup()
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        context.coordinator.layer = layer
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.layer?.frame = uiView.bounds
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var layer: AVCaptureVideoPreviewLayer?
    }
}

#Preview {
    MusicVideoRecorderView()
}
