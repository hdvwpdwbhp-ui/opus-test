//
//  CourseDownloadView.swift
//  Tanzen mit Tatiana Drexler
//
//  Download-Verwaltung für Kurs-Videos
//

import SwiftUI

struct CourseDownloadView: View {
    let course: Course
    @EnvironmentObject var storeViewModel: StoreViewModel
    @StateObject private var downloadManager = VideoDownloadManager.shared
    @StateObject private var userManager = UserManager.shared
    @State private var isDownloading = false
    @State private var showDeleteConfirm = false
    @Environment(\.dismiss) private var dismiss
    
    private var isPurchased: Bool {
        userManager.hasCourseUnlocked(course.id)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                TDGradients.mainBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: TDSpacing.lg) {
                        // Course Info
                        courseInfoCard
                        
                        // Download Status
                        downloadStatusCard
                        
                        // Video List
                        videoListSection
                        
                        // Actions
                        actionButtons
                    }
                    .padding(TDSpacing.md)
                }
            }
            .navigationTitle(T("Downloads"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(T("Fertig")) {
                        dismiss()
                    }
                    .foregroundColor(Color.accentGold)
                }
            }
            .alert(T("Videos löschen?"), isPresented: $showDeleteConfirm) {
                Button(T("Abbrechen"), role: .cancel) { }
                Button(T("Löschen"), role: .destructive) {
                    downloadManager.deleteCourseVideos(course)
                }
            } message: {
                Text(T("Alle heruntergeladenen Videos dieses Kurses werden gelöscht. Du kannst sie jederzeit erneut herunterladen."))
            }
        }
    }
    
    // MARK: - Course Info Card
    private var courseInfoCard: some View {
        HStack(spacing: TDSpacing.md) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: TDRadius.md)
                    .fill(
                        LinearGradient(
                            colors: [Color.accentGold.opacity(0.4), Color.purple.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 70, height: 70)
                
                Image(systemName: course.style.icon)
                    .font(.system(size: 28))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: TDSpacing.xs) {
                Text(course.title)
                    .font(TDTypography.headline)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                Text("\(course.lessonCount) Videos • \(VideoHelper.estimatedDownloadSize(for: course))")
                    .font(TDTypography.caption1)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(TDSpacing.md)
        .glassBackground()
    }
    
    // MARK: - Download Status Card
    private var downloadStatusCard: some View {
        VStack(spacing: TDSpacing.md) {
            let status = downloadManager.courseDownloadStatus(course)
            
            switch status {
            case .notDownloaded:
                HStack {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: TDSpacing.xs) {
                        Text(T("Nicht heruntergeladen"))
                            .font(TDTypography.headline)
                            .foregroundColor(.primary)
                        
                        Text(T("Lade die Videos herunter, um sie offline anzusehen."))
                            .font(TDTypography.caption1)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
            case .partiallyDownloaded(let downloaded, let total):
                HStack {
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 4)
                            .frame(width: 50, height: 50)
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(downloaded) / CGFloat(total))
                            .stroke(Color.accentGold, lineWidth: 4)
                            .frame(width: 50, height: 50)
                            .rotationEffect(.degrees(-90))
                        
                        Text("\(downloaded)/\(total)")
                            .font(TDTypography.caption2)
                            .foregroundColor(.primary)
                    }
                    
                    VStack(alignment: .leading, spacing: TDSpacing.xs) {
                        Text(T("Teilweise heruntergeladen"))
                            .font(TDTypography.headline)
                            .foregroundColor(.primary)
                        
                        Text("\(downloaded) von \(total) Videos verfügbar")
                            .font(TDTypography.caption1)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
            case .downloaded:
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.green)
                    
                    VStack(alignment: .leading, spacing: TDSpacing.xs) {
                        Text(T("Vollständig heruntergeladen"))
                            .font(TDTypography.headline)
                            .foregroundColor(.primary)
                        
                        Text(T("Alle Videos sind offline verfügbar."))
                            .font(TDTypography.caption1)
                            .foregroundColor(.green)
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(TDSpacing.md)
        .glassBackground()
    }
    
    // MARK: - Video List Section
    private var videoListSection: some View {
        VStack(alignment: .leading, spacing: TDSpacing.md) {
            Text(T("Videos"))
                .font(TDTypography.headline)
                .foregroundColor(.secondary)
                .padding(.leading, TDSpacing.sm)
            
            // Trailer
            VideoDownloadRow(
                title: "Trailer",
                videoName: course.trailerURL,
                duration: "1:00",
                isTrailer: true
            )
            
            // Lektionen
            let lessons = MockData.lessons(for: course.id)
            ForEach(lessons) { lesson in
                VideoDownloadRow(
                    title: "\(lesson.orderIndex). \(lesson.title)",
                    videoName: lesson.videoURL,
                    duration: lesson.formattedDuration,
                    isTrailer: false
                )
            }
        }
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: TDSpacing.md) {
            let status = downloadManager.courseDownloadStatus(course)
            
            if !isPurchased {
                // Nicht gekauft - Hinweis zeigen
                HStack {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.orange)
                    Text(T("Kaufe den Kurs, um alle Videos herunterzuladen"))
                        .font(TDTypography.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(TDSpacing.md)
                .frame(maxWidth: .infinity)
                .glassBackground()
                
            } else {
                // Download-Button
                if case .downloaded = status {
                    // Bereits heruntergeladen - Löschen-Button
                    Button {
                        showDeleteConfirm = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text(T("Downloads löschen"))
                        }
                        .font(TDTypography.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(TDSpacing.md)
                        .background(Color.red.opacity(0.8))
                        .cornerRadius(TDRadius.md)
                    }
                } else {
                    // Download-Button
                    Button {
                        Task {
                            isDownloading = true
                            await downloadManager.downloadCourseVideos(course)
                            isDownloading = false
                        }
                    } label: {
                        HStack {
                            if isDownloading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "arrow.down.circle.fill")
                            }
                            Text(isDownloading ? "Wird heruntergeladen..." : "Alle Videos herunterladen")
                        }
                        .font(TDTypography.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(TDSpacing.md)
                        .background(Color.accentGold)
                        .cornerRadius(TDRadius.md)
                    }
                    .disabled(isDownloading)
                }
            }
        }
    }
}

// MARK: - Video Download Row
struct VideoDownloadRow: View {
    let title: String
    let videoName: String
    let duration: String
    let isTrailer: Bool
    
    @StateObject private var downloadManager = VideoDownloadManager.shared
    
    var body: some View {
        HStack(spacing: TDSpacing.md) {
            // Status Icon
            statusIcon
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(title)
                        .font(TDTypography.body)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if isTrailer {
                        Text(T("GRATIS"))
                            .font(TDTypography.caption2)
                            .foregroundColor(.green)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Capsule().stroke(Color.green, lineWidth: 1))
                    }
                }
                
                Text(duration)
                    .font(TDTypography.caption1)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Download Progress or Action
            downloadStatusView
        }
        .padding(TDSpacing.md)
        .glassBackground()
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        let state = downloadManager.downloadState(for: videoName)
        
        switch state {
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(.green)
        case .downloading(let progress):
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 3)
                    .frame(width: 24, height: 24)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.accentGold, lineWidth: 3)
                    .frame(width: 24, height: 24)
                    .rotationEffect(.degrees(-90))
            }
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(.red)
        case .notStarted:
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 24))
                .foregroundColor(.secondary)
        }
    }
    
    @ViewBuilder
    private var downloadStatusView: some View {
        let state = downloadManager.downloadState(for: videoName)
        
        switch state {
        case .completed:
            Text(T("Verfügbar"))
                .font(TDTypography.caption1)
                .foregroundColor(.green)
        case .downloading(let progress):
            Text("\(Int(progress * 100))%")
                .font(TDTypography.caption1)
                .foregroundColor(Color.accentGold)
        case .failed(_):
            Button {
                Task {
                    await downloadManager.downloadVideo(videoName)
                }
            } label: {
                Text(T("Erneut"))
                    .font(TDTypography.caption1)
                    .foregroundColor(Color.accentGold)
            }
        case .notStarted:
            Button {
                Task {
                    await downloadManager.downloadVideo(videoName)
                }
            } label: {
                Image(systemName: "arrow.down")
                    .font(.system(size: 16))
                    .foregroundColor(Color.accentGold)
            }
        }
    }
}

#Preview {
    CourseDownloadView(course: MockData.courses[0])
        .environmentObject(StoreViewModel())
}
