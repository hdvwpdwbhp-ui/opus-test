//
//  MyCoursesView.swift
//  Tanzen mit Tatiana Drexler
//
//  View for purchased courses - Offline App with In-App Purchases
//

import SwiftUI

struct MyCoursesView: View {
    @EnvironmentObject var courseViewModel: CourseViewModel
    @EnvironmentObject var storeViewModel: StoreViewModel
    @StateObject private var userManager = UserManager.shared
    @StateObject private var courseDataManager = CourseDataManager.shared
    
    private var purchasedCourses: [Course] {
        // Versuche erst Firebase-Kurse, dann Fallback auf MockData
        let courses = courseDataManager.courses.isEmpty ? MockData.courses : courseDataManager.courses
        return courses.filter { course in
            userManager.hasCourseUnlocked(course.id)
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                TDGradients.mainBackground
                    .ignoresSafeArea()
                
                if purchasedCourses.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVStack(spacing: TDSpacing.md) {
                            ForEach(purchasedCourses) { course in
                                NavigationLink(destination: CourseDetailView(course: course)) {
                                    PurchasedCourseCard(course: course)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(TDSpacing.md)
                    }
                }
            }
            .navigationTitle(T("Meine Kurse"))
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: TDSpacing.lg) {
            Image(systemName: "play.square.stack")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text(T("Noch keine Kurse"))
                .font(TDTypography.title2)
                .foregroundColor(.primary)
            
            Text(T("Entdecke unsere Tanzkurse und starte deine Tanzreise!"))
                .font(TDTypography.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, TDSpacing.xl)
        }
    }
}

// MARK: - Purchased Course Card
struct PurchasedCourseCard: View {
    let course: Course
    
    var body: some View {
        HStack(spacing: TDSpacing.md) {
            // Thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: TDRadius.md)
                    .fill(
                        LinearGradient(
                            colors: [Color.accentGold.opacity(0.4), Color.purple.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Image(systemName: course.style.icon)
                    .font(.system(size: 30))
                    .foregroundColor(.white.opacity(0.7))
            }
            .frame(width: 100, height: 80)
            
            // Info
            VStack(alignment: .leading, spacing: TDSpacing.xs) {
                Text(course.title)
                    .font(TDTypography.headline)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                HStack(spacing: TDSpacing.sm) {
                    Text(course.language.flag)
                    Text(course.language.rawValue)
                    Text(T("•"))
                    Label(course.formattedDuration, systemImage: "clock")
                    Label("\(course.lessonCount)", systemImage: "play.rectangle")
                }
                .font(TDTypography.caption1)
                .foregroundColor(.secondary)
                
                // Progress (placeholder)
                ProgressView(value: 0.3)
                    .tint(Color.accentGold)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding(TDSpacing.md)
        .glassBackground()
    }
}

#Preview {
    MyCoursesView()
        .environmentObject(CourseViewModel())
        .environmentObject(StoreViewModel())
}
