//
//  VideoPlayerView.swift
//  Tanzen mit Tatiana Drexler
//
//  Custom Video Player with controls and screenshot protection
//

import SwiftUI
import AVKit
import Combine

struct VideoPlayerView: View {
    let videoURL: String
    let title: String
    let suggestedStyle: DanceStyle?

    @Environment(\.dismiss) private var dismiss
    @StateObject private var playerManager = VideoPlayerManager()
    @State private var showControls = true
    @State private var controlsTimer: Timer?
    @State private var isScreenCaptured = UIScreen.main.isCaptured
    @State private var showScreenshotOverlay = false
    @State private var showMusicPlayer = false
    @State private var openRecorderDirectly = false
    @State private var autoSelectSuggestedTrack = false
    @State private var showPostVideoPrompt = false
    @State private var recPulse = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Video Player
            if let player = playerManager.player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
                    .onTapGesture {
                        toggleControls()
                    }
            } else {
                ProgressView("Lade Video...")
                    .foregroundColor(.white)
            }

            if isScreenCaptured || showScreenshotOverlay {
                Color.black.ignoresSafeArea()
            }

            if playerManager.isLoading {
                ProgressView("Video wird geladen...")
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(TDRadius.md)
            }

            if let error = playerManager.errorMessage {
                VStack(spacing: TDSpacing.md) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.yellow)
                    Text(T("Video konnte nicht abgespielt werden"))
                        .font(TDTypography.headline)
                        .foregroundColor(.white)
                    Text(error)
                        .font(TDTypography.caption1)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .padding(TDSpacing.lg)
                .background(Color.black.opacity(0.7))
                .cornerRadius(TDRadius.md)
                .padding()
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        openMusicRecorder(direct: true, suggest: false)
                    } label: {
                        HStack(spacing: TDSpacing.xs) {
                            ZStack {
                                Circle()
                                    .fill(Color.red.opacity(recPulse ? 0.25 : 0.1))
                                    .frame(width: 28, height: 28)
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 10, height: 10)
                            }
                            Text(T("REC"))
                        }
                        .font(TDTypography.caption1)
                        .foregroundColor(.white)
                        .padding(.horizontal, TDSpacing.sm)
                        .padding(.vertical, TDSpacing.xs)
                        .background(Capsule().fill(Color.black.opacity(0.6)))
                        .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
                        .shadow(color: Color.red.opacity(0.35), radius: 6, x: 0, y: 2)
                    }
                    .padding(.trailing, TDSpacing.md)
                    .padding(.bottom, TDSpacing.md)
                }
            }

            // Custom Controls Overlay
            if showControls {
                controlsOverlay
            }
        }
        // Screenshot-Schutz deaktiviert, um Black-Screen bei Video-Playback zu vermeiden
         .onAppear {
             playerManager.setupPlayer(url: videoURL)
             startControlsTimer()
            isScreenCaptured = UIScreen.main.isCaptured
            playerManager.handleScreenCaptureChanged(isCaptured: isScreenCaptured)
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                recPulse = true
            }
         }
         .onDisappear {
             playerManager.cleanup()
             controlsTimer?.invalidate()
         }
        .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)) { notification in
            guard let item = notification.object as? AVPlayerItem,
                  item == playerManager.player?.currentItem else { return }
            showPostVideoPrompt = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIScreen.capturedDidChangeNotification)) { _ in
            isScreenCaptured = UIScreen.main.isCaptured
            playerManager.handleScreenCaptureChanged(isCaptured: isScreenCaptured)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.userDidTakeScreenshotNotification)) { _ in
            showScreenshotOverlay = true
            Task { @MainActor in
                await playerManager.pauseForScreenshot()
                try? await Task.sleep(nanoseconds: 800_000_000)
                showScreenshotOverlay = false
            }
        }
         .statusBarHidden(true)
        .fullScreenCover(isPresented: $showMusicPlayer) {
            NavigationStack {
                MusicPlayerView(
                    autoStartRecorder: openRecorderDirectly,
                    autoSelectSuggestedTrack: autoSelectSuggestedTrack,
                    suggestedStyle: suggestedStyle
                )
            }
        }
        .confirmationDialog("Kurs beendet", isPresented: $showPostVideoPrompt, titleVisibility: .visible) {
            Button(T("Mit Übungsmusik filmen")) {
                openMusicRecorder(direct: true, suggest: true)
            }
            Button(T("Musik abspielen")) {
                openMusicRecorder(direct: false, suggest: true)
            }
            Button(T("Mit Musik filmen")) {
                openMusicRecorder(direct: true, suggest: false)
            }
            Button(T("Abbrechen"), role: .cancel) {}
        } message: {
            Text(T("Möchtest du jetzt mit Musik weiterüben und dich filmen?"))
        }
    }
    
    // MARK: - Controls Overlay
    private var controlsOverlay: some View {
        ZStack {
            // Gradient backgrounds
            VStack {
                LinearGradient(colors: [.black.opacity(0.7), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 120)
                Spacer()
                LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 150)
            }
            .ignoresSafeArea()
            
            VStack {
                // Top Bar
                topBar
                
                Spacer()
                
                // Center Controls
                centerControls
                
                Spacer()
                
                // Bottom Bar
                bottomBar
            }
            .padding()
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.2), value: showControls)
    }
    
    // MARK: - Top Bar
    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(TDSpacing.sm)
                    .background(Circle().fill(.ultraThinMaterial))
            }
            
            Spacer()
            
            Text(title)
                .font(TDTypography.headline)
                .foregroundColor(.white)
                .lineLimit(1)
            
            Spacer()
            
            // Placeholder for symmetry
            Color.clear
                .frame(width: 44, height: 44)
        }
    }
    
    // MARK: - Center Controls
    private var centerControls: some View {
        HStack(spacing: TDSpacing.xxl) {
            // Skip Back 10s
            Button {
                playerManager.skipBackward()
                resetControlsTimer()
            } label: {
                Image(systemName: "gobackward.10")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
            }
            
            // Play/Pause
            Button {
                playerManager.togglePlayPause()
                resetControlsTimer()
            } label: {
                Image(systemName: playerManager.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
                    .frame(width: 80, height: 80)
                    .background(Circle().fill(.ultraThinMaterial))
            }
            
            // Skip Forward 10s
            Button {
                playerManager.skipForward()
                resetControlsTimer()
            } label: {
                Image(systemName: "goforward.10")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
            }
        }
    }
    
    // MARK: - Bottom Bar
    private var bottomBar: some View {
        VStack(spacing: TDSpacing.sm) {
            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    Capsule()
                        .fill(Color.white.opacity(0.3))
                        .frame(height: 4)
                    
                    // Progress
                    Capsule()
                        .fill(Color.accentGold)
                        .frame(width: geometry.size.width * playerManager.progress, height: 4)
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let progress = value.location.x / geometry.size.width
                            playerManager.seek(to: max(0, min(1, progress)))
                            resetControlsTimer()
                        }
                )
            }
            .frame(height: 20)
            
            // Time & Speed
            HStack {
                Text(playerManager.currentTimeString)
                    .font(TDTypography.caption1)
                    .foregroundColor(.white.opacity(0.8))
                
                Spacer()
                
                // Playback Speed
                Menu {
                    ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { speed in
                        Button {
                            playerManager.setPlaybackSpeed(speed)
                            resetControlsTimer()
                        } label: {
                            HStack {
                                Text("\(speed, specifier: "%.2g")x")
                                if playerManager.playbackSpeed == speed {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: TDSpacing.xxs) {
                        Image(systemName: "speedometer")
                        Text("\(playerManager.playbackSpeed, specifier: "%.2g")x")
                    }
                    .font(TDTypography.caption1)
                    .foregroundColor(.white)
                    .padding(.horizontal, TDSpacing.sm)
                    .padding(.vertical, TDSpacing.xxs)
                    .background(Capsule().fill(.ultraThinMaterial))
                }
                
                Spacer()
                
                Text(playerManager.durationString)
                    .font(TDTypography.caption1)
                    .foregroundColor(.white.opacity(0.8))
            }

            Button {
                openMusicRecorder(direct: true, suggest: false)
                resetControlsTimer()
            } label: {
                HStack(spacing: TDSpacing.xs) {
                    Image(systemName: "music.note.list")
                    Text(T("Mit Musik filmen"))
                }
                .font(TDTypography.caption1)
                .foregroundColor(.white)
                .padding(.horizontal, TDSpacing.md)
                .padding(.vertical, TDSpacing.xs)
                .background(Capsule().fill(Color.accentGold))
            }
        }
    }
    
    // MARK: - Helper Methods
    private func toggleControls() {
        withAnimation {
            showControls.toggle()
        }
        if showControls {
            startControlsTimer()
        }
    }
    
    private func startControlsTimer() {
        controlsTimer?.invalidate()
        controlsTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { _ in
            // Timer callback - UI-Update muss über den playerManager erfolgen
            DispatchQueue.main.async {
                // Hier wird showControls nicht direkt aktualisiert wegen struct-Limitierung
                // Die Controls werden beim nächsten Tap ausgeblendet
            }
        }
    }
    
    private func resetControlsTimer() {
        startControlsTimer()
    }
    
    private func openMusicRecorder(direct: Bool, suggest: Bool) {
        openRecorderDirectly = direct
        autoSelectSuggestedTrack = suggest
        showMusicPlayer = true
    }
}

