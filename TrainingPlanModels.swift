//
//  TrainingPlanModels.swift
//  Tanzen mit Tatiana Drexler
//
//  Created on 09.02.2026.
//

import Foundation

// MARK: - Training Plan Order

/// Bestellung eines personalisierten Trainingsplans
struct TrainingPlanOrder: Identifiable, Codable {
    let id: String
    let orderNumber: String
    let userId: String
    let userName: String
    let userEmail: String
    let trainerId: String
    let trainerName: String
    
    // Formular-Daten
    let formData: TrainingPlanFormData
    
    // Bestellung
    let planType: TrainingPlanType
    let price: Double
    let coinAmount: Int
    let status: TrainingPlanOrderStatus
    
    // Zeitstempel
    let createdAt: Date
    var paidAt: Date?
    var deliveredAt: Date?
    
    // In-App-Kauf
    var transactionId: String?
    var productId: String?

    var formattedCoinAmount: String {
        "\(coinAmount) Coins"
    }
    
    // Der erstellte Plan (nach Lieferung)
    var deliveredPlan: DeliveredTrainingPlan?
    
    // Kommunikation
    var trainerNotes: String?
    var userFeedback: String?
    var rating: Int?
    
    init(
        id: String = UUID().uuidString,
        userId: String,
        userName: String,
        userEmail: String,
        trainerId: String,
        trainerName: String,
        formData: TrainingPlanFormData,
        planType: TrainingPlanType,
        price: Double,
        coinAmount: Int
    ) {
        self.id = id
        self.orderNumber = TrainingPlanOrder.generateOrderNumber()
        self.userId = userId
        self.userName = userName
        self.userEmail = userEmail
        self.trainerId = trainerId
        self.trainerName = trainerName
        self.formData = formData
        self.planType = planType
        self.price = price
        self.coinAmount = coinAmount
        self.status = .paid // Status auf bezahlt setzen, da Coins direkt abgezogen werden
        self.createdAt = Date()
        self.paidAt = Date() // Bezahlt-Zeitpunkt setzen
    }
    
    static func generateOrderNumber() -> String {
        let year = Calendar.current.component(.year, from: Date())
        let random = Int.random(in: 10000...99999)
        return "TP-\(year)-\(random)"
    }

    enum CodingKeys: String, CodingKey {
        case id, orderNumber, userId, userName, userEmail, trainerId, trainerName
        case formData, planType, price, coinAmount, status
        case createdAt, paidAt, deliveredAt
        case transactionId, productId
        case deliveredPlan, trainerNotes, userFeedback, rating
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        orderNumber = try container.decode(String.self, forKey: .orderNumber)
        userId = try container.decode(String.self, forKey: .userId)
        userName = try container.decode(String.self, forKey: .userName)
        userEmail = try container.decode(String.self, forKey: .userEmail)
        trainerId = try container.decode(String.self, forKey: .trainerId)
        trainerName = try container.decode(String.self, forKey: .trainerName)
        formData = try container.decode(TrainingPlanFormData.self, forKey: .formData)
        planType = try container.decode(TrainingPlanType.self, forKey: .planType)
        price = try container.decode(Double.self, forKey: .price)
        coinAmount = try container.decodeIfPresent(Int.self, forKey: .coinAmount) ?? DanceCoinConfig.coinsForPrice(Decimal(price))
        status = try container.decode(TrainingPlanOrderStatus.self, forKey: .status)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        paidAt = try container.decodeIfPresent(Date.self, forKey: .paidAt)
        deliveredAt = try container.decodeIfPresent(Date.self, forKey: .deliveredAt)
        transactionId = try container.decodeIfPresent(String.self, forKey: .transactionId)
        productId = try container.decodeIfPresent(String.self, forKey: .productId)
        deliveredPlan = try container.decodeIfPresent(DeliveredTrainingPlan.self, forKey: .deliveredPlan)
        trainerNotes = try container.decodeIfPresent(String.self, forKey: .trainerNotes)
        userFeedback = try container.decodeIfPresent(String.self, forKey: .userFeedback)
        rating = try container.decodeIfPresent(Int.self, forKey: .rating)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(orderNumber, forKey: .orderNumber)
        try container.encode(userId, forKey: .userId)
        try container.encode(userName, forKey: .userName)
        try container.encode(userEmail, forKey: .userEmail)
        try container.encode(trainerId, forKey: .trainerId)
        try container.encode(trainerName, forKey: .trainerName)
        try container.encode(formData, forKey: .formData)
        try container.encode(planType, forKey: .planType)
        try container.encode(price, forKey: .price)
        try container.encode(coinAmount, forKey: .coinAmount)
        try container.encode(status, forKey: .status)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(paidAt, forKey: .paidAt)
        try container.encodeIfPresent(deliveredAt, forKey: .deliveredAt)
        try container.encodeIfPresent(transactionId, forKey: .transactionId)
        try container.encodeIfPresent(productId, forKey: .productId)
        try container.encodeIfPresent(deliveredPlan, forKey: .deliveredPlan)
        try container.encodeIfPresent(trainerNotes, forKey: .trainerNotes)
        try container.encodeIfPresent(userFeedback, forKey: .userFeedback)
        try container.encodeIfPresent(rating, forKey: .rating)
    }
}

