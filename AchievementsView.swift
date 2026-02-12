//
//  AchievementsView.swift
//  Tanzen mit Tatiana Drexler
//
//  Achievements/Erfolge Übersicht
//

import SwiftUI

struct AchievementsView: View {
    @StateObject private var progressManager = LearningProgressManager.shared
    @StateObject private var userManager = UserManager.shared
    
    var unlockedAchievements: [Achievement] {
        progressManager.achievements.filter { $0.isUnlocked }
    }
    
    var lockedAchievements: [Achievement] {
        progressManager.achievements.filter { !$0.isUnlocked }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: TDSpacing.lg) {
                // Header Stats
                headerSection
                
                // Freigeschaltete Achievements
                if !unlockedAchievements.isEmpty {
                    achievementSection(title: "Freigeschaltet", achievements: unlockedAchievements, isUnlocked: true)
                }
                
                // Noch nicht freigeschaltet
                if !lockedAchievements.isEmpty {
                    achievementSection(title: "In Arbeit", achievements: lockedAchievements, isUnlocked: false)
                }
            }
            .padding(TDSpacing.md)
        }
        .background(TDGradients.mainBackground.ignoresSafeArea())
        .navigationTitle(T("Achievements"))
    }
    
    private var headerSection: some View {
        VStack(spacing: TDSpacing.md) {
            // Trophy Icon
            ZStack {
                Circle()
                    .fill(Color.accentGold.opacity(0.2))
                    .frame(width: 100, height: 100)
                Image(systemName: "trophy.fill")
                    .font(.system(size: 50))
                    .foregroundColor(Color.accentGold)
            }
            
            // Progress
            Text("\(unlockedAchievements.count) / \(progressManager.achievements.count)")
                .font(TDTypography.title1)
                .fontWeight(.bold)
            
            Text(T("Achievements freigeschaltet"))
                .font(TDTypography.subheadline)
                .foregroundColor(.secondary)
            
            // Stats
            HStack(spacing: TDSpacing.lg) {
                VStack {
                    Text("\(progressManager.userStatistics.currentStreak)")
                        .font(TDTypography.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Color.accentGold)
                    Text(T("Tage Streak"))
                        .font(TDTypography.caption2)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text(progressManager.userStatistics.formattedTotalWatchTime)
                        .font(TDTypography.headline)
                        .fontWeight(.bold)
                        .foregroundColor(Color.accentGold)
                    Text(T("Watch Time"))
                        .font(TDTypography.caption2)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text("\(progressManager.userStatistics.totalPoints)")
                        .font(TDTypography.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Color.accentGold)
                    Text(T("Punkte"))
                        .font(TDTypography.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(TDSpacing.lg)
        .frame(maxWidth: .infinity)
        .glassBackground()
    }
    
    private func achievementSection(title: String, achievements: [Achievement], isUnlocked: Bool) -> some View {
        VStack(alignment: .leading, spacing: TDSpacing.md) {
            HStack {
                Text(title)
                    .font(TDTypography.headline)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(achievements.count)")
                    .font(TDTypography.caption1)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, TDSpacing.sm)
            
            ForEach(achievements) { achievement in
                AchievementCard(achievement: achievement, isUnlocked: isUnlocked)
            }
        }
    }
}

// MARK: - Achievement Card

struct AchievementCard: View {
    let achievement: Achievement
    let isUnlocked: Bool
    
    var body: some View {
        HStack(spacing: TDSpacing.md) {
            // Icon
            ZStack {
                Circle()
                    .fill(isUnlocked ? Color.accentGold.opacity(0.2) : Color.gray.opacity(0.1))
                    .frame(width: 50, height: 50)
                Image(systemName: achievement.icon)
                    .font(.system(size: 24))
                    .foregroundColor(isUnlocked ? Color.accentGold : .gray)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(achievement.title)
                    .font(TDTypography.headline)
                    .foregroundColor(isUnlocked ? .primary : .secondary)
                
                Text(achievement.description)
                    .font(TDTypography.caption1)
                    .foregroundColor(.secondary)
                
                // Unlocked Date
                if isUnlocked, let date = achievement.unlockedAt {
                    Text(T("Freigeschaltet am %@", date.formatted(date: .abbreviated, time: .omitted)))
                        .font(TDTypography.caption2)
                        .foregroundColor(.green)
                }
            }
            
            Spacer()
            
            // Status
            if isUnlocked {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.green)
            } else {
                Image(systemName: "lock.fill")
                    .font(.title3)
                    .foregroundColor(.gray)
            }
        }
        .padding(TDSpacing.md)
        .background(isUnlocked ? Color.accentGold.opacity(0.05) : Color.gray.opacity(0.05))
        .cornerRadius(TDRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: TDRadius.md)
                .stroke(isUnlocked ? Color.accentGold.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}

#Preview {
    NavigationStack {
        AchievementsView()
    }
}
