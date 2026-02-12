//
//  VideoDownloadManager.swift
//  Tanzen mit Tatiana Drexler
//
//  Verwaltet das Herunterladen und Speichern von Videos nach dem Kauf
//

import Foundation
import SwiftUI
import Combine

@MainActor
class VideoDownloadManager: ObservableObject {
    
    static let shared = VideoDownloadManager()
    
    // MARK: - Published Properties
    @Published var downloads: [String: DownloadState] = [:]
    @Published var downloadedVideos: Set<String> = []
    
    // MARK: - Private Properties
    private let fileManager = FileManager.default
    private var downloadTasks: [String: URLSessionDownloadTask] = [:]
    
    // UserDefaults Key für heruntergeladene Videos
    private let downloadedVideosKey = "downloadedVideoNames"
    
    // MARK: - Base URL für Videos
    static var baseVideoURL: String {
        if CloudConfig.isConfigured {
            return CloudConfig.videoBaseURL
        }
        // Fallback für Tests
        return "https://example.com/videos/"
    }
    
    /// Gibt die vollständige Video-URL zurück
    static func getRemoteVideoURL(for videoName: String) -> URL? {
        if CloudConfig.isConfigured {
            return CloudConfig.videoURL(for: videoName)
        }
        return URL(string: "\(baseVideoURL)\(videoName)")
    }

    // MARK: - Filename Normalization (für lokale Speicherung)
    private func localFileName(for videoName: String) -> String {
        // Ordnerpfade in Dateinamen umwandeln, damit lokale Speicherung robust bleibt
        let sanitized = videoName.replacingOccurrences(of: "/", with: "_")
        let hasExtension = sanitized.contains(".")
        return hasExtension ? sanitized : "\(sanitized).mp4"
    }
    
    // MARK: - Initialization
    private init() {
        loadDownloadedVideos()
        createVideoDirectory()
    }
    
