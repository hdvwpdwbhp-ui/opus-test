//
//  LearningStatsView.swift
//  Tanzen mit Tatiana Drexler
//
//  Zeigt Lernfortschritt, Statistiken, Streaks und Achievements
//

import SwiftUI

// MARK: - Main Statistics View
struct LearningStatsView: View {
    @StateObject private var progressManager = LearningProgressManager.shared
    @State private var showAllAchievements = false
    @State private var showGoalSetting = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: TDSpacing.lg) {
                // Streak & Points Header
                streakHeader
                
                // Quick Stats
                quickStatsGrid
                
                // Daily Goal
                dailyGoalCard
                
                // Achievements
                achievementsSection
                
                // Weekly Activity
                weeklyActivityChart
            }
            .padding()
        }
        .background(TDGradients.mainBackground.ignoresSafeArea())
        .navigationTitle(T("Mein Fortschritt"))
        .sheet(isPresented: $showAllAchievements) {
            AllAchievementsView()
        }
        .sheet(isPresented: $showGoalSetting) {
            GoalSettingView()
        }
    }
    
    // MARK: - Streak Header
    private var streakHeader: some View {
        HStack(spacing: TDSpacing.xl) {
            // Streak
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                    Text("\(progressManager.userStatistics.currentStreak)")
                        .font(.system(size: 32, weight: .bold))
                }
                Text(T("Tage Streak"))
                    .font(TDTypography.caption1)
                    .foregroundColor(.secondary)
            }
            
            Divider()
                .frame(height: 50)
            
            // Points
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundColor(Color.accentGold)
                    Text("\(progressManager.userStatistics.totalPoints)")
                        .font(.system(size: 32, weight: .bold))
                }
                Text(T("Punkte"))
                    .font(TDTypography.caption1)
                    .foregroundColor(.secondary)
            }
            
            Divider()
                .frame(height: 50)
            
            // Longest Streak
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "trophy.fill")
                        .foregroundColor(.yellow)
                    Text("\(progressManager.userStatistics.longestStreak)")
                        .font(.system(size: 32, weight: .bold))
                }
                Text(T("Bester Streak"))
                    .font(TDTypography.caption1)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .glassBackground()
    }
    
    // MARK: - Quick Stats Grid
    private var quickStatsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: TDSpacing.md) {
            LearningStatCard(
                title: "Lernzeit",
                value: progressManager.userStatistics.formattedTotalWatchTime,
                icon: "clock.fill",
                color: .blue
            )
            
            LearningStatCard(
                title: "Lektionen",
                value: "\(progressManager.userStatistics.totalLessonsCompleted)",
                icon: "play.rectangle.fill",
                color: .green
            )
            
            LearningStatCard(
                title: "Kurse gestartet",
                value: "\(progressManager.userStatistics.totalCoursesStarted)",
                icon: "book.fill",
                color: .purple
            )
            
            LearningStatCard(
                title: "Kurse abgeschlossen",
                value: "\(progressManager.userStatistics.totalCoursesCompleted)",
                icon: "checkmark.seal.fill",
                color: Color.accentGold
            )
        }
    }
    
    // MARK: - Daily Goal Card
    private var dailyGoalCard: some View {
        VStack(alignment: .leading, spacing: TDSpacing.md) {
            HStack {
                Text(T("Tagesziel"))
                    .font(TDTypography.headline)
                Spacer()
                Button {
                    showGoalSetting = true
                } label: {
                    Image(systemName: "gear")
                        .foregroundColor(Color.accentGold)
                }
            }
            
            if let dailyGoal = progressManager.learningGoals.first(where: { $0.type == .dailyMinutes && $0.isActive }) {
                VStack(spacing: TDSpacing.sm) {
                    HStack {
                        Text("\(dailyGoal.currentValue) / \(dailyGoal.targetValue) Min.")
                            .font(TDTypography.body)
                        Spacer()
                        Text("\(Int(dailyGoal.progress * 100))%")
                            .font(TDTypography.headline)
                            .foregroundColor(Color.accentGold)
                    }
                    
                    ProgressView(value: dailyGoal.progress)
                        .tint(Color.accentGold)
                    
                    if dailyGoal.isCompleted {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(T("Tagesziel erreicht! 🎉"))
                                .font(TDTypography.caption1)
                        }
                    }
                }
            } else {
                Button {
                    showGoalSetting = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text(T("Tagesziel festlegen"))
                    }
                    .foregroundColor(Color.accentGold)
                }
            }
        }
        .padding()
        .glassBackground()
    }
    
    // MARK: - Achievements Section
    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: TDSpacing.md) {
            HStack {
                Text(T("Achievements"))
                    .font(TDTypography.headline)
                Spacer()
                Button(T("Alle anzeigen")) {
                    showAllAchievements = true
                }
                .font(TDTypography.caption1)
                .foregroundColor(Color.accentGold)
            }
            
            let unlockedCount = progressManager.achievements.filter { $0.isUnlocked }.count
            Text("\(unlockedCount) von \(progressManager.achievements.count) freigeschaltet")
                .font(TDTypography.caption1)
                .foregroundColor(.secondary)
            
            // Show recent achievements
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: TDSpacing.md) {
                    ForEach(progressManager.achievements.filter { $0.isUnlocked }.prefix(5)) { achievement in
                        AchievementBadge(achievement: achievement)
                    }
                    
                    // Show next locked achievement
                    if let nextLocked = progressManager.achievements.first(where: { !$0.isUnlocked }) {
                        AchievementBadge(achievement: nextLocked, isLocked: true)
                    }
                }
            }
        }
        .padding()
        .glassBackground()
    }
    
    // MARK: - Weekly Activity Chart
    private var weeklyActivityChart: some View {
        VStack(alignment: .leading, spacing: TDSpacing.md) {
            Text(T("Diese Woche"))
                .font(TDTypography.headline)
            
            HStack(spacing: TDSpacing.sm) {
                ForEach(0..<7, id: \.self) { dayOffset in
                    let date = Calendar.current.date(byAdding: .day, value: -6 + dayOffset, to: Date()) ?? Date()
                    let dateString = formatDateKey(date)
                    let isActive = progressManager.userStatistics.dailyActivity[dateString] ?? false
                    let isToday = Calendar.current.isDateInToday(date)
                    
                    VStack(spacing: 4) {
                        Circle()
                            .fill(isActive ? Color.accentGold : Color.gray.opacity(0.3))
                            .frame(width: 36, height: 36)
                            .overlay(
                                isActive ? Image(systemName: "checkmark")
                                    .font(.caption.bold())
                                    .foregroundColor(.white) : nil
                            )
                            .overlay(
                                isToday ? Circle().stroke(Color.accentGold, lineWidth: 2) : nil
                            )
                        
                        Text(dayName(for: date))
                            .font(.system(size: 10))
                            .foregroundColor(isToday ? Color.accentGold : .secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .glassBackground()
    }
    
    private func formatDateKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    private func dayName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.string(from: date)
    }
}

// MARK: - Learning Stat Card
struct LearningStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: TDSpacing.sm) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(TDTypography.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(TDTypography.caption1)
                .foregroundColor(.secondary)
        }
        .padding()
        .glassBackground()
    }
}

