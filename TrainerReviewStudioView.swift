//
//  TrainerReviewStudioView.swift
//  Tanzen mit Tatiana Drexler
//
//  Review Studio für Trainer: Annotationen, Audio, Text-Kommentare
//

import SwiftUI
import Combine
import AVKit
import AVFoundation
import PencilKit

// MARK: - Trainer: Submissions Overview

struct TrainerSubmissionsView: View {
    @StateObject private var reviewManager = VideoReviewManager.shared
    @State private var selectedFilter: SubmissionFilter = .pending
    
    enum SubmissionFilter: String, CaseIterable {
        case pending = "Offen"
        case inProgress = "In Bearbeitung"
        case completed = "Abgeschlossen"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter Picker
                Picker("Filter", selection: $selectedFilter) {
                    ForEach(SubmissionFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Submissions List
                if let trainerId = UserManager.shared.currentUser?.id {
                    let filteredSubmissions = filterSubmissions(reviewManager.submissionsForTrainer(trainerId))
                    
                    if filteredSubmissions.isEmpty {
                        ContentUnavailableView(
                            "Keine Einreichungen",
                            systemImage: "video.slash",
                            description: Text(T("Keine Einreichungen in dieser Kategorie."))
                        )
                    } else {
                        List(filteredSubmissions) { submission in
                            NavigationLink {
                                ReviewStudioView(submission: submission)
                            } label: {
                                TrainerSubmissionRow(submission: submission)
                            }
                        }
                    }
                }
            }
            .navigationTitle(T("Video-Reviews"))
            .task {
                if let trainerId = UserManager.shared.currentUser?.id {
                    await reviewManager.loadSubmissionsForTrainer(trainerId)
                }
            }
        }
    }
    
    private func filterSubmissions(_ submissions: [VideoSubmission]) -> [VideoSubmission] {
        switch selectedFilter {
        case .pending:
            return submissions.filter { $0.submissionStatus == .submitted }
        case .inProgress:
            return submissions.filter { $0.submissionStatus == .inReview }
        case .completed:
            return submissions.filter { $0.submissionStatus == .feedbackDelivered || $0.submissionStatus == .completed }
        }
    }
}

struct TrainerSubmissionRow: View {
    let submission: VideoSubmission
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(submission.userName)
                    .font(.headline)
                Text(submission.submissionNumber)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Label("\(submission.requestedMinutes) Min", systemImage: "clock")
                    Label(submission.formattedPrice, systemImage: "eurosign.circle")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Label(submission.submissionStatus.rawValue, systemImage: submission.submissionStatus.icon)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(submission.submissionStatus.color.opacity(0.2))
                    .foregroundColor(submission.submissionStatus.color)
                    .cornerRadius(8)
                