// MARK: - Plan Types

enum TrainingPlanType: String, Codable, CaseIterable {
    case basic = "basic"           // 2 Wochen
    case standard = "standard"     // 4 Wochen
    case premium = "premium"       // 8 Wochen
    case intensive = "intensive"   // 12 Wochen
    
    var displayName: String {
        switch self {
        case .basic: return "Basic Plan"
        case .standard: return "Standard Plan"
        case .premium: return "Premium Plan"
        case .intensive: return "Intensiv Plan"
        }
    }
    
    var durationWeeks: Int {
        switch self {
        case .basic: return 2
        case .standard: return 4
        case .premium: return 8
        case .intensive: return 12
        }
    }
    
    var description: String {
        switch self {
        case .basic:
            return "Perfekt zum Reinschnuppern. 2 Wochen personalisierter Plan mit Grundlagen."
        case .standard:
            return "Der beliebteste Plan. 4 Wochen strukturiertes Training für messbare Fortschritte."
        case .premium:
            return "Für ambitionierte Tänzer. 8 Wochen intensives Programm mit regelmäßigen Updates."
        case .intensive:
            return "Das Rundum-Paket. 12 Wochen Transformation mit persönlicher Betreuung."
        }
    }
    
    var productId: String {
        return "com.TanzenmitTatianaDrexler.trainingplan.\(self.rawValue)"
    }
    
    var features: [String] {
        switch self {
        case .basic:
            return [
                "2 Wochen Trainingsplan",
                "3 Übungen pro Woche",
                "Video-Anleitungen",
                "PDF zum Download"
            ]
        case .standard:
            return [
                "4 Wochen Trainingsplan",
                "4 Übungen pro Woche",
                "Video-Anleitungen",
                "PDF zum Download",
                "1x Feedback vom Trainer",
                "Fortschrittstracking"
            ]
        case .premium:
            return [
                "8 Wochen Trainingsplan",
                "5 Übungen pro Woche",
                "Video-Anleitungen",
                "PDF zum Download",
                "3x Feedback vom Trainer",
                "Fortschrittstracking",
                "Musik-Empfehlungen"
            ]
        case .intensive:
            return [
                "12 Wochen Trainingsplan",
                "6 Übungen pro Woche",
                "Video-Anleitungen",
                "PDF zum Download",
                "Wöchentliches Feedback",
                "Fortschrittstracking",
                "Musik-Empfehlungen",
                "1 gratis Privatstunde"
            ]
        }
    }
}

// MARK: - Order Status

enum TrainingPlanOrderStatus: String, Codable, CaseIterable {
    case pendingPayment = "pending_payment"     // Wartet auf Zahlung
    case paid = "paid"                          // Bezahlt, wartet auf Bearbeitung
    case inProgress = "in_progress"             // Trainer arbeitet daran
    case readyForReview = "ready_for_review"    // Fertig, wartet auf Freigabe
    case delivered = "delivered"                // An Kunde geliefert
    case completed = "completed"                // Abgeschlossen mit Feedback
    case refunded = "refunded"                  // Erstattet
    case cancelled = "cancelled"                // Storniert
    
    var displayName: String {
        switch self {
        case .pendingPayment: return "Zahlung ausstehend"
        case .paid: return "Bezahlt"
        case .inProgress: return "In Bearbeitung"
        case .readyForReview: return "Bereit zur Prüfung"
        case .delivered: return "Geliefert"
        case .completed: return "Abgeschlossen"
        case .refunded: return "Erstattet"
        case .cancelled: return "Storniert"
        }
    }
    
    var icon: String {
        switch self {
        case .pendingPayment: return "clock"
        case .paid: return "checkmark.circle"
        case .inProgress: return "hammer"
        case .readyForReview: return "eye"
        case .delivered: return "paperplane.fill"
        case .completed: return "star.fill"
        case .refunded: return "arrow.uturn.left"
        case .cancelled: return "xmark.circle"
        }
    }
    
