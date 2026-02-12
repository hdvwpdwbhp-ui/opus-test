//
//  MusicPlayerView.swift
//  Tanzen mit Tatiana Drexler
//
//  Musik-Features: Eigene Musik, Tempo anpassen
//

import SwiftUI
import AVFoundation
import MediaPlayer
import Combine

struct SpotifyAppConfig {
    static var clientId: String {
        Bundle.main.object(forInfoDictionaryKey: "SpotifyClientID") as? String ?? ""
    }

    static var redirectURI: String {
        Bundle.main.object(forInfoDictionaryKey: "SpotifyRedirectURI") as? String ?? ""
    }

    static var isConfigured: Bool {
        !clientId.isEmpty && !redirectURI.isEmpty
    }
}

enum MusicSource: String, Codable, CaseIterable, Identifiable {
    case appleMusic = "Apple Music"
    case spotify = "Spotify"

    var id: String { rawValue }
}

// MARK: - Music Player Manager
@MainActor
class MusicPlayerManager: ObservableObject {
    static let shared = MusicPlayerManager()

    @Published var isPlaying = false
    @Published var currentTrack: MusicTrack?
    @Published var playlist: [MusicTrack] = []
    @Published var currentTempo: Float = 1.0 // 0.5 - 2.0
    @Published var volume: Float = 0.7
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var appleMusicAuthorization: MPMediaLibraryAuthorizationStatus = .notDetermined
    @Published var appleMusicTracks: [MusicTrack] = []
    @Published var spotifyTracks: [MusicTrack] = []

    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    private let appleMusicPlayer = MPMusicPlayerApplicationController.systemMusicPlayer

    // Sample BPMs for different dance styles (for reference when loading external music)
    let styleBPMs: [DanceStyle: Int] = [
        .waltz: 180,
        .tango: 130,
        .salsa: 180,
        .cha_cha: 120,
        .rumba: 100,
        .jive: 176,
        .discofox: 132,
        .bachata: 130,
        .latein: 140,
        .standard: 120,
        .foxtrot: 120,
        .quickstep: 200,
        .viennese_waltz: 180
    ]

    private init() {
        setupAudioSession()
        setupAppleMusic()
    }

    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session setup failed: \(error)")
        }
    }

    // MARK: - Playback Control

    func play(track: MusicTrack) {
        currentTrack = track

        switch track.source {
        case .appleMusic:
            playAppleMusic(track: track)
        case .spotify:
            // Placeholder: Spotify SDK Integration erforderlich
            isPlaying = false
        }
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            resume()
        }
    }

    func pause() {
        if currentTrack?.source == .appleMusic {
            appleMusicPlayer.pause()
        } else {
            audioPlayer?.pause()
        }
        isPlaying = false
        timer?.invalidate()
    }

    func resume() {
        if currentTrack?.source == .appleMusic {
            appleMusicPlayer.play()
        } else {
            audioPlayer?.play()
        }
        isPlaying = true
        startTimer()
    }

    func stop() {
        if currentTrack?.source == .appleMusic {
            appleMusicPlayer.stop()
        } else {
            audioPlayer?.stop()
        }
        isPlaying = false
        currentTime = 0
        timer?.invalidate()
    }

    func seek(to time: TimeInterval) {
        if currentTrack?.source == .appleMusic {
            appleMusicPlayer.currentPlaybackTime = time
        } else {
            audioPlayer?.currentTime = time
        }
        currentTime = time
    }

    // MARK: - Tempo Control

    func setTempo(_ tempo: Float) {
        currentTempo = tempo
        audioPlayer?.rate = tempo
        // For AVPlayer-based implementation
    }

    func increaseTempo() {
        let newTempo = min(currentTempo + 0.1, 2.0)
        setTempo(newTempo)
    }

    func decreaseTempo() {
        let newTempo = max(currentTempo - 0.1, 0.5)
        setTempo(newTempo)
    }

    func setVolume(_ volume: Float) {
        self.volume = volume
        audioPlayer?.volume = volume
    }

    // MARK: - Timer

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                if self.isPlaying {
                    if self.currentTrack?.source == .appleMusic {
                        self.currentTime = self.appleMusicPlayer.currentPlaybackTime
                        self.duration = self.appleMusicPlayer.nowPlayingItem?.playbackDuration ?? 0
                    } else {
                        self.currentTime += 0.5 * Double(self.currentTempo)
                    }
                    if self.currentTime >= self.duration {
                        self.playNext()
                    }
                }
            }
        }
    }

    func playNext() {
        guard !playlist.isEmpty, let current = currentTrack else { return }
        if let currentIndex = playlist.firstIndex(where: { $0.id == current.id }),
           currentIndex < playlist.count - 1 {
            play(track: playlist[currentIndex + 1])
        } else {
            stop()
        }
    }

    func playPrevious() {
        guard !playlist.isEmpty, let current = currentTrack else { return }
        if let currentIndex = playlist.firstIndex(where: { $0.id == current.id }),
           currentIndex > 0 {
            play(track: playlist[currentIndex - 1])
        }
    }

    func suggestedTrack(for style: DanceStyle?, referenceBPM: Int? = nil) -> MusicTrack? {
        // First check Apple Music tracks for matching style
        if let style, let match = appleMusicTracks.first(where: { $0.style == style }) {
            return match
        }
        // Return first available track if no match
        return appleMusicTracks.first ?? spotifyTracks.first
    }

    func suggestedBPM(for style: DanceStyle?) -> Int? {
        if let style {
            return styleBPMs[style]
        }
        return nil
    }
}