                Text(submission.createdAt, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Review Studio

struct ReviewStudioView: View {
    let submission: VideoSubmission
    @StateObject private var reviewManager = VideoReviewManager.shared
    @StateObject private var studioViewModel = ReviewStudioViewModel()
    @Environment(\.dismiss) private var dismiss
    
    @State private var showSendConfirmation = false
    @State private var isSending = false
    
    var body: some View {
        GeometryReader { geometry in
            if geometry.size.width > 700 {
                // iPad Layout
                HStack(spacing: 0) {
                    videoPlayerSection
                        .frame(width: geometry.size.width * 0.6)
                    
                    Divider()
                    
                    toolsSection
                        .frame(width: geometry.size.width * 0.4)
                }
            } else {
                // iPhone Layout
                VStack(spacing: 0) {
                    videoPlayerSection
                        .frame(height: geometry.size.height * 0.45)
                    
                    toolsSection
                }
            }
        }
        .navigationTitle(T("Review Studio"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(T("Senden")) {
                    showSendConfirmation = true
                }
                .disabled(isSending || !studioViewModel.hasContent)
            }
            
            ToolbarItem(placement: .secondaryAction) {
                Button(T("Speichern")) {
                    Task { await saveDraft() }
                }
            }
        }
        .alert(T("Feedback senden?"), isPresented: $showSendConfirmation) {
            Button(T("Abbrechen"), role: .cancel) {}
            Button(T("Senden")) {
                Task { await sendFeedback() }
            }
        } message: {
            Text(T("Das Feedback wird an %@ gesendet und kann nicht mehr bearbeitet werden.", submission.userName))
        }
        .task {
            await loadExistingFeedback()
            studioViewModel.loadVideo(url: submission.userVideoURL)
        }
        .onDisappear {
            studioViewModel.cleanup()
        }
    }
    
    private var videoPlayerSection: some View {
        VStack(spacing: 0) {
            // Video mit Annotation Overlay
            ZStack {
                VideoPlayerWithControls(viewModel: studioViewModel)
                
                if studioViewModel.showAnnotations {
                    AnnotationCanvasView(viewModel: studioViewModel)
                }
            }
            
            // Timeline mit Markern
            TimelineView(viewModel: studioViewModel)
                .frame(height: 60)
        }
    }
    
    private var toolsSection: some View {
        TabView {
            // Annotationen
            AnnotationToolsView(viewModel: studioViewModel)
                .tabItem { Label(T("Zeichnen"), systemImage: "pencil.tip") }
            
            // Audio
            AudioRecordingView(viewModel: studioViewModel, submissionId: submission.id)
                .tabItem { Label(T("Audio"), systemImage: "waveform") }
            
            // Kommentare
            CommentsEditorView(viewModel: studioViewModel)
                .tabItem { Label(T("Text"), systemImage: "text.bubble") }
            
            // Beispielvideos
            ExampleVideosEditor(viewModel: studioViewModel, submissionId: submission.id)
                .tabItem { Label(T("Videos"), systemImage: "video.badge.plus") }
        }
    }
    
    private func loadExistingFeedback() async {
        // Review starten falls noch nicht geschehen
        if submission.submissionStatus == .submitted {
            _ = await reviewManager.startReview(submissionId: submission.id)
        }
        
        // Existierendes Feedback laden
        if let feedback = await reviewManager.loadFeedback(submissionId: submission.id) {
            studioViewModel.loadFeedback(feedback)
        } else {
            // Neues Feedback erstellen
            studioViewModel.feedback = ReviewFeedback(
                submissionId: submission.id,
                trainerId: UserManager.shared.currentUser?.id ?? ""
            )
        }
    }
    
    private func saveDraft() async {
        guard let feedback = studioViewModel.buildFeedback() else { return }
        _ = await reviewManager.saveFeedbackDraft(feedback)
    }
    
    private func sendFeedback() async {
        isSending = true
        defer { isSending = false }
        
        // Erst als Draft speichern
        await saveDraft()
        
        // Dann senden
        let success = await reviewManager.deliverFeedback(submissionId: submission.id)
        
        if success {
            dismiss()
        }
    }
}

// MARK: - Review Studio ViewModel

@MainActor
class ReviewStudioViewModel: ObservableObject {
    // Video
    @Published var player: AVPlayer?
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var isPlaying = false
    
    // Annotations
    @Published var annotations: [VideoAnnotation] = []
    @Published var currentTool: AnnotationType = .freehand
    @Published var currentColor: String = "#FFD700"
    @Published var strokeWidth: CGFloat = 3.0
    @Published var showAnnotations = true
    
    // Drawing
    @Published var currentPath: [CGPoint] = []
    @Published var isDrawing = false
    
    // Audio
    @Published var audioTracks: [AudioTrack] = []
    @Published var isRecordingAudio = false
    
    // Comments
    @Published var comments = ReviewComments()
    
    // Example Videos
    @Published var trainerVideos: [TrainerExampleVideo] = []
    
    // Feedback
    var feedback: ReviewFeedback?
    
    private var timeObserver: Any?
    
    var hasContent: Bool {
        !annotations.isEmpty || !audioTracks.isEmpty || comments.hasContent || !trainerVideos.isEmpty
    }
    
    func loadVideo(url: String?) {
        guard let urlString = url, let videoURL = URL(string: urlString) else { return }
        
        player = AVPlayer(url: videoURL)
        
        // Zeit-Observer
        timeObserver = player?.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor [weak self] in
                self?.currentTime = CMTimeGetSeconds(time)
            }
        }
        
        // Dauer ermitteln
        Task {
            if let duration = try? await player?.currentItem?.asset.load(.duration) {
                self.duration = CMTimeGetSeconds(duration)
            }
        }
    }
    
