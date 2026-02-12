import Foundation

enum UserGroup: String, Codable, CaseIterable {
    case admin = "Admin"
    case support = "Support"
    case trainer = "Trainer"
    case premium = "Premium"
    case user = "User"
    var displayName: String { rawValue }
    var icon: String { switch self { case .admin: return "shield.fill"; case .support: return "headphones"; case .trainer: return "person.badge.shield.checkmark.fill"; case .premium: return "crown.fill"; case .user: return "person.fill" } }
    var isAdmin: Bool { self == .admin }
    var isSupport: Bool { self == .admin || self == .support }
    var isTrainer: Bool { self == .admin || self == .trainer }
    var hasPremiumAccess: Bool { self == .admin || self == .trainer || self == .premium }
}

struct AppUser: Codable, Identifiable, Equatable {
    let id: String; var name: String; var username: String; var email: String; var passwordHash: String; var group: UserGroup; var createdAt: Date; var lastLoginAt: Date?; var isActive: Bool; var profileImageURL: String?; var trainerProfile: TrainerProfile?; var premiumExpiresAt: Date?; var unlockedCourseIds: [String]?; var purchasedProductIds: [String]?; var firebaseUid: String?; var isEmailVerified: Bool; var marketingConsent: Bool
    var loginStreakCurrent: Int; var loginStreakLongest: Int; var lastLoginStreakDate: Date?
    static func generateId() -> String { "USR-\(Int(Date().timeIntervalSince1970))-\(Int.random(in: 1000...9999))" }
    static func create(name: String, username: String, email: String, password: String, group: UserGroup = .user, marketingConsent: Bool = false) -> AppUser { AppUser(id: generateId(), name: name, username: username.lowercased(), email: email.lowercased(), passwordHash: hashPassword(password), group: group, createdAt: Date(), lastLoginAt: nil, isActive: true, profileImageURL: nil, trainerProfile: group == .trainer ? TrainerProfile.empty() : nil, premiumExpiresAt: nil, unlockedCourseIds: [], purchasedProductIds: [], firebaseUid: nil, isEmailVerified: false, marketingConsent: marketingConsent, loginStreakCurrent: 0, loginStreakLongest: 0, lastLoginStreakDate: nil) }
    static func hashPassword(_ password: String) -> String { password.data(using: .utf8)!.base64EncodedString() }
    func verifyPassword(_ password: String) -> Bool { AppUser.hashPassword(password) == passwordHash }

    // CodingKeys für Kompatibilität mit älteren Daten ohne firebaseUid
    enum CodingKeys: String, CodingKey {
        case id, name, username, email, passwordHash, group, createdAt, lastLoginAt, isActive
        case profileImageURL, trainerProfile, premiumExpiresAt, unlockedCourseIds, purchasedProductIds
        case firebaseUid, isEmailVerified, marketingConsent
        case loginStreakCurrent, loginStreakLongest, lastLoginStreakDate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        username = try container.decode(String.self, forKey: .username)
        email = try container.decode(String.self, forKey: .email)
        passwordHash = try container.decode(String.self, forKey: .passwordHash)
        group = try container.decode(UserGroup.self, forKey: .group)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        lastLoginAt = try container.decodeIfPresent(Date.self, forKey: .lastLoginAt)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        profileImageURL = try container.decodeIfPresent(String.self, forKey: .profileImageURL)
        trainerProfile = try container.decodeIfPresent(TrainerProfile.self, forKey: .trainerProfile)
        premiumExpiresAt = try container.decodeIfPresent(Date.self, forKey: .premiumExpiresAt)
        unlockedCourseIds = try container.decodeIfPresent([String].self, forKey: .unlockedCourseIds)
        purchasedProductIds = try container.decodeIfPresent([String].self, forKey: .purchasedProductIds)
        firebaseUid = try container.decodeIfPresent(String.self, forKey: .firebaseUid)
        isEmailVerified = try container.decodeIfPresent(Bool.self, forKey: .isEmailVerified) ?? false
        marketingConsent = try container.decodeIfPresent(Bool.self, forKey: .marketingConsent) ?? false
        loginStreakCurrent = try container.decodeIfPresent(Int.self, forKey: .loginStreakCurrent) ?? 0
        loginStreakLongest = try container.decodeIfPresent(Int.self, forKey: .loginStreakLongest) ?? 0
        lastLoginStreakDate = try container.decodeIfPresent(Date.self, forKey: .lastLoginStreakDate)
    }

