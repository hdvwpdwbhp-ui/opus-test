//
//  LeaderboardView.swift
//  Tanzen mit Tatiana Drexler
//
//  Rangliste und Gamification Features
//

import SwiftUI

// MARK: - Leaderboard Entry
struct LeaderboardEntry: Codable, Identifiable {
    let id: String
    let rank: Int
    let userId: String
    let userName: String
    var points: Int
    var lessonsCompleted: Int
    var coursesCompleted: Int
    var currentStreak: Int
    var profileImageURL: String?
    var lastUpdated: Date
    
    static func fromStatistics(userId: String, userName: String, stats: UserStatistics, profileImageURL: String?) -> LeaderboardEntry {
        LeaderboardEntry(
            id: userId,
            rank: 0,
            userId: userId,
            userName: userName,
            points: stats.totalPoints,
            lessonsCompleted: stats.totalLessonsCompleted,
            coursesCompleted: stats.totalCoursesCompleted,
            currentStreak: stats.currentStreak,
            profileImageURL: profileImageURL,
            lastUpdated: Date()
        )
    }
}

// MARK: - Leaderboard View
struct LeaderboardView: View {
    @StateObject private var progressManager = LearningProgressManager.shared
    @StateObject private var userManager = UserManager.shared
    @State private var leaderboard: [LeaderboardEntry] = []
    @State private var selectedTimeframe: Timeframe = .allTime
    @State private var selectedCategory: LeaderboardCategory = .points
    @State private var isLoading = true
    
    enum Timeframe: String, CaseIterable {
        case week = "Diese Woche"
        case month = "Dieser Monat"
        case allTime = "Alle Zeit"
    }
    
    enum LeaderboardCategory: String, CaseIterable {
        case points = "Punkte"
        case streak = "Streak"
        case lessons = "Lektionen"
        case courses = "Kurse"
    }
    
    var currentUserEntry: LeaderboardEntry? {
        guard let userId = userManager.currentUser?.id else { return nil }
        return leaderboard.first { $0.userId == userId }
    }
    