// MARK: - Achievement Badge
struct AchievementBadge: View {
    let achievement: Achievement
    var isLocked: Bool = false
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isLocked ? Color.gray.opacity(0.3) : Color.accentGold.opacity(0.2))
                    .frame(width: 60, height: 60)
                
                Image(systemName: achievement.icon)
                    .font(.title2)
                    .foregroundColor(isLocked ? .gray : Color.accentGold)
                
                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .offset(x: 20, y: 20)
                }
            }
            
            Text(achievement.title)
                .font(TDTypography.caption2)
                .foregroundColor(isLocked ? .secondary : .primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 70)
        }
    }
}

// MARK: - All Achievements View
struct AllAchievementsView: View {
    @StateObject private var progressManager = LearningProgressManager.shared
    @Environment(\.dismiss) var dismiss
    
    var unlockedAchievements: [Achievement] {
        progressManager.achievements.filter { $0.isUnlocked }
    }
    
    var lockedAchievements: [Achievement] {
        progressManager.achievements.filter { !$0.isUnlocked }
    }
    
    var body: some View {
        NavigationStack {
            List {
                if !unlockedAchievements.isEmpty {
                    Section(T("Freigeschaltet (%@)", "\(unlockedAchievements.count)")) {
                        ForEach(unlockedAchievements) { achievement in
                            AchievementRow(achievement: achievement)
                        }
                    }
                }
                
                Section(T("Noch zu erreichen (%@)", "\(lockedAchievements.count)")) {
                    ForEach(lockedAchievements) { achievement in
                        AchievementRow(achievement: achievement, isLocked: true)
                    }
                }
            }
            .navigationTitle(T("Achievements"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(T("Fertig")) { dismiss() }
                }
            }
        }
    }
}

