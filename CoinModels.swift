//
//  CoinModels.swift
//  Tanzen mit Tatiana Drexler
//
//  DanceCoins System - Virtuelle Währung für Kursfreischaltungen
//

import Foundation

// MARK: - DanceCoin Konfiguration
struct DanceCoinConfig {
    /// Wert eines Coins in Euro
    static let coinValueEUR: Decimal = 0.50

    /// Cashback Prozentsatz bei Kurskaeufen
    static let courseCashbackPercent: Decimal = 0.05

    /// Täglicher Login-Bonus
    static let dailyLoginBonus: Int = 1
    
    /// Coin-Pakete für In-App-Käufe
    static let coinPackages: [CoinPackage] = [
        CoinPackage(id: "coins_10", coins: 10, priceEUR: 4.99, bonusCoins: 0, storeProductId: "com.tanzen.coins.coins_10"),
        CoinPackage(id: "coins_24", coins: 24, priceEUR: 11.99, bonusCoins: 2, storeProductId: "com.tanzen.coins.coins_25"),
        CoinPackage(id: "coins_60", coins: 60, priceEUR: 29.99, bonusCoins: 10, storeProductId: "com.tanzen.coins.coins_50"),
        CoinPackage(id: "coins_100", coins: 100, priceEUR: 49.99, bonusCoins: 10, storeProductId: "com.tanzen.coins.coins_100"),
        CoinPackage(id: "coins_160", coins: 160, priceEUR: 79.99, bonusCoins: 30, storeProductId: "com.tanzen.coins.coins_160"),
        CoinPackage(id: "coins_200", coins: 200, priceEUR: 99.99, bonusCoins: 50, storeProductId: "com.tanzen.coins.coins_250")
    ]
    
    /// Berechnet wie viele Coins für einen Kurs benötigt werden
    static func coinsForPrice(_ price: Decimal) -> Int {
        let coins = price / coinValueEUR
        return Int(NSDecimalNumber(decimal: coins).doubleValue.rounded(.up))
    }

    /// Berechnet Cashback-Coins fuer einen Kurskauf
    static func cashbackCoins(for price: Decimal) -> Int {
        let cashbackValue = price * courseCashbackPercent
        let coins = cashbackValue / coinValueEUR
        return Int(NSDecimalNumber(decimal: coins).doubleValue.rounded(.down))
    }
}

// MARK: - Coin Package (für In-App-Käufe)
struct CoinPackage: Identifiable, Codable {
    let id: String
    let coins: Int
    let priceEUR: Decimal
    let bonusCoins: Int
    let storeProductId: String?
    
    var totalCoins: Int { coins + bonusCoins }
    
    var formattedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.string(from: priceEUR as NSDecimalNumber) ?? "€\(priceEUR)"
    }
    
    var productId: String { storeProductId ?? "com.tanzen.coins.\(id)" }
}

// MARK: - User Coin Wallet
struct CoinWallet: Codable, Identifiable {
    var id: String // = UserId
    var balance: Int
    var totalEarned: Int
    var totalSpent: Int
    var lastDailyBonusDate: Date?
    var transactions: [CoinTransaction]
    var createdAt: Date
    var updatedAt: Date
    
    init(userId: String) {
        self.id = userId
        self.balance = 0
        self.totalEarned = 0
        self.totalSpent = 0
        self.lastDailyBonusDate = nil
        self.transactions = []
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    /// Prüft ob der tägliche Bonus bereits abgeholt wurde
    var canClaimDailyBonus: Bool {
        guard let lastDate = lastDailyBonusDate else { return true }
        return !Calendar.current.isDateInToday(lastDate)
    }
    
    /// Prüft ob genug Coins vorhanden sind
    func hasEnoughCoins(_ amount: Int) -> Bool {
        balance >= amount
    }
    
    /// Fügt Coins hinzu
    mutating func addCoins(_ amount: Int, reason: CoinTransactionType, description: String? = nil) {
        balance += amount
        totalEarned += amount
        updatedAt = Date()
        
        let transaction = CoinTransaction(
            type: reason,
            amount: amount,
            description: description ?? reason.defaultDescription,
            balanceAfter: balance
        )
        transactions.insert(transaction, at: 0)
        
        // Nur die letzten 100 Transaktionen behalten
        if transactions.count > 100 {
            transactions = Array(transactions.prefix(100))
        }
    }
    
    /// Zieht Coins ab
    mutating func spendCoins(_ amount: Int, reason: CoinTransactionType, description: String? = nil) -> Bool {
        guard hasEnoughCoins(amount) else { return false }
        
        balance -= amount
        totalSpent += amount
        updatedAt = Date()
        
        let transaction = CoinTransaction(
            type: reason,
            amount: -amount,
            description: description ?? reason.defaultDescription,
            balanceAfter: balance
        )
        transactions.insert(transaction, at: 0)
        
        if transactions.count > 100 {
            transactions = Array(transactions.prefix(100))
        }
        
        return true
    }
    
    /// Täglichen Bonus abholen
    mutating func claimDailyBonus() -> Bool {
        guard canClaimDailyBonus else { return false }
        
        addCoins(DanceCoinConfig.dailyLoginBonus, reason: .dailyBonus)
        lastDailyBonusDate = Date()
        return true
    }
}

// MARK: - Coin Transaction
struct CoinTransaction: Codable, Identifiable {
    let id: String
    let type: CoinTransactionType
    let amount: Int // positiv = erhalten, negativ = ausgegeben
    let description: String
    let balanceAfter: Int
    let createdAt: Date
    
