//
//  LearningProgressManager.swift
//  Tanzen mit Tatiana Drexler
//
//  Verwaltet Lernfortschritt, Statistiken, Streaks und Achievements
//

import Foundation
import Combine

// MARK: - Learning Progress Models

struct LearningCourseProgress: Codable, Identifiable {
    let id: String
    let courseId: String
    let userId: String
    var completedLessonIds: Set<String>
    var lessonProgress: [String: LessonProgress] // lessonId -> Progress
    var startedAt: Date
    var lastAccessedAt: Date
    var totalWatchTime: TimeInterval
    var isCompleted: Bool
    var completedAt: Date?
    
    var progressPercentage: Double {
        guard !completedLessonIds.isEmpty else { return 0 }
        return Double(completedLessonIds.count)
    }
    
    static func create(courseId: String, userId: String) -> LearningCourseProgress {
        LearningCourseProgress(
            id: UUID().uuidString,
            courseId: courseId,
            userId: userId,
            completedLessonIds: [],
            lessonProgress: [:],
            startedAt: Date(),
            lastAccessedAt: Date(),
            totalWatchTime: 0,
            isCompleted: false,
            completedAt: nil
        )
    }
}

struct LessonProgress: Codable {
    var lessonId: String
    var watchedSeconds: TimeInterval
    var totalSeconds: TimeInterval
    var lastPosition: TimeInterval
    var completedAt: Date?
    var watchCount: Int
    
    var percentageWatched: Double {
        guard totalSeconds > 0 else { return 0 }
        return min(watchedSeconds / totalSeconds * 100, 100)
    }
    
    var isCompleted: Bool {
        completedAt != nil || percentageWatched >= 90
    }
}

struct UserStatistics: Codable {
    var totalWatchTime: TimeInterval
    var totalCoursesStarted: Int
    var totalCoursesCompleted: Int
    var totalLessonsCompleted: Int
    var currentStreak: Int
    var longestStreak: Int
    var lastActiveDate: Date?
    var totalPoints: Int
    var weeklyWatchTime: [String: TimeInterval] // "2026-W06" -> seconds
    var dailyActivity: [String: Bool] // "2026-02-09" -> active
    
    static func empty() -> UserStatistics {
        UserStatistics(
            totalWatchTime: 0,
            totalCoursesStarted: 0,
            totalCoursesCompleted: 0,
            totalLessonsCompleted: 0,
            currentStreak: 0,
            longestStreak: 0,
            lastActiveDate: nil,
            totalPoints: 0,
            weeklyWatchTime: [:],
            dailyActivity: [:]
        )
    }
    
    var formattedTotalWatchTime: String {
        let hours = Int(totalWatchTime) / 3600
        let minutes = (Int(totalWatchTime) % 3600) / 60
        if hours > 0 {
            return "\(hours) Std. \(minutes) Min."
        }
        return "\(minutes) Minuten"
    }
}

struct LearningGoal: Codable, Identifiable {
    let id: String
    var type: GoalType
    var targetValue: Int
    var currentValue: Int
    var startDate: Date
    var endDate: Date?
    var isActive: Bool
    
    enum GoalType: String, Codable {
        case dailyMinutes = "Tägliche Minuten"
        case weeklyLessons = "Wöchentliche Lektionen"
        case weeklyCourses = "Wöchentliche Kurse"
        case streakDays = "Streak Tage"
    }
    
    var progress: Double {
        guard targetValue > 0 else { return 0 }
        return min(Double(currentValue) / Double(targetValue), 1.0)
    }
    
    var isCompleted: Bool {
        currentValue >= targetValue
    }
}

// MARK: - Achievement System

struct Achievement: Codable, Identifiable {
    let id: String
    let type: AchievementType
    let title: String
    let description: String
    let icon: String
    let requiredValue: Int
    var unlockedAt: Date?
    var isUnlocked: Bool { unlockedAt != nil }
    
    enum AchievementType: String, Codable, CaseIterable {
        case firstLesson = "first_lesson"
        case firstCourse = "first_course"
        case streak3 = "streak_3"
        case streak7 = "streak_7"
        case streak30 = "streak_30"
        case lessons10 = "lessons_10"
        case lessons50 = "lessons_50"
        case lessons100 = "lessons_100"
        case hours5 = "hours_5"
        case hours25 = "hours_25"
        case hours100 = "hours_100"
        case courses3 = "courses_3"
        case courses10 = "courses_10"
        case allStyles = "all_styles"
        case nightOwl = "night_owl"
        case earlyBird = "early_bird"
        case weekendWarrior = "weekend_warrior"
        case perfectWeek = "perfect_week"
        case speedLearner = "speed_learner"
    }
}

// MARK: - Learning Progress Manager

@MainActor
class LearningProgressManager: ObservableObject {
    static let shared = LearningProgressManager()
    
