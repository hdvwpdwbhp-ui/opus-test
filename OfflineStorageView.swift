//
//  OfflineStorageView.swift
//  Tanzen mit Tatiana Drexler
//
//  Offline-Speicherverwaltung und Auto-Download
//

import SwiftUI

// MARK: - Storage Manager Extension
extension VideoDownloadManager {
    func getTotalDownloadedSize() -> Int64 {
        var totalSize: Int64 = 0
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return 0 }
        let videosURL = documentsURL.appendingPathComponent("DownloadedVideos")
        
        guard let enumerator = fileManager.enumerator(at: videosURL, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        
        for case let fileURL as URL in enumerator {
            if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                totalSize += Int64(fileSize)
            }
        }
        
        return totalSize
    }
    
    func deleteAllDownloads() {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let videosURL = documentsURL.appendingPathComponent("DownloadedVideos")
        
        try? fileManager.removeItem(at: videosURL)
        try? fileManager.createDirectory(at: videosURL, withIntermediateDirectories: true)
        
        downloads.removeAll()
    }
}

// MARK: - Offline Storage View
struct OfflineStorageView: View {
    @StateObject private var downloadManager = VideoDownloadManager.shared
    @StateObject private var courseDataManager = CourseDataManager.shared
    @State private var autoDownloadEnabled = UserDefaults.standard.bool(forKey: "autoDownloadEnabled")
    @State private var autoDownloadOnWiFiOnly = UserDefaults.standard.bool(forKey: "autoDownloadOnWiFiOnly")
    @State private var showDeleteConfirm = false
    @State private var downloadedCourses: [DownloadedCourseInfo] = []
    
    var totalStorageUsed: String {
        let bytes = downloadManager.getTotalDownloadedSize()
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
    
    var availableStorage: String {
        if let systemAttributes = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
           let freeSpace = systemAttributes[.systemFreeSize] as? Int64 {
            return ByteCountFormatter.string(fromByteCount: freeSpace, countStyle: .file)
        }
        return "Unbekannt"
    }
    
    var body: some View {
        List {
            // Storage Overview
            Section {
                storageOverviewCard
            }
            
            // Auto-Download Settings
            Section(T("Automatischer Download")) {
                Toggle("Auto-Download aktivieren", isOn: $autoDownloadEnabled)
                    .onChange(of: autoDownloadEnabled) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "autoDownloadEnabled")
                    }
                
                if autoDownloadEnabled {
                    Toggle("Nur bei WLAN", isOn: $autoDownloadOnWiFiOnly)
                        .onChange(of: autoDownloadOnWiFiOnly) { _, newValue in
                            UserDefaults.standard.set(newValue, forKey: "autoDownloadOnWiFiOnly")
                        }
                    
                    Text(T("Neue Lektionen werden automatisch heruntergeladen, wenn du einen Kurs beginnst."))
                        .font(TDTypography.caption1)
                        .foregroundColor(.secondary)
                }
            }
            
            // Downloaded Courses
            Section(T("Heruntergeladene Kurse")) {
                if downloadedCourses.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "arrow.down.circle")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text(T("Keine Downloads"))
                                .font(TDTypography.caption1)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding()
                } else {
                    ForEach(downloadedCourses) { courseInfo in
                        DownloadedCourseRow(courseInfo: courseInfo) {
                            deleteDownload(courseInfo)
                        }
                    }
                }
            }
            
            // Delete All
            if !downloadedCourses.isEmpty {
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text(T("Alle Downloads löschen"))
                        }
                    }
                }
            }
            
            // Tips
            Section(T("Tipps")) {
                VStack(alignment: .leading, spacing: TDSpacing.sm) {
                    TipRow(icon: "wifi", text: "Lade Videos bei WLAN herunter, um mobile Daten zu sparen")
                    TipRow(icon: "clock", text: "Abgeschlossene Kurse können gelöscht werden, um Speicher freizugeben")
                    TipRow(icon: "iphone.and.arrow.forward", text: "Videos werden lokal gespeichert und sind offline verfügbar")
                }
            }
        }
        .navigationTitle(T("Offline-Speicher"))
        .alert(T("Alle Downloads löschen?"), isPresented: $showDeleteConfirm) {
            Button(T("Abbrechen"), role: .cancel) { }
            Button(T("Löschen"), role: .destructive) {
                downloadManager.deleteAllDownloads()
                loadDownloadedCourses()
            }
        } message: {
            Text(T("Alle heruntergeladenen Videos werden gelöscht. Du kannst sie später erneut herunterladen."))
        }
        .onAppear {
            loadDownloadedCourses()
        }
    }
    
    // MARK: - Storage Overview Card
    private var storageOverviewCard: some View {
        VStack(spacing: TDSpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(T("Verwendeter Speicher"))
                        .font(TDTypography.caption1)
                        .foregroundColor(.secondary)
                    Text(totalStorageUsed)
                        .font(.system(size: 28, weight: .bold))
                }
                
                Spacer()
                
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                        .frame(width: 60, height: 60)
                    
                    Circle()
                        .trim(from: 0, to: storagePercentage)
                        .stroke(Color.accentGold, lineWidth: 8)
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))
                    
                    Image(systemName: "internaldrive")
                        .foregroundColor(Color.accentGold)
                }
            }
            
            Divider()
            
            HStack {
                Label(availableStorage, systemImage: "checkmark.circle")
                    .font(TDTypography.caption1)
                    .foregroundColor(.green)
                Text(T("verfügbar"))
                    .font(TDTypography.caption1)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding()
    }
    
    private var storagePercentage: Double {
        let used = downloadManager.getTotalDownloadedSize()
        guard used > 0 else { return 0 }
        // Simplified - in real app would compare to total device storage
        return min(Double(used) / Double(1024 * 1024 * 1024), 1.0) // Max 1GB for visual
    }
    
    // MARK: - Helper Functions
    
    private func loadDownloadedCourses() {
        var courses: [DownloadedCourseInfo] = []
        
        for course in courseDataManager.courses {
            let lessons = MockData.lessons(for: course.id)
            var downloadedCount = 0
            var totalSize: Int64 = 0
            
            for lesson in lessons {
                if let state = downloadManager.downloads[lesson.videoURL], case .completed = state {
                    downloadedCount += 1
                    // Estimate size
                    totalSize += Int64(lesson.duration * 1000) // ~1KB per second estimate
                }
            }
            
            if downloadedCount > 0 {
                courses.append(DownloadedCourseInfo(
                    courseId: course.id,
                    courseTitle: course.title,
                    downloadedLessons: downloadedCount,
                    totalLessons: lessons.count,
                    size: totalSize
                ))
            }
        }
        
        downloadedCourses = courses
    }
    
    private func deleteDownload(_ courseInfo: DownloadedCourseInfo) {
        let lessons = MockData.lessons(for: courseInfo.courseId)
        for lesson in lessons {
            downloadManager.deleteVideo(lesson.videoURL)
        }
        loadDownloadedCourses()
    }
}

