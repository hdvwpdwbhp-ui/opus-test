//
//  AppAnalyticsView.swift
//  Tanzen mit Tatiana Drexler
//
//  Analytics Dashboard für Admins
//

import SwiftUI
import Charts

struct AppAnalyticsView: View {
    @StateObject private var analytics = AppAnalyticsManager.shared
    @StateObject private var userManager = UserManager.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: TDSpacing.lg) {
                // User Stats Cards
                userStatsSection
                
                // User Activity Chart
                activityChartSection
                
                // Revenue Stats
                revenueSection
                
                // Privatstunden Stats
                privateLessonSection
                
                // Engagement Stats
                engagementSection
                
                // Top Kurse
                topCoursesSection
                
                // User Gruppen Verteilung
                userGroupsSection
                
                // Admin Actions
                adminActionsSection
            }
            .padding(TDSpacing.md)
        }
        .background(TDGradients.mainBackground.ignoresSafeArea())
        .navigationTitle(T("App Analytics"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    analytics.calculateStats()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .onAppear {
            analytics.calculateStats()
        }
    }
    
    // MARK: - User Stats Section
    private var userStatsSection: some View {
        VStack(alignment: .leading, spacing: TDSpacing.sm) {
            Text(T("User Statistiken"))
                .font(TDTypography.headline)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: TDSpacing.md) {
                AnalyticsCard(
                    title: "Gesamt User",
                    value: "\(analytics.totalUsers)",
                    icon: "person.3.fill",
                    color: .blue
                )
                
                AnalyticsCard(
                    title: "Heute aktiv",
                    value: "\(analytics.dailyActiveUsers)",
                    icon: "person.fill.checkmark",
                    color: .green
                )
                
                AnalyticsCard(
                    title: "Diese Woche",
                    value: "\(analytics.weeklyActiveUsers)",
                    icon: "calendar.badge.clock",
                    color: .orange
                )
                
                AnalyticsCard(
                    title: "Diesen Monat",
                    value: "\(analytics.monthlyActiveUsers)",
                    icon: "calendar",
                    color: .purple
                )
                
                AnalyticsCard(
                    title: "Neu heute",
                    value: "+\(analytics.newUsersToday)",
                    icon: "person.badge.plus",
                    color: .mint,
                    highlight: analytics.newUsersToday > 0
                )
                
                AnalyticsCard(
                    title: "Neu diese Woche",
                    value: "+\(analytics.newUsersThisWeek)",
                    icon: "person.2.badge.gearshape",
                    color: .cyan
                )
            }
        }
    }
    
    // MARK: - Activity Chart
    private var activityChartSection: some View {
        VStack(alignment: .leading, spacing: TDSpacing.sm) {
            Text(T("Aktivität (30 Tage)"))
                .font(TDTypography.headline)
                .foregroundColor(.secondary)
            
            if #available(iOS 16.0, *) {
                Chart(analytics.dailyStats) { stat in
                    BarMark(
                        x: .value("Tag", stat.date, unit: .day),
                        y: .value("Aktive User", stat.activeUsers)
                    )
                    .foregroundStyle(Color.accentGold.gradient)
                }
                .frame(height: 200)
                .padding(TDSpacing.md)
                .glassBackground()
            } else {
                // Fallback für ältere iOS Versionen
                SimpleBarChart(data: analytics.dailyStats)
                    .frame(height: 200)
                    .padding(TDSpacing.md)
                    .glassBackground()
            }
        }
    }
    
    // MARK: - Revenue Section
    private var revenueSection: some View {
        VStack(alignment: .leading, spacing: TDSpacing.sm) {
            Text(T("Umsatz"))
                .font(TDTypography.headline)
                .foregroundColor(.secondary)
            
            VStack(spacing: TDSpacing.md) {
                HStack {
                    RevenueStatRow(title: "Gesamt", value: analytics.revenueStats.totalRevenue, icon: "dollarsign.circle.fill")
                    RevenueStatRow(title: "Diesen Monat", value: analytics.revenueStats.monthlyRevenue, icon: "calendar.circle.fill")
                }
                
                HStack {
                    RevenueStatRow(title: "Dieses Jahr", value: analytics.revenueStats.yearlyRevenue, icon: "chart.line.uptrend.xyaxis.circle.fill")
                    RevenueStatRow(title: "Ø Bestellung", value: analytics.revenueStats.averageOrderValue, icon: "cart.circle.fill")
                }
                
                Divider()
                
                HStack {
                    Text(T("Käufe insgesamt:"))
                        .font(TDTypography.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(analytics.revenueStats.totalPurchases)")
                        .font(TDTypography.headline)
                        .foregroundColor(Color.accentGold)
                }
            }
            .padding(TDSpacing.md)
            .glassBackground()
        }
    }
    
    // MARK: - Privatstunden Section
    private var privateLessonSection: some View {
        VStack(alignment: .leading, spacing: TDSpacing.sm) {
            Text(T("Privatstunden"))
                .font(TDTypography.headline)
                .foregroundColor(.secondary)
            
            VStack(spacing: TDSpacing.md) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: TDSpacing.sm) {
                    MiniStatCard(title: "Gesamt", value: "\(analytics.privateLessonStats.totalBookings)", color: .blue)
                    MiniStatCard(title: "Ausstehend", value: "\(analytics.privateLessonStats.pendingBookings)", color: .orange)
                    MiniStatCard(title: "Bestätigt", value: "\(analytics.privateLessonStats.confirmedBookings)", color: .green)
                    MiniStatCard(title: "Abgeschlossen", value: "\(analytics.privateLessonStats.completedBookings)", color: .purple)
                    MiniStatCard(title: "Storniert", value: "\(analytics.privateLessonStats.cancelledBookings)", color: .red)
                    MiniStatCard(title: "Trainer", value: "\(analytics.privateLessonStats.activeTrainers)", color: .cyan)
                }
                
                Divider()
                
                HStack {
                    Text(T("Privatstunden-Umsatz:"))
                        .font(TDTypography.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(analytics.privateLessonStats.totalRevenue.formatted(.currency(code: "EUR")))
                        .font(TDTypography.headline)
                        .foregroundColor(.green)
                }
            }
            .padding(TDSpacing.md)
            .glassBackground()
        }
    }
    
    // MARK: - Engagement Section
    private var engagementSection: some View {
        VStack(alignment: .leading, spacing: TDSpacing.sm) {
            Text(T("Engagement"))
                .font(TDTypography.headline)
                .foregroundColor(.secondary)
            
            VStack(spacing: TDSpacing.md) {
                EngagementRow(
                    title: "Ø Watch-Time pro User",
                    value: formatDuration(analytics.engagementStats.avgWatchTimePerUser),
                    icon: "play.circle"
                )
                
                EngagementRow(
                    title: "Ø Kurse pro User",
                    value: String(format: "%.1f", analytics.engagementStats.avgCoursesPerUser),
                    icon: "book.circle"
                )
                
                EngagementRow(
                    title: "Completion Rate",
                    value: String(format: "%.0f%%", analytics.engagementStats.completionRate),
                    icon: "checkmark.circle"
                )
                
                Divider()
                
                Text(T("Retention"))
                    .font(TDTypography.subheadline)
                    .foregroundColor(.secondary)
                
                HStack(spacing: TDSpacing.lg) {
                    RetentionBadge(title: "7 Tage", value: analytics.engagementStats.weeklyRetention)
                    RetentionBadge(title: "30 Tage", value: analytics.engagementStats.monthlyRetention)
                }
            }
            .padding(TDSpacing.md)
            .glassBackground()
        }
    }
    
    // MARK: - Top Courses Section
    private var topCoursesSection: some View {
        VStack(alignment: .leading, spacing: TDSpacing.sm) {
            Text(T("Top Kurse"))
                .font(TDTypography.headline)
                .foregroundColor(.secondary)
            
            VStack(spacing: 0) {
                if analytics.topCourses.isEmpty {
                    Text(T("Noch keine Daten verfügbar"))
                        .font(TDTypography.body)
                        .foregroundColor(.secondary)
                        .padding(TDSpacing.lg)
                } else {
                    ForEach(Array(analytics.topCourses.enumerated()), id: \.element.id) { index, course in
                        HStack {
                            Text("#\(index + 1)")
                                .font(TDTypography.headline)
                                .foregroundColor(index < 3 ? Color.accentGold : .secondary)
                                .frame(width: 30)
                            
                            Text(course.courseName)
                                .font(TDTypography.body)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text("\(course.views) Views")
                                .font(TDTypography.caption1)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, TDSpacing.sm)
                        
                        if index < analytics.topCourses.count - 1 {
                            Divider()
                        }
                    }
                }
            }
            .padding(TDSpacing.md)
            .glassBackground()
        }
    }
    
    // MARK: - User Groups Section
    private var userGroupsSection: some View {
        VStack(alignment: .leading, spacing: TDSpacing.sm) {
            Text(T("User-Gruppen"))
                .font(TDTypography.headline)
                .foregroundColor(.secondary)
            
            VStack(spacing: TDSpacing.sm) {
                ForEach(analytics.userGroupDistribution) { stat in
                    HStack {
                        Image(systemName: stat.group.icon)
                            .foregroundColor(colorForGroup(stat.group))
                            .frame(width: 30)
                        
                        Text(stat.group.displayName)
                            .font(TDTypography.body)
                        
                        Spacer()
                        
                        Text("\(stat.count)")
                            .font(TDTypography.headline)
                            .foregroundColor(colorForGroup(stat.group))
                        
                        // Prozent-Balken
                        let percentage = analytics.totalUsers > 0 ? Double(stat.count) / Double(analytics.totalUsers) : 0
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(colorForGroup(stat.group).opacity(0.3))
                                .frame(width: geo.size.width * percentage)
                        }
                        .frame(width: 60, height: 8)
                    }
                }
            }
            .padding(TDSpacing.md)
            .glassBackground()
        }
    }
    
    // MARK: - Admin Actions
    private var adminActionsSection: some View {
        VStack(alignment: .leading, spacing: TDSpacing.sm) {
            Text(T("Admin-Aktionen"))
                .font(TDTypography.headline)
                .foregroundColor(.secondary)
            
            Button {
                analytics.resetAnalytics()
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text(T("Analytics zurücksetzen"))
                }
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding(TDSpacing.md)
            }
            .glassBackground()
        }
    }
    
    // MARK: - Helpers
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
    
    private func colorForGroup(_ group: UserGroup) -> Color {
        switch group {
        case .admin: return .red
        case .support: return .orange
        case .trainer: return .blue
        case .premium: return Color.accentGold
        case .user: return .gray
        }
    }
}

