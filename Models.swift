//
//  Models.swift
//  Tanzen mit Tatiana Drexler
//
//  Data Models for Courses, Lessons, and Users
//

import Foundation

// MARK: - Course Level
enum CourseLevel: String, Codable, CaseIterable, Identifiable {
    case beginner = "Anfänger"
    case intermediate = "Mittelstufe"
    case advanced = "Fortgeschritten"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .beginner: return "1.circle.fill"
        case .intermediate: return "2.circle.fill"
        case .advanced: return "3.circle.fill"
        }
    }
}

// MARK: - Course Language
enum CourseLanguage: String, Codable, CaseIterable, Identifiable {
    case german = "Deutsch"
    case english = "English"
    case russian = "Русский"
    case czech = "Čeština"
    case slovak = "Slovenčina"
    
    var id: String { rawValue }
    
    /// Flaggen-Emoji für die Sprache
    var flag: String {
        switch self {
        case .german: return "🇩🇪"
        case .english: return "🇬🇧"
        case .russian: return "🇷🇺"
        case .czech: return "🇨🇿"
        case .slovak: return "🇸🇰"
        }
    }
    
    /// ISO Sprachcode
    var languageCode: String {
        switch self {
        case .german: return "de"
        case .english: return "en"
        case .russian: return "ru"
        case .czech: return "cs"
        case .slovak: return "sk"
        }
    }
    
    /// Kurzform für Tags
    var shortName: String {
        switch self {
        case .german: return "DE"
        case .english: return "EN"
        case .russian: return "RU"
        case .czech: return "CZ"
        case .slovak: return "SK"
        }
    }
}

// MARK: - Dance Style
enum DanceStyle: String, Codable, CaseIterable, Identifiable {
    case waltz = "Walzer"
    case tango = "Tango"
    case foxtrot = "Foxtrott"
    case salsa = "Salsa"
    case bachata = "Bachata"
    case cha_cha = "Cha-Cha-Cha"
    case rumba = "Rumba"
    case jive = "Jive"
    case quickstep = "Quickstep"
    case viennese_waltz = "Wiener Walzer"
    case discofox = "Discofox"
    case latein = "Latein"
    case standard = "Standard"
    case other = "Sonstiges"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .waltz, .viennese_waltz: return "figure.dance"
        case .tango: return "figure.socialdance"
        case .salsa, .bachata: return "figure.dance"
        case .cha_cha, .rumba: return "figure.dance"
        case .jive, .quickstep: return "figure.run"
        case .foxtrot, .discofox: return "figure.dance"
        case .latein: return "figure.dance"
        case .standard: return "figure.socialdance"
        case .other: return "music.note"
        }
    }
}

// MARK: - Course Model
struct Course: Identifiable, Codable, Equatable {
    let id: String
    var title: String
    var description: String
    var level: CourseLevel
    var style: DanceStyle
    var coverURL: String
    var trailerURL: String
    var price: Decimal
    var productId: String
    var createdAt: Date
    var updatedAt: Date
    var lessonCount: Int
    var totalDuration: TimeInterval
    var trainerId: String? // Zugewiesener Trainer
    var trainerName: String? // Name des Trainers (für Anzeige)
    var language: CourseLanguage // Sprache des Kurses
    