    var color: String {
        switch self {
        case .pendingPayment: return "orange"
        case .paid: return "blue"
        case .inProgress: return "purple"
        case .readyForReview: return "indigo"
        case .delivered: return "green"
        case .completed: return "green"
        case .refunded: return "gray"
        case .cancelled: return "red"
        }
    }
}

// MARK: - Form Data

struct TrainingPlanFormData: Codable {
    // Persönliche Infos
    var age: Int
    var gender: Gender
    var height: Int // in cm
    var weight: Int // in kg
    
    // Tanzerfahrung
    var danceExperience: DanceExperience
    var currentDanceStyles: [String]
    var targetDanceStyles: [String]
    
    // Fitness Level
    var fitnessLevel: FitnessLevel
    var healthIssues: String?
    var injuries: String?
    
    // Ziele
    var primaryGoal: TrainingGoal
    var secondaryGoals: [TrainingGoal]
    var specificGoalDescription: String?
    
    // Verfügbarkeit
    var trainingDaysPerWeek: Int
    var minutesPerSession: Int
    var preferredTrainingTimes: [PreferredTime]
    var hasHomeSpace: Bool
    var hasEquipment: [Equipment]
    
    // Präferenzen
    var musicPreferences: [String]
    var learningStyle: LearningStyle
    var motivationFactors: [MotivationFactor]
    
    // Zusätzliche Infos
    var additionalNotes: String?
    
    init() {
        self.age = 30
        self.gender = .notSpecified
        self.height = 170
        self.weight = 70
        self.danceExperience = .beginner
        self.currentDanceStyles = []
        self.targetDanceStyles = []
        self.fitnessLevel = .moderate
        self.primaryGoal = .learnNewStyle
        self.secondaryGoals = []
        self.trainingDaysPerWeek = 3
        self.minutesPerSession = 30
        self.preferredTrainingTimes = [.evening]
        self.hasHomeSpace = true
        self.hasEquipment = []
        self.musicPreferences = []
        self.learningStyle = .visual
        self.motivationFactors = []
    }
}

enum Gender: String, Codable, CaseIterable {
    case male = "male"
    case female = "female"
    case diverse = "diverse"
    case notSpecified = "not_specified"
    
    var displayName: String {
        switch self {
        case .male: return "Männlich"
        case .female: return "Weiblich"
        case .diverse: return "Divers"
        case .notSpecified: return "Keine Angabe"
        }
    }
}

enum DanceExperience: String, Codable, CaseIterable {
    case none = "none"
    case beginner = "beginner"
    case intermediate = "intermediate"
    case advanced = "advanced"
    case professional = "professional"
    
    var displayName: String {
        switch self {
        case .none: return "Keine Erfahrung"
        case .beginner: return "Anfänger (< 1 Jahr)"
        case .intermediate: return "Fortgeschritten (1-3 Jahre)"
        case .advanced: return "Erfahren (3-5 Jahre)"
        case .professional: return "Profi (> 5 Jahre)"
        }
    }
}

enum FitnessLevel: String, Codable, CaseIterable {
    case low = "low"
    case moderate = "moderate"
    case good = "good"
    case athletic = "athletic"
    
    var displayName: String {
        switch self {
        case .low: return "Niedrig"
        case .moderate: return "Mittel"
        case .good: return "Gut"
        case .athletic: return "Sportlich"
        }
    }
}

enum TrainingGoal: String, Codable, CaseIterable {
    case learnNewStyle = "learn_new_style"
    case improveExisting = "improve_existing"
    case competition = "competition"
    case fitness = "fitness"
    case flexibility = "flexibility"
    case performance = "performance"
    case socialDancing = "social_dancing"
    case wedding = "wedding"
    
    var displayName: String {
        switch self {
        case .learnNewStyle: return "Neuen Tanzstil lernen"
        case .improveExisting: return "Bestehende Fähigkeiten verbessern"
        case .competition: return "Wettkampf-Vorbereitung"
        case .fitness: return "Fitness & Ausdauer"
        case .flexibility: return "Beweglichkeit"
        case .performance: return "Auftritt/Show"
        case .socialDancing: return "Social Dancing"
        case .wedding: return "Hochzeitstanz"
        }
    }
    
    var icon: String {
        switch self {
        case .learnNewStyle: return "sparkles"
        case .improveExisting: return "arrow.up.circle"
        case .competition: return "trophy"
        case .fitness: return "heart.fill"
        case .flexibility: return "figure.flexibility"
        case .performance: return "star.fill"
        case .socialDancing: return "person.2.fill"
        case .wedding: return "heart.circle.fill"
        }
    }
}

enum PreferredTime: String, Codable, CaseIterable {
    case earlyMorning = "early_morning"
    case morning = "morning"
    case afternoon = "afternoon"
    case evening = "evening"
    case lateNight = "late_night"
    