    init(id: String, name: String, username: String, email: String, passwordHash: String, group: UserGroup, createdAt: Date, lastLoginAt: Date?, isActive: Bool, profileImageURL: String? = nil, trainerProfile: TrainerProfile? = nil, premiumExpiresAt: Date? = nil, unlockedCourseIds: [String]? = nil, purchasedProductIds: [String]? = nil, firebaseUid: String? = nil, isEmailVerified: Bool = false, marketingConsent: Bool = false, loginStreakCurrent: Int = 0, loginStreakLongest: Int = 0, lastLoginStreakDate: Date? = nil) {
        self.id = id; self.name = name; self.username = username; self.email = email; self.passwordHash = passwordHash; self.group = group; self.createdAt = createdAt; self.lastLoginAt = lastLoginAt; self.isActive = isActive; self.profileImageURL = profileImageURL; self.trainerProfile = trainerProfile; self.premiumExpiresAt = premiumExpiresAt; self.unlockedCourseIds = unlockedCourseIds; self.purchasedProductIds = purchasedProductIds; self.firebaseUid = firebaseUid; self.isEmailVerified = isEmailVerified; self.marketingConsent = marketingConsent
        self.loginStreakCurrent = loginStreakCurrent; self.loginStreakLongest = loginStreakLongest; self.lastLoginStreakDate = lastLoginStreakDate
    }
}

struct TrainerProfile: Codable, Equatable {
    var bio: String
    var profileImageURL: String?
    var assignedCourseIds: [String]
    var specialties: [String]
    var socialLinks: [String: String]
    var revenueSharePercent: Int
    var totalEarnings: Decimal
    var paymentInfo: PaymentInfo?
    var teachingLanguages: [String]  // Sprachen in denen der Trainer unterrichten kann (z.B. ["de", "en", "ru"])
    var introVideoURL: String?  // Vorstellungsvideo des Trainers
    
    static func empty() -> TrainerProfile {
        TrainerProfile(
            bio: "",
            profileImageURL: nil,
            assignedCourseIds: [],
            specialties: [],
            socialLinks: [:],
            revenueSharePercent: 30,
            totalEarnings: 0,
            paymentInfo: nil,
            teachingLanguages: ["de"],  // Standard: Deutsch
            introVideoURL: nil
        )
    }
    
    // CodingKeys für Kompatibilität mit alten Daten
    enum CodingKeys: String, CodingKey {
        case bio, profileImageURL, assignedCourseIds, specialties, socialLinks
        case revenueSharePercent, totalEarnings, paymentInfo, teachingLanguages
        case introVideoURL
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bio = try container.decodeIfPresent(String.self, forKey: .bio) ?? ""
        profileImageURL = try container.decodeIfPresent(String.self, forKey: .profileImageURL)
        assignedCourseIds = try container.decodeIfPresent([String].self, forKey: .assignedCourseIds) ?? []
        specialties = try container.decodeIfPresent([String].self, forKey: .specialties) ?? []
        socialLinks = try container.decodeIfPresent([String: String].self, forKey: .socialLinks) ?? [:]
        revenueSharePercent = try container.decodeIfPresent(Int.self, forKey: .revenueSharePercent) ?? 30
        totalEarnings = try container.decodeIfPresent(Decimal.self, forKey: .totalEarnings) ?? 0
        paymentInfo = try container.decodeIfPresent(PaymentInfo.self, forKey: .paymentInfo)
        teachingLanguages = try container.decodeIfPresent([String].self, forKey: .teachingLanguages) ?? ["de"]
        introVideoURL = try container.decodeIfPresent(String.self, forKey: .introVideoURL)
    }
    