// MARK: - Supporting Models & Views

struct DownloadedCourseInfo: Identifiable {
    let id = UUID()
    let courseId: String
    let courseTitle: String
    let downloadedLessons: Int
    let totalLessons: Int
    let size: Int64
    
    var sizeString: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    var progress: Double {
        guard totalLessons > 0 else { return 0 }
        return Double(downloadedLessons) / Double(totalLessons)
    }
}

struct DownloadedCourseRow: View {
    let courseInfo: DownloadedCourseInfo
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: TDSpacing.md) {
            // Course Icon
            ZStack {
                Circle()
                    .fill(Color.accentGold.opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundColor(Color.accentGold)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(courseInfo.courseTitle)
                    .font(TDTypography.body)
                    .lineLimit(1)
                
                HStack {
                    Text("\(courseInfo.downloadedLessons)/\(courseInfo.totalLessons) Lektionen")
                    Text(T("•"))
                    Text(courseInfo.sizeString)
                }
                .font(TDTypography.caption1)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Delete Button
            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
        }
    }
}

struct TipRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(Color.accentGold)
                .frame(width: 20)
            
            Text(text)
                .font(TDTypography.caption1)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Quick Download Button (for Course Detail View)
struct QuickDownloadButton: View {
    let courseId: String
    @StateObject private var downloadManager = VideoDownloadManager.shared
    @StateObject private var courseDataManager = CourseDataManager.shared
    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0
    
    var lessons: [Lesson] {
        MockData.lessons(for: courseId)
    }
    
    var downloadedCount: Int {
        lessons.filter { lesson in
            if let state = downloadManager.downloads[lesson.videoURL], case .completed = state {
                return true
            }
            return false
        }.count
    }
    
    var isFullyDownloaded: Bool {
        downloadedCount == lessons.count && !lessons.isEmpty
    }
    
    var body: some View {
        Button {
            if !isFullyDownloaded {
                downloadAllLessons()
            }
        } label: {
            HStack(spacing: 8) {
                if isDownloading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else if isFullyDownloaded {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(T("Offline verfügbar"))
                } else {
                    Image(systemName: "arrow.down.circle")
                    Text(downloadedCount > 0 ? "\(downloadedCount)/\(lessons.count)" : "Herunterladen")
                }
            }
            .font(TDTypography.caption1)
            .foregroundColor(isFullyDownloaded ? .green : Color.accentGold)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isFullyDownloaded ? Color.green.opacity(0.1) : Color.accentGold.opacity(0.1))
            )
        }
        .disabled(isDownloading || isFullyDownloaded)
    }
    
    private func downloadAllLessons() {
        isDownloading = true
        
        Task {
            for (index, lesson) in lessons.enumerated() {
                _ = await downloadManager.downloadVideo(lesson.videoURL)
                downloadProgress = Double(index + 1) / Double(lessons.count)
            }
            isDownloading = false
        }
    }
}

#Preview {
    NavigationStack {
        OfflineStorageView()
    }
}
