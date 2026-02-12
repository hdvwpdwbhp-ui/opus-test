//
//  AppAnalyticsManager.swift
//  Tanzen mit Tatiana Drexler
//
//  Sammelt und verwaltet App-Analytics für den Admin-Bereich
//

import Foundation
import Combine

@MainActor
class AppAnalyticsManager: ObservableObject {
    static let shared = AppAnalyticsManager()
    
    // MARK: - Published Analytics
    @Published var dailyActiveUsers: Int = 0
    @Published var weeklyActiveUsers: Int = 0
    @Published var monthlyActiveUsers: Int = 0
    @Published var totalUsers: Int = 0
    @Published var newUsersToday: Int = 0
    @Published var newUsersThisWeek: Int = 0
    @Published var totalCourseViews: Int = 0
    @Published var totalLessonViews: Int = 0
    @Published var totalWatchTime: TimeInterval = 0
    @Published var topCourses: [CourseAnalytics] = []
    @Published var userGroupDistribution: [UserGroupStat] = []
    @Published var revenueStats: RevenueStats = RevenueStats()
    @Published var privateLessonStats: PrivateLessonStats = PrivateLessonStats()
    @Published var engagementStats: EngagementStats = EngagementStats()
    @Published var dailyStats: [DailyStatPoint] = []
    
    private let analyticsKey = "app_analytics_data"
    private var analyticsData: AnalyticsData = AnalyticsData()
    
    private init() {
        loadAnalytics()
        calculateStats()
    }
    
    // MARK: - Track Events
    
    /// Tracke Kurs-Aufruf
    func trackCourseView(courseId: String, courseName: String) {
        analyticsData.courseViews[courseId, default: 0] += 1
        analyticsData.totalCourseViews += 1
        analyticsData.lastUpdated = Date()
        saveAnalytics()
        calculateStats()
    }
    
    /// Tracke Lektion-Aufruf
    func trackLessonView(lessonId: String, courseId: String, duration: TimeInterval) {
        analyticsData.lessonViews[lessonId, default: 0] += 1
        analyticsData.totalLessonViews += 1
        analyticsData.totalWatchTime += duration
        analyticsData.lessonWatchTime[lessonId, default: 0] += duration
        analyticsData.courseWatchTime[courseId, default: 0] += duration
        analyticsData.lastUpdated = Date()
        saveAnalytics()
        calculateStats()
    }
    
    /// Tracke User-Login
    func trackUserLogin(userId: String) {
        let today = Calendar.current.startOfDay(for: Date())
        var dailyUsers = analyticsData.dailyActiveUsers[today] ?? Set<String>()
        dailyUsers.insert(userId)
        analyticsData.dailyActiveUsers[today] = dailyUsers
        analyticsData.lastUpdated = Date()
        saveAnalytics()
        calculateStats()
    }
    
    /// Tracke Suche
    func trackSearch(query: String) {
        analyticsData.searchQueries[query, default: 0] += 1
        saveAnalytics()
    }
    
    /// Tracke Kauf
    func trackPurchase(productId: String, price: Decimal) {
        analyticsData.purchases.append(PurchaseRecord(productId: productId, price: price, date: Date()))
        saveAnalytics()
        calculateStats()
    }
    
    /// Tracke Privatstunden-Buchung
    func trackPrivateLessonBooking(trainerId: String, price: Decimal) {
        analyticsData.privateLessonBookings += 1
        analyticsData.privateLessonRevenue += price
        saveAnalytics()
        calculateStats()
    }
    
    // MARK: - Calculate Stats
    
    func calculateStats() {
        let userManager = UserManager.shared
        let privateLessonManager = PrivateLessonManager.shared
        let now = Date()
        let calendar = Calendar.current
        
        // User Stats
        totalUsers = userManager.allUsers.count
        
        // Neue User heute
        let todayStart = calendar.startOfDay(for: now)
        newUsersToday = userManager.allUsers.filter { calendar.isDate($0.createdAt, inSameDayAs: now) }.count
        
        // Neue User diese Woche
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        newUsersThisWeek = userManager.allUsers.filter { $0.createdAt >= weekAgo }.count
        
        // Aktive User
        dailyActiveUsers = analyticsData.dailyActiveUsers[todayStart]?.count ?? 0
        weeklyActiveUsers = calculateActiveUsers(days: 7)
        monthlyActiveUsers = calculateActiveUsers(days: 30)
        
        // Content Stats
        totalCourseViews = analyticsData.totalCourseViews
        totalLessonViews = analyticsData.totalLessonViews
        totalWatchTime = analyticsData.totalWatchTime
        
        // Top Kurse
        topCourses = calculateTopCourses()
        
        // User-Gruppen Verteilung
        userGroupDistribution = calculateUserGroupDistribution()
        
        // Revenue Stats
        revenueStats = calculateRevenueStats()
        
        // Privatstunden Stats
        privateLessonStats = calculatePrivateLessonStats(privateLessonManager)
        
        // Engagement Stats
        engagementStats = calculateEngagementStats()
        
        // Daily Stats für Grafik
        dailyStats = calculateDailyStats()
    }
    
