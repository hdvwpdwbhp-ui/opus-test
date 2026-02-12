//
//  CommunityViews.swift
//  Tanzen mit Tatiana Drexler
//
//  Community Views: Bewertungen, Reviews, Teilen
//

import SwiftUI

// MARK: - Course Rating Card
struct CourseRatingCard: View {
    let courseId: String
    @StateObject private var communityManager = CommunityManager.shared
    @State private var showAllReviews = false
    @State private var showWriteReview = false
    
    var averageRating: Double {
        communityManager.getAverageRating(for: courseId)
    }
    
    var ratingCount: Int {
        communityManager.getRatingCount(for: courseId)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: TDSpacing.md) {
            // Header
            HStack {
                Text(T("Bewertungen"))
                    .font(TDTypography.headline)
                Spacer()
                Button(T("Alle anzeigen")) {
                    showAllReviews = true
                }
                .font(TDTypography.caption1)
                .foregroundColor(Color.accentGold)
            }
            
            // Rating Summary
            HStack(spacing: TDSpacing.lg) {
                // Average Score
                VStack(spacing: 4) {
                    Text(String(format: "%.1f", averageRating))
                        .font(.system(size: 40, weight: .bold))
                    
                    StarRatingView(rating: averageRating, size: 16)
                    
                    Text("\(ratingCount) Bewertungen")
                        .font(TDTypography.caption2)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                    .frame(height: 60)
                
                // Rating Distribution
                VStack(alignment: .leading, spacing: 4) {
                    ForEach([5, 4, 3, 2, 1], id: \.self) { star in
                        RatingDistributionRow(
                            stars: star,
                            count: getCountForRating(star),
                            total: ratingCount
                        )
                    }
                }
            }
            
            // Write Review Button
            Button {
                showWriteReview = true
            } label: {
                HStack {
                    Image(systemName: "square.and.pencil")
                    Text(T("Bewertung schreiben"))
                }
                .fontWeight(.medium)
                .foregroundColor(Color.accentGold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentGold.opacity(0.1))
                .cornerRadius(TDRadius.md)
            }
            
            // Recent Reviews
            let recentReviews = communityManager.getRatings(for: courseId)
                .filter { $0.review != nil && !$0.review!.isEmpty }
                .prefix(2)
            
            if !recentReviews.isEmpty {
                VStack(spacing: TDSpacing.sm) {
                    ForEach(Array(recentReviews)) { review in
                        ReviewCard(review: review)
                    }
                }
            }
        }
        .padding()
        .glassBackground()
        .sheet(isPresented: $showAllReviews) {
            AllReviewsView(courseId: courseId)
        }
        .sheet(isPresented: $showWriteReview) {
            WriteReviewView(courseId: courseId)
        }
    }
    
    private func getCountForRating(_ rating: Int) -> Int {
        communityManager.getRatings(for: courseId).filter { $0.rating == rating }.count
    }
}

// MARK: - Star Rating View
struct StarRatingView: View {
    let rating: Double
    var size: CGFloat = 20
    var activeColor: Color = Color.accentGold
    var inactiveColor: Color = .gray.opacity(0.3)
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: starIcon(for: star))
                    .font(.system(size: size))
                    .foregroundColor(star <= Int(rating.rounded()) ? activeColor : inactiveColor)
            }
        }
    }
    
    private func starIcon(for star: Int) -> String {
        if Double(star) <= rating {
            return "star.fill"
        } else if Double(star) - 0.5 <= rating {
            return "star.leadinghalf.filled"
        } else {
            return "star"
        }
    }
}

// MARK: - Interactive Star Rating
struct InteractiveStarRating: View {
    @Binding var rating: Int
    var size: CGFloat = 30
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...5, id: \.self) { star in
                Button {
                    rating = star
                } label: {
                    Image(systemName: star <= rating ? "star.fill" : "star")
                        .font(.system(size: size))
                        .foregroundColor(star <= rating ? Color.accentGold : .gray.opacity(0.3))
                }
            }
        }
    }
}

// MARK: - Rating Distribution Row
struct RatingDistributionRow: View {
    let stars: Int
    let count: Int
    let total: Int
    
    var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(count) / Double(total)
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Text("\(stars)")
                .font(TDTypography.caption2)
                .frame(width: 12)
            
