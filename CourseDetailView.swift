//
//  CourseDetailView.swift
//  Tanzen mit Tatiana Drexler
//
//  Detailed view for a single course - with video download support
//

import SwiftUI
import AVKit

struct CourseDetailView: View {
    let course: Course
    @EnvironmentObject var courseViewModel: CourseViewModel
    @EnvironmentObject var storeViewModel: StoreViewModel
    @StateObject private var downloadManager = VideoDownloadManager.shared
    @StateObject private var userManager = UserManager.shared
    @StateObject private var settingsManager = AppSettingsManager.shared
    @StateObject private var coinManager = CoinManager.shared
    @State private var showTrailer = false
    @State private var selectedLesson: Lesson?
    @State private var showDownloadManager = false
    @State private var showAuthView = false
    @Environment(\.dismiss) private var dismiss
    
    private var isFree: Bool {
        settingsManager.isCourseFree(course.id)
    }
    
    private var activeSale: CourseSale? {
        settingsManager.getSaleForCourse(course.id)
    }
    
    private var isPurchased: Bool {
        isFree || userManager.hasCourseUnlocked(course.id)
    }
    
    private var coinsNeeded: Int {
        coinManager.coinsNeededForCourse(course)
    }

    private var coinsDisplay: String {
        "\(coinsNeeded) Coins"
    }
    
    private var salePrice: String? {
        guard let sale = activeSale, sale.isCurrentlyActive else { return nil }
        let discount = course.price * Decimal(sale.discountPercent) / 100
        let newPrice = course.price - discount
        let saleCoins = DanceCoinConfig.coinsForPrice(newPrice)
        return "\(saleCoins) Coins"
    }
    
    var body: some View {
        ZStack {
            TDGradients.mainBackground
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    // Hero Section with Trailer
                    heroSection
                    
                    // Content Section
                    VStack(alignment: .leading, spacing: TDSpacing.lg) {
                        // Course Info
                        courseInfoSection
                        
                        // Download Status (wenn gekauft)
                        if isPurchased {
                            downloadStatusSection
                        }
                        
                        // Description
                        descriptionSection
                        
                        // Purchase Button or Access Button
                        actionSection
                        
                        // Lessons List
                        lessonsSection
                    }
                    .padding(TDSpacing.md)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: TDSpacing.md) {
                    if userManager.canModerateCourse(course.id) {
                        NavigationLink(destination: CoursePerformanceView(course: course)) {
                            Image(systemName: "chart.bar.xaxis")
                                .foregroundColor(.primary)
                        }
                    }
                    // Download Button (wenn gekauft)
                    if isPurchased {
                        Button {
                            showDownloadManager = true
                        } label: {
                            Image(systemName: downloadStatusIcon)
                                .foregroundColor(downloadStatusColor)
                        }
                    }
                    
                    // Favorite Button
                    Button {
                        courseViewModel.toggleFavorite(course)
                    } label: {
                        Image(systemName: courseViewModel.isFavorite(course) ? "heart.fill" : "heart")
                            .foregroundColor(courseViewModel.isFavorite(course) ? .red : .primary)
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showTrailer) {
            VideoPlayerView(videoURL: course.trailerURL, title: "Trailer: \(course.title)", suggestedStyle: course.style)
        }
        .fullScreenCover(item: $selectedLesson) { lesson in
            VideoPlayerView(videoURL: lesson.videoURL, title: lesson.title, suggestedStyle: course.style)
        }
        .sheet(isPresented: $showDownloadManager) {
            CourseDownloadView(course: course)
        }
        .onAppear {
            courseViewModel.loadLessons(for: course)
        }
    }
    
    // MARK: - Download Status Helpers
    private var downloadStatusIcon: String {
        switch downloadManager.courseDownloadStatus(course) {
        case .downloaded:
            return "arrow.down.circle.fill"
        case .partiallyDownloaded:
            return "arrow.down.circle.dotted"
        case .notDownloaded:
            return "arrow.down.circle"
        }
    }
    
    private var downloadStatusColor: Color {
        switch downloadManager.courseDownloadStatus(course) {
        case .downloaded:
            return .green
        case .partiallyDownloaded:
            return .orange
        case .notDownloaded:
            return .primary
        }
    }
    
    // MARK: - Download Status Section
    private var downloadStatusSection: some View {
        Button {
            showDownloadManager = true
        } label: {
            HStack {
                let status = downloadManager.courseDownloadStatus(course)
                
                switch status {
                case .downloaded:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(T("Offline verfügbar"))
                        .foregroundColor(.green)
                case .partiallyDownloaded(let downloaded, let total):
                    Image(systemName: "arrow.down.circle.dotted")
                        .foregroundColor(.orange)
                    Text("\(downloaded)/\(total) Videos heruntergeladen")
                        .foregroundColor(.orange)
                case .notDownloaded:
                    Image(systemName: "arrow.down.circle")
                        .foregroundColor(.secondary)
                    Text(T("Videos herunterladen für Offline-Nutzung"))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14))
            }
            .font(TDTypography.subheadline)
            .padding(TDSpacing.md)
            .glassBackground()
        }
    }