    func loadFeedback(_ feedback: ReviewFeedback) {
        self.feedback = feedback
        self.annotations = feedback.annotations
        self.audioTracks = feedback.audioTracks
        self.comments = feedback.comments
        self.trainerVideos = feedback.trainerVideos
    }
    
    func buildFeedback() -> ReviewFeedback? {
        guard var feedback = feedback else { return nil }
        feedback.annotations = annotations
        feedback.audioTracks = audioTracks
        feedback.comments = comments
        feedback.trainerVideos = trainerVideos
        feedback.updatedAt = Date()
        return feedback
    }
    
    // MARK: - Playback Controls
    
    func play() {
        player?.play()
        isPlaying = true
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
    }
    
    func seek(to time: Double) {
        player?.seek(to: CMTime(seconds: time, preferredTimescale: 600))
        currentTime = time
    }
    
    func stepForward() {
        seek(to: min(currentTime + 1/30, duration))
    }
    
    func stepBackward() {
        seek(to: max(currentTime - 1/30, 0))
    }
    
    // MARK: - Annotations

    func startDrawing(at normalizedPoint: CGPoint) {
        pause()
        isDrawing = true
        currentPath = [normalizedPoint]
    }

    func continueDrawing(at normalizedPoint: CGPoint) {
        guard isDrawing else { return }
        currentPath.append(normalizedPoint)
    }

    func endDrawing() {
        guard isDrawing, currentPath.count >= 2 else {
            isDrawing = false
            currentPath = []
            return
        }
        
        let annotation = VideoAnnotation(
            type: currentTool,
            startTime: currentTime,
            endTime: nil, // Persistent
            data: AnnotationData(points: currentPath),
            color: currentColor,
            strokeWidth: strokeWidth
        )
        
        annotations.append(annotation)
        isDrawing = false
        currentPath = []
    }
    
    func addTextAnnotation(text: String, at position: CGPoint) {
        let annotation = VideoAnnotation(
            type: .text,
            startTime: currentTime,
            data: AnnotationData(text: text, position: position),
            color: currentColor
        )
        annotations.append(annotation)
    }
    
    func addMarker(at time: Double) {
        let annotation = VideoAnnotation(
            type: .marker,
            startTime: time,
            data: AnnotationData(text: "Marker")
        )
        annotations.append(annotation)
    }
    
    func deleteAnnotation(_ id: String) {
        annotations.removeAll { $0.id == id }
    }
    
    func cleanup() {
        guard let observer = timeObserver else { return }
        player?.removeTimeObserver(observer)
        timeObserver = nil
    }
}

// MARK: - Video Player with Controls

struct VideoPlayerWithControls: View {
    @ObservedObject var viewModel: ReviewStudioViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Video
            if let player = viewModel.player {
                VideoPlayer(player: player)
            } else {
                Rectangle()
                    .fill(Color.black)
                    .overlay(
                        ProgressView()
                            .tint(.white)
                    )
            }
            
            // Controls
            HStack(spacing: 20) {
                // Frame zurück
                Button(action: viewModel.stepBackward) {
                    Image(systemName: "backward.frame")
                }
                
                // Play/Pause
                Button(action: {
                    viewModel.isPlaying ? viewModel.pause() : viewModel.play()
                }) {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                }
                
                // Frame vor
                Button(action: viewModel.stepForward) {
                    Image(systemName: "forward.frame")
                }
                
                Spacer()
                
                // Zeit
                Text(formatTime(viewModel.currentTime))
                    .monospacedDigit()
                Text(T("/"))
                Text(formatTime(viewModel.duration))
                    .monospacedDigit()
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Annotationen Toggle
                Toggle("", isOn: $viewModel.showAnnotations)
                    .toggleStyle(.button)
                    .labelStyle(.iconOnly)
                
                Image(systemName: "pencil.tip.crop.circle")
                    .foregroundColor(viewModel.showAnnotations ? .blue : .secondary)
            }
            .padding()
            .background(Color.black.opacity(0.8))
            .foregroundColor(.white)
        }
    }
    
    private func formatTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Timeline View

