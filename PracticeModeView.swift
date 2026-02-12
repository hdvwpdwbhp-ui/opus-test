//
//  PracticeModeView.swift
//  Tanzen mit Tatiana Drexler
//
//  Übungsmodus mit Slow-Motion, Loop, Spiegel-Modus und Metronom
//

import SwiftUI
import AVKit
import AVFoundation
import Combine

// MARK: - Practice Mode Settings
struct PracticeModeSettings {
    var playbackSpeed: Float = 1.0
    var isMirrored: Bool = false
    var isLoopEnabled: Bool = false
    var loopStart: TimeInterval = 0
    var loopEnd: TimeInterval = 0
    var metronomeEnabled: Bool = false
    var metronomeBPM: Int = 120
    var showBeatCounter: Bool = false
}

// MARK: - Practice Mode Video Player
struct PracticeModeView: View {
    let videoURL: String
    let lessonTitle: String
    
    @Environment(\.dismiss) var dismiss
    @StateObject private var playerManager = PracticeModePlayerManager()
    @State private var settings = PracticeModeSettings()
    @State private var showSettings = false
    @State private var showSpeedPicker = false
    @State private var isSettingLoopStart = false
    @State private var isSettingLoopEnd = false
    
    let speedOptions: [Float] = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5]
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Video Player
                ZStack {
                    if let player = playerManager.player {
                        VideoPlayer(player: player)
                            .scaleEffect(x: settings.isMirrored ? -1 : 1, y: 1)
                            .onAppear {
                                playerManager.setupPlayer(url: videoURL)
                                playerManager.setPlaybackSpeed(settings.playbackSpeed)
                            }
                    } else {
                        ProgressView()
                            .tint(.white)
                    }
                    
                    // Beat Counter Overlay
                    if settings.showBeatCounter && settings.metronomeEnabled {
                        VStack {
                            Spacer()
                            HStack {
                                BeatCounterView(bpm: settings.metronomeBPM)
                                Spacer()
                            }
                            .padding()
                        }
                    }
                    
                    // Loop Indicator
                    if settings.isLoopEnabled && settings.loopEnd > settings.loopStart {
                        VStack {
                            HStack {
                                Spacer()
                                LoopIndicator(
                                    start: settings.loopStart,
                                    end: settings.loopEnd,
                                    current: playerManager.currentTime,
                                    duration: playerManager.duration
                                )
                                .padding()
                            }
                            Spacer()
                        }
                    }
                }
                .frame(maxHeight: UIScreen.main.bounds.height * 0.6)
                
                // Controls
                VStack(spacing: TDSpacing.md) {
                    // Progress Bar
                    PracticeProgressBar(
                        currentTime: playerManager.currentTime,
                        duration: playerManager.duration,
                        loopStart: settings.isLoopEnabled ? settings.loopStart : nil,
                        loopEnd: settings.isLoopEnabled ? settings.loopEnd : nil,
                        onSeek: { time in
                            playerManager.seek(to: time)
                        }
                    )
                    
                    // Time Display
                    HStack {
                        Text(formatTime(playerManager.currentTime))
                        Spacer()
                        Text(formatTime(playerManager.duration))
                    }
                    .font(TDTypography.caption1)
                    .foregroundColor(.white.opacity(0.7))
                    
                    // Main Controls
                    HStack(spacing: TDSpacing.xl) {
                        // Speed Control
                        Button {
                            showSpeedPicker.toggle()
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "speedometer")
                                    .font(.title2)
                                Text("\(settings.playbackSpeed, specifier: "%.2g")x")
                                    .font(TDTypography.caption2)
                            }
                            .foregroundColor(settings.playbackSpeed != 1.0 ? Color.accentGold : .white)
                        }
                        
                        // Skip Back 5s
                        Button {
                            playerManager.skip(seconds: -5)
                        } label: {
                            Image(systemName: "gobackward.5")
                                .font(.title)
                                .foregroundColor(.white)
                        }
                        
                        // Play/Pause
                        Button {
                            playerManager.togglePlayPause()
                        } label: {
                            Image(systemName: playerManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.white)
                        }
                        
                        // Skip Forward 5s
                        Button {
                            playerManager.skip(seconds: 5)
                        } label: {
                            Image(systemName: "goforward.5")
                                .font(.title)
                                .foregroundColor(.white)
                        }
                        
                        // Settings
                        Button {
                            showSettings.toggle()
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.title2)
                                Text(T("Mehr"))
                                    .font(TDTypography.caption2)
                            }
                            .foregroundColor(.white)
                        }
                    }
                    
                    // Quick Action Buttons
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: TDSpacing.sm) {
                            // Mirror Toggle
                            PracticeQuickButton(
                                icon: "arrow.left.and.right.righttriangle.left.righttriangle.right",
                                label: "Spiegel",
                                isActive: settings.isMirrored
                            ) {
                                settings.isMirrored.toggle()
                            }
                            
                            // Loop Toggle
                            PracticeQuickButton(
                                icon: "repeat",
                                label: "Loop",
                                isActive: settings.isLoopEnabled
                            ) {
                                if !settings.isLoopEnabled {
                                    // Enable loop with current position as start
                                    settings.loopStart = playerManager.currentTime
                                    settings.loopEnd = min(playerManager.currentTime + 10, playerManager.duration)
                                    settings.isLoopEnabled = true
                                    playerManager.setLoop(start: settings.loopStart, end: settings.loopEnd)
                                } else {
                                    settings.isLoopEnabled = false
                                    playerManager.disableLoop()
                                }
                            }
                            
                            // Set Loop Start
                            if settings.isLoopEnabled {
                                PracticeQuickButton(
                                    icon: "a.square",
                                    label: "Start",
                                    isActive: false
                                ) {
                                    settings.loopStart = playerManager.currentTime
                                    playerManager.setLoop(start: settings.loopStart, end: settings.loopEnd)
                                }
                                
                                PracticeQuickButton(
                                    icon: "b.square",
                                    label: "Ende",
                                    isActive: false
                                ) {
                                    settings.loopEnd = playerManager.currentTime
                                    playerManager.setLoop(start: settings.loopStart, end: settings.loopEnd)
                                }
                            }
                            
                            // Metronome
                            PracticeQuickButton(
                                icon: "metronome",
                                label: "Takt",
                                isActive: settings.metronomeEnabled
                            ) {
                                settings.metronomeEnabled.toggle()
                                if settings.metronomeEnabled {
                                    playerManager.startMetronome(bpm: settings.metronomeBPM)
                                } else {
                                    playerManager.stopMetronome()
                                }
                            }
                            
                            // Slow Motion Presets
                            PracticeQuickButton(
                                icon: "tortoise",
                                label: "0.5x",
                                isActive: settings.playbackSpeed == 0.5
                            ) {
                                settings.playbackSpeed = 0.5
                                playerManager.setPlaybackSpeed(0.5)
                            }
                            
                            PracticeQuickButton(
                                icon: "hare",
                                label: "1x",
                                isActive: settings.playbackSpeed == 1.0
                            ) {
                                settings.playbackSpeed = 1.0
                                playerManager.setPlaybackSpeed(1.0)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding()
            }
        }
        .overlay(alignment: .topLeading) {
            // Close Button
            Button {
                playerManager.cleanup()
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.white.opacity(0.8))
                    .padding()
            }
        }
        .overlay(alignment: .top) {
            // Title
            Text(lessonTitle)
                .font(TDTypography.headline)
                .foregroundColor(.white)
                .padding(.top, 50)
        }
        .sheet(isPresented: $showSpeedPicker) {
            SpeedPickerSheet(
                selectedSpeed: $settings.playbackSpeed,
                onSelect: { speed in
                    playerManager.setPlaybackSpeed(speed)
                }
            )
            .presentationDetents([.height(300)])
        }
        .sheet(isPresented: $showSettings) {
            PracticeModeSettingsSheet(
                settings: $settings,
                playerManager: playerManager
            )
            .presentationDetents([.medium])
        }
        .onDisappear {
            playerManager.cleanup()
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Practice Mode Player Manager
@MainActor
class PracticeModePlayerManager: ObservableObject {
    @Published var player: AVPlayer?
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    
    private var timeObserver: Any?
    private var loopObserver: Any?
    private var metronomeTimer: Timer?
    private var audioPlayer: AVAudioPlayer?
    
    func setupPlayer(url: String) {
        guard let videoURL = URL(string: url) else { return }
        
        let playerItem = AVPlayerItem(url: videoURL)
        player = AVPlayer(playerItem: playerItem)
        
        // Get duration
        Task {
            if let duration = try? await playerItem.asset.load(.duration) {
                self.duration = CMTimeGetSeconds(duration)
            }
        }
        
        // Time observer
        timeObserver = player?.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor [weak self] in
                self?.currentTime = CMTimeGetSeconds(time)
            }
         }
        
        player?.play()
        isPlaying = true
    }
    
    func togglePlayPause() {
        if isPlaying {
            player?.pause()
        } else {
            player?.play()
        }
        isPlaying.toggle()
    }
    
    func skip(seconds: Double) {
        guard let player = player else { return }
        let currentTime = CMTimeGetSeconds(player.currentTime())
        let newTime = max(0, min(currentTime + seconds, duration))
        player.seek(to: CMTime(seconds: newTime, preferredTimescale: 600))
    }
    
    func seek(to time: TimeInterval) {
        player?.seek(to: CMTime(seconds: time, preferredTimescale: 600))
    }
    
    func setPlaybackSpeed(_ speed: Float) {
        player?.rate = isPlaying ? speed : 0
        if isPlaying {
            player?.rate = speed
        }
    }
    
    func setLoop(start: TimeInterval, end: TimeInterval) {
        // Remove existing observer
        if let observer = loopObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        
        // Add boundary observer
        let endTime = CMTime(seconds: end, preferredTimescale: 600)
        loopObserver = player?.addBoundaryTimeObserver(
            forTimes: [NSValue(time: endTime)],
            queue: .main
        ) { [weak self] in
            Task { @MainActor [weak self] in
                self?.seek(to: start)
            }
         }
    }
    
    func disableLoop() {
        if let observer = loopObserver {
            NotificationCenter.default.removeObserver(observer)
            loopObserver = nil
        }
    }
    
    func startMetronome(bpm: Int) {
        let interval = 60.0 / Double(bpm)
        metronomeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.playMetronomeClick()
            }
         }
    }
    
    func stopMetronome() {
        metronomeTimer?.invalidate()
        metronomeTimer = nil
    }
    
    private func playMetronomeClick() {
        AudioServicesPlaySystemSound(1104) // Tock sound
    }
    
    func cleanup() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
        disableLoop()
        stopMetronome()
        player?.pause()
        player = nil
    }
}