    // MARK: - Video Directory
    private var videoDirectory: URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("Videos", isDirectory: true)
    }
    
    private func createVideoDirectory() {
        if !fileManager.fileExists(atPath: videoDirectory.path) {
            try? fileManager.createDirectory(at: videoDirectory, withIntermediateDirectories: true)
        }
    }
    
    // MARK: - Check if Video is Downloaded
    func isVideoDownloaded(_ videoName: String) -> Bool {
        downloadedVideos.contains(videoName)
    }
    
    func getLocalVideoURL(_ videoName: String) -> URL? {
        let localURL = videoDirectory.appendingPathComponent(localFileName(for: videoName))
        if fileManager.fileExists(atPath: localURL.path) {
            return localURL
        }
        return nil
    }
    
    // MARK: - Download Video
    func downloadVideo(_ videoName: String) async -> Bool {
        // Prüfe ob bereits heruntergeladen
        if isVideoDownloaded(videoName) {
            return true
        }
        
        // Prüfe ob bereits am Downloaden
        if case .downloading = downloads[videoName] {
            return false
        }
        
        // Hole die richtige URL (Firebase oder Fallback)
        guard let remoteURL = VideoDownloadManager.getRemoteVideoURL(for: videoName) else {
            downloads[videoName] = .failed(error: "Ungültige Video-URL")
            return false
        }
        
        let localURL = videoDirectory.appendingPathComponent(localFileName(for: videoName))
        
        downloads[videoName] = .downloading(progress: 0)
        
        do {
            let (tempURL, _) = try await URLSession.shared.download(from: remoteURL) { [weak self] progress in
                Task { @MainActor in
                    self?.downloads[videoName] = .downloading(progress: progress)
                }
            }
            
            // Verschiebe zu finalem Speicherort
            if fileManager.fileExists(atPath: localURL.path) {
                try fileManager.removeItem(at: localURL)
            }
            try fileManager.moveItem(at: tempURL, to: localURL)
            
            // Markiere als heruntergeladen
            downloadedVideos.insert(videoName)
            saveDownloadedVideos()
            downloads[videoName] = .completed
            
            return true
            
        } catch {
            print("❌ Download fehlgeschlagen für \(videoName): \(error)")
            downloads[videoName] = .failed(error: error.localizedDescription)
            return false
        }
    }
    
    // MARK: - Download All Course Videos
    func downloadCourseVideos(_ course: Course) async {
        // Trailer herunterladen
        _ = await downloadVideo(course.trailerURL)
        
        // Alle Lektionen herunterladen
        let lessons = MockData.lessons(for: course.id)
        for lesson in lessons {
            _ = await downloadVideo(lesson.videoURL)
        }
    }
    
    // MARK: - Cancel Download
    func cancelDownload(_ videoName: String) {
        downloadTasks[videoName]?.cancel()
        downloadTasks.removeValue(forKey: videoName)
        downloads[videoName] = .notStarted
    }
    
    // MARK: - Delete Video
    func deleteVideo(_ videoName: String) {
        let localURL = videoDirectory.appendingPathComponent(localFileName(for: videoName))
        try? fileManager.removeItem(at: localURL)
        downloadedVideos.remove(videoName)
        saveDownloadedVideos()
        downloads[videoName] = .notStarted
    }
    
    // MARK: - Delete All Course Videos
    func deleteCourseVideos(_ course: Course) {
        deleteVideo(course.trailerURL)
        
        let lessons = MockData.lessons(for: course.id)
        for lesson in lessons {
            deleteVideo(lesson.videoURL)
        }
    }
    
    // MARK: - Get Download State
    func downloadState(for videoName: String) -> DownloadState {
        if isVideoDownloaded(videoName) {
            return .completed
        }
        return downloads[videoName] ?? .notStarted
    }
    
    // MARK: - Course Download Status
    func courseDownloadStatus(_ course: Course) -> CourseDownloadStatus {
        let lessons = MockData.lessons(for: course.id)
        let allVideos = [course.trailerURL] + lessons.map { $0.videoURL }
        
        let downloadedCount = allVideos.filter { isVideoDownloaded($0) }.count
        let totalCount = allVideos.count
        
        if downloadedCount == 0 {
            return .notDownloaded
        } else if downloadedCount == totalCount {
            return .downloaded
        } else {
            return .partiallyDownloaded(downloaded: downloadedCount, total: totalCount)
        }
    }
    
    // MARK: - Storage
    func getStorageUsed() -> String {
        var totalSize: Int64 = 0
        
        if let enumerator = fileManager.enumerator(at: videoDirectory, includingPropertiesForKeys: [.fileSizeKey]) {
            while let fileURL = enumerator.nextObject() as? URL {
                if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += Int64(fileSize)
                }
            }
        }
        
        return ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
    
    func deleteAllVideos() {
        try? fileManager.removeItem(at: videoDirectory)
        createVideoDirectory()
        downloadedVideos.removeAll()
        downloads.removeAll()
        saveDownloadedVideos()
    }
    
    // MARK: - Persistence
    private func loadDownloadedVideos() {
        if let saved = UserDefaults.standard.array(forKey: downloadedVideosKey) as? [String] {
            downloadedVideos = Set(saved)
        }
    }
    
    private func saveDownloadedVideos() {
        UserDefaults.standard.set(Array(downloadedVideos), forKey: downloadedVideosKey)
    }
}

// MARK: - Download State
enum DownloadState: Equatable {
    case notStarted
    case downloading(progress: Double)
    case completed
    case failed(error: String)
    
    static func == (lhs: DownloadState, rhs: DownloadState) -> Bool {
        switch (lhs, rhs) {
        case (.notStarted, .notStarted): return true
        case (.completed, .completed): return true
        case (.downloading(let p1), .downloading(let p2)): return p1 == p2
        case (.failed(let e1), .failed(let e2)): return e1 == e2
        default: return false
        }
    }
}

// MARK: - Course Download Status
enum CourseDownloadStatus {
    case notDownloaded
    case partiallyDownloaded(downloaded: Int, total: Int)
    case downloaded
}

// MARK: - URLSession Extension for Progress
extension URLSession {
    func download(from url: URL, progressHandler: @escaping (Double) -> Void) async throws -> (URL, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            let task = self.downloadTask(with: url) { localURL, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let localURL = localURL, let response = response else {
                    continuation.resume(throwing: URLError(.badServerResponse))
                    return
                }
                
                // Kopiere zu temporärem Ort, da downloadTask die Datei löscht
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
                do {
                    try FileManager.default.copyItem(at: localURL, to: tempURL)
                    continuation.resume(returning: (tempURL, response))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            
            // Progress tracking
            let observation = task.progress.observe(\.fractionCompleted) { progress, _ in
                progressHandler(progress.fractionCompleted)
            }
            
            task.resume()
            
            // Cleanup observation when done
            Task {
                try? await Task.sleep(nanoseconds: 100_000_000)
                _ = observation // Keep alive
            }
        }
    }
}