    init(bio: String, profileImageURL: String?, assignedCourseIds: [String], specialties: [String], socialLinks: [String: String], revenueSharePercent: Int, totalEarnings: Decimal, paymentInfo: PaymentInfo?, teachingLanguages: [String] = ["de"], introVideoURL: String? = nil) {
        self.bio = bio
        self.profileImageURL = profileImageURL
        self.assignedCourseIds = assignedCourseIds
        self.specialties = specialties
        self.socialLinks = socialLinks
        self.revenueSharePercent = revenueSharePercent
        self.totalEarnings = totalEarnings
        self.paymentInfo = paymentInfo
        self.teachingLanguages = teachingLanguages
        self.introVideoURL = introVideoURL
    }
}

struct PaymentInfo: Codable, Equatable { var paypalEmail: String?; var iban: String?; var bankName: String?; var accountHolder: String? }

struct SupportMessage: Codable, Identifiable {
    let id: String; let conversationId: String; let senderId: String; let senderName: String; let senderGroup: UserGroup; let content: String; let timestamp: Date; var isRead: Bool
    static func create(conversationId: String, senderId: String, senderName: String, senderGroup: UserGroup, content: String) -> SupportMessage { SupportMessage(id: UUID().uuidString, conversationId: conversationId, senderId: senderId, senderName: senderName, senderGroup: senderGroup, content: content, timestamp: Date(), isRead: false) }
}

struct SupportConversation: Codable, Identifiable {
    let id: String; let userId: String; let userName: String; let userEmail: String; var subject: String; var status: ConversationStatus; var createdAt: Date; var lastMessageAt: Date; var assignedAdminId: String?
    enum ConversationStatus: String, Codable, CaseIterable { case open = "Offen"; case inProgress = "In Bearbeitung"; case resolved = "Gelöst"; case closed = "Geschlossen"
        var icon: String { switch self { case .open: return "envelope.open"; case .inProgress: return "clock"; case .resolved: return "checkmark.circle"; case .closed: return "xmark.circle" } } }
    static func create(userId: String, userName: String, userEmail: String, subject: String) -> SupportConversation { SupportConversation(id: UUID().uuidString, userId: userId, userName: userName, userEmail: userEmail, subject: subject, status: .open, createdAt: Date(), lastMessageAt: Date(), assignedAdminId: nil) }
}

struct SupportChange: Codable, Identifiable {
    let id: String; let supportUserId: String; let supportUserName: String; let targetUserId: String; let targetUserName: String; let changeType: ChangeType; let description: String; let oldValue: String?; let newValue: String?; let timestamp: Date; var isReverted: Bool; var revertedBy: String?; var revertedAt: Date?
    enum ChangeType: String, Codable { case courseUnlocked = "Kurs freigeschaltet"; case courseLocked = "Kurs gesperrt"; case userEdited = "User bearbeitet"; case premiumGranted = "Premium gewährt"; case premiumRevoked = "Premium entzogen"; case other = "Sonstiges" }
    static func create(supportUserId: String, supportUserName: String, targetUserId: String, targetUserName: String, changeType: ChangeType, description: String, oldValue: String? = nil, newValue: String? = nil) -> SupportChange { SupportChange(id: UUID().uuidString, supportUserId: supportUserId, supportUserName: supportUserName, targetUserId: targetUserId, targetUserName: targetUserName, changeType: changeType, description: description, oldValue: oldValue, newValue: newValue, timestamp: Date(), isReverted: false, revertedBy: nil, revertedAt: nil) }
}

