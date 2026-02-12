//
//  CourseCard.swift
//  Tanzen mit Tatiana Drexler
//
//  Glass Card Component for Course Display - Offline App with In-App Purchases
//

import SwiftUI

struct CourseCard: View {
    let course: Course
    @EnvironmentObject var courseViewModel: CourseViewModel
    @EnvironmentObject var storeViewModel: StoreViewModel
    @StateObject private var userManager = UserManager.shared
    @StateObject private var coinManager = CoinManager.shared
    
    private var isPurchased: Bool {
        userManager.hasCourseUnlocked(course.id)
    }
    
    private var coinPriceText: String {
        "\(coinManager.coinsNeededForCourse(course)) Coins"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Cover Image
            ZStack(alignment: .topTrailing) {
                coverImage
                
                // Favorite Button
                favoriteButton
            }
            
            // Content
            VStack(alignment: .leading, spacing: TDSpacing.sm) {
                // Level, Style & Language Tags
                HStack(spacing: TDSpacing.xs) {
                    // Sprach-Badge mit Flagge und vollem Namen
                    HStack(spacing: 4) {
                        Text(course.language.flag)
                        Text(course.language.rawValue)
                    }
                    .font(TDTypography.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.blue.opacity(0.15))
                    .foregroundColor(.blue)
                    .cornerRadius(4)
                    
                    TagView(text: course.level.rawValue, color: levelColor)
                    TagView(text: course.style.rawValue, color: Color.accentGold.opacity(0.9))
                }
                
                // Title
                Text(course.title)
                    .font(TDTypography.title3)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                // Description
                Text(course.description)
                    .font(TDTypography.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                // Bottom Row
                HStack {
                    // Duration & Lessons
                    HStack(spacing: TDSpacing.md) {
                        Label(course.formattedDuration, systemImage: "clock")
                        Label("\(course.lessonCount) Lektionen", systemImage: "play.rectangle.on.rectangle")
                    }
                    .font(TDTypography.caption1)
                    .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // Price or Purchased Badge
                    if isPurchased {
                        purchasedBadge
                    } else {
                        priceTag
                    }
                }
            }
            .padding(TDSpacing.md)
        }
        .glassBackground()
    }
    
    // MARK: - Cover Image
    private var coverImage: some View {
        ZStack {
            // Placeholder gradient
            LinearGradient(
                colors: [
                    Color.accentGold.opacity(0.3),
                    Color.purple.opacity(0.3)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Dance icon
            Image(systemName: course.style.icon)
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.3))
            
            // Play button overlay
            Circle()
                .fill(.regularMaterial)
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: "play.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color.accentGold)
                        .offset(x: 2)
                )
        }
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: TDRadius.md))
        .padding([.top, .horizontal], TDSpacing.sm)
    }
    
    // MARK: - Favorite Button
    private var favoriteButton: some View {
        Button {
            withAnimation(TDAnimation.spring) {
                courseViewModel.toggleFavorite(course)
            }
        } label: {
            Image(systemName: courseViewModel.isFavorite(course) ? "heart.fill" : "heart")
                .font(.system(size: 18))
                .foregroundColor(courseViewModel.isFavorite(course) ? .red : .gray)
                .padding(TDSpacing.sm)
                .background(Circle().fill(.regularMaterial))
        }
        .padding(TDSpacing.md)
    }
    
    // MARK: - Price Tag
    private var priceTag: some View {
        HStack {
            Text(coinPriceText)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(isPurchased ? .green : .primary)
            Spacer()
            Text("5% Cashback")
                .font(.caption2)
                .fontWeight(.bold)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.accentGold.opacity(0.15))
                .foregroundColor(Color.accentGold)
                .cornerRadius(6)
        }
    }
    
    // MARK: - Purchased Badge
    private var purchasedBadge: some View {
        HStack(spacing: TDSpacing.xxs) {
            Image(systemName: "checkmark.circle.fill")
            Text(T("Gekauft"))
        }
        .font(TDTypography.caption1)
        .foregroundColor(.green)
    }
    
    // MARK: - Level Color
    private var levelColor: Color {
        switch course.level {
        case .beginner:
            return .green.opacity(0.7)
        case .intermediate:
            return .orange.opacity(0.7)
        case .advanced:
            return .red.opacity(0.7)
        }
    }
}

// MARK: - Tag View
struct TagView: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(TDTypography.caption2)
            .foregroundColor(.white)
            .padding(.horizontal, TDSpacing.xs)
            .padding(.vertical, TDSpacing.xxs)
            .background(
                Capsule()
                    .fill(color)
            )
    }
}

// MARK: - Language Flag View
struct LanguageFlagView: View {
    let language: CourseLanguage
    var showText: Bool = false
    var showFullName: Bool = false  // Zeigt den vollen Namen statt Kurzform
    var size: FlagSize = .small
    
    enum FlagSize {
        case small, medium, large
        
        var fontSize: CGFloat {
            switch self {
            case .small: return 14
            case .medium: return 18
            case .large: return 24
            }
        }
        
        var textFont: Font {
            switch self {
            case .small: return TDTypography.caption2
            case .medium: return TDTypography.caption1
            case .large: return TDTypography.body
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Text(language.flag)
                .font(.system(size: size.fontSize))
            
            if showText {
                Text(showFullName ? language.rawValue : language.shortName)
                    .font(size.textFont)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, showText ? TDSpacing.xs : 0)
        .padding(.vertical, TDSpacing.xxs)
        .background(
            showText ?
            Capsule()
                .fill(Color.gray.opacity(0.2))
            : nil
        )
    }
}

// MARK: - Language Picker View
struct LanguagePickerView: View {
    @Binding var selectedLanguage: CourseLanguage
    
    var body: some View {
        Picker("Sprache", selection: $selectedLanguage) {
            ForEach(CourseLanguage.allCases) { language in
                HStack {
                    Text(language.flag)
                    Text(language.rawValue)
                }
                .tag(language)
            }
        }
    }
}

// MARK: - Language Filter Chips
struct LanguageFilterChips: View {
    @Binding var selectedLanguages: Set<CourseLanguage>
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: TDSpacing.sm) {
                ForEach(CourseLanguage.allCases) { language in
                    Button {
                        if selectedLanguages.contains(language) {
                            selectedLanguages.remove(language)
                        } else {
                            selectedLanguages.insert(language)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(language.flag)
                            Text(language.shortName)
                        }
                        .font(TDTypography.caption1)
                        .foregroundColor(selectedLanguages.contains(language) ? .white : .primary)
                        .padding(.horizontal, TDSpacing.sm)
                        .padding(.vertical, TDSpacing.xs)
                        .background(
                            Capsule()
                                .fill(selectedLanguages.contains(language) ? Color.accentGold : Color.gray.opacity(0.2))
                        )
                    }
                }
            }
            .padding(.horizontal, TDSpacing.sm)
        }
    }
}

#Preview {
    ZStack {
        TDGradients.mainBackground
            .ignoresSafeArea()
        
        CourseCard(course: MockData.courses[0])
            .padding()
            .environmentObject(CourseViewModel())
            .environmentObject(StoreViewModel())
    }
}