struct AchievementRow: View {
    let achievement: Achievement
    var isLocked: Bool = false
    
    var body: some View {
        HStack(spacing: TDSpacing.md) {
            ZStack {
                Circle()
                    .fill(isLocked ? Color.gray.opacity(0.2) : Color.accentGold.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: achievement.icon)
                    .font(.title3)
                    .foregroundColor(isLocked ? .gray : Color.accentGold)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(achievement.title)
                    .font(TDTypography.headline)
                    .foregroundColor(isLocked ? .secondary : .primary)
                
                Text(achievement.description)
                    .font(TDTypography.caption1)
                    .foregroundColor(.secondary)
                
                if let unlockedAt = achievement.unlockedAt {
                    Text(T("Erreicht am %@", unlockedAt.formatted(date: .abbreviated, time: .omitted)))
                        .font(TDTypography.caption2)
                        .foregroundColor(Color.accentGold)
                }
            }
            
            Spacer()
            
            if isLocked {
                Image(systemName: "lock.fill")
                    .foregroundColor(.gray)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
    }
}

// MARK: - Goal Setting View
struct GoalSettingView: View {
    @StateObject private var progressManager = LearningProgressManager.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var dailyMinutes = 15
    let minuteOptions = [5, 10, 15, 20, 30, 45, 60]
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: TDSpacing.lg) {
                        Image(systemName: "target")
                            .font(.system(size: 50))
                            .foregroundColor(Color.accentGold)
                        
                        Text(T("Setze dein tägliches Lernziel"))
                            .font(TDTypography.title3)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                
                Section(T("Tägliche Lernzeit")) {
                    Picker("Minuten pro Tag", selection: $dailyMinutes) {
                        ForEach(minuteOptions, id: \.self) { minutes in
                            Text("\(minutes) Minuten").tag(minutes)
                        }
                    }
                    .pickerStyle(.wheel)
                }
                
                Section {
                    Button {
                        progressManager.setDailyGoal(minutes: dailyMinutes)
                        dismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Text(T("Ziel festlegen"))
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .listRowBackground(Color.accentGold)
                    .foregroundColor(.white)
                }
            }
            .navigationTitle(T("Lernziel"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(T("Abbrechen")) { dismiss() }
                }
            }
        }
    }
}

// MARK: - Course Progress Card (für Kursansicht)
struct CourseProgressCard: View {
    let courseId: String
    let totalLessons: Int
    @StateObject private var progressManager = LearningProgressManager.shared
    
    var progress: Double {
        progressManager.getProgressPercentage(for: courseId, totalLessons: totalLessons)
    }
    
    var completedLessons: Int {
        progressManager.getProgress(for: courseId)?.completedLessonIds.count ?? 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: TDSpacing.sm) {
            HStack {
                Text(T("Fortschritt"))
                    .font(TDTypography.subheadline)
                Spacer()
                Text("\(Int(progress))%")
                    .font(TDTypography.headline)
                    .foregroundColor(Color.accentGold)
            }
            
            ProgressView(value: progress / 100)
                .tint(Color.accentGold)
            
            Text("\(completedLessons) von \(totalLessons) Lektionen")
                .font(TDTypography.caption1)
                .foregroundColor(.secondary)
        }
        .padding()
        .glassBackground()
    }
}

#Preview {
    NavigationStack {
        LearningStatsView()
    }
}