            Image(systemName: "star.fill")
                .font(.system(size: 10))
                .foregroundColor(Color.accentGold)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)
                        .cornerRadius(3)
                    
                    Rectangle()
                        .fill(Color.accentGold)
                        .frame(width: geometry.size.width * percentage, height: 6)
                        .cornerRadius(3)
                }
            }
            .frame(height: 6)
            
            Text("\(count)")
                .font(TDTypography.caption2)
                .foregroundColor(.secondary)
                .frame(width: 20)
        }
    }
}

// MARK: - Review Card
struct ReviewCard: View {
    let review: CourseRating
    @StateObject private var communityManager = CommunityManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: TDSpacing.sm) {
            HStack {
                // User Avatar
                Circle()
                    .fill(Color.accentGold.opacity(0.2))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text(String(review.userName.prefix(1)))
                            .font(TDTypography.headline)
                            .foregroundColor(Color.accentGold)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(review.userName)
                        .font(TDTypography.subheadline)
                        .fontWeight(.medium)
                    
                    HStack(spacing: 4) {
                        StarRatingView(rating: Double(review.rating), size: 12)
                        Text("• \(review.createdAt.formatted(date: .abbreviated, time: .omitted))")
                            .font(TDTypography.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            
            if let reviewText = review.review, !reviewText.isEmpty {
                Text(reviewText)
                    .font(TDTypography.body)
                    .foregroundColor(.secondary)
            }
            
            // Helpful Button
            HStack {
                Button {
                    communityManager.markRatingHelpful(ratingId: review.id, courseId: review.courseId)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "hand.thumbsup")
                        Text(T("Hilfreich (%@)", "\(review.helpfulCount)"))
                    }
                    .font(TDTypography.caption1)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(TDRadius.sm)
    }
}

// MARK: - All Reviews View
struct AllReviewsView: View {
    let courseId: String
    @StateObject private var communityManager = CommunityManager.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var sortBy: SortOption = .newest
    
    enum SortOption: String, CaseIterable {
        case newest = "Neueste"
        case highest = "Beste"
        case lowest = "Schlechteste"
        case helpful = "Hilfreichste"
    }
    
    var sortedReviews: [CourseRating] {
        let reviews = communityManager.getRatings(for: courseId)
        switch sortBy {
        case .newest:
            return reviews.sorted { $0.createdAt > $1.createdAt }
        case .highest:
            return reviews.sorted { $0.rating > $1.rating }
        case .lowest:
            return reviews.sorted { $0.rating < $1.rating }
        case .helpful:
            return reviews.sorted { $0.helpfulCount > $1.helpfulCount }
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Sort Options
                Section {
                    Picker("Sortieren nach", selection: $sortBy) {
                        ForEach(SortOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                // Reviews
                Section {
                    if sortedReviews.isEmpty {
                        ContentUnavailableView(
                            "Noch keine Bewertungen",
                            systemImage: "star",
                            description: Text(T("Sei der Erste, der diesen Kurs bewertet!"))
                        )
                    } else {
                        ForEach(sortedReviews) { review in
                            ReviewCard(review: review)
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                        }
                    }
                }
            }
            .navigationTitle(T("Bewertungen"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(T("Fertig")) { dismiss() }
                }
            }
        }
    }
}

// MARK: - Write Review View
struct WriteReviewView: View {
    let courseId: String
    @StateObject private var communityManager = CommunityManager.shared
    @StateObject private var userManager = UserManager.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var rating = 0
    @State private var reviewText = ""
    @State private var isSaving = false
    
    var canSubmit: Bool {
        rating > 0
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: TDSpacing.lg) {
                        Text(T("Wie hat dir der Kurs gefallen?"))
                            .font(TDTypography.headline)
                        
                        InteractiveStarRating(rating: $rating, size: 40)
                        
                        ratingDescription
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                }
                
                Section(T("Dein Review (optional)")) {
                    TextEditor(text: $reviewText)
                        .frame(minHeight: 100)
                    
                    Text(T("Teile deine Erfahrung mit anderen Nutzern"))
                        .font(TDTypography.caption1)
                        .foregroundColor(.secondary)
                }
                
                Section {
                    Button {
                        Task { await submitReview() }
                    } label: {
                        HStack {
                            Spacer()
                            if isSaving {
                                ProgressView().tint(.white)
                            } else {
                                Text(T("Bewertung abgeben"))
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .listRowBackground(canSubmit ? Color.accentGold : Color.gray)
                    .foregroundColor(.white)
                    .disabled(!canSubmit || isSaving)
                }
            }
            .navigationTitle(T("Bewertung"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(T("Abbrechen")) { dismiss() }
                }
            }
        }
    }
    
    private var ratingDescription: some View {
        Group {
            switch rating {
            case 1: Text(T("Schlecht")).foregroundColor(.red)
            case 2: Text(T("Nicht gut")).foregroundColor(.orange)
            case 3: Text(T("OK")).foregroundColor(.yellow)
            case 4: Text(T("Gut")).foregroundColor(.green)
            case 5: Text(T("Ausgezeichnet!")).foregroundColor(Color.accentGold)
            default: Text(T("Tippe auf die Sterne")).foregroundColor(.secondary)
            }
        }
        .font(TDTypography.caption1)
    }
    
    private func submitReview() async {
        guard let user = userManager.currentUser else { return }
        
        isSaving = true
        defer { isSaving = false }
        
        let success = await communityManager.submitRating(
            courseId: courseId,
            userId: user.id,
            userName: user.name,
            rating: rating,
            review: reviewText.isEmpty ? nil : reviewText
        )
        
        if success {
            dismiss()
        }
    }
}

// MARK: - Share Course Button
struct ShareCourseButton: View {
    let course: Course
    @StateObject private var communityManager = CommunityManager.shared
    @StateObject private var userManager = UserManager.shared
    @State private var showShareSheet = false
    
    var body: some View {
        Button {
            showShareSheet = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "square.and.arrow.up")
                Text(T("Teilen"))
            }
            .font(TDTypography.caption1)
            .foregroundColor(Color.accentGold)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(course: course)
        }
    }
}

// MARK: - Share Sheet
struct ShareSheet: View {
    let course: Course
    @StateObject private var communityManager = CommunityManager.shared
    @StateObject private var userManager = UserManager.shared
    @Environment(\.dismiss) var dismiss
    
    var shareText: String {
        """
        🩰 Schau dir diesen Tanzkurs an: \(course.title)
        
        \(course.description)
        
        Lerne Tanzen mit der App "Tanzen mit Tatiana Drexler"!
        """
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: TDSpacing.xl) {
                // Course Preview
                VStack(spacing: TDSpacing.md) {
                    AsyncImage(url: URL(string: course.coverURL)) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color.gray.opacity(0.2)
                    }
                    .frame(width: 120, height: 80)
                    .cornerRadius(TDRadius.sm)
                    
                    Text(course.title)
                        .font(TDTypography.headline)
                }
                .padding(.top)
                
                // Share Options
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: TDSpacing.lg) {
                    ShareOptionButton(icon: "message.fill", label: "Nachricht", color: .green) {
                        shareVia(.other)
                    }
                    
                    ShareOptionButton(icon: "envelope.fill", label: "E-Mail", color: .blue) {
                        shareVia(.other)
                    }
                    
                    ShareOptionButton(icon: "doc.on.doc", label: "Kopieren", color: .gray) {
                        UIPasteboard.general.string = shareText
                        shareVia(.copyLink)
                        dismiss()
                    }
                }
                
                Spacer()
                
                // System Share Sheet
                Button {
                    shareViaSystem()
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text(T("Weitere Optionen"))
                    }
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentGold)
                    .cornerRadius(TDRadius.md)
                }
                .padding(.horizontal)
            }
            .navigationTitle(T("Kurs teilen"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(T("Fertig")) { dismiss() }
                }
            }
        }
    }
    
    private func shareVia(_ platform: CourseShare.SharePlatform) {
        if let userId = userManager.currentUser?.id {
            communityManager.recordShare(courseId: course.id, userId: userId, platform: platform)
        }
    }
    
    private func shareViaSystem() {
        let activityVC = UIActivityViewController(
            activityItems: [shareText],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
        
        shareVia(.other)
    }
}

struct ShareOptionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(color)
                }
                
                Text(label)
                    .font(TDTypography.caption1)
                    .foregroundColor(.primary)
            }
        }
    }
}

// MARK: - Like Button
struct LikeButton: View {
    let id: String
    @StateObject private var communityManager = CommunityManager.shared
    
    var isLiked: Bool {
        communityManager.isLiked(id)
    }
    
    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                communityManager.toggleLike(id)
            }
        } label: {
            Image(systemName: isLiked ? "heart.fill" : "heart")
                .font(.title3)
                .foregroundColor(isLiked ? .red : .secondary)
                .scaleEffect(isLiked ? 1.1 : 1.0)
        }
    }
}

#Preview {
    NavigationStack {
        ScrollView {
            CourseRatingCard(courseId: "course1")
                .padding()
        }
    }
}