struct TrainerEditRequest: Codable, Identifiable {
    let id: String; let trainerId: String; let trainerName: String; let courseId: String; let courseName: String; let fieldName: String; let oldValue: String; let newValue: String; let requestedAt: Date; var status: RequestStatus; var reviewedBy: String?; var reviewedAt: Date?; var reviewNote: String?
    enum RequestStatus: String, Codable { case pending = "Ausstehend"; case approved = "Genehmigt"; case rejected = "Abgelehnt" }
    static func create(trainerId: String, trainerName: String, courseId: String, courseName: String, fieldName: String, oldValue: String, newValue: String) -> TrainerEditRequest { TrainerEditRequest(id: UUID().uuidString, trainerId: trainerId, trainerName: trainerName, courseId: courseId, courseName: courseName, fieldName: fieldName, oldValue: oldValue, newValue: newValue, requestedAt: Date(), status: .pending, reviewedBy: nil, reviewedAt: nil, reviewNote: nil) }
}

struct AppSettings: Codable {
    var freeCourseIds: [String]
    var freeLessonIds: [String]
    var activeSales: [CourseSale]
    var legalDocuments: LegalDocuments
    var lastUpdated: Date
    
    // Admin Benachrichtigungen
    var adminPurchaseNotificationsEnabled: Bool
    var adminEmail: String?  // E-Mail für Kaufbenachrichtigungen
    
    static func defaultSettings() -> AppSettings {
        AppSettings(
            freeCourseIds: [],
            freeLessonIds: [],
            activeSales: [],
            legalDocuments: LegalDocuments.defaultDocuments(),
            lastUpdated: Date(),
            adminPurchaseNotificationsEnabled: true,
            adminEmail: nil
        )
    }
}

struct CourseSale: Codable, Identifiable {
    let id: String; var courseIds: [String]; var discountPercent: Int; var title: String; var description: String; var startDate: Date; var endDate: Date; var isActive: Bool; var notifiedUserIds: [String]
    var isCurrentlyActive: Bool { let now = Date(); return isActive && now >= startDate && now <= endDate }
    static func create(courseIds: [String], discountPercent: Int, title: String, description: String, startDate: Date, endDate: Date) -> CourseSale { CourseSale(id: UUID().uuidString, courseIds: courseIds, discountPercent: discountPercent, title: title, description: description, startDate: startDate, endDate: endDate, isActive: true, notifiedUserIds: []) }
}

struct LegalDocuments: Codable { var privacyPolicy: String; var termsOfService: String; var impressum: String; var lastUpdated: Date; static func defaultDocuments() -> LegalDocuments { LegalDocuments(privacyPolicy: "Datenschutz", termsOfService: "AGB", impressum: "Impressum", lastUpdated: Date()) } }

struct PrivateLessonBooking: Codable, Identifiable {
    let id: String
    let bookingNumber: String  // Lesbare Buchungsnummer z.B. "PL-2026-00001"
    let trainerId: String
    let trainerName: String
    let userId: String
    let userName: String
    let userEmail: String
    var status: BookingStatus
    var requestedDate: Date
    var confirmedDate: Date?
    var duration: Int
    var price: Decimal
    var notes: String
    var messages: [PrivateLessonMessage]
    let createdAt: Date
    var updatedAt: Date
    
    // Payment-Informationen
    var paymentStatus: PaymentStatus
    var paypalOrderId: String?
    var paypalTransactionId: String?
    var paymentLink: String?
    var paymentDeadline: Date?
    var paidAt: Date?
    
    // Trainer Revenue
    var trainerRevenue: Decimal?  // Trainer-Anteil nach Abzug von Gebühren
    var platformFee: Decimal?     // Plattform-Gebühr
    
    enum BookingStatus: String, Codable {
        case pending = "Angefragt"
        case confirmed = "Bestätigt"
        case awaitingPayment = "Warte auf Zahlung"
        case paid = "Bezahlt"
        case completed = "Abgeschlossen"
        case cancelled = "Abgesagt"
        case rejected = "Abgelehnt"
        case expired = "Abgelaufen"
    }
    