struct TimelineView: View {
    @ObservedObject var viewModel: ReviewStudioViewModel
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                
                // Progress
                Rectangle()
                    .fill(Color.blue.opacity(0.5))
                    .frame(width: geometry.size.width * (viewModel.currentTime / max(viewModel.duration, 1)))
                
                // Markers
                ForEach(viewModel.annotations.filter { $0.type == .marker }) { marker in
                    Rectangle()
                        .fill(Color.yellow)
                        .frame(width: 2)
                        .offset(x: geometry.size.width * (marker.startTime / max(viewModel.duration, 1)))
                }
                
                // Annotations indicators
                ForEach(viewModel.annotations.filter { $0.type != .marker }) { annotation in
                    Circle()
                        .fill(Color(hex: annotation.color))
                        .frame(width: 8, height: 8)
                        .offset(
                            x: geometry.size.width * (annotation.startTime / max(viewModel.duration, 1)) - 4,
                            y: 10
                        )
                }
                
                // Playhead
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 2)
                    .offset(x: geometry.size.width * (viewModel.currentTime / max(viewModel.duration, 1)))
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let progress = value.location.x / geometry.size.width
                        viewModel.seek(to: max(0, min(viewModel.duration, viewModel.duration * progress)))
                    }
            )
        }
        .cornerRadius(4)
        .padding(.horizontal)
    }
}

// MARK: - Annotation Canvas

struct AnnotationCanvasView: View {
    @ObservedObject var viewModel: ReviewStudioViewModel

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Existing annotations
                ForEach(viewModel.annotations.filter { $0.isVisible(at: viewModel.currentTime) }) { annotation in
                    AnnotationShapeView(annotation: annotation, size: geometry.size)
                }

                // Current drawing path (currentPath is normalized)
                if viewModel.isDrawing && viewModel.currentPath.count >= 2 {
                    Path { path in
                        let first = viewPoint(from: viewModel.currentPath[0], in: geometry.size)
                        path.move(to: first)
                        for point in viewModel.currentPath.dropFirst() {
                            path.addLine(to: viewPoint(from: point, in: geometry.size))
                        }
                    }
                    .stroke(Color(hex: viewModel.currentColor), lineWidth: viewModel.strokeWidth)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let normalizedPoint = CGPoint(
                            x: value.location.x / max(geometry.size.width, 1),
                            y: value.location.y / max(geometry.size.height, 1)
                        )

                        if !viewModel.isDrawing {
                            viewModel.startDrawing(at: normalizedPoint)
                        } else {
                            viewModel.continueDrawing(at: normalizedPoint)
                        }
                    }
                    .onEnded { _ in
                        viewModel.endDrawing()
                    }
            )
        }
    }

    private func viewPoint(from normalizedPoint: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: normalizedPoint.x * size.width, y: normalizedPoint.y * size.height)
    }
}

// MARK: - Annotation Tools

struct AnnotationToolsView: View {
    @ObservedObject var viewModel: ReviewStudioViewModel
    @State private var showTextInput = false
    @State private var textInput = ""
    