    var displayName: String {
        switch self {
        case .earlyMorning: return "Früher Morgen (5-8 Uhr)"
        case .morning: return "Vormittag (8-12 Uhr)"
        case .afternoon: return "Nachmittag (12-17 Uhr)"
        case .evening: return "Abend (17-21 Uhr)"
        case .lateNight: return "Spät abends (21+ Uhr)"
        }
    }
}

enum Equipment: String, Codable, CaseIterable {
    case mirror = "mirror"
    case yogaMat = "yoga_mat"
    case resistanceBands = "resistance_bands"
    case weights = "weights"
    case danceShoes = "dance_shoes"
    case speaker = "speaker"
    
    var displayName: String {
        switch self {
        case .mirror: return "Spiegel"
        case .yogaMat: return "Yoga-Matte"
        case .resistanceBands: return "Widerstandsbänder"
        case .weights: return "Gewichte"
        case .danceShoes: return "Tanzschuhe"
        case .speaker: return "Lautsprecher"
        }
    }
}

enum LearningStyle: String, Codable, CaseIterable {
    case visual = "visual"
    case auditory = "auditory"
    case kinesthetic = "kinesthetic"
    case mixed = "mixed"
    
    var displayName: String {
        switch self {
        case .visual: return "Visuell (Videos anschauen)"
        case .auditory: return "Auditiv (Erklärungen hören)"
        case .kinesthetic: return "Praktisch (Learning by Doing)"
        case .mixed: return "Gemischt"
        }
    }
}

enum MotivationFactor: String, Codable, CaseIterable {
    case progress = "progress"
    case community = "community"
    case music = "music"
    case health = "health"
    case challenges = "challenges"
    case fun = "fun"
    
    var displayName: String {
        switch self {
        case .progress: return "Fortschritte sehen"
        case .community: return "Gemeinschaft"
        case .music: return "Musik & Rhythmus"
        case .health: return "Gesundheit"
        case .challenges: return "Herausforderungen"
        case .fun: return "Spaß & Freude"
        }
    }
}

// MARK: - Delivered Plan

struct DeliveredTrainingPlan: Codable {
    let id: String
    let createdAt: Date
    let weeks: [TrainingWeek]
    var pdfUrl: String?
    var additionalVideos: [String]?
    var musicPlaylist: String?
    var trainerMessage: String?
}

struct TrainingWeek: Codable, Identifiable {
    let id: String
    let weekNumber: Int
    let theme: String
    let days: [TrainingDay]
    var notes: String?
}

struct TrainingDay: Codable, Identifiable {
    let id: String
    let dayNumber: Int
    let title: String
    let exercises: [TrainingExercise]
    let totalDuration: Int // in Minuten
    var warmup: String?
    var cooldown: String?
}

struct TrainingExercise: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let duration: Int // in Minuten
    let repetitions: Int?
    let sets: Int?
    var videoUrl: String?
    var tips: String?
    let difficulty: ExerciseDifficulty
}

enum ExerciseDifficulty: String, Codable {
    case easy = "easy"
    case medium = "medium"
    case hard = "hard"
    
    var displayName: String {
        switch self {
        case .easy: return "Leicht"
        case .medium: return "Mittel"
        case .hard: return "Schwer"
        }
    }
    
    var color: String {
        switch self {
        case .easy: return "green"
        case .medium: return "orange"
        case .hard: return "red"
        }
    }
}

// MARK: - Trainer Settings Extension

struct TrainerPlanSettings: Codable {
    var offersTrainingPlans: Bool
    var availablePlanTypes: [TrainingPlanType]
    var specializations: [String]
    var maxActiveOrders: Int
    var averageDeliveryDays: Int
    var customIntroText: String?
    
    init() {
        self.offersTrainingPlans = false
        self.availablePlanTypes = [.basic, .standard]
        self.specializations = []
        self.maxActiveOrders = 5
        self.averageDeliveryDays = 7
    }
}

// MARK: - Admin Pricing

struct TrainingPlanPricing: Codable {
    var basicPrice: Double
    var standardPrice: Double
    var premiumPrice: Double
    var intensivePrice: Double
    var lastUpdated: Date
    var updatedBy: String
    
    init() {
        self.basicPrice = 29.99
        self.standardPrice = 49.99
        self.premiumPrice = 89.99
        self.intensivePrice = 149.99
        self.lastUpdated = Date()
        self.updatedBy = ""
    }
    
    func price(for type: TrainingPlanType) -> Double {
        switch type {
        case .basic: return basicPrice
        case .standard: return standardPrice
        case .premium: return premiumPrice
        case .intensive: return intensivePrice
        }
    }
}