    /// Generiert eine lesbare Buchungsnummer
    static func generateBookingNumber() -> String {
        let year = Calendar.current.component(.year, from: Date())
        let random = String(format: "%05d", Int.random(in: 1...99999))
        return "PL-\(year)-\(random)"
    }
    
    static func create(trainerId: String, trainerName: String, userId: String, userName: String, userEmail: String, requestedDate: Date, duration: Int, price: Decimal, notes: String) -> PrivateLessonBooking {
        // Bei PayPal-Zahlung geht 100% an den Trainer (keine Plattform-Gebühr)
        return PrivateLessonBooking(
            id: UUID().uuidString,
            bookingNumber: generateBookingNumber(),
            trainerId: trainerId,
            trainerName: trainerName,
            userId: userId,
            userName: userName,
            userEmail: userEmail,
            status: .pending,
            requestedDate: requestedDate,
            confirmedDate: nil,
            duration: duration,
            price: price,
            notes: notes,
            messages: [],
            createdAt: Date(),
            updatedAt: Date(),
            paymentStatus: .pending,
            paypalOrderId: nil,
            paypalTransactionId: nil,
            paymentLink: nil,
            paymentDeadline: nil,
            paidAt: nil,
            trainerRevenue: price,  // 100% für Trainer
            platformFee: 0          // Keine Plattform-Gebühr bei PayPal
        )
    }
    
    /// Beschreibung für PayPal-Zahlung
    var paypalDescription: String {
        "Privatstunde \(bookingNumber) - \(trainerName) (\(duration) Min)"
    }
    
    /// Berechnet die Zahlungsfrist (24 Stunden vor Termin)
    var calculatedPaymentDeadline: Date? {
        guard let confirmedDate = confirmedDate else { return nil }
        return confirmedDate.addingTimeInterval(-24 * 60 * 60)
    }
    
    /// Prüft ob die Zahlungsfrist abgelaufen ist
    var isPaymentExpired: Bool {
        guard let deadline = paymentDeadline ?? calculatedPaymentDeadline else { return false }
        return Date() > deadline && paymentStatus != .completed
    }
    
    /// Prüft ob Zahlung noch möglich ist
    var canPay: Bool {
        return (status == .confirmed || status == .awaitingPayment) &&
               paymentStatus == .awaitingPayment &&
               !isPaymentExpired
    }
    
    // CodingKeys für Kompatibilität mit alten Daten
    enum CodingKeys: String, CodingKey {
        case id, bookingNumber, trainerId, trainerName, userId, userName, userEmail
        case status, requestedDate, confirmedDate, duration, price, notes, messages
        case createdAt, updatedAt, paymentStatus, paypalOrderId, paypalTransactionId
        case paymentLink, paymentDeadline, paidAt, trainerRevenue, platformFee
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        // Fallback für alte Daten ohne bookingNumber
        bookingNumber = try container.decodeIfPresent(String.self, forKey: .bookingNumber) ?? "PL-\(Int(Date().timeIntervalSince1970))"
        trainerId = try container.decode(String.self, forKey: .trainerId)
        trainerName = try container.decode(String.self, forKey: .trainerName)
        userId = try container.decode(String.self, forKey: .userId)
        userName = try container.decode(String.self, forKey: .userName)
        userEmail = try container.decodeIfPresent(String.self, forKey: .userEmail) ?? ""
        status = try container.decode(BookingStatus.self, forKey: .status)
        requestedDate = try container.decode(Date.self, forKey: .requestedDate)
        confirmedDate = try container.decodeIfPresent(Date.self, forKey: .confirmedDate)
        duration = try container.decode(Int.self, forKey: .duration)
        price = try container.decode(Decimal.self, forKey: .price)
        notes = try container.decode(String.self, forKey: .notes)
        messages = try container.decodeIfPresent([PrivateLessonMessage].self, forKey: .messages) ?? []
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        paymentStatus = try container.decodeIfPresent(PaymentStatus.self, forKey: .paymentStatus) ?? .pending
        paypalOrderId = try container.decodeIfPresent(String.self, forKey: .paypalOrderId)
        paypalTransactionId = try container.decodeIfPresent(String.self, forKey: .paypalTransactionId)
        paymentLink = try container.decodeIfPresent(String.self, forKey: .paymentLink)
        paymentDeadline = try container.decodeIfPresent(Date.self, forKey: .paymentDeadline)
        paidAt = try container.decodeIfPresent(Date.self, forKey: .paidAt)
        trainerRevenue = try container.decodeIfPresent(Decimal.self, forKey: .trainerRevenue)
        platformFee = try container.decodeIfPresent(Decimal.self, forKey: .platformFee)
    }
    