// MARK: - Supporting Views

struct PracticeQuickButton: View {
    let icon: String
    let label: String
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                Text(label)
                    .font(.system(size: 10))
            }
            .foregroundColor(isActive ? Color.accentGold : .white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isActive ? Color.accentGold.opacity(0.2) : Color.white.opacity(0.1))
            )
        }
    }
}

struct PracticeProgressBar: View {
    let currentTime: TimeInterval
    let duration: TimeInterval
    let loopStart: TimeInterval?
    let loopEnd: TimeInterval?
    let onSeek: (TimeInterval) -> Void
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(height: 4)
                
                // Loop Region
                if let start = loopStart, let end = loopEnd, duration > 0 {
                    Rectangle()
                        .fill(Color.accentGold.opacity(0.3))
                        .frame(
                            width: CGFloat((end - start) / duration) * geometry.size.width,
                            height: 4
                        )
                        .offset(x: CGFloat(start / duration) * geometry.size.width)
                }
                
                // Progress
                Rectangle()
                    .fill(Color.accentGold)
                    .frame(width: duration > 0 ? CGFloat(currentTime / duration) * geometry.size.width : 0, height: 4)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let progress = value.location.x / geometry.size.width
                        let time = Double(progress) * duration
                        onSeek(max(0, min(time, duration)))
                    }
            )
        }
        .frame(height: 20)
    }
}

