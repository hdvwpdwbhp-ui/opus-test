//
//  FeedbackModels.swift
//  Tanzen mit Tatiana Drexler
//
//  User-Feedback System
//

import Foundation
import UIKit

// MARK: - User Feedback
struct UserFeedback: Codable, Identifiable {
    let id: String
    let userId: String
    let userName: String
    let userEmail: String
    let type: FeedbackType
    let rating: Int? // 1-5 Sterne (optional)
    let title: String
    let message: String
    let category: FeedbackCategory
    let appVersion: String
    let deviceInfo: String
    let screenshotURL: String?
    let status: FeedbackStatus
    var adminResponse: String?
    var adminRespondedAt: Date?
    var adminRespondedBy: String?
    let createdAt: Date
    var updatedAt: Date
    
    init(
        userId: String,
        userName: String,
        userEmail: String,
        type: FeedbackType,
        rating: Int? = nil,
        title: String,
        message: String,
        category: FeedbackCategory,
        screenshotURL: String? = nil
    ) {
        self.id = UUID().uuidString
        self.userId = userId
        self.userName = userName
        self.userEmail = userEmail
        self.type = type
        self.rating = rating
        self.title = title
        self.message = message
        self.category = category
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        self.deviceInfo = "\(UIDevice.current.model) - iOS \(UIDevice.current.systemVersion)"
        self.screenshotURL = screenshotURL
        self.status = .new
        self.adminResponse = nil
        self.adminRespondedAt = nil
        self.adminRespondedBy = nil
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Feedback Type
enum FeedbackType: String, Codable, CaseIterable {
    case bug = "bug"
    case feature = "feature"
    case improvement = "improvement"
    case praise = "praise"
    case complaint = "complaint"
    case question = "question"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .bug: return "Fehler melden"
        case .feature: return "Feature-Wunsch"
        case .improvement: return "Verbesserungsvorschlag"
        case .praise: return "Lob"
        case .complaint: return "Beschwerde"
        case .question: return "Frage"
        case .other: return "Sonstiges"
        }
    }
    
    var icon: String {
        switch self {
        case .bug: return "ladybug.fill"
        case .feature: return "star.fill"
        case .improvement: return "lightbulb.fill"
        case .praise: return "heart.fill"
        case .complaint: return "exclamationmark.triangle.fill"
        case .question: return "questionmark.circle.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .bug: return "red"
        case .feature: return "purple"
        case .improvement: return "blue"
        case .praise: return "green"
        case .complaint: return "orange"
        case .question: return "teal"
        case .other: return "gray"
        }
    }
}

// MARK: - Feedback Category
enum FeedbackCategory: String, Codable, CaseIterable {
    case courses = "courses"
    case payments = "payments"
    case account = "account"
    case liveClasses = "liveClasses"
    case privateLessons = "privateLessons"
    case trainingPlans = "trainingPlans"
    case app = "app"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .courses: return "Kurse"
        case .payments: return "Zahlungen & Coins"
        case .account: return "Account & Profil"
        case .liveClasses: return "Livestreams"
        case .privateLessons: return "Privatstunden"
        case .trainingPlans: return "Trainingspläne"
        case .app: return "App allgemein"
        case .other: return "Sonstiges"
        }
    }
}

// MARK: - Feedback Status
enum FeedbackStatus: String, Codable, CaseIterable {
    case new = "new"
    case inReview = "in_review"
    case responded = "responded"
    case resolved = "resolved"
    case closed = "closed"
    
    var displayName: String {
        switch self {
        case .new: return "Neu"
        case .inReview: return "In Bearbeitung"
        case .responded: return "Beantwortet"
        case .resolved: return "Gelöst"
        case .closed: return "Geschlossen"
        }
    }
    
    var color: String {
        switch self {
        case .new: return "blue"
        case .inReview: return "orange"
        case .responded: return "purple"
        case .resolved: return "green"
        case .closed: return "gray"
        }
    }
}

// MARK: - Feedback Statistics
struct FeedbackStatistics {
    let totalCount: Int
    let newCount: Int
    let inReviewCount: Int
    let respondedCount: Int
    let resolvedCount: Int
    let averageRating: Double
    let byType: [FeedbackType: Int]
    let byCategory: [FeedbackCategory: Int]
    
    static var empty: FeedbackStatistics {
        FeedbackStatistics(
            totalCount: 0,
            newCount: 0,
            inReviewCount: 0,
            respondedCount: 0,
            resolvedCount: 0,
            averageRating: 0,
            byType: [:],
            byCategory: [:]
        )
    }
}
