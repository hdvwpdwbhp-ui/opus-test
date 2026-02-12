//
//  VideoHelper.swift
//  Tanzen mit Tatiana Drexler
//
//  Helper für Video-Dateien - unterstützt Downloads und lokale Dateien
//

import Foundation
import AVKit
import UIKit

struct VideoHelper {
    
    // MARK: - Video Aspect Ratio
    
    /// Seitenverhältnis eines Videos
    enum VideoAspectRatio {
        case portrait   // Hochformat (9:16, 3:4, etc.)
        case landscape  // Querformat (16:9, 4:3, etc.)
        case square     // Quadrat (1:1)
        
        var isPortrait: Bool { self == .portrait }
        var isLandscape: Bool { self == .landscape }
    }
    
    /// Ermittelt das Seitenverhältnis eines Videos asynchron
    static func getVideoAspectRatio(for videoURL: URL) async -> VideoAspectRatio {
        let asset = AVAsset(url: videoURL)
        
        do {
            let tracks = try await asset.loadTracks(withMediaType: .video)
            guard let track = tracks.first else { return .landscape }
            
            let size = try await track.load(.naturalSize)
            let transform = try await track.load(.preferredTransform)
            
            // Berücksichtige Video-Rotation
            let transformedSize = size.applying(transform)
            let width = abs(transformedSize.width)
            let height = abs(transformedSize.height)
            
            if width > height * 1.1 {
                return .landscape
            } else if height > width * 1.1 {
                return .portrait
            } else {
                return .square
            }
        } catch {
            print("⚠️ Konnte Video-Aspekt nicht ermitteln: \(error)")
            return .landscape
        }
    }
    
    /// Generiert ein Thumbnail aus einem Video an einer bestimmten Position
    static func generateThumbnail(for videoURL: URL, at time: CMTime = CMTime(seconds: 1, preferredTimescale: 600)) async -> UIImage? {
        let asset = AVAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.maximumSize = CGSize(width: 600, height: 600)
        
        do {
            let cgImage = try await imageGenerator.image(at: time).image
            return UIImage(cgImage: cgImage)
        } catch {
            print("⚠️ Konnte Thumbnail nicht generieren: \(error)")
            return nil
        }
    }
    
    /// Generiert ein Thumbnail an einer zufälligen Position im Video
    static func generateRandomThumbnail(for videoURL: URL) async -> UIImage? {
        let asset = AVAsset(url: videoURL)
        
        do {
            let duration = try await asset.load(.duration)
            let seconds = CMTimeGetSeconds(duration)
            
            // Wähle eine zufällige Position zwischen 10% und 90% des Videos
            let randomSeconds = seconds * Double.random(in: 0.1...0.9)
            let time = CMTime(seconds: randomSeconds, preferredTimescale: 600)
            
            return await generateThumbnail(for: videoURL, at: time)
        } catch {
            // Fallback: Versuche bei 1 Sekunde
            return await generateThumbnail(for: videoURL)
        }
    }
    
    /// Gibt die natürliche Größe eines Videos zurück
    static func getVideoSize(for videoURL: URL) async -> CGSize? {
        let asset = AVAsset(url: videoURL)
        
        do {
            let tracks = try await asset.loadTracks(withMediaType: .video)
            guard let track = tracks.first else { return nil }
            
            let size = try await track.load(.naturalSize)
            let transform = try await track.load(.preferredTransform)
            
            // Berücksichtige Video-Rotation
            let transformedSize = size.applying(transform)
            return CGSize(width: abs(transformedSize.width), height: abs(transformedSize.height))
        } catch {
            return nil
        }
    }
    