// MARK: - Music Track Model
struct MusicTrack: Identifiable, Codable {
    let id: String
    let title: String
    let artist: String
    let bpm: Int
    let style: DanceStyle
    let source: MusicSource
    var fileURL: String?
    var appleMusicPersistentId: UInt64?
    var spotifyURI: String?

    var tempoDescription: String {
        switch bpm {
        case 0..<80: return "Sehr langsam"
        case 80..<100: return "Langsam"
        case 100..<130: return "Mittel"
        case 130..<160: return "Schnell"
        default: return "Sehr schnell"
        }
    }
}

// MARK: - Music Player View
struct MusicPlayerView: View {
    @StateObject private var musicManager = MusicPlayerManager.shared
    @State private var selectedStyle: DanceStyle?
    @State private var showMiniPlayer = false
    @State private var selectedSource: MusicSource = .appleMusic
    @State private var showAppleMusicPicker = false
    @State private var showRecorder = false
    @State private var showRecorderRequiresTrack = false

    let autoStartRecorder: Bool
    let autoSelectSuggestedTrack: Bool
    let suggestedStyle: DanceStyle?

    init(autoStartRecorder: Bool = false, autoSelectSuggestedTrack: Bool = false, suggestedStyle: DanceStyle? = nil) {
        self.autoStartRecorder = autoStartRecorder
        self.autoSelectSuggestedTrack = autoSelectSuggestedTrack
        self.suggestedStyle = suggestedStyle
    }

    var filteredTracks: [MusicTrack] {
        if let style = selectedStyle {
            return currentTracks.filter { $0.style == style }
        }
        return currentTracks
    }

    private var suggestedTrack: MusicTrack? {
        guard suggestedStyle != nil else { return nil }
        return musicManager.suggestedTrack(for: suggestedStyle)
    }

    private var currentTracks: [MusicTrack] {
        switch selectedSource {
        case .appleMusic:
            return musicManager.appleMusicTracks
        case .spotify:
            return musicManager.spotifyTracks
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main Content
            ScrollView {
                VStack(spacing: TDSpacing.lg) {
                    sourceSelector

                    if selectedSource == .appleMusic {
                        appleMusicControls
                    }
                    if selectedSource == .spotify {
                        spotifyNotice
                    }

                    // Style Filter
                    styleFilter

                    // Track List
                    trackList
                }
                .padding()
            }

            // Mini Player
            if musicManager.currentTrack != nil {
                miniPlayerBar
            }
        }
        .background(TDGradients.mainBackground.ignoresSafeArea())
        .navigationTitle(T("Übungsmusik"))
        .sheet(isPresented: $showMiniPlayer) {
            FullMusicPlayerView()
        }
        .fullScreenCover(isPresented: $showRecorder) {
            MusicVideoRecorderView()
        }
        .sheet(isPresented: $showAppleMusicPicker) {
            AppleMusicPicker { items in
                musicManager.addAppleMusicItems(items)
            }
        }
        .onAppear {
            if autoSelectSuggestedTrack, musicManager.currentTrack == nil {
                let suggested = musicManager.suggestedTrack(for: suggestedStyle)
                if let suggested {
                    musicManager.play(track: suggested)
                }
            }
            guard autoStartRecorder else { return }
            if musicManager.currentTrack != nil {
                musicManager.resume()
                showRecorder = true
            } else {
                showRecorderRequiresTrack = true
            }
        }
        .alert(T("Bitte Track wählen"), isPresented: $showRecorderRequiresTrack) {
            Button(T("OK"), role: .cancel) {}
        } message: {
            Text(T("Wähle zuerst einen Musik‑Track, dann kannst du mit der Aufnahme starten."))
        }
    }