    var currentUserRank: Int {
        guard let userId = userManager.currentUser?.id,
              let index = leaderboard.firstIndex(where: { $0.userId == userId }) else { return 0 }
        return index + 1
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: TDSpacing.lg) {
                // User's Position Card
                if let user = userManager.currentUser {
                    myPositionCard(user: user)
                }
                
                // Category Picker
                categoryPicker
                
                // Timeframe Picker
                timeframePicker
                
                // Top 3 Podium
                if leaderboard.count >= 3 {
                    podiumView
                }
                
                // Full Leaderboard
                leaderboardList
            }
            .padding()
        }
        .background(TDGradients.mainBackground.ignoresSafeArea())
        .navigationTitle(T("Rangliste"))
        .onAppear {
            loadLeaderboard()
        }
    }
    
    // MARK: - My Position Card
    private func myPositionCard(user: AppUser) -> some View {
        VStack(spacing: TDSpacing.md) {
            HStack(spacing: TDSpacing.lg) {
                // Rank Badge
                ZStack {
                    Circle()
                        .fill(getRankColor(currentUserRank))
                        .frame(width: 60, height: 60)
                    
                    Text("#\(currentUserRank)")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                }
                
                // User Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.name)
                        .font(TDTypography.headline)
                    
                    Text("\(progressManager.userStatistics.totalPoints) Punkte")
                        .font(TDTypography.subheadline)
                        .foregroundColor(Color.accentGold)
                    
                    HStack(spacing: TDSpacing.md) {
                        LeaderboardStatBadge(icon: "flame.fill", value: "\(progressManager.userStatistics.currentStreak)", color: .orange)
                        LeaderboardStatBadge(icon: "play.rectangle.fill", value: "\(progressManager.userStatistics.totalLessonsCompleted)", color: .green)
                    }
                }
                
                Spacer()
            }
            
            // Progress to next rank
            if currentUserRank > 1, let nextUser = leaderboard[safe: currentUserRank - 2] {
                let pointsNeeded = nextUser.points - progressManager.userStatistics.totalPoints
                if pointsNeeded > 0 {
                    VStack(spacing: 4) {
                        HStack {
                            Text(T("Noch %@ Punkte bis Platz %@", "\(pointsNeeded)", "\(currentUserRank - 1)"))
                                .font(TDTypography.caption1)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        ProgressView(value: Double(progressManager.userStatistics.totalPoints), total: Double(nextUser.points))
                            .tint(Color.accentGold)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: TDRadius.lg)
                .fill(Color.accentGold.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: TDRadius.lg)
                        .stroke(Color.accentGold, lineWidth: 2)
                )
        )
    }
    
    // MARK: - Category Picker
    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: TDSpacing.sm) {
                ForEach(LeaderboardCategory.allCases, id: \.self) { category in
                    Button {
                        withAnimation {
                            selectedCategory = category
                            sortLeaderboard()
                        }
                    } label: {
                        Text(category.rawValue)
                            .font(TDTypography.caption1)
                            .fontWeight(selectedCategory == category ? .semibold : .regular)
                            .foregroundColor(selectedCategory == category ? .white : .primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(selectedCategory == category ? Color.accentGold : Color.gray.opacity(0.1))
                            )
                    }
                }
            }
        }
    }
    
    // MARK: - Timeframe Picker
    private var timeframePicker: some View {
        Picker("Zeitraum", selection: $selectedTimeframe) {
            ForEach(Timeframe.allCases, id: \.self) { timeframe in
                Text(timeframe.rawValue).tag(timeframe)
            }
        }
        .pickerStyle(.segmented)
    }
    
    // MARK: - Podium View
    private var podiumView: some View {
        HStack(alignment: .bottom, spacing: TDSpacing.md) {
            // 2nd Place
            if leaderboard.count > 1 {
                PodiumPosition(entry: leaderboard[1], rank: 2, height: 80)
            }
            
            // 1st Place
            if !leaderboard.isEmpty {
                PodiumPosition(entry: leaderboard[0], rank: 1, height: 100)
            }
            
            // 3rd Place
            if leaderboard.count > 2 {
                PodiumPosition(entry: leaderboard[2], rank: 3, height: 60)
            }
        }
        .padding(.vertical)
    }
    
    // MARK: - Leaderboard List
    private var leaderboardList: some View {
        VStack(spacing: TDSpacing.sm) {
            ForEach(Array(leaderboard.enumerated()), id: \.element.id) { index, entry in
                LeaderboardRow(entry: entry, rank: index + 1, isCurrentUser: entry.userId == userManager.currentUser?.id)
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func loadLeaderboard() {
        isLoading = true
        
        // In real app, this would load from Firebase
        // For now, create sample data + current user
        var entries: [LeaderboardEntry] = []
        
        // Add current user
        if let user = userManager.currentUser {
            let entry = LeaderboardEntry.fromStatistics(
                userId: user.id,
                userName: user.name,
                stats: progressManager.userStatistics,
                profileImageURL: user.profileImageURL
            )
            entries.append(entry)
        }
        
        // Add sample users for demo
        let sampleUsers = [
            ("Maria S.", 2850, 45, 5, 21),
            ("Thomas K.", 2340, 38, 4, 14),
            ("Julia M.", 1980, 32, 3, 7),
            ("Andreas B.", 1650, 28, 2, 12),
            ("Sophie L.", 1420, 24, 2, 9),
            ("Michael R.", 1100, 18, 1, 5),
            ("Laura W.", 890, 15, 1, 3),
            ("David H.", 650, 11, 1, 2),
            ("Emma F.", 420, 7, 0, 1)
        ]
        
        for (index, sample) in sampleUsers.enumerated() {
            let entry = LeaderboardEntry(
                id: "sample_\(index)",
                rank: 0,
                userId: "sample_\(index)",
                userName: sample.0,
                points: sample.1,
                lessonsCompleted: sample.2,
                coursesCompleted: sample.3,
                currentStreak: sample.4,
                profileImageURL: nil,
                lastUpdated: Date()
            )
            entries.append(entry)
        }
        
        leaderboard = entries
        sortLeaderboard()
        isLoading = false
    }
    
    private func sortLeaderboard() {
        switch selectedCategory {
        case .points:
            leaderboard.sort { $0.points > $1.points }
        case .streak:
            leaderboard.sort { $0.currentStreak > $1.currentStreak }
        case .lessons:
            leaderboard.sort { $0.lessonsCompleted > $1.lessonsCompleted }
        case .courses:
            leaderboard.sort { $0.coursesCompleted > $1.coursesCompleted }
        }
    }
    
    private func getRankColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return Color.yellow
        case 2: return Color.gray
        case 3: return Color.orange
        default: return Color.accentGold
        }
    }
}

