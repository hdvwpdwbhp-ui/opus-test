//
//  TrainerWalletModels.swift
//  Tanzen mit Tatiana Drexler
//
//  Trainer-Wallet System - Separates Coin-Wallet für Trainer-Einnahmen aus Kursverkäufen
//  WICHTIG: Dieses Wallet ist komplett getrennt vom normalen User-Wallet
//

import Foundation

// MARK: - Trainer Wallet
/// Separates Wallet für Trainer-Einnahmen aus Kursverkäufen
/// Coins können nur durch Kursverkäufe hinzugefügt werden (keine anderen Quellen)
struct TrainerWallet: Codable, Identifiable {
    var id: String // = TrainerId
    var balance: Int
    var totalEarned: Int
    var totalWithdrawn: Int
    var createdAt: Date
    var updatedAt: Date
    
    init(trainerId: String) {
        self.id = trainerId
        self.balance = 0
        self.totalEarned = 0
        self.totalWithdrawn = 0
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    /// Berechnet den Euro-Wert des Wallets
    var balanceInEUR: Decimal {
        Decimal(balance) * DanceCoinConfig.coinValueEUR
    }
    
    var formattedBalance: String {
        "\(balance) DC"
    }
    
    var formattedBalanceEUR: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.string(from: balanceInEUR as NSDecimalNumber) ?? "€0,00"
    }
}

// MARK: - Trainer Wallet Transaction
/// Immutable Transaktions-Log für Trainer-Wallet
/// Jede Transaktion wird in Firebase gespeichert und kann nicht gelöscht werden
struct TrainerWalletTransaction: Codable, Identifiable {
    let id: String
    let trainerId: String
    let type: TrainerWalletTransactionType
    let amount: Int // positiv = Eingang, negativ = Auszahlung
    let courseId: String? // Bei Kursverkäufen
    let courseName: String? // Kursname für Anzeige
    let userId: String? // User der den Kurs gekauft hat
    let userName: String? // Username für Anzeige
    let percentageApplied: Int? // Welcher Prozentsatz wurde angewendet
    let originalCoins: Int? // Originale Coins die der User bezahlt hat
    let description: String
    let balanceAfter: Int
    let createdAt: Date
    let verifiedByAdmin: Bool // Admin hat die Transaktion verifiziert
    let adminNote: String? // Optionale Admin-Notiz
    
    init(
        trainerId: String,
        type: TrainerWalletTransactionType,
        amount: Int,
        courseId: String? = nil,
        courseName: String? = nil,
        userId: String? = nil,
        userName: String? = nil,
        percentageApplied: Int? = nil,
        originalCoins: Int? = nil,
        description: String,
        balanceAfter: Int,
        verifiedByAdmin: Bool = false,
        adminNote: String? = nil
    ) {
        self.id = UUID().uuidString
        self.trainerId = trainerId
        self.type = type
        self.amount = amount
        self.courseId = courseId
        self.courseName = courseName
        self.userId = userId
        self.userName = userName
        self.percentageApplied = percentageApplied
        self.originalCoins = originalCoins
        self.description = description
        self.balanceAfter = balanceAfter
        self.createdAt = Date()
        self.verifiedByAdmin = verifiedByAdmin
        self.adminNote = adminNote
    }
    
    var isPositive: Bool { amount > 0 }
    
    var formattedAmount: String {
        isPositive ? "+\(amount) DC" : "\(amount) DC"
    }
    
    var formattedAmountEUR: String {
        let value = Decimal(abs(amount)) * DanceCoinConfig.coinValueEUR
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "de_DE")
        let formatted = formatter.string(from: value as NSDecimalNumber) ?? "€0,00"
        return isPositive ? "+\(formatted)" : "-\(formatted)"
    }
    
    var icon: String {
        type.icon
    }
}

// MARK: - Transaction Type
enum TrainerWalletTransactionType: String, Codable, CaseIterable {
    case courseSale = "course_sale"           // Einnahmen aus Kursverkauf
    case adminAdjustment = "admin_adjustment" // Admin-Korrektur (positiv oder negativ)
    case withdrawal = "withdrawal"             // Auszahlung (wird extern abgewickelt)
    