    // MARK: - Hero Section
    private var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            // Cover Image / Gradient
            LinearGradient(
                colors: [
                    Color.accentGold.opacity(0.5),
                    Color.purple.opacity(0.4)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 280)
            .overlay(
                Image(systemName: course.style.icon)
                    .font(.system(size: 100))
                    .foregroundColor(.white.opacity(0.3))
            )
            
            // Gradient overlay for light theme
            LinearGradient(
                colors: [.clear, Color(red: 0.98, green: 0.97, blue: 0.95)],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Play Trailer Button
            Button {
                showTrailer = true
            } label: {
                HStack(spacing: TDSpacing.sm) {
                    Image(systemName: "play.fill")
                    Text(T("Trailer ansehen"))
                }
                .font(TDTypography.headline)
                .foregroundColor(.white)
                .padding(.horizontal, TDSpacing.lg)
                .padding(.vertical, TDSpacing.md)
                .background(Color.accentGold)
                .clipShape(Capsule())
            }
            .padding(TDSpacing.lg)
        }
    }
    
    // MARK: - Course Info Section
    private var courseInfoSection: some View {
        VStack(alignment: .leading, spacing: TDSpacing.sm) {
            // Tags mit Sprache
            HStack(spacing: TDSpacing.xs) {
                // Sprach-Badge
                HStack(spacing: 4) {
                    Text(course.language.flag)
                    Text(course.language.rawValue)
                }
                .font(TDTypography.caption1)
                .fontWeight(.medium)
                .padding(.horizontal, TDSpacing.sm)
                .padding(.vertical, TDSpacing.xs)
                .background(Color.blue.opacity(0.15))
                .foregroundColor(.blue)
                .cornerRadius(TDRadius.sm)
                
                TagView(text: course.level.rawValue, color: levelColor)
                TagView(text: course.style.rawValue, color: Color.accentGold.opacity(0.9))
            }
            
            // Title
            Text(course.title)
                .font(TDTypography.largeTitle)
                .foregroundColor(.primary)
            
            // Stats
            HStack(spacing: TDSpacing.lg) {
                Label(course.formattedDuration, systemImage: "clock")
                Label("\(course.lessonCount) Lektionen", systemImage: "play.rectangle.on.rectangle")
            }
            .font(TDTypography.subheadline)
            .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Description Section
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: TDSpacing.sm) {
            Text(T("Über diesen Kurs"))
                .font(TDTypography.headline)
                .foregroundColor(.primary)
            
            Text(course.description)
                .font(TDTypography.body)
                .foregroundColor(.secondary)
                .lineSpacing(4)
        }
        .padding(TDSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassBackground()
    }
    
    // MARK: - Action Section
    private var actionSection: some View {
        Group {
            if isPurchased {
                Button {
                    if let firstLesson = courseViewModel.lessons.first {
                        selectedLesson = firstLesson
                    }
                } label: {
                    HStack {
                        Image(systemName: "play.fill")
                        Text(T("Jetzt ansehen"))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.tdPrimary)
            } else if isFree {
                // Kostenloser Kurs - direkt freischalten
                Button {
                    // Course is free
                } label: {
                    VStack(spacing: 4) {
                        Text(coinsDisplay)
                             .strikethrough()
                             .foregroundColor(.white.opacity(0.7))
                        Text(T("KOSTENLOS"))
                            .fontWeight(.black)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.tdPrimary)
            } else {
                VStack(spacing: TDSpacing.sm) {
                    // Hinweis wenn nicht eingeloggt
                    if !userManager.isLoggedIn {
                        HStack(spacing: TDSpacing.sm) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(T("Bitte erstelle zuerst einen Account"))
                                .font(TDTypography.caption1)
                                .foregroundColor(.orange)
                        }
                        .padding(TDSpacing.sm)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(TDRadius.sm)
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "percent")
                            .foregroundColor(Color.accentGold)
                        Text(T("5% DanceCoins Cashback bei jedem Kurskauf"))
                            .font(TDTypography.caption1)
                            .foregroundColor(Color.accentGold)
                    }
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity)
                    .background(Color.black.opacity(0.05))
                    .cornerRadius(TDRadius.sm)
                    
                    Button {
                        if userManager.isLoggedIn {
                            Task {
                                _ = await coinManager.unlockCourseWithCoins(course: course)
                            }
                        } else {
                            showAuthView = true
                        }
                    } label: {
                        HStack {
                            Image(systemName: "bitcoinsign.circle")
                            Text(T("Mit %@ freischalten", coinsDisplay))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.tdSecondary)
                    .disabled(!coinManager.canAffordCourse(course) || !userManager.isLoggedIn)
                }
                .sheet(isPresented: $showAuthView) {
                    AuthView()
                }
            }
        }
    }
    
    // MARK: - Lessons Section
    private var lessonsSection: some View {
        VStack(alignment: .leading, spacing: TDSpacing.md) {
            Text(T("Lektionen"))
                .font(TDTypography.title2)
                .foregroundColor(.primary)
            
            if courseViewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(courseViewModel.lessons) { lesson in
                    LessonRow(lesson: lesson, isLocked: !canAccessLesson(lesson)) {
                        if canAccessLesson(lesson) {
                            selectedLesson = lesson
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private var levelColor: Color {
        switch course.level {
        case .beginner: return .green.opacity(0.8)
        case .intermediate: return .orange.opacity(0.8)
        case .advanced: return .red.opacity(0.8)
        }
    }
    
    private func canAccessLesson(_ lesson: Lesson) -> Bool {
        lesson.isPreview || isPurchased
    }
}

// MARK: - Lesson Row with Comments
struct LessonRow: View {
    let lesson: Lesson
    let isLocked: Bool
    let onTap: () -> Void
    
    @StateObject private var commentManager = CommentManager.shared
    @State private var showComments = false
    
    var commentCount: Int {
        commentManager.commentCountFor(lessonId: lesson.id)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main Lesson Row
            Button(action: onTap) {
                HStack(spacing: TDSpacing.md) {
                    // Lesson Number
                    ZStack {
                        Circle()
                            .fill(isLocked ? Color.gray.opacity(0.2) : Color.accentGold.opacity(0.3))
                            .frame(width: 44, height: 44)
                        
                        if isLocked {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.secondary)
                        } else {
                            Text("\(lesson.orderIndex)")
                                .font(TDTypography.headline)
                                .foregroundColor(Color.accentGold)
                        }
                    }
                    
                    // Lesson Info
                    VStack(alignment: .leading, spacing: TDSpacing.xxs) {
                        HStack {
                            Text(lesson.title)
                                .font(TDTypography.headline)
                                .foregroundColor(isLocked ? .secondary : .primary)
                            
                            if lesson.isPreview {
                                Text(T("VORSCHAU"))
                                    .font(TDTypography.caption2)
                                    .foregroundColor(Color.accentGold)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule()
                                            .stroke(Color.accentGold, lineWidth: 1)
                                    )
                            }
                        }
                        
                        Text(lesson.formattedDuration)
                            .font(TDTypography.caption1)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Play Icon
                    Image(systemName: isLocked ? "lock.fill" : "play.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(isLocked ? .secondary : Color.accentGold)
                }
                .padding(TDSpacing.md)
            }
            .disabled(isLocked)
            
            // Comments Toggle Button
            Button {
                withAnimation { showComments.toggle() }
            } label: {
                HStack {
                    Image(systemName: "bubble.left.and.bubble.right")
                    Text(T("Kommentare"))
                    if commentCount > 0 {
                        Text("(\(commentCount))")
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: showComments ? "chevron.up" : "chevron.down")
                }
                .font(TDTypography.caption1)
                .foregroundColor(Color.accentGold)
                .padding(.horizontal, TDSpacing.md)
                .padding(.bottom, TDSpacing.sm)
            }
            
            // Comments Section
            if showComments {
                CommentsView(lessonId: lesson.id, courseId: lesson.courseId)
                    .frame(maxHeight: 350)
                    .padding(.horizontal, TDSpacing.sm)
                    .padding(.bottom, TDSpacing.sm)
            }
        }
        .glassBackground()
    }
}

#Preview {
    NavigationStack {
        CourseDetailView(course: MockData.courses[0])
            .environmentObject(CourseViewModel())
            .environmentObject(StoreViewModel())
    }
}