    let colors = ["#FFD700", "#FF0000", "#00FF00", "#0000FF", "#FF00FF", "#00FFFF", "#FFFFFF"]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Tools
                Text(T("Werkzeug"))
                    .font(.headline)
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 12) {
                    ForEach(AnnotationType.allCases.filter { $0 != .marker }, id: \.self) { tool in
                        ToolButton(
                            type: tool,
                            isSelected: viewModel.currentTool == tool
                        ) {
                            viewModel.currentTool = tool
                            if tool == .text {
                                showTextInput = true
                            }
                        }
                    }
                }
                
                Divider()
                
                // Colors
                Text(T("Farbe"))
                    .font(.headline)
                
                HStack(spacing: 12) {
                    ForEach(colors, id: \.self) { color in
                        Circle()
                            .fill(Color(hex: color))
                            .frame(width: 30, height: 30)
                            .overlay(
                                Circle()
                                    .stroke(viewModel.currentColor == color ? Color.white : Color.clear, lineWidth: 2)
                            )
                            .onTapGesture {
                                viewModel.currentColor = color
                            }
                    }
                }
                
                Divider()
                
                // Stroke Width
                Text(T("Strichstärke"))
                    .font(.headline)
                
                Slider(value: $viewModel.strokeWidth, in: 1...10, step: 1)
                
                Divider()
                
                // Markers
                Text(T("Marker"))
                    .font(.headline)
                
                Button(action: {
                    viewModel.addMarker(at: viewModel.currentTime)
                }) {
                    Label(T("Marker setzen"), systemImage: "mappin.and.ellipse")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.yellow.opacity(0.2))
                        .cornerRadius(8)
                }
                
                Divider()
                
                // Annotations List
                Text(T("Annotationen (%@)", "\(viewModel.annotations.count)"))
                    .font(.headline)
                
                ForEach(viewModel.annotations) { annotation in
                    AnnotationListItem(annotation: annotation) {
                        viewModel.deleteAnnotation(annotation.id)
                    } onTap: {
                        viewModel.seek(to: annotation.startTime)
                    }
                }
            }
            .padding()
        }
        .alert(T("Text hinzufügen"), isPresented: $showTextInput) {
            TextField(T("Text"), text: $textInput)
            Button(T("Abbrechen"), role: .cancel) { textInput = "" }
            Button(T("Hinzufügen")) {
                viewModel.addTextAnnotation(text: textInput, at: CGPoint(x: 0.5, y: 0.5))
                textInput = ""
            }
        }
    }
}