    init(id: String, bookingNumber: String, trainerId: String, trainerName: String, userId: String, userName: String, userEmail: String, status: BookingStatus, requestedDate: Date, confirmedDate: Date?, duration: Int, price: Decimal, notes: String, messages: [PrivateLessonMessage], createdAt: Date, updatedAt: Date, paymentStatus: PaymentStatus, paypalOrderId: String?, paypalTransactionId: String?, paymentLink: String?, paymentDeadline: Date?, paidAt: Date?, trainerRevenue: Decimal?, platformFee: Decimal?) {
        self.id = id; self.bookingNumber = bookingNumber; self.trainerId = trainerId; self.trainerName = trainerName; self.userId = userId; self.userName = userName; self.userEmail = userEmail; self.status = status; self.requestedDate = requestedDate; self.confirmedDate = confirmedDate; self.duration = duration; self.price = price; self.notes = notes; self.messages = messages; self.createdAt = createdAt; self.updatedAt = updatedAt; self.paymentStatus = paymentStatus; self.paypalOrderId = paypalOrderId; self.paypalTransactionId = paypalTransactionId; self.paymentLink = paymentLink; self.paymentDeadline = paymentDeadline; self.paidAt = paidAt; self.trainerRevenue = trainerRevenue; self.platformFee = platformFee
    }
}

struct PrivateLessonMessage: Codable, Identifiable { let id: String; let senderId: String; let senderName: String; let content: String; let timestamp: Date; var isRead: Bool }
struct TrainerAvailability: Codable, Identifiable { let id: String; let trainerId: String; var dayOfWeek: Int; var startTime: String; var endTime: String; var pricePerHour: Decimal; var isAvailable: Bool }
struct PrivateLessonSettings: Codable { var trainerId: String; var isEnabled: Bool; var pricePerHour: Decimal; var minDuration: Int; var maxDuration: Int; var availabilities: [TrainerAvailability]; var description: String }

struct VideoComment: Codable, Identifiable {
    let id: String; let lessonId: String; let courseId: String; let userId: String; let userName: String; let userGroup: UserGroup; var content: String; let createdAt: Date; var updatedAt: Date; var editedAt: Date?; var isDeleted: Bool; var isHidden: Bool; var hiddenReason: String?; var hiddenBy: String?; var replyToId: String?; var likes: Int; var likedByUserIds: [String]
    static func create(lessonId: String, courseId: String, userId: String, userName: String, userGroup: UserGroup, content: String, replyToId: String? = nil) -> VideoComment { VideoComment(id: UUID().uuidString, lessonId: lessonId, courseId: courseId, userId: userId, userName: userName, userGroup: userGroup, content: content, createdAt: Date(), updatedAt: Date(), editedAt: nil, isDeleted: false, isHidden: false, hiddenReason: nil, hiddenBy: nil, replyToId: replyToId, likes: 0, likedByUserIds: []) }
}

/// Firebase-kompatibles Comment Model
struct CourseComment: Codable, Identifiable {
    let id: String
    let lessonId: String
    let courseId: String
    let userId: String
    let userName: String
    let userGroup: UserGroup
    var content: String
    let createdAt: Date
    var editedAt: Date?
    var likes: Int
    var likedByUserIds: [String]
    var isHidden: Bool
    var hiddenReason: String?
    var hiddenBy: String?
}