    private func calculateActiveUsers(days: Int) -> Int {
        let calendar = Calendar.current
        let now = Date()
        var uniqueUsers = Set<String>()
        
        for dayOffset in 0..<days {
            if let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) {
                let dayStart = calendar.startOfDay(for: date)
                if let users = analyticsData.dailyActiveUsers[dayStart] {
                    uniqueUsers.formUnion(users)
                }
            }
        }
        
        return uniqueUsers.count
    }
    
    private func calculateTopCourses() -> [CourseAnalytics] {
        let courses = MockData.courses
        return analyticsData.courseViews
            .sorted { $0.value > $1.value }
            .prefix(10)
            .compactMap { courseId, views in
                guard let course = courses.first(where: { $0.id == courseId }) else { return nil }
                return CourseAnalytics(courseId: courseId, courseName: course.title, views: views)
            }
    }
    
    private func calculateUserGroupDistribution() -> [UserGroupStat] {
        let users = UserManager.shared.allUsers
        var distribution: [UserGroup: Int] = [:]
        
        for user in users {
            distribution[user.group, default: 0] += 1
        }
        
        return distribution.map { UserGroupStat(group: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }
    
    private func calculateRevenueStats() -> RevenueStats {
        let calendar = Calendar.current
        let now = Date()
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        let yearStart = calendar.date(from: calendar.dateComponents([.year], from: now)) ?? now
        
        var stats = RevenueStats()
        
        for purchase in analyticsData.purchases {
            stats.totalRevenue += purchase.price
            
            if purchase.date >= monthStart {
                stats.monthlyRevenue += purchase.price
            }
            
            if purchase.date >= yearStart {
                stats.yearlyRevenue += purchase.price
            }
        }
        
        stats.totalPurchases = analyticsData.purchases.count
        stats.averageOrderValue = stats.totalPurchases > 0 ? stats.totalRevenue / Decimal(stats.totalPurchases) : 0
        
        return stats
    }
    
    private func calculatePrivateLessonStats(_ manager: PrivateLessonManager) -> PrivateLessonStats {
        var stats = PrivateLessonStats()
        let bookings = manager.bookings
        
        stats.totalBookings = bookings.count
        stats.pendingBookings = bookings.filter { $0.status == .pending }.count
        stats.confirmedBookings = bookings.filter { $0.status == .confirmed }.count
        stats.completedBookings = bookings.filter { $0.status == .completed }.count
        stats.cancelledBookings = bookings.filter { $0.status == .cancelled || $0.status == .rejected }.count
        stats.totalRevenue = bookings.filter { $0.status == .completed }.reduce(0) { $0 + $1.price }
        
        // Aktive Trainer
        stats.activeTrainers = manager.trainerSettings.filter { $0.value.isEnabled }.count
        
        return stats
    }
    
    private func calculateEngagementStats() -> EngagementStats {
        var stats = EngagementStats()
        let userManager = UserManager.shared
        
        // Durchschnittliche Watch-Time pro User
        if totalUsers > 0 {
            stats.avgWatchTimePerUser = totalWatchTime / Double(totalUsers)
        }
        
        // Kurse pro User
        let totalPurchases = userManager.allUsers.reduce(0) { $0 + ($1.purchasedProductIds?.count ?? 0) }
        stats.avgCoursesPerUser = totalUsers > 0 ? Double(totalPurchases) / Double(totalUsers) : 0
        
        // Completion Rate (geschätzt basierend auf Views)
        stats.completionRate = totalLessonViews > 0 ? min(100, Double(totalLessonViews) / Double(max(1, totalCourseViews)) * 10) : 0
        
        // Retention (basierend auf wiederkehrenden Logins)
        stats.weeklyRetention = calculateRetentionRate(days: 7)
        stats.monthlyRetention = calculateRetentionRate(days: 30)
        
        return stats
    }
    
    private func calculateRetentionRate(days: Int) -> Double {
        let calendar = Calendar.current
        let now = Date()
        var returningUsers = 0
        var totalNewUsers = 0
        
        // User die vor 'days' Tagen erstellt wurden und seitdem aktiv waren
        for user in UserManager.shared.allUsers {
            let daysSinceCreation = calendar.dateComponents([.day], from: user.createdAt, to: now).day ?? 0
            if daysSinceCreation >= days {
                totalNewUsers += 1
                // Prüfe ob User in den letzten Tagen aktiv war
                for dayOffset in 0..<days {
                    if let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) {
                        let dayStart = calendar.startOfDay(for: date)
                        if analyticsData.dailyActiveUsers[dayStart]?.contains(user.id) == true {
                            returningUsers += 1
                            break
                        }
                    }
                }
            }
        }
        
        return totalNewUsers > 0 ? Double(returningUsers) / Double(totalNewUsers) * 100 : 0
    }
    
    private func calculateDailyStats() -> [DailyStatPoint] {
        let calendar = Calendar.current
        let now = Date()
        var stats: [DailyStatPoint] = []
        
        for dayOffset in (0..<30).reversed() {
            if let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) {
                let dayStart = calendar.startOfDay(for: date)
                let activeUsers = analyticsData.dailyActiveUsers[dayStart]?.count ?? 0
                let newUsers = UserManager.shared.allUsers.filter { calendar.isDate($0.createdAt, inSameDayAs: date) }.count
                
                stats.append(DailyStatPoint(date: dayStart, activeUsers: activeUsers, newUsers: newUsers))
            }
        }
        
        return stats
    }
    
    // MARK: - Course Performance

    func coursePerformance(for course: Course, lessons: [Lesson]) -> CoursePerformanceMetrics {
        let courseViews = analyticsData.courseViews[course.id, default: 0]
        let lessonViews = lessons.reduce(0) { $0 + analyticsData.lessonViews[$1.id, default: 0] }
        let lessonWatchSum = lessons.reduce(0.0) { $0 + analyticsData.lessonWatchTime[$1.id, default: 0] }
        let watchTime = analyticsData.courseWatchTime[course.id, default: lessonWatchSum]
        let avgWatchPerLessonView = lessonViews > 0 ? watchTime / Double(lessonViews) : 0
        let avgWatchPerCourseView = courseViews > 0 ? watchTime / Double(courseViews) : 0

        return CoursePerformanceMetrics(
            courseId: course.id,
            courseTitle: course.title,
            courseViews: courseViews,
            lessonViews: lessonViews,
            totalWatchTime: watchTime,
            avgWatchTimePerLessonView: avgWatchPerLessonView,
            avgWatchTimePerCourseView: avgWatchPerCourseView
        )
    }

    func lessonPerformance(for lessons: [Lesson]) -> [LessonPerformanceStat] {
        lessons.map { lesson in
            LessonPerformanceStat(
                lessonId: lesson.id,
                lessonTitle: lesson.title,
                views: analyticsData.lessonViews[lesson.id, default: 0],
                watchTime: analyticsData.lessonWatchTime[lesson.id, default: 0]
            )
        }.sorted { $0.views > $1.views }
    }
    
    // MARK: - Storage
    
    private func saveAnalytics() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(analyticsData) {
            UserDefaults.standard.set(data, forKey: analyticsKey)
        }
    }
    
    private func loadAnalytics() {
        guard let data = UserDefaults.standard.data(forKey: analyticsKey) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let loaded = try? decoder.decode(AnalyticsData.self, from: data) {
            analyticsData = loaded
        }
    }
    
    /// Setzt alle Analytics zurück (Admin-Funktion)
    func resetAnalytics() {
        analyticsData = AnalyticsData()
        saveAnalytics()
        calculateStats()
    }
}