struct ToolButton: View {
    let type: AnnotationType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                Image(systemName: type.icon)
                    .font(.title2)
                Text(type.rawValue)
                    .font(.caption2)
            }
            .frame(width: 60, height: 60)
            .background(isSelected ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

struct AnnotationListItem: View {
    let annotation: VideoAnnotation
    let onDelete: () -> Void
    let onTap: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: annotation.type.icon)
                .foregroundColor(Color(hex: annotation.color))
            
            VStack(alignment: .leading) {
                Text(annotation.type.rawValue)
                    .font(.subheadline)
                Text(formatTime(annotation.startTime))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
    
    private func formatTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Audio Recording

struct AudioRecordingView: View {
    @ObservedObject var viewModel: ReviewStudioViewModel
    let submissionId: String
    
    @StateObject private var audioRecorder = AudioRecorderManager()
    @State private var recordingStartTime: Double = 0
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(T("Audio-Kommentare"))
                    .font(.headline)
                
                // Recording Controls
                VStack(spacing: 12) {
                    if audioRecorder.isRecording {
                        HStack {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 12, height: 12)
                            Text(T("Aufnahme läuft..."))
                            Spacer()
                            Text(formatDuration(audioRecorder.recordingDuration))
                                .monospacedDigit()
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                        
                        Button(action: stopRecording) {
                            Label(T("Aufnahme beenden"), systemImage: "stop.circle.fill")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    } else {
                        Text(T("Starte eine Aufnahme ab der aktuellen Videoposition."))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(T("Aktuelle Position: %@", formatTime(viewModel.currentTime)))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button(action: startRecording) {
                            Label(T("Aufnahme starten"), systemImage: "mic.circle.fill")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                }
                
                Divider()
                
                // Audio Tracks List
                Text(T("Aufnahmen (%@)", "\(viewModel.audioTracks.count)"))
                    .font(.headline)
                
                if viewModel.audioTracks.isEmpty {
                    Text(T("Noch keine Audio-Kommentare"))
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    ForEach(viewModel.audioTracks) { track in
                        AudioTrackEditorRow(track: track) {
                            viewModel.audioTracks.removeAll { $0.id == track.id }
                        } onTap: {
                            viewModel.seek(to: track.startTime)
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    private func startRecording() {
        viewModel.pause()
        recordingStartTime = viewModel.currentTime
        audioRecorder.startRecording()
    }
    
    private func stopRecording() {
        audioRecorder.stopRecording()
        
        // Audio-Track erstellen
        if let url = audioRecorder.lastRecordingURL {
            Task {
                if let feedbackId = viewModel.feedback?.id {
                    if let track = await VideoReviewManager.shared.uploadAudioTrack(
                        feedbackId: feedbackId,
                        localURL: url,
                        startTime: recordingStartTime,
                        duration: audioRecorder.recordingDuration
                    ) {
                        viewModel.audioTracks.append(track)
                    }
                }
            }
        }
    }
    
    private func formatTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct AudioTrackEditorRow: View {
    let track: AudioTrack
    let onDelete: () -> Void
    let onTap: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "waveform")
                .foregroundColor(.blue)
            
            VStack(alignment: .leading) {
                Text(track.title ?? T("Audio-Kommentar"))
                    .font(.subheadline)
                Text(T("Ab %@ • %@s", track.formattedStartTime, "\(Int(track.duration))"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .onTapGesture(perform: onTap)
    }
}

// MARK: - Audio Recorder Manager

class AudioRecorderManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var recordingError: String?

    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?
    var lastRecordingURL: URL?

    func startRecording() {
        let audioSession = AVAudioSession.sharedInstance()

        requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                guard let self = self else { return }
                guard granted else {
                    self.recordingError = "Mikrofon-Zugriff verweigert"
                    self.isRecording = false
                    return
                }

                do {
                    let options: AVAudioSession.CategoryOptions
                    if #available(iOS 17.0, *) {
                        options = [.defaultToSpeaker, .allowBluetoothHFP]
                    } else {
                        options = [.defaultToSpeaker, .allowBluetooth]
                    }

                    try audioSession.setCategory(
                        .playAndRecord,
                        mode: .default,
                        options: options
                    )
                    try audioSession.setActive(true)

                    let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    let audioFilename = documentsPath.appendingPathComponent("\(UUID().uuidString).m4a")

                    let settings: [String: Any] = [
                        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                        AVSampleRateKey: 44100,
                        AVNumberOfChannelsKey: 1,
                        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
                    ]

                    self.audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
                    self.audioRecorder?.record()

                    self.lastRecordingURL = audioFilename
                    self.isRecording = true
                    self.recordingDuration = 0
                    self.recordingError = nil

                    self.timer?.invalidate()
                    self.timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                        self?.recordingDuration += 0.1
                    }
                } catch {
                    self.recordingError = "Aufnahme fehlgeschlagen"
                    self.isRecording = false
                    print("Failed to start recording: \(error)")
                }
            }
        }
    }

    private func requestRecordPermission(_ completion: @escaping (Bool) -> Void) {
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission(completionHandler: completion)
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission(completion)
        }
    }

    func stopRecording() {
        audioRecorder?.stop()
        timer?.invalidate()
        isRecording = false
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {
            print("Failed to deactivate audio session: \(error)")
        }
    }
}

// MARK: - Comments Editor

struct CommentsEditorView: View {
    @ObservedObject var viewModel: ReviewStudioViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Summary
                TextSection(
                    title: "Zusammenfassung",
                    text: $viewModel.comments.summary,
                    placeholder: "Allgemeines Feedback zum Video..."
                )
                
                // Top Mistakes
                ListEditorSection(
                    title: "Top Fehler",
                    icon: "exclamationmark.triangle",
                    items: $viewModel.comments.topMistakes,
                    color: .red
                )
                
                // Top Drills
                ListEditorSection(
                    title: "Empfohlene Übungen",
                    icon: "figure.walk",
                    items: $viewModel.comments.topDrills,
                    color: .blue
                )
                
                // Next Steps
                ListEditorSection(
                    title: "Nächste Schritte",
                    icon: "arrow.right.circle",
                    items: $viewModel.comments.nextSteps,
                    color: .green
                )
                
                // Additional Notes
                TextSection(
                    title: "Weitere Hinweise",
                    text: $viewModel.comments.additionalNotes,
                    placeholder: "Zusätzliche Anmerkungen..."
                )
            }
            .padding()
        }
    }
}

struct TextSection: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            
            TextEditor(text: $text)
                .frame(minHeight: 80)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3))
                )
                .overlay(
                    Group {
                        if text.isEmpty {
                            Text(placeholder)
                                .foregroundColor(.gray.opacity(0.5))
                                .padding(8)
                        }
                    },
                    alignment: .topLeading
                )
        }
    }
}