struct LoopIndicator: View {
    let start: TimeInterval
    let end: TimeInterval
    let current: TimeInterval
    let duration: TimeInterval
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "repeat")
                .font(.caption)
            Text("\(formatTime(start)) - \(formatTime(end))")
                .font(TDTypography.caption2)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.accentGold.opacity(0.8))
        .cornerRadius(4)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct BeatCounterView: View {
    let bpm: Int
    @State private var currentBeat = 1
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...4, id: \.self) { beat in
                Circle()
                    .fill(beat == currentBeat ? Color.accentGold : Color.white.opacity(0.3))
                    .frame(width: 12, height: 12)
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.5))
        .cornerRadius(8)
        .onAppear {
            startBeatAnimation()
        }
    }
    
    private func startBeatAnimation() {
        let interval = 60.0 / Double(bpm)
        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            currentBeat = currentBeat % 4 + 1
        }
    }
}

struct SpeedPickerSheet: View {
    @Binding var selectedSpeed: Float
    let onSelect: (Float) -> Void
    @Environment(\.dismiss) var dismiss
    
    let speeds: [(Float, String)] = [
        (0.25, "0.25x - Sehr langsam"),
        (0.5, "0.5x - Langsam"),
        (0.75, "0.75x - Etwas langsamer"),
        (1.0, "1x - Normal"),
        (1.25, "1.25x - Etwas schneller"),
        (1.5, "1.5x - Schnell")
    ]
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(speeds, id: \.0) { speed, label in
                    Button {
                        selectedSpeed = speed
                        onSelect(speed)
                        dismiss()
                    } label: {
                        HStack {
                            Text(label)
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedSpeed == speed {
                                Image(systemName: "checkmark")
                                    .foregroundColor(Color.accentGold)
                            }
                        }
                    }
                }
            }
            .navigationTitle(T("Geschwindigkeit"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct PracticeModeSettingsSheet: View {
    @Binding var settings: PracticeModeSettings
    let playerManager: PracticeModePlayerManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section(T("Wiedergabe")) {
                    Toggle("Spiegeln", isOn: $settings.isMirrored)
                    
                    Toggle("Loop aktivieren", isOn: $settings.isLoopEnabled)
                        .onChange(of: settings.isLoopEnabled) { _, newValue in
                            if newValue {
                                playerManager.setLoop(start: settings.loopStart, end: settings.loopEnd)
                            } else {
                                playerManager.disableLoop()
                            }
                        }
                }
                
                Section(T("Metronom")) {
                    Toggle("Metronom aktivieren", isOn: $settings.metronomeEnabled)
                        .onChange(of: settings.metronomeEnabled) { _, newValue in
                            if newValue {
                                playerManager.startMetronome(bpm: settings.metronomeBPM)
                            } else {
                                playerManager.stopMetronome()
                            }
                        }
                    
                    if settings.metronomeEnabled {
                        Stepper("BPM: \(settings.metronomeBPM)", value: $settings.metronomeBPM, in: 40...200, step: 5)
                            .onChange(of: settings.metronomeBPM) { _, newValue in
                                playerManager.stopMetronome()
                                playerManager.startMetronome(bpm: newValue)
                            }
                        
                        Toggle("Beat-Zähler anzeigen", isOn: $settings.showBeatCounter)
                    }
                }
            }
            .navigationTitle(T("Einstellungen"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(T("Fertig")) { dismiss() }
                }
            }
        }
    }
}

#Preview {
    PracticeModeView(
        videoURL: "https://example.com/video.mp4",
        lessonTitle: "Salsa Grundschritt"
    )
}
