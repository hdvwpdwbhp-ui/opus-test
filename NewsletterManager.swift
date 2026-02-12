//
//  NewsletterManager.swift
//  Tanzen mit Tatiana Drexler
//
//  Newsletter, Push-Benachrichtigungen und Updates
//

import Foundation
import Combine
import UserNotifications

// MARK: - Notification Preferences
struct NotificationPreferences: Codable {
    var newCourses: Bool = true
    var weeklyTips: Bool = true
    var salesAndOffers: Bool = true
    var streakReminders: Bool = true
    var learningReminders: Bool = true
    var partnerRequests: Bool = true
    var lessonReminders: Bool = true
    var achievementUnlocked: Bool = true
    var reminderTime: Date = Calendar.current.date(from: DateComponents(hour: 18, minute: 0)) ?? Date()
    var reminderDays: Set<Int> = [2, 3, 4, 5, 6] // Mon-Fri
}

// MARK: - News Item
struct NewsItem: Codable, Identifiable {
    let id: String
    let title: String
    let body: String
    let type: NewsType
    let imageURL: String?
    let linkType: LinkType?
    let linkId: String?
    let createdAt: Date
    var isRead: Bool
    
    enum NewsType: String, Codable {
        case newCourse = "Neuer Kurs"
        case tip = "Tipp"
        case sale = "Angebot"
        case update = "Update"
        case event = "Event"
    }
    
    enum LinkType: String, Codable {
        case course, lesson, profile, url
    }
}

// MARK: - Newsletter Manager
@MainActor
class NewsletterManager: ObservableObject {
    static let shared = NewsletterManager()
    
    @Published var preferences = NotificationPreferences()
    @Published var newsItems: [NewsItem] = []
    @Published var unreadCount: Int = 0
    
    private let prefsKey = "notification_preferences"
    private let newsKey = "news_items"
    
    private init() {
        loadLocalData()
        loadSampleNews()
        calculateUnreadCount()
    }
    
    // MARK: - Preferences
    
    func updatePreferences(_ prefs: NotificationPreferences) {
        preferences = prefs
        saveLocal()
        
        // Update push notification settings
        if prefs.learningReminders {
            scheduleLearningReminders()
        } else {
            cancelLearningReminders()
        }
    }
    
    // MARK: - Learning Reminders
    
    private func scheduleLearningReminders() {
        let center = UNUserNotificationCenter.current()
        
        // Cancel existing reminders
        center.removePendingNotificationRequests(withIdentifiers: ["daily_reminder"])
        
        // Create new reminder
        let content = UNMutableNotificationContent()
        content.title = "🩰 Zeit zum Tanzen!"
        content.body = "Vergiss nicht zu üben. Nur 15 Minuten am Tag machen den Unterschied!"
        content.sound = .default
        
        // Get reminder time components
        let timeComponents = Calendar.current.dateComponents([.hour, .minute], from: preferences.reminderTime)
        
        // Schedule for each selected day
        for day in preferences.reminderDays {
            var dateComponents = DateComponents()
            dateComponents.weekday = day
            dateComponents.hour = timeComponents.hour
            dateComponents.minute = timeComponents.minute
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(
                identifier: "daily_reminder_\(day)",
                content: content,
                trigger: trigger
            )
            
            center.add(request)
        }
    }
    
    private func cancelLearningReminders() {
        let center = UNUserNotificationCenter.current()
        let ids = (1...7).map { "daily_reminder_\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }
    
    // MARK: - News Management
    
    func markAsRead(_ newsId: String) {
        if let index = newsItems.firstIndex(where: { $0.id == newsId }) {
            newsItems[index].isRead = true
            calculateUnreadCount()
            saveLocal()
        }
    }
    
    func markAllAsRead() {
        for i in newsItems.indices {
            newsItems[i].isRead = true
        }
        calculateUnreadCount()
        saveLocal()
    }
    
    private func calculateUnreadCount() {
        unreadCount = newsItems.filter { !$0.isRead }.count
    }
    
    // MARK: - Sample News
    
    private func loadSampleNews() {
        newsItems = [
            NewsItem(
                id: "news1",
                title: "🎉 Neuer Kurs: Bachata Sensual",
                body: "Lerne die sinnlichste Form der Bachata mit unserem neuen Kurs! 10 Lektionen vom Grundschritt bis zu fortgeschrittenen Figuren.",
                type: .newCourse,
                imageURL: nil,
                linkType: .course,
                linkId: "bachata_sensual",
                createdAt: Date().addingTimeInterval(-3600),
                isRead: false
            ),
            NewsItem(
                id: "news2",
                title: "💡 Tipp der Woche: Körperhaltung",
                body: "Eine gute Körperhaltung ist die Basis für jeden Tanz. Achte darauf, die Schultern zurück und den Kopf hoch zu halten.",
                type: .tip,
                imageURL: nil,
                linkType: nil,
                linkId: nil,
                createdAt: Date().addingTimeInterval(-86400),
                isRead: false
            ),
            NewsItem(
                id: "news3",
                title: "🔥 50% Rabatt auf Jahresabo!",
                body: "Nur noch diese Woche: Sichere dir das Jahresabo zum halben Preis und lerne unbegrenzt Tanzen!",
                type: .sale,
                imageURL: nil,
                linkType: .url,
                linkId: "subscription",
                createdAt: Date().addingTimeInterval(-172800),
                isRead: true
            ),
            NewsItem(
                id: "news4",
                title: "📱 App-Update 2.0",
                body: "Wir haben viele neue Features hinzugefügt: Übungsmodus mit Slow-Motion, Rangliste, Partner-Matching und mehr!",
                type: .update,
                imageURL: nil,
                linkType: nil,
                linkId: nil,
                createdAt: Date().addingTimeInterval(-259200),
                isRead: true
            )
        ]
    }
    
    // MARK: - Persistence
    
    private func loadLocalData() {
        if let data = UserDefaults.standard.data(forKey: prefsKey),
           let prefs = try? JSONDecoder().decode(NotificationPreferences.self, from: data) {
            preferences = prefs
        }
        
        if let data = UserDefaults.standard.data(forKey: newsKey),
           let items = try? JSONDecoder().decode([NewsItem].self, from: data) {
            newsItems = items
        }
    }
    
    private func saveLocal() {
        if let data = try? JSONEncoder().encode(preferences) {
            UserDefaults.standard.set(data, forKey: prefsKey)
        }
        if let data = try? JSONEncoder().encode(newsItems) {
            UserDefaults.standard.set(data, forKey: newsKey)
        }
    }
}