// MARK: - Podium Position
struct PodiumPosition: View {
    let entry: LeaderboardEntry
    let rank: Int
    let height: CGFloat
    
    var body: some View {
        VStack(spacing: 8) {
            // Crown for 1st place
            if rank == 1 {
                Image(systemName: "crown.fill")
                    .font(.title2)
                    .foregroundColor(.yellow)
            }
            
            // Avatar
            ZStack {
                Circle()
                    .fill(rankColor.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                if let imageURL = entry.profileImageURL, !imageURL.isEmpty {
                    AsyncImage(url: URL(string: imageURL)) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Text(String(entry.userName.prefix(1)))
                            .font(TDTypography.headline)
                            .foregroundColor(rankColor)
                    }
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                } else {
                    Text(String(entry.userName.prefix(1)))
                        .font(TDTypography.headline)
                        .foregroundColor(rankColor)
                }
            }
            .overlay(
                Circle()
                    .stroke(rankColor, lineWidth: 3)
            )
            
            // Name
            Text(entry.userName)
                .font(TDTypography.caption1)
                .lineLimit(1)
            
            // Points
            Text("\(entry.points)")
                .font(TDTypography.headline)
                .foregroundColor(rankColor)
            
            // Podium
            RoundedRectangle(cornerRadius: 8)
                .fill(rankColor)
                .frame(width: 80, height: height)
                .overlay(
                    Text("#\(rank)")
                        .font(.title.bold())
                        .foregroundColor(.white)
                )
        }
    }
    
    var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return Color.accentGold
        }
    }
}

// MARK: - Leaderboard Row
struct LeaderboardRow: View {
    let entry: LeaderboardEntry
    let rank: Int
    let isCurrentUser: Bool
    
    var body: some View {
        HStack(spacing: TDSpacing.md) {
            // Rank
            Text("#\(rank)")
                .font(TDTypography.headline)
                .foregroundColor(rank <= 3 ? getRankColor(rank) : .secondary)
                .frame(width: 40)
            
            // Avatar
            ZStack {
                Circle()
                    .fill(isCurrentUser ? Color.accentGold.opacity(0.2) : Color.gray.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Text(String(entry.userName.prefix(1)))
                    .font(TDTypography.subheadline)
                    .foregroundColor(isCurrentUser ? Color.accentGold : .primary)
            }
            
            // Name
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.userName)
                    .font(TDTypography.body)
                    .fontWeight(isCurrentUser ? .semibold : .regular)
                
                HStack(spacing: 8) {
                    Label("\(entry.currentStreak)", systemImage: "flame.fill")
                        .font(TDTypography.caption2)
                        .foregroundColor(.orange)
                }
            }
            
            Spacer()
            
            // Points
            Text("\(entry.points)")
                .font(TDTypography.headline)
                .foregroundColor(isCurrentUser ? Color.accentGold : .primary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: TDRadius.md)
                .fill(isCurrentUser ? Color.accentGold.opacity(0.1) : Color.white)
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
    
    private func getRankColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .secondary
        }
    }
}

// MARK: - Stat Badge
struct LeaderboardStatBadge: View {
    let icon: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            Text(value)
                .font(TDTypography.caption2)
        }
    }
}

// MARK: - Array Extension for safe access
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    NavigationStack {
        LeaderboardView()
    }
}