    /// Gibt die URL für ein Video zurück
    /// Priorität: 1. Vollständige URL, 2. Heruntergeladenes Video, 3. Bundle-Video, 4. Remote-URL
    @MainActor
    static func getVideoURL(for videoName: String) -> URL? {
        print("🎬 VideoHelper: Suche Video '\(videoName)'")
        
        // Prüfe ob es bereits eine vollständige URL ist (http/https/firebase)
        if videoName.hasPrefix("http://") || videoName.hasPrefix("https://") {
            print("✅ Vollständige URL erkannt: \(videoName)")
            return URL(string: videoName)
        }
        
        // Prüfe Firebase Storage URLs (gs://)
        if videoName.hasPrefix("gs://") {
            // Firebase Storage URL - konvertiere zu Download-URL
            // Format: gs://bucket-name/path/to/file.mp4
            // Wird zu: https://firebasestorage.googleapis.com/v0/b/bucket-name/o/path%2Fto%2Ffile.mp4?alt=media
            let components = videoName.replacingOccurrences(of: "gs://", with: "").split(separator: "/", maxSplits: 1)
            if components.count == 2 {
                let bucket = String(components[0])
                let path = String(components[1]).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)?.replacingOccurrences(of: "/", with: "%2F") ?? ""
                let url = "https://firebasestorage.googleapis.com/v0/b/\(bucket)/o/\(path)?alt=media"
                print("✅ Firebase Storage URL konvertiert: \(url)")
                return URL(string: url)
            }
        }
        
        // 1. Prüfe heruntergeladene Videos
        if let downloadedURL = VideoDownloadManager.shared.getLocalVideoURL(videoName) {
            print("✅ Video aus Downloads: \(videoName)")
            return downloadedURL
        }
        
        // 2. Prüfe Bundle (für Trailer oder Test-Videos)
        let extensions = ["mp4", "mov", "m4v"]
        for ext in extensions {
            if let bundleURL = Bundle.main.url(forResource: videoName, withExtension: ext) {
                print("✅ Video aus Bundle: \(videoName)")
                return bundleURL
            }
        }
        
        // 3. Remote URL (für Streaming ohne Download)
        if CloudConfig.isConfigured {
            let remoteURLString = CloudConfig.videoPath(for: videoName)
            print("⚠️ Versuche Video von Server: \(remoteURLString)")
            return URL(string: remoteURLString)
        }
        
        // 4. Fallback: Test-Video für Demo-Zwecke
        print("⚠️ Kein Video gefunden für '\(videoName)', verwende Test-Video")
        return URL(string: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4")
    }
    
    /// Prüft ob ein Video lokal verfügbar ist (Download oder Bundle)
    @MainActor
    static func isVideoAvailableOffline(_ videoName: String) -> Bool {
        // Vollständige URL ist nie "offline"
        if videoName.hasPrefix("http://") || videoName.hasPrefix("https://") || videoName.hasPrefix("gs://") {
            return false
        }
        
        // Heruntergeladen?
        if VideoDownloadManager.shared.isVideoDownloaded(videoName) {
            return true
        }
        
        // Im Bundle?
        let extensions = ["mp4", "mov", "m4v"]
        for ext in extensions {
            if Bundle.main.url(forResource: videoName, withExtension: ext) != nil {
                return true
            }
        }
        
        return false
    }
    
    /// Für Abwärtskompatibilität
    static func isVideoAvailable(_ videoName: String) -> Bool {
        // Vollständige URLs sind immer "verfügbar" (zum Streaming)
        if videoName.hasPrefix("http://") || videoName.hasPrefix("https://") || videoName.hasPrefix("gs://") {
            return true
        }
        
        // Bundle check only (synchron)
        let extensions = ["mp4", "mov", "m4v"]
        for ext in extensions {
            if Bundle.main.url(forResource: videoName, withExtension: ext) != nil {
                return true
            }
        }
        
        // Cloudflare R2 konfiguriert?
        if CloudConfig.isConfigured {
            return true
        }
        
        return false
    }
    
    /// Erstellt einen AVPlayer für ein Video
    @MainActor
    static func createPlayer(for videoName: String) -> AVPlayer? {
        guard let url = getVideoURL(for: videoName) else {
            return nil
        }
        return AVPlayer(url: url)
    }
    
    /// Liste aller Video-Namen die benötigt werden
    static func getRequiredVideos(for course: Course) -> [String] {
        var videos = [course.trailerURL]
        videos += MockData.lessons(for: course.id).map { $0.videoURL }
        return videos
    }
    
    /// Berechnet die geschätzte Downloadgröße für einen Kurs (in MB)
    static func estimatedDownloadSize(for course: Course) -> String {
        // Durchschnitt: ~50MB pro 10 Minuten Video
        let totalMinutes = course.totalDuration / 60
        let estimatedMB = (totalMinutes / 10) * 50
        
        if estimatedMB < 1000 {
            return "\(Int(estimatedMB)) MB"
        } else {
            return String(format: "%.1f GB", estimatedMB / 1000)
        }
    }
}