    // MARK: - Style Filter
    private var styleFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: TDSpacing.sm) {
                MusicFilterChip(label: "Alle", isSelected: selectedStyle == nil) {
                    selectedStyle = nil
                }

                ForEach(DanceStyle.allCases, id: \.self) { style in
                    MusicFilterChip(label: style.rawValue, isSelected: selectedStyle == style) {
                        selectedStyle = style
                    }
                }
            }
        }
    }

    // MARK: - Track List
    private var trackList: some View {
        VStack(spacing: TDSpacing.sm) {
            ForEach(filteredTracks) { track in
                TrackRow(
                    track: track,
                    isPlaying: musicManager.currentTrack?.id == track.id && musicManager.isPlaying,
                    isSuggested: suggestedTrack?.id == track.id
                ) {
                    musicManager.play(track: track)
                }
            }
        }
    }

    // MARK: - Mini Player Bar
    private var miniPlayerBar: some View {
        VStack(spacing: 0) {
            // Progress Bar
            GeometryReader { geometry in
                Rectangle()
                    .fill(Color.accentGold)
                    .frame(width: geometry.size.width * CGFloat(musicManager.currentTime / max(musicManager.duration, 1)))
            }
            .frame(height: 2)

            HStack(spacing: TDSpacing.md) {
                // Track Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(musicManager.currentTrack?.title ?? "")
                        .font(TDTypography.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    Text("\(musicManager.currentTrack?.bpm ?? 0) BPM • \(Int(musicManager.currentTempo * 100))%")
                        .font(TDTypography.caption1)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Controls
                HStack(spacing: TDSpacing.lg) {
                    Button {
                        musicManager.playPrevious()
                    } label: {
                        Image(systemName: "backward.fill")
                            .font(.title3)
                    }

                    Button {
                        musicManager.togglePlayPause()
                    } label: {
                        Image(systemName: musicManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(Color.accentGold)
                    }

                    Button {
                        musicManager.playNext()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.title3)
                    }

                    Button {
                        showRecorder = true
                    } label: {
                        Image(systemName: "camera.fill")
                            .font(.title3)
                    }
                }
                .foregroundColor(.primary)
            }
            .padding()
            .background(Color.white)
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: -2)
            .onTapGesture {
                showMiniPlayer = true
            }
        }
    }

    private var sourceSelector: some View {
        HStack(spacing: TDSpacing.sm) {
            ForEach(MusicSource.allCases) { source in
                MusicFilterChip(label: source.rawValue, isSelected: selectedSource == source) {
                    selectedSource = source
                }
            }
        }
    }

    private var appleMusicControls: some View {
        VStack(alignment: .leading, spacing: TDSpacing.sm) {
            Button(T("Apple Music Titel hinzufügen")) {
                Task {
                    await musicManager.requestAppleMusicAccess()
                    if musicManager.appleMusicAuthorization == .authorized {
                        showAppleMusicPicker = true
                    }
                }
            }
            .buttonStyle(.tdPrimary)

            if musicManager.appleMusicTracks.isEmpty {
                Text(T("Wähle Titel aus deiner Apple‑Music‑Mediathek aus."))
                    .font(TDTypography.caption1)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var spotifyNotice: some View {
        VStack(alignment: .leading, spacing: TDSpacing.sm) {
            if SpotifyAppConfig.isConfigured {
                Text(T("Spotify‑Login ist vorbereitet."))
                    .font(TDTypography.caption1)
                    .foregroundColor(.secondary)
                Text(T("Für echte In‑App‑Wiedergabe fehlt noch das Spotify SDK."))
                    .font(TDTypography.caption2)
                    .foregroundColor(.secondary)
            } else {
                Text(T("Spotify ist noch nicht konfiguriert."))
                    .font(TDTypography.caption1)
                    .foregroundColor(.secondary)
                Text(T("Trage Client‑ID und Redirect‑URI in der Info.plist ein."))
                    .font(TDTypography.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Filter Chip
struct MusicFilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(TDTypography.caption1)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.accentGold : Color.gray.opacity(0.1))
                )
        }
    }
}

// MARK: - Track Row
struct TrackRow: View {
    let track: MusicTrack
    let isPlaying: Bool
    let isSuggested: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: TDSpacing.md) {
                // Style Icon
                ZStack {
                    Circle()
                        .fill(isPlaying ? Color.accentGold : Color.gray.opacity(0.1))
                        .frame(width: 50, height: 50)

                    if isPlaying {
                        // Animated equalizer
                        HStack(spacing: 2) {
                            ForEach(0..<3, id: \.self) { i in
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(Color.white)
                                    .frame(width: 3, height: CGFloat.random(in: 8...20))
                            }
                        }
                    } else {
                        Image(systemName: "music.note")
                            .foregroundColor(.secondary)
                    }
                }

                // Track Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(track.title)
                        .font(TDTypography.body)
                        .foregroundColor(isPlaying ? Color.accentGold : .primary)

                    HStack {
                        Text(track.style.rawValue)
                        Text(T("•"))
                        Text("\(track.bpm) BPM")
                    }
                    .font(TDTypography.caption1)
                    .foregroundColor(.secondary)

                    if isSuggested {
                        Text(T("Empfohlen für deinen Kurs"))
                            .font(TDTypography.caption2)
                            .foregroundColor(Color.accentGold)
                    }
                }

                Spacer()

                // Play indicator
                if isPlaying {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundColor(Color.accentGold)
                } else {
                    Image(systemName: "play.circle")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: TDRadius.md)
                    .fill(isPlaying ? Color.accentGold.opacity(0.1) : Color.white)
            )
        }
    }
}