// MARK: - Supporting Views

struct AnalyticsCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    var highlight: Bool = false
    
    var body: some View {
        VStack(spacing: TDSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(color)
            
            Text(value)
                .font(TDTypography.title2)
                .fontWeight(.bold)
                .foregroundColor(highlight ? color : .primary)
            
            Text(title)
                .font(TDTypography.caption1)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(TDSpacing.md)
        .glassBackground()
    }
}

struct RevenueStatRow: View {
    let title: String
    let value: Decimal
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.green)
                Text(title)
                    .font(TDTypography.caption1)
                    .foregroundColor(.secondary)
            }
            Text(value.formatted(.currency(code: "EUR")))
                .font(TDTypography.headline)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MiniStatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(TDTypography.headline)
                .foregroundColor(color)
            Text(title)
                .font(TDTypography.caption2)
                .foregroundColor(.secondary)
        }
        .padding(TDSpacing.sm)
        .background(color.opacity(0.1))
        .cornerRadius(TDRadius.sm)
    }
}

struct EngagementRow: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(Color.accentGold)
                .frame(width: 30)
            
            Text(title)
                .font(TDTypography.body)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(TDTypography.headline)
        }
    }
}

struct RetentionBadge: View {
    let title: String
    let value: Double
    
    var body: some View {
        VStack(spacing: 4) {
            Text(String(format: "%.0f%%", value))
                .font(TDTypography.title3)
                .fontWeight(.bold)
                .foregroundColor(retentionColor)
            Text(title)
                .font(TDTypography.caption1)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(TDSpacing.sm)
        .background(retentionColor.opacity(0.1))
        .cornerRadius(TDRadius.sm)
    }
    
    var retentionColor: Color {
        if value >= 60 { return .green }
        if value >= 30 { return .orange }
        return .red
    }
}

// Fallback Chart für ältere iOS Versionen
struct SimpleBarChart: View {
    let data: [DailyStatPoint]
    
    var maxValue: Int {
        data.map { $0.activeUsers }.max() ?? 1
    }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(data) { point in
                VStack {
                    Spacer()
                    Rectangle()
                        .fill(Color.accentGold)
                        .frame(height: maxValue > 0 ? CGFloat(point.activeUsers) / CGFloat(maxValue) * 150 : 0)
                }
            }
        }
    }
}