    init(type: CoinTransactionType, amount: Int, description: String, balanceAfter: Int) {
        self.id = UUID().uuidString
        self.type = type
        self.amount = amount
        self.description = description
        self.balanceAfter = balanceAfter
        self.createdAt = Date()
    }
    
    var isPositive: Bool { amount > 0 }
    
    var formattedAmount: String {
        isPositive ? "+\(amount)" : "\(amount)"
    }
    
    var icon: String {
        type.icon
    }
    
    var color: String {
        isPositive ? "green" : "red"
    }
}

// MARK: - Transaction Type
enum CoinTransactionType: String, Codable, CaseIterable {
    case purchase = "purchase"           // In-App-Kauf
    case dailyBonus = "daily_bonus"      // Täglicher Login-Bonus
    case adminGrant = "admin_grant"      // Admin hat Coins gegeben
    case adminRemove = "admin_remove"    // Admin hat Coins entfernt
    case keyRedemption = "key_redemption" // Per Einlöse-Code
    case courseUnlock = "course_unlock"  // Kurs freigeschaltet
    case refund = "refund"               // Erstattung
    case promotion = "promotion"         // Werbeaktion
    case referral = "referral"           // Empfehlungsbonus
    case cashback = "cashback"           // 5% Cashback bei Kurskauf
    case liveClassBookingCharge = "liveclass_booking_charge" // Livestream-Gruppenstunde
    case liveClassBookingRefund = "liveclass_booking_refund"  // Erstattung Livestream
    case trainingPlanCharge = "training_plan_charge"         // Trainingsplan gekauft
    case trainingPlanRefund = "training_plan_refund"         // Trainingsplan erstattet
    case videoReviewCharge = "video_review_charge"           // Video-Review bezahlt
    case videoReviewRefund = "video_review_refund"           // Video-Review erstattet
 
     var defaultDescription: String {
         switch self {
         case .purchase: return "Coin-Paket gekauft"
         case .dailyBonus: return "Täglicher Login-Bonus"
         case .adminGrant: return "Von Admin gutgeschrieben"
         case .adminRemove: return "Von Admin entfernt"
         case .keyRedemption: return "Einlöse-Code verwendet"
         case .courseUnlock: return "Kurs freigeschaltet"
         case .refund: return "Erstattung"
         case .promotion: return "Werbeaktion"
         case .referral: return "Empfehlungsbonus"
         case .cashback: return "Cashback erhalten"
         case .liveClassBookingCharge: return "Livestream-Gruppenstunde gebucht"
         case .liveClassBookingRefund: return "Livestream-Gruppenstunde erstattet"
         case .trainingPlanCharge: return "Trainingsplan gekauft"
         case .trainingPlanRefund: return "Trainingsplan erstattet"
         case .videoReviewCharge: return "Video-Review bezahlt"
         case .videoReviewRefund: return "Video-Review erstattet"
         }
     }

    var icon: String {
        switch self {
        case .purchase: return "creditcard.fill"
        case .dailyBonus: return "gift.fill"
        case .adminGrant: return "person.badge.plus"
        case .adminRemove: return "person.badge.minus"
        case .keyRedemption: return "key.fill"
        case .courseUnlock: return "play.rectangle.fill"
        case .refund: return "arrow.uturn.backward.circle.fill"
        case .promotion: return "star.fill"
        case .referral: return "person.2.fill"
        case .cashback: return "percent"
        case .liveClassBookingCharge: return "dot.radiowaves.left.and.right"
        case .liveClassBookingRefund: return "arrow.uturn.backward.circle"
        case .trainingPlanCharge: return "doc.text.fill"
        case .trainingPlanRefund: return "arrow.uturn.backward.circle"
        case .videoReviewCharge: return "video.fill"
        case .videoReviewRefund: return "arrow.uturn.backward.circle"
        }
    }
}

// MARK: - Coin Redemption Key
struct CoinRedemptionKey: Codable, Identifiable {
    let id: String
    let code: String
    let coinAmount: Int
    var isUsed: Bool
    var usedBy: String?
    var usedAt: Date?
    let createdAt: Date
    let createdBy: String
    let expiresAt: Date?
    let maxUses: Int
    var currentUses: Int
    
    var isValid: Bool {
        if isUsed && maxUses == 1 { return false }
        if currentUses >= maxUses { return false }
        if let expires = expiresAt, expires < Date() { return false }
        return true
    }
    
    static func create(code: String, coinAmount: Int, createdBy: String, maxUses: Int = 1, expiresIn: TimeInterval? = nil) -> CoinRedemptionKey {
        CoinRedemptionKey(
            id: UUID().uuidString,
            code: code.uppercased(),
            coinAmount: coinAmount,
            isUsed: false,
            usedBy: nil,
            usedAt: nil,
            createdAt: Date(),
            createdBy: createdBy,
            expiresAt: expiresIn.map { Date().addingTimeInterval($0) },
            maxUses: maxUses,
            currentUses: 0
        )
    }
}

// MARK: - Coin Ledger (immutables Journal)
struct CoinLedgerEntry: Codable, Identifiable {
    let id: String
    let userId: String
    let type: CoinTransactionType
    let amount: Int
    let referenceId: String
    let createdAt: Date
    let note: String

    static func create(userId: String, type: CoinTransactionType, amount: Int, referenceId: String, note: String) -> CoinLedgerEntry {
        CoinLedgerEntry(
            id: UUID().uuidString,
            userId: userId,
            type: type,
            amount: amount,
            referenceId: referenceId,
            createdAt: Date(),
            note: note
        )
    }
}