// MARK: - Data Models

struct AnalyticsData: Codable {
    var courseViews: [String: Int] = [:]
    var lessonViews: [String: Int] = [:]
    var courseWatchTime: [String: TimeInterval] = [:]
    var lessonWatchTime: [String: TimeInterval] = [:]
    var totalCourseViews: Int = 0
    var totalLessonViews: Int = 0
    var totalWatchTime: TimeInterval = 0
    var dailyActiveUsers: [Date: Set<String>] = [:]
    var searchQueries: [String: Int] = [:]
    var purchases: [PurchaseRecord] = []
    var privateLessonBookings: Int = 0
    var privateLessonRevenue: Decimal = 0
    var lastUpdated: Date = Date()
}

struct PurchaseRecord: Codable {
    let productId: String
    let price: Decimal
    let date: Date
}

struct CourseAnalytics: Identifiable {
    let id = UUID()
    let courseId: String
    let courseName: String
    let views: Int
}

struct UserGroupStat: Identifiable {
    let id = UUID()
    let group: UserGroup
    let count: Int
}

struct RevenueStats {
    var totalRevenue: Decimal = 0
    var monthlyRevenue: Decimal = 0
    var yearlyRevenue: Decimal = 0
    var totalPurchases: Int = 0
    var averageOrderValue: Decimal = 0
}

struct PrivateLessonStats {
    var totalBookings: Int = 0
    var pendingBookings: Int = 0
    var confirmedBookings: Int = 0
    var completedBookings: Int = 0
    var cancelledBookings: Int = 0
    var totalRevenue: Decimal = 0
    var activeTrainers: Int = 0
}

struct EngagementStats {
    var avgWatchTimePerUser: TimeInterval = 0
    var avgCoursesPerUser: Double = 0
    var completionRate: Double = 0
    var weeklyRetention: Double = 0
    var monthlyRetention: Double = 0
}

struct DailyStatPoint: Identifiable {
    let id = UUID()
    let date: Date
    let activeUsers: Int
    let newUsers: Int
}

struct CoursePerformanceMetrics {
    let courseId: String
    let courseTitle: String
    let courseViews: Int
    let lessonViews: Int
    let totalWatchTime: TimeInterval
    let avgWatchTimePerLessonView: TimeInterval
    let avgWatchTimePerCourseView: TimeInterval
}

struct LessonPerformanceStat: Identifiable {
    let id = UUID()
    let lessonId: String
    let lessonTitle: String
    let views: Int
    let watchTime: TimeInterval
}