    var formattedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.string(from: price as NSDecimalNumber) ?? "€\(price)"
    }
    
    var formattedDuration: String {
        let hours = Int(totalDuration) / 3600
        let minutes = (Int(totalDuration) % 3600) / 60
        if hours > 0 {
            return "\(hours) Std. \(minutes) Min."
        }
        return "\(minutes) Min."
    }
    
    static func == (lhs: Course, rhs: Course) -> Bool {
        lhs.id == rhs.id &&
        lhs.title == rhs.title &&
        lhs.description == rhs.description &&
        lhs.level == rhs.level &&
        lhs.style == rhs.style &&
        lhs.language == rhs.language &&
        lhs.price == rhs.price &&
        lhs.updatedAt == rhs.updatedAt
    }
    
    // CodingKeys für Abwärtskompatibilität (falls language fehlt)
    enum CodingKeys: String, CodingKey {
        case id, title, description, level, style, coverURL, trailerURL
        case price, productId, createdAt, updatedAt, lessonCount, totalDuration
        case trainerId, trainerName, language
    }
    
    init(id: String, title: String, description: String, level: CourseLevel, style: DanceStyle,
         coverURL: String, trailerURL: String, price: Decimal, productId: String,
         createdAt: Date, updatedAt: Date, lessonCount: Int, totalDuration: TimeInterval,
         trainerId: String? = nil, trainerName: String? = nil, language: CourseLanguage = .german) {
        self.id = id
        self.title = title
        self.description = description
        self.level = level
        self.style = style
        self.coverURL = coverURL
        self.trailerURL = trailerURL
        self.price = price
        self.productId = productId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lessonCount = lessonCount
        self.totalDuration = totalDuration
        self.trainerId = trainerId
        self.trainerName = trainerName
        self.language = language
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        level = try container.decode(CourseLevel.self, forKey: .level)
        style = try container.decode(DanceStyle.self, forKey: .style)
        coverURL = try container.decode(String.self, forKey: .coverURL)
        trailerURL = try container.decode(String.self, forKey: .trailerURL)
        price = try container.decode(Decimal.self, forKey: .price)
        productId = try container.decode(String.self, forKey: .productId)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        lessonCount = try container.decode(Int.self, forKey: .lessonCount)
        totalDuration = try container.decode(TimeInterval.self, forKey: .totalDuration)
        trainerId = try container.decodeIfPresent(String.self, forKey: .trainerId)
        trainerName = try container.decodeIfPresent(String.self, forKey: .trainerName)
        // Default zu German falls nicht vorhanden (Abwärtskompatibilität)
        language = try container.decodeIfPresent(CourseLanguage.self, forKey: .language) ?? .german
    }
}

// MARK: - Lesson Model
struct Lesson: Identifiable, Codable, Equatable {
    let id: String
    let courseId: String
    var title: String
    var orderIndex: Int
    var videoURL: String
    var duration: TimeInterval
    var notes: String?
    var isPreview: Bool
    
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    static func == (lhs: Lesson, rhs: Lesson) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - User Model
struct User: Identifiable, Codable {
    let id: String
    var name: String
    var email: String?
    var purchasedProductIds: Set<String>
    var favoritesCourseIds: Set<String>
    var lastSeenCourseId: String?
    var lastSeenLessonId: String?
    var isAdmin: Bool
    var createdAt: Date
    
    func hasPurchased(course: Course) -> Bool {
        purchasedProductIds.contains(course.productId)
    }
    
    func isFavorite(course: Course) -> Bool {
        favoritesCourseIds.contains(course.id)
    }
}

// MARK: - Course Progress
struct CourseProgress: Identifiable, Codable {
    let id: String
    let courseId: String
    let userId: String
    var completedLessonIds: Set<String>
    var currentLessonId: String?
    var currentPosition: TimeInterval
    var lastWatchedAt: Date
    
    var progressPercentage: Double {
        guard completedLessonIds.count > 0 else { return 0 }
        return Double(completedLessonIds.count)
    }
}

// MARK: - Filter Options
struct CourseFilter {
    var levels: Set<CourseLevel> = []
    var styles: Set<DanceStyle> = []
    var languages: Set<CourseLanguage> = [] // Sprach-Filter
    var showPurchasedOnly: Bool = false
    var showUnpurchasedOnly: Bool = false
    var searchText: String = ""
    
    var isActive: Bool {
        !levels.isEmpty || !styles.isEmpty || !languages.isEmpty || showPurchasedOnly || showUnpurchasedOnly || !searchText.isEmpty
    }
    
    func matches(course: Course, isPurchased: Bool) -> Bool {
        // Level filter
        if !levels.isEmpty && !levels.contains(course.level) {
            return false
        }
        
        // Style filter
        if !styles.isEmpty && !styles.contains(course.style) {
            return false
        }
        
        // Language filter
        if !languages.isEmpty && !languages.contains(course.language) {
            return false
        }
        
        // Purchase status filter
        if showPurchasedOnly && !isPurchased {
            return false
        }
        if showUnpurchasedOnly && isPurchased {
            return false
        }
        
        // Search text
        if !searchText.isEmpty {
            let searchLower = searchText.lowercased()
            let titleMatch = course.title.lowercased().contains(searchLower)
            let descMatch = course.description.lowercased().contains(searchLower)
            let styleMatch = course.style.rawValue.lowercased().contains(searchLower)
            let langMatch = course.language.rawValue.lowercased().contains(searchLower)
            if !titleMatch && !descMatch && !styleMatch && !langMatch {
                return false
            }
        }
        
        return true
    }
}