// MARK: - Video Player Manager
@MainActor
class VideoPlayerManager: ObservableObject {
    @Published var player: AVPlayer?
    @Published var isPlaying = false
    @Published var progress: Double = 0
    @Published var currentTimeString = "0:00"
    @Published var durationString = "0:00"
    @Published var playbackSpeed: Double = 1.0
    @Published var errorMessage: String?
    @Published var isLoading = false
    
    private var timeObserver: Any?
    private var statusObserver: NSKeyValueObservation?
    private var keepUpObserver: NSKeyValueObservation?
    private var wasPlayingBeforeCapture = false
    
    func setupPlayer(url: String) {
        // Nutze VideoHelper für flexible Video-Quellen
        guard let videoURL = VideoHelper.getVideoURL(for: url) else {
            errorMessage = "Video konnte nicht geladen werden"
            print("❌ Video URL ungültig: \(url)")
            return
        }
        
        print("✅ Lade Video von: \(videoURL)")
        
        let playerItem = AVPlayerItem(url: videoURL)
        player = AVPlayer(playerItem: playerItem)
        isLoading = true
        errorMessage = nil
        
        // Observe player status for errors
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] notification in
            if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
                print("❌ Video Playback Fehler: \(error.localizedDescription)")
                Task { @MainActor [weak self] in
                    self?.errorMessage = "Video konnte nicht abgespielt werden: \(error.localizedDescription)"
                    self?.isLoading = false
                }
            }
        }

        statusObserver = playerItem.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            Task { @MainActor [weak self] in
                switch item.status {
                case .readyToPlay:
                    self?.isLoading = false
                case .failed:
                    self?.isLoading = false
                    let message = item.error?.localizedDescription ?? "Unbekannter Fehler"
                    self?.errorMessage = "Video konnte nicht abgespielt werden: \(message)"
                case .unknown:
                    self?.isLoading = true
                @unknown default:
                    self?.isLoading = false
                }
            }
        }

        keepUpObserver = playerItem.observe(\.isPlaybackLikelyToKeepUp, options: [.new]) { [weak self] item, _ in
            Task { @MainActor [weak self] in
                if item.isPlaybackLikelyToKeepUp {
                    self?.isLoading = false
                }
            }
        }

        // Add time observer
        timeObserver = player?.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor [weak self] in
                self?.updateProgress(time: time)
            }
        }
        
        // Start playing
        player?.play()
        isPlaying = true
    }
    
    func cleanup() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
        NotificationCenter.default.removeObserver(self)
        statusObserver?.invalidate()
        statusObserver = nil
        keepUpObserver?.invalidate()
        keepUpObserver = nil
        player?.pause()
        player = nil
    }
    
    func handleScreenCaptureChanged(isCaptured: Bool) {
        if isCaptured {
            wasPlayingBeforeCapture = isPlaying
            player?.pause()
            isPlaying = false
        } else if wasPlayingBeforeCapture {
            player?.play()
            isPlaying = true
            wasPlayingBeforeCapture = false
        }
    }
    
    func pauseForScreenshot() async {
        let shouldResume = isPlaying
        player?.pause()
        isPlaying = false
        if shouldResume && !UIScreen.main.isCaptured {
            player?.play()
            isPlaying = true
        }
    }
    
    func togglePlayPause() {
        guard let player = player else { return }
        
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }
    
    func skipForward() {
        guard let player = player else { return }
        let currentTime = player.currentTime()
        let newTime = CMTimeAdd(currentTime, CMTime(seconds: 10, preferredTimescale: 600))
        player.seek(to: newTime)
    }
    
    func skipBackward() {
        guard let player = player else { return }
        let currentTime = player.currentTime()
        let newTime = CMTimeSubtract(currentTime, CMTime(seconds: 10, preferredTimescale: 600))
        player.seek(to: newTime)
    }
    
    func seek(to progress: Double) {
        guard let player = player,
              let duration = player.currentItem?.duration else { return }
        
        let totalSeconds = CMTimeGetSeconds(duration)
        let seekTime = CMTime(seconds: totalSeconds * progress, preferredTimescale: 600)
        player.seek(to: seekTime)
    }
    
    func setPlaybackSpeed(_ speed: Double) {
        player?.rate = Float(speed)
        playbackSpeed = speed
        if !isPlaying {
            player?.pause()
        }
    }
    
    private func updateProgress(time: CMTime) {
        guard let duration = player?.currentItem?.duration else { return }
        
        let currentSeconds = CMTimeGetSeconds(time)
        let totalSeconds = CMTimeGetSeconds(duration)
        
        if totalSeconds > 0 {
            progress = currentSeconds / totalSeconds
        }
        
        currentTimeString = formatTime(currentSeconds)
        durationString = formatTime(totalSeconds)
    }
    
    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && !seconds.isNaN else { return "0:00" }
        
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

#Preview {
    VideoPlayerView(
        videoURL: "https://sample-videos.com/video321/mp4/720/big_buck_bunny_720p_1mb.mp4",
        title: "Wiener Walzer - Lektion 1",
        suggestedStyle: .viennese_waltz
    )
}