// MARK: - Full Music Player View
struct FullMusicPlayerView: View {
    @StateObject private var musicManager = MusicPlayerManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var showRecorder = false

    var body: some View {
        NavigationStack {
            VStack(spacing: TDSpacing.xl) {
                Spacer()

                // Album Art
                ZStack {
                    Circle()
                        .fill(Color.accentGold.opacity(0.2))
                        .frame(width: 200, height: 200)

                    Image(systemName: "music.note")
                        .font(.system(size: 60))
                        .foregroundColor(Color.accentGold)
                }
                .rotationEffect(.degrees(musicManager.isPlaying ? 360 : 0))
                .animation(musicManager.isPlaying ? .linear(duration: 3).repeatForever(autoreverses: false) : .default, value: musicManager.isPlaying)

                // Track Info
                VStack(spacing: 8) {
                    Text(musicManager.currentTrack?.title ?? "Keine Musik")
                        .font(TDTypography.title2)

                    Text(musicManager.currentTrack?.style.rawValue ?? "")
                        .font(TDTypography.subheadline)
                        .foregroundColor(.secondary)

                    Text("\(musicManager.currentTrack?.bpm ?? 0) BPM")
                        .font(TDTypography.caption1)
                        .foregroundColor(Color.accentGold)
                }

                // Progress Bar
                VStack(spacing: 8) {
                    Slider(value: Binding(
                        get: { musicManager.currentTime },
                        set: { musicManager.seek(to: $0) }
                    ), in: 0...max(musicManager.duration, 1))
                    .tint(Color.accentGold)

                    HStack {
                        Text(formatTime(musicManager.currentTime))
                        Spacer()
                        Text(formatTime(musicManager.duration))
                    }
                    .font(TDTypography.caption1)
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal)

                // Controls
                HStack(spacing: TDSpacing.xl) {
                    Button { musicManager.playPrevious() } label: {
                        Image(systemName: "backward.fill")
                            .font(.title)
                    }

                    Button { musicManager.togglePlayPause() } label: {
                        Image(systemName: musicManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 70))
                            .foregroundColor(Color.accentGold)
                    }

                    Button { musicManager.playNext() } label: {
                        Image(systemName: "forward.fill")
                            .font(.title)
                    }
                }
                .foregroundColor(.primary)

                Button {
                    showRecorder = true
                } label: {
                    HStack {
                        Image(systemName: "camera.fill")
                        Text(T("Mit Musik filmen"))
                    }
                    .font(TDTypography.caption1)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.accentGold))
                    .foregroundColor(.white)
                }
            }
            .padding()
            .navigationTitle(T("Musik-Player"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(T("Fertig")) { dismiss() }
                }
            }
            .fullScreenCover(isPresented: $showRecorder) {
                MusicVideoRecorderView()
            }
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct TempoButton: View {
    let label: String
    let tempo: Float
    let currentTempo: Float
    let action: () -> Void

    var isSelected: Bool {
        abs(currentTempo - tempo) < 0.01
    }

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(TDTypography.caption1)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.accentGold : Color.white)
                )
        }
    }
}