    var defaultDescription: String {
        switch self {
        case .courseSale: return "Einnahmen aus Kursverkauf"
        case .adminAdjustment: return "Admin-Korrektur"
        case .withdrawal: return "Auszahlung beantragt"
        }
    }
    
    var icon: String {
        switch self {
        case .courseSale: return "play.rectangle.fill"
        case .adminAdjustment: return "person.badge.shield.checkmark"
        case .withdrawal: return "arrow.up.circle.fill"
        }
    }
}

// MARK: - Trainer Course Commission Settings
/// Einstellungen für den Trainer-Anteil pro Kurs
/// Wird vom Admin festgelegt
/// MEHRERE TRAINER pro Kurs möglich
struct TrainerCourseCommission: Codable, Identifiable {
    var id: String // Unique ID (courseId_trainerId)
    var courseId: String
    var trainerId: String
    var commissionPercent: Int // 0-100
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date
    var createdBy: String // AdminId
    var lastUpdatedBy: String // AdminId
    var notes: String? // Admin-Notizen
    
    init(courseId: String, trainerId: String, commissionPercent: Int, createdBy: String) {
        self.id = "\(courseId)_\(trainerId)" // Unique ID für Kurs+Trainer Kombination
        self.courseId = courseId
        self.trainerId = trainerId
        self.commissionPercent = min(100, max(0, commissionPercent)) // Clamp 0-100
        self.isActive = true
        self.createdAt = Date()
        self.updatedAt = Date()
        self.createdBy = createdBy
        self.lastUpdatedBy = createdBy
        self.notes = nil
    }
    
    /// Berechnet die Trainer-Coins basierend auf dem Kaufpreis
    func calculateTrainerCoins(from userPaidCoins: Int) -> Int {
        guard isActive && commissionPercent > 0 else { return 0 }
        return Int(Double(userPaidCoins) * Double(commissionPercent) / 100.0)
    }
}

// MARK: - Trainer Stats Summary
/// Zusammenfassung der Trainer-Statistiken (für Dashboard)
struct TrainerStatsSummary: Codable {
    let trainerId: String
    let totalPrivateLessonHours: Double
    let totalPrivateLessonCount: Int
    let completedPrivateLessonCount: Int
    let pendingPrivateLessonCount: Int
    let walletBalance: Int
    let walletBalanceEUR: Decimal
    let totalCourseSales: Int
    let totalCourseCoinsEarned: Int
    let periodStart: Date
    let periodEnd: Date
    
    var formattedHours: String {
        String(format: "%.1f Std.", totalPrivateLessonHours)
    }
    
    var formattedWalletBalance: String {
        "\(walletBalance) DC"
    }
    
    var formattedWalletBalanceEUR: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.string(from: walletBalanceEUR as NSDecimalNumber) ?? "€0,00"
    }
}

// MARK: - Withdrawal Request
/// Auszahlungsantrag (für spätere Implementierung)
struct TrainerWithdrawalRequest: Codable, Identifiable {
    let id: String
    let trainerId: String
    let requestedAmount: Int // in Coins
    let requestedAmountEUR: Decimal
    var status: WithdrawalStatus
    let createdAt: Date
    var processedAt: Date?
    var processedBy: String? // AdminId
    var adminNote: String?
    let paymentMethod: String? // z.B. "PayPal", "Banküberweisung"
    let paymentDetails: String? // z.B. PayPal-Email oder IBAN (verschlüsselt)
    
    enum WithdrawalStatus: String, Codable {
        case pending = "pending"
        case approved = "approved"
        case rejected = "rejected"
        case completed = "completed"
        case cancelled = "cancelled"
    }
    
    init(trainerId: String, amount: Int, paymentMethod: String?, paymentDetails: String?) {
        self.id = UUID().uuidString
        self.trainerId = trainerId
        self.requestedAmount = amount
        self.requestedAmountEUR = Decimal(amount) * DanceCoinConfig.coinValueEUR
        self.status = .pending
        self.createdAt = Date()
        self.processedAt = nil
        self.processedBy = nil
        self.adminNote = nil
        self.paymentMethod = paymentMethod
        self.paymentDetails = paymentDetails
    }
}