    @Published var courseProgress: [String: LearningCourseProgress] = [:] // courseId -> progress
    @Published var userStatistics: UserStatistics = .empty()
    @Published var achievements: [Achievement] = []
    @Published var learningGoals: [LearningGoal] = []
    @Published var recentlyUnlockedAchievement: Achievement?
    
    private let progressKey = "learning_progress"
    private let statisticsKey = "user_statistics"
    private let achievementsKey = "user_achievements"
    private let goalsKey = "learning_goals"
    
    private let firebase = FirebaseService.shared
    
    private init() {
        loadLocalData()
        initializeAchievements()
        Task { await loadFromCloud() }
    }
    
    // MARK: - Progress Tracking
    
    func startCourse(_ courseId: String, userId: String) {
        if courseProgress[courseId] == nil {
            courseProgress[courseId] = LearningCourseProgress.create(courseId: courseId, userId: userId)
            userStatistics.totalCoursesStarted += 1
            addPoints(10, reason: "Kurs gestartet")
        }
        courseProgress[courseId]?.lastAccessedAt = Date()
        recordDailyActivity()
        saveAndSync()
    }
    
    func updateLessonProgress(courseId: String, lessonId: String, watchedSeconds: TimeInterval, totalSeconds: TimeInterval, currentPosition: TimeInterval) {
        guard var progress = courseProgress[courseId] else { return }
        
        var lessonProgress = progress.lessonProgress[lessonId] ?? LessonProgress(
            lessonId: lessonId,
            watchedSeconds: 0,
            totalSeconds: totalSeconds,
            lastPosition: 0,
            completedAt: nil,
            watchCount: 0
        )
        
        // Update watch time
        let additionalTime = max(0, watchedSeconds - lessonProgress.watchedSeconds)
        lessonProgress.watchedSeconds = watchedSeconds
        lessonProgress.totalSeconds = totalSeconds
        lessonProgress.lastPosition = currentPosition
        
        // Check completion
        if lessonProgress.percentageWatched >= 90 && lessonProgress.completedAt == nil {
            lessonProgress.completedAt = Date()
            lessonProgress.watchCount += 1
            progress.completedLessonIds.insert(lessonId)
            userStatistics.totalLessonsCompleted += 1
            addPoints(5, reason: "Lektion abgeschlossen")
            checkAchievements()
        }
        
        progress.lessonProgress[lessonId] = lessonProgress
        progress.totalWatchTime += additionalTime
        progress.lastAccessedAt = Date()
        
        // Update global stats
        userStatistics.totalWatchTime += additionalTime
        updateWeeklyWatchTime(additionalTime)
        
        courseProgress[courseId] = progress
        recordDailyActivity()
        saveAndSync()
    }
    
    func markLessonComplete(courseId: String, lessonId: String, totalLessons: Int) {
        guard var progress = courseProgress[courseId] else { return }
        
        if !progress.completedLessonIds.contains(lessonId) {
            progress.completedLessonIds.insert(lessonId)
            userStatistics.totalLessonsCompleted += 1
            addPoints(5, reason: "Lektion abgeschlossen")
        }
        
        // Check if course is complete
        if progress.completedLessonIds.count >= totalLessons && !progress.isCompleted {
            progress.isCompleted = true
            progress.completedAt = Date()
            userStatistics.totalCoursesCompleted += 1
            addPoints(50, reason: "Kurs abgeschlossen")
        }
        
        courseProgress[courseId] = progress
        checkAchievements()
        saveAndSync()
    }
    
    func getProgress(for courseId: String) -> LearningCourseProgress? {
        return courseProgress[courseId]
    }
    
    func getProgressPercentage(for courseId: String, totalLessons: Int) -> Double {
        guard let progress = courseProgress[courseId], totalLessons > 0 else { return 0 }
        return Double(progress.completedLessonIds.count) / Double(totalLessons) * 100
    }
    
    func getLastPosition(courseId: String, lessonId: String) -> TimeInterval {
        return courseProgress[courseId]?.lessonProgress[lessonId]?.lastPosition ?? 0
    }
    
    // MARK: - Streak Management
    
    private func recordDailyActivity() {
        let today = dateString(for: Date())
        let wasActiveToday = userStatistics.dailyActivity[today] ?? false
        
        if !wasActiveToday {
            userStatistics.dailyActivity[today] = true
            updateStreak()
        }
        
        userStatistics.lastActiveDate = Date()
    }
    