// MARK: - Apple Music Picker
struct AppleMusicPicker: UIViewControllerRepresentable {
    let onPicked: ([MPMediaItem]) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> MPMediaPickerController {
        let picker = MPMediaPickerController(mediaTypes: .music)
        picker.allowsPickingMultipleItems = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: MPMediaPickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPicked: onPicked, dismiss: dismiss)
    }

    final class Coordinator: NSObject, MPMediaPickerControllerDelegate {
        let onPicked: ([MPMediaItem]) -> Void
        let dismiss: DismissAction

        init(onPicked: @escaping ([MPMediaItem]) -> Void, dismiss: DismissAction) {
            self.onPicked = onPicked
            self.dismiss = dismiss
        }

        func mediaPicker(_ mediaPicker: MPMediaPickerController, didPickMediaItems mediaItemCollection: MPMediaItemCollection) {
            onPicked(mediaItemCollection.items)
            dismiss()
        }

        func mediaPickerDidCancel(_ mediaPicker: MPMediaPickerController) {
            dismiss()
        }
    }
}

extension MusicPlayerManager {
    func requestAppleMusicAccess() async {
        let status = MPMediaLibrary.authorizationStatus()
        if status == .notDetermined {
            let newStatus = await withCheckedContinuation { continuation in
                MPMediaLibrary.requestAuthorization { auth in
                    continuation.resume(returning: auth)
                }
            }
            appleMusicAuthorization = newStatus
        } else {
            appleMusicAuthorization = status
        }
    }

    func addAppleMusicItems(_ items: [MPMediaItem]) {
        let newTracks = items.map { item in
            MusicTrack(
                id: "am_\(item.persistentID)",
                title: item.title ?? "Unbekannt",
                artist: item.artist ?? "Unbekannt",
                bpm: 0,
                style: .other,
                source: .appleMusic,
                fileURL: nil,
                appleMusicPersistentId: item.persistentID,
                spotifyURI: nil
            )
        }
        let merged = (appleMusicTracks + newTracks).uniqued(by: { $0.id })
        appleMusicTracks = merged
    }

    private func setupAppleMusic() {
        appleMusicPlayer.beginGeneratingPlaybackNotifications()
        NotificationCenter.default.addObserver(forName: .MPMusicPlayerControllerPlaybackStateDidChange, object: appleMusicPlayer, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.isPlaying = self.appleMusicPlayer.playbackState == .playing
            }
         }
         NotificationCenter.default.addObserver(forName: .MPMusicPlayerControllerNowPlayingItemDidChange, object: appleMusicPlayer, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, let item = self.appleMusicPlayer.nowPlayingItem else { return }
                self.currentTrack = MusicTrack(
                    id: "am_\(item.persistentID)",
                    title: item.title ?? "Unbekannt",
                    artist: item.artist ?? "Unbekannt",
                    bpm: 0,
                    style: .other,
                    source: .appleMusic,
                    fileURL: nil,
                    appleMusicPersistentId: item.persistentID,
                    spotifyURI: nil
                )
                self.duration = item.playbackDuration
            }
         }
     }

    private func playAppleMusic(track: MusicTrack) {
        guard let persistentId = track.appleMusicPersistentId else { return }
        let predicate = MPMediaPropertyPredicate(value: persistentId, forProperty: MPMediaItemPropertyPersistentID)
        let query = MPMediaQuery.songs()
        query.addFilterPredicate(predicate)
        guard let item = query.items?.first else { return }
        let collection = MPMediaItemCollection(items: [item])
        appleMusicPlayer.setQueue(with: collection)
        appleMusicPlayer.play()
        isPlaying = true
        duration = item.playbackDuration
        startTimer()
    }
}

private extension Array {
    func uniqued<T: Hashable>(by key: (Element) -> T) -> [Element] {
        var seen: Set<T> = []
        return filter { seen.insert(key($0)).inserted }
    }
}

#Preview {
    NavigationStack {
        MusicPlayerView()
    }
}
