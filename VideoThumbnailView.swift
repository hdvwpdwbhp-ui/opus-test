//
//  VideoThumbnailView.swift
//  Tanzen mit Tatiana Drexler
//
//  Zeigt ein Vorschaubild eines Videos mit korrektem Seitenverhältnis
//

import SwiftUI
import AVKit
import Combine

struct VideoThumbnailView: View {
    let videoURL: String
    var customThumbnailURL: String? = nil
    var maxHeight: CGFloat = 200
    var showPlayButton: Bool = true
    
    @State private var thumbnail: UIImage?
    @State private var aspectRatio: VideoHelper.VideoAspectRatio = .landscape
    @State private var isLoading = true
    @State private var videoSize: CGSize?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Hintergrund
                Color.gray.opacity(0.2)
                
                // Thumbnail oder Placeholder
                if let thumbnail = thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: frameSize(for: geometry).width,
                               height: frameSize(for: geometry).height)
                        .clipped()
                } else if isLoading {
                    ProgressView()
                        .scaleEffect(1.2)
                } else {
                    // Fallback Placeholder
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.5))
                }
                
                // Play Button Overlay
                if showPlayButton && thumbnail != nil {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: "play.fill")
                                .font(.system(size: 20))
                                .foregroundColor(Color.accentGold)
                                .offset(x: 2)
                        )
                }
            }
            .frame(width: frameSize(for: geometry).width,
                   height: frameSize(for: geometry).height)
        }
        .frame(height: calculatedHeight)
        .clipShape(RoundedRectangle(cornerRadius: TDRadius.md))
        .task {
            await loadThumbnail()
        }
    }
    
    private var calculatedHeight: CGFloat {
        switch aspectRatio {
        case .portrait:
            return maxHeight * 1.5  // Höher für Hochformat
        case .landscape:
            return maxHeight
        case .square:
            return maxHeight
        }
    }
    
    private func frameSize(for geometry: GeometryProxy) -> CGSize {
        let width = geometry.size.width
        
        if let size = videoSize {
            let ratio = size.height / size.width
            return CGSize(width: width, height: width * ratio)
        }
        
        switch aspectRatio {
        case .portrait:
            return CGSize(width: width, height: width * 16/9)
        case .landscape:
            return CGSize(width: width, height: width * 9/16)
        case .square:
            return CGSize(width: width, height: width)
        }
    }
    
    private func loadThumbnail() async {
        isLoading = true
        defer { isLoading = false }
        
        // Prüfe ob ein Custom-Thumbnail gesetzt ist
        if let customURL = customThumbnailURL, !customURL.isEmpty {
            // Lade Custom-Thumbnail von URL
            if let url = URL(string: customURL) {
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    if let image = UIImage(data: data) {
                        await MainActor.run {
                            self.thumbnail = image
                            // Aspect Ratio aus Bild ermitteln
                            if image.size.height > image.size.width * 1.1 {
                                self.aspectRatio = .portrait
                            } else if image.size.width > image.size.height * 1.1 {
                                self.aspectRatio = .landscape
                            } else {
                                self.aspectRatio = .square
                            }
                            self.videoSize = image.size
                        }
                        return
                    }
                } catch {
                    print("⚠️ Konnte Custom-Thumbnail nicht laden: \(error)")
                }
            }
        }
        
        // Generiere Thumbnail aus Video
        guard let url = VideoHelper.getVideoURL(for: videoURL) else {
            return
        }
        
        // Ermittle Seitenverhältnis
        let ratio = await VideoHelper.getVideoAspectRatio(for: url)
        let size = await VideoHelper.getVideoSize(for: url)
        
        await MainActor.run {
            self.aspectRatio = ratio
            self.videoSize = size
        }
        
        // Generiere Thumbnail
        if let image = await VideoHelper.generateRandomThumbnail(for: url) {
            await MainActor.run {
                self.thumbnail = image
            }
        }
    }
}

// MARK: - Compact Thumbnail View (für Listen)
struct CompactVideoThumbnailView: View {
    let videoURL: String
    var customThumbnailURL: String? = nil
    var size: CGFloat = 80
    
    @State private var thumbnail: UIImage?
    @State private var aspectRatio: VideoHelper.VideoAspectRatio = .landscape
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            Color.gray.opacity(0.2)
            
            if let thumbnail = thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if isLoading {
                ProgressView()
            } else {
                Image(systemName: "play.rectangle")
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: frameWidth, height: frameHeight)
        .clipShape(RoundedRectangle(cornerRadius: TDRadius.sm))
        .task {
            await loadThumbnail()
        }
    }
    
    private var frameWidth: CGFloat {
        switch aspectRatio {
        case .portrait: return size * 0.6
        case .landscape: return size
        case .square: return size * 0.8
        }
    }
    
    private var frameHeight: CGFloat {
        switch aspectRatio {
        case .portrait: return size
        case .landscape: return size * 0.6
        case .square: return size * 0.8
        }
    }
    
    private func loadThumbnail() async {
        isLoading = true
        defer { isLoading = false }
        
        // Prüfe Custom-Thumbnail
        if let customURL = customThumbnailURL, !customURL.isEmpty, let url = URL(string: customURL) {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    await MainActor.run {
                        self.thumbnail = image
                        if image.size.height > image.size.width * 1.1 {
                            self.aspectRatio = .portrait
                        } else if image.size.width > image.size.height * 1.1 {
                            self.aspectRatio = .landscape
                        } else {
                            self.aspectRatio = .square
                        }
                    }
                    return
                }
            } catch { }
        }
        
        // Generiere aus Video
        guard let url = VideoHelper.getVideoURL(for: videoURL) else { return }
        
        let ratio = await VideoHelper.getVideoAspectRatio(for: url)
        await MainActor.run { self.aspectRatio = ratio }
        
        if let image = await VideoHelper.generateRandomThumbnail(for: url) {
            await MainActor.run { self.thumbnail = image }
        }
    }
}

// MARK: - Cached Thumbnail Manager
class ThumbnailCache: ObservableObject {
    static let shared = ThumbnailCache()
    
    private var cache: [String: UIImage] = [:]
    private var aspectRatios: [String: VideoHelper.VideoAspectRatio] = [:]
    private let lock = NSLock()
    
    @MainActor
    func getThumbnail(for videoURL: String) -> UIImage? {
        lock.lock()
        defer { lock.unlock() }
        return cache[videoURL]
    }
    
    @MainActor
    func getAspectRatio(for videoURL: String) -> VideoHelper.VideoAspectRatio? {
        lock.lock()
        defer { lock.unlock() }
        return aspectRatios[videoURL]
    }
    
    @MainActor
    func setThumbnail(_ image: UIImage, aspectRatio: VideoHelper.VideoAspectRatio, for videoURL: String) {
        lock.lock()
        defer { lock.unlock() }
        cache[videoURL] = image
        aspectRatios[videoURL] = aspectRatio
    }
    
    @MainActor
    func clearCache() {
        lock.lock()
        defer { lock.unlock() }
        cache.removeAll()
        aspectRatios.removeAll()
    }
}

#Preview {
    VStack(spacing: 20) {
        Text(T("Querformat Video"))
        VideoThumbnailView(
            videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
        )
        .frame(width: 200)
        
        Text(T("Kompakte Ansicht"))
        HStack {
            CompactVideoThumbnailView(
                videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
            )
        }
    }
    .padding()
}