    private func updateStreak() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Check if yesterday was active
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: today) {
            let yesterdayString = dateString(for: yesterday)
            if userStatistics.dailyActivity[yesterdayString] == true {
                userStatistics.currentStreak += 1
            } else {
                // Check if streak should reset (more than 1 day gap)
                userStatistics.currentStreak = 1
            }
        } else {
            userStatistics.currentStreak = 1
        }
        
        // Update longest streak
        if userStatistics.currentStreak > userStatistics.longestStreak {
            userStatistics.longestStreak = userStatistics.currentStreak
        }
        
        checkAchievements()
    }
    
    private func dateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    private func updateWeeklyWatchTime(_ seconds: TimeInterval) {
        let calendar = Calendar.current
        let weekOfYear = calendar.component(.weekOfYear, from: Date())
        let year = calendar.component(.year, from: Date())
        let weekKey = "\(year)-W\(String(format: "%02d", weekOfYear))"
        
        userStatistics.weeklyWatchTime[weekKey, default: 0] += seconds
    }
    
    // MARK: - Points System
    
    private func addPoints(_ points: Int, reason: String) {
        userStatistics.totalPoints += points
        print("🏆 +\(points) Punkte: \(reason)")
    }
    
    // MARK: - Achievements
    
    private func initializeAchievements() {
        let allAchievements: [Achievement] = [
            Achievement(id: "first_lesson", type: .firstLesson, title: "Erster Schritt", description: "Schließe deine erste Lektion ab", icon: "star.fill", requiredValue: 1),
            Achievement(id: "first_course", type: .firstCourse, title: "Kurs-Absolvent", description: "Schließe deinen ersten Kurs ab", icon: "trophy.fill", requiredValue: 1),
            Achievement(id: "streak_3", type: .streak3, title: "Auf dem Weg", description: "3 Tage in Folge gelernt", icon: "flame.fill", requiredValue: 3),
            Achievement(id: "streak_7", type: .streak7, title: "Wochenkrieger", description: "7 Tage in Folge gelernt", icon: "flame.fill", requiredValue: 7),
            Achievement(id: "streak_30", type: .streak30, title: "Monatschampion", description: "30 Tage in Folge gelernt", icon: "flame.circle.fill", requiredValue: 30),
            Achievement(id: "lessons_10", type: .lessons10, title: "Fleißiger Schüler", description: "10 Lektionen abgeschlossen", icon: "book.fill", requiredValue: 10),
            Achievement(id: "lessons_50", type: .lessons50, title: "Wissensdurst", description: "50 Lektionen abgeschlossen", icon: "books.vertical.fill", requiredValue: 50),
            Achievement(id: "lessons_100", type: .lessons100, title: "Meisterschüler", description: "100 Lektionen abgeschlossen", icon: "graduationcap.fill", requiredValue: 100),
            Achievement(id: "hours_5", type: .hours5, title: "Zeitinvestor", description: "5 Stunden Lernzeit", icon: "clock.fill", requiredValue: 5),
            Achievement(id: "hours_25", type: .hours25, title: "Engagiert", description: "25 Stunden Lernzeit", icon: "clock.badge.checkmark.fill", requiredValue: 25),
            Achievement(id: "hours_100", type: .hours100, title: "Tanzmeister", description: "100 Stunden Lernzeit", icon: "crown.fill", requiredValue: 100),
            Achievement(id: "courses_3", type: .courses3, title: "Vielseitig", description: "3 Kurse abgeschlossen", icon: "square.stack.3d.up.fill", requiredValue: 3),
            Achievement(id: "courses_10", type: .courses10, title: "Kurs-Sammler", description: "10 Kurse abgeschlossen", icon: "rectangle.stack.fill", requiredValue: 10),
            Achievement(id: "night_owl", type: .nightOwl, title: "Nachteule", description: "Nach 22 Uhr gelernt", icon: "moon.stars.fill", requiredValue: 1),
            Achievement(id: "early_bird", type: .earlyBird, title: "Frühaufsteher", description: "Vor 7 Uhr gelernt", icon: "sunrise.fill", requiredValue: 1),
            Achievement(id: "weekend_warrior", type: .weekendWarrior, title: "Wochenend-Held", description: "Am Wochenende gelernt", icon: "calendar.badge.clock", requiredValue: 1),
            Achievement(id: "perfect_week", type: .perfectWeek, title: "Perfekte Woche", description: "7 Tage in einer Woche aktiv", icon: "checkmark.seal.fill", requiredValue: 7),
            Achievement(id: "speed_learner", type: .speedLearner, title: "Schnelllerner", description: "Kurs in unter 7 Tagen abgeschlossen", icon: "hare.fill", requiredValue: 1)
        ]
        
        // Load saved achievements or use defaults
        if let data = UserDefaults.standard.data(forKey: achievementsKey),
           let saved = try? JSONDecoder().decode([Achievement].self, from: data) {
            achievements = saved
        } else {
            achievements = allAchievements
        }
    }
    
    private func checkAchievements() {
        let hour = Calendar.current.component(.hour, from: Date())
        let weekday = Calendar.current.component(.weekday, from: Date())
        
        for i in achievements.indices {
            guard !achievements[i].isUnlocked else { continue }
            
            var shouldUnlock = false
            
            switch achievements[i].type {
            case .firstLesson:
                shouldUnlock = userStatistics.totalLessonsCompleted >= 1
            case .firstCourse:
                shouldUnlock = userStatistics.totalCoursesCompleted >= 1
            case .streak3:
                shouldUnlock = userStatistics.currentStreak >= 3
            case .streak7:
                shouldUnlock = userStatistics.currentStreak >= 7
            case .streak30:
                shouldUnlock = userStatistics.currentStreak >= 30
            case .lessons10:
                shouldUnlock = userStatistics.totalLessonsCompleted >= 10
            case .lessons50:
                shouldUnlock = userStatistics.totalLessonsCompleted >= 50
            case .lessons100:
                shouldUnlock = userStatistics.totalLessonsCompleted >= 100
            case .hours5:
                shouldUnlock = userStatistics.totalWatchTime >= 5 * 3600
            case .hours25:
                shouldUnlock = userStatistics.totalWatchTime >= 25 * 3600
            case .hours100:
                shouldUnlock = userStatistics.totalWatchTime >= 100 * 3600
            case .courses3:
                shouldUnlock = userStatistics.totalCoursesCompleted >= 3
            case .courses10:
                shouldUnlock = userStatistics.totalCoursesCompleted >= 10
            case .nightOwl:
                shouldUnlock = hour >= 22
            case .earlyBird:
                shouldUnlock = hour < 7
            case .weekendWarrior:
                shouldUnlock = weekday == 1 || weekday == 7
            case .perfectWeek, .allStyles, .speedLearner:
                break // Complex checks done elsewhere
            }
            
            if shouldUnlock {
                unlockAchievement(at: i)
            }
        }
    }
    
    private func unlockAchievement(at index: Int) {
        achievements[index].unlockedAt = Date()
        recentlyUnlockedAchievement = achievements[index]
        addPoints(25, reason: "Achievement: \(achievements[index].title)")
        
        // Show notification
        Task {
            await PushNotificationService.shared.sendLocalNotification(
                title: "🏆 Achievement freigeschaltet!",
                body: achievements[index].title
            )
        }
        
        saveAndSync()
    }
    
    // MARK: - Learning Goals
    
    func setDailyGoal(minutes: Int) {
        let goal = LearningGoal(
            id: UUID().uuidString,
            type: .dailyMinutes,
            targetValue: minutes,
            currentValue: 0,
            startDate: Date(),
            endDate: nil,
            isActive: true
        )
        
        // Remove existing daily goal
        learningGoals.removeAll { $0.type == .dailyMinutes }
        learningGoals.append(goal)
        saveAndSync()
    }
    
    func updateGoalProgress() {
        let todayMinutes = Int(getTodayWatchTime() / 60)
        
        for i in learningGoals.indices {
            if learningGoals[i].type == .dailyMinutes && learningGoals[i].isActive {
                learningGoals[i].currentValue = todayMinutes
            }
        }
        
        saveAndSync()
    }
    
    func getTodayWatchTime() -> TimeInterval {
        // This would need actual tracking per day - simplified for now
        return userStatistics.totalWatchTime // Placeholder
    }
    
    // MARK: - Persistence
    
    private func loadLocalData() {
        // Load progress
        if let data = UserDefaults.standard.data(forKey: progressKey),
           let progress = try? JSONDecoder().decode([String: LearningCourseProgress].self, from: data) {
            courseProgress = progress
        }
        
        // Load statistics
        if let data = UserDefaults.standard.data(forKey: statisticsKey),
           let stats = try? JSONDecoder().decode(UserStatistics.self, from: data) {
            userStatistics = stats
        }
        
        // Load goals
        if let data = UserDefaults.standard.data(forKey: goalsKey),
           let goals = try? JSONDecoder().decode([LearningGoal].self, from: data) {
            learningGoals = goals
        }
    }
    
    private func saveLocal() {
        if let data = try? JSONEncoder().encode(courseProgress) {
            UserDefaults.standard.set(data, forKey: progressKey)
        }
        if let data = try? JSONEncoder().encode(userStatistics) {
            UserDefaults.standard.set(data, forKey: statisticsKey)
        }
        if let data = try? JSONEncoder().encode(achievements) {
            UserDefaults.standard.set(data, forKey: achievementsKey)
        }
        if let data = try? JSONEncoder().encode(learningGoals) {
            UserDefaults.standard.set(data, forKey: goalsKey)
        }
    }
    
    private func saveAndSync() {
        saveLocal()
        Task { await saveToCloud() }
    }
    
    func loadFromCloud() async {
        // Load from Firebase if needed
    }
    
    private func saveToCloud() async {
        // Save to Firebase if needed
    }
}