struct ListEditorSection: View {
    let title: String
    let icon: String
    @Binding var items: [String]
    let color: Color
    
    @State private var newItem = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundColor(color)
            
            ForEach(items.indices, id: \.self) { index in
                HStack {
                    Text("\(index + 1).")
                        .foregroundColor(color)
                    TextField(T(""), text: $items[index])
                    Button(action: { items.remove(at: index) }) {
                        Image(systemName: "minus.circle")
                            .foregroundColor(.red)
                    }
                }
            }
            
            HStack {
                TextField(T("Neuer Eintrag..."), text: $newItem)
                Button(action: {
                    if !newItem.isEmpty {
                        items.append(newItem)
                        newItem = ""
                    }
                }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(color)
                }
            }
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Example Videos Editor

struct ExampleVideosEditor: View {
    @ObservedObject var viewModel: ReviewStudioViewModel
    let submissionId: String
    
    @State private var showVideoPicker = false
    @State private var videoTitle = ""
    @State private var isUploading = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(T("Beispielvideos"))
                    .font(.headline)
                
                Text(T("Lade kurze Videos hoch, um dem Schüler die richtige Ausführung zu zeigen."))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if isUploading {
                    ProgressView("Video wird hochgeladen...")
                        .padding()
                } else {
                    TextField(T("Video-Titel"), text: $videoTitle)
                        .textFieldStyle(.roundedBorder)
                    
                    Button(action: { showVideoPicker = true }) {
                        Label(T("Video auswählen"), systemImage: "video.badge.plus")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.purple.opacity(0.2))
                            .cornerRadius(8)
                    }
                    .disabled(videoTitle.isEmpty)
                }
                
                Divider()
                
                Text(T("Hochgeladene Videos (%@)", "\(viewModel.trainerVideos.count)"))
                    .font(.headline)
                
                ForEach(viewModel.trainerVideos) { video in
                    ExampleVideoEditorRow(video: video) {
                        viewModel.trainerVideos.removeAll { $0.id == video.id }
                    }
                }
            }
            .padding()
        }
        .sheet(isPresented: $showVideoPicker) {
            VideoPicker { url in
                if let url = url {
                    Task { await uploadExampleVideo(url) }
                }
            }
        }
    }
    
    private func uploadExampleVideo(_ url: URL) async {
        isUploading = true
        defer { isUploading = false }
        
        if let feedbackId = viewModel.feedback?.id {
            if let video = await VideoReviewManager.shared.uploadTrainerExampleVideo(
                feedbackId: feedbackId,
                localURL: url,
                title: videoTitle,
                relatedTimestamp: viewModel.currentTime
            ) {
                viewModel.trainerVideos.append(video)
                videoTitle = ""
            }
        }
    }
}

struct ExampleVideoEditorRow: View {
    let video: TrainerExampleVideo
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "video.fill")
                .foregroundColor(.purple)
            
            VStack(alignment: .leading) {
                Text(video.title)
                    .font(.subheadline)
                if let timestamp = video.relatedTimestamp {
                    Text(T("Zu Zeitpunkt %@", formatTime(timestamp)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color.purple.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func formatTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
