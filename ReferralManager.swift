//
//  ReferralManager.swift
//  Tanzen mit Tatiana Drexler
//
//  Referral-System: Freunde einladen und DanceCoins verdienen
//

import Foundation
import Combine
import FirebaseFirestore

// MARK: - Referral Models

struct Referral: Codable, Identifiable {
    let id: String
    let referrerId: String           // Wer hat eingeladen
    let referredUserId: String       // Wer wurde eingeladen
    let referredUserName: String
    let referredUserEmail: String
    let code: String                 // Verwendeter Code
    var status: ReferralStatus
    var coinsEarnedReferrer: Int     // Coins die der Einladende verdient hat
    var coinsEarnedReferred: Int     // Coins die der Eingeladene verdient hat
    let createdAt: Date
    var completedAt: Date?
    var firstPurchaseBonusPaid: Bool // Wurde der First-Purchase-Bonus bereits gezahlt?
    var firstPurchaseDate: Date?     // Wann war der erste Kauf?
    
    enum ReferralStatus: String, Codable {
        case pending = "pending"           // User registriert, aber nicht verifiziert
        case verified = "verified"         // Email verifiziert, Basis-Coins gezahlt
        case completed = "completed"       // First-Purchase-Bonus auch gezahlt
        case expired = "expired"           // Abgelaufen (30 Tage)
    }
    
    // Legacy support
    var coinsEarned: Int { coinsEarnedReferrer }
}

struct ReferralStats: Codable {
    var totalReferrals: Int
    var successfulReferrals: Int
    var pendingReferrals: Int
    var totalCoinsEarned: Int
    var firstPurchaseBonusCount: Int  // Wie viele First-Purchase-Boni wurden gezahlt
    
    static func empty() -> ReferralStats {
        ReferralStats(totalReferrals: 0, successfulReferrals: 0, pendingReferrals: 0, totalCoinsEarned: 0, firstPurchaseBonusCount: 0)
    }
}

// MARK: - Referral Configuration

struct ReferralConfig {
    /// Coins für den Einladenden wenn neuer User sich registriert und Email verifiziert
    static let referrerRewardOnSignup: Int = 3
    
    /// Coins für den eingeladenen User bei Registrierung
    static let referredRewardOnSignup: Int = 3
    
    /// Bonus wenn eingeladener User ERSTEN Kauf macht - für beide!
    static let firstPurchaseBonusReferrer: Int = 10
    static let firstPurchaseBonusReferred: Int = 10
    
    /// Maximale Referrals pro Monat
    static let maxReferralsPerMonth: Int = 20
    
    /// Gültigkeit eines Referral-Codes in Tagen
    static let codeValidityDays: Int = 30
}

// MARK: - Referral Manager

@MainActor
class ReferralManager: ObservableObject {
    static let shared = ReferralManager()
    
    @Published var myReferralCode: String = ""
    @Published var myReferrals: [Referral] = []
    @Published var stats: ReferralStats = .empty()
    @Published var isLoading = false
    @Published var usedReferralCode: String?
    
    private let db = Firestore.firestore()
    private let localCodeKey = "my_referral_code"
    private let usedCodeKey = "used_referral_code"
    
    private init() {
        loadLocalData()
    }
    
    // MARK: - Generate Referral Code
    
    /// Generiert oder lädt den Referral-Code des Users
    func getOrCreateReferralCode(for userId: String, userName: String) async -> String {
        // Prüfe ob bereits ein Code existiert
        if !myReferralCode.isEmpty {
            return myReferralCode
        }
        
        do {
            // Prüfe Firebase
            let doc = try await db.collection("referralCodes").document(userId).getDocument()
            if doc.exists, let code = doc.data()?["code"] as? String {
                myReferralCode = code
                saveLocalData()
                return code
            }
            
            // Erstelle neuen Code
            let code = generateCode(from: userName)
            try await db.collection("referralCodes").document(userId).setData([
                "code": code,
                "userId": userId,
                "userName": userName,
                "createdAt": Timestamp(date: Date()),
                "usageCount": 0,
                "isActive": true
            ])
            
            myReferralCode = code
            saveLocalData()
            return code
            
        } catch {
            print("❌ Fehler beim Erstellen des Referral-Codes: \(error)")
            return ""
        }
    }
    
    private func generateCode(from userName: String) -> String {
        let namePrefix = String(userName.uppercased().prefix(4).filter { $0.isLetter })
        let randomPart = String(format: "%04d", Int.random(in: 1000...9999))
        return "\(namePrefix)-\(randomPart)"
    }
    
    // MARK: - Use Referral Code
    
    /// Wendet einen Referral-Code beim Registrieren an
    func applyReferralCode(_ code: String, newUserId: String, newUserName: String, newUserEmail: String) async -> (success: Bool, message: String) {
        let normalizedCode = code.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Prüfe ob User bereits einen Code verwendet hat
        if usedReferralCode != nil {
            return (false, "Du hast bereits einen Einladungscode verwendet")
        }
        
        do {
            // Finde den Referrer
            let snapshot = try await db.collection("referralCodes")
                .whereField("code", isEqualTo: normalizedCode)
                .whereField("isActive", isEqualTo: true)
                .limit(to: 1)
                .getDocuments()
            
            guard let doc = snapshot.documents.first,
                  let referrerId = doc.data()["userId"] as? String else {
                return (false, "Ungültiger Einladungscode")
            }
            
            // Prüfe ob User sich nicht selbst einlädt
            if referrerId == newUserId {
                return (false, "Du kannst deinen eigenen Code nicht verwenden")
            }
            
            // Prüfe monatliches Limit
            let monthlyCount = await getMonthlyReferralCount(for: referrerId)
            if monthlyCount >= ReferralConfig.maxReferralsPerMonth {
                return (false, "Der Einladende hat sein monatliches Limit erreicht")
            }
            
            // Erstelle Referral-Eintrag
            let referralId = UUID().uuidString
            let referralData: [String: Any] = [
                "id": referralId,
                "referrerId": referrerId,
                "referredUserId": newUserId,
                "referredUserName": newUserName,
                "referredUserEmail": newUserEmail,
                "code": normalizedCode,
                "status": Referral.ReferralStatus.pending.rawValue,
                "coinsEarnedReferrer": 0,
                "coinsEarnedReferred": 0,
                "createdAt": Timestamp(date: Date()),
                "firstPurchaseBonusPaid": false
            ]
            
            try await db.collection("referrals").document(referralId).setData(referralData)
            
            // Speichere verwendeten Code
            usedReferralCode = normalizedCode
            saveLocalData()
            
            return (true, "Einladungscode akzeptiert! Du erhältst \(ReferralConfig.referredRewardOnSignup) DanceCoins nach der Email-Bestätigung und \(ReferralConfig.firstPurchaseBonusReferred) Bonus-Coins bei deinem ersten Kauf!")
            
        } catch {
            print("❌ Fehler beim Anwenden des Codes: \(error)")
            return (false, "Fehler: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Complete Referral (after email verification)
    
    /// Schließt das Referral ab und vergibt Basis-Coins (3 für beide)
    func completeReferralAfterVerification(userId: String) async {
        do {
            // Finde pending Referral für diesen User
            let snapshot = try await db.collection("referrals")
                .whereField("referredUserId", isEqualTo: userId)
                .whereField("status", isEqualTo: Referral.ReferralStatus.pending.rawValue)
                .limit(to: 1)
                .getDocuments()
            
            guard let doc = snapshot.documents.first else {
                return
            }
            
            let referralId = doc.documentID
            let referrerId = doc.data()["referrerId"] as? String ?? ""
            let referredUserName = doc.data()["referredUserName"] as? String ?? ""
            
            // Coins vergeben - BEIDE bekommen 3 Coins
            let coinManager = CoinManager.shared
            
            // Referrer bekommt 3 Coins
            _ = await coinManager.adminAddCoins(
                userId: referrerId,
                amount: ReferralConfig.referrerRewardOnSignup,
                reason: "Einladung: \(referredUserName) hat sich registriert"
            )
            
            // Referred User bekommt 3 Coins
            _ = await coinManager.addCoins(
                ReferralConfig.referredRewardOnSignup,
                reason: .referral,
                description: "Willkommensbonus für Einladung"
            )
            
            // Update Referral auf "verified"
            try await db.collection("referrals").document(referralId).updateData([
                "status": Referral.ReferralStatus.verified.rawValue,
                "completedAt": Timestamp(date: Date()),
                "coinsEarnedReferrer": ReferralConfig.referrerRewardOnSignup,
                "coinsEarnedReferred": ReferralConfig.referredRewardOnSignup
            ])
            
            // Update Usage Count
            if let codeDoc = try? await db.collection("referralCodes")
                .whereField("userId", isEqualTo: referrerId)
                .limit(to: 1)
                .getDocuments().documents.first {
                try await codeDoc.reference.updateData([
                    "usageCount": FieldValue.increment(Int64(1))
                ])
            }
            
            print("✅ Referral verifiziert: \(referredUserName) - 3 Coins für beide")
            
        } catch {
            print("❌ Fehler beim Abschließen des Referrals: \(error)")
        }
    }
    
    // MARK: - First Purchase Bonus
    
    /// Prüft und vergibt First-Purchase-Bonus (10 Coins für beide) - NUR beim ERSTEN Kauf
    func checkAndAwardFirstPurchaseBonus(userId: String) async {
        do {
            // Finde verified Referral für diesen User, bei dem noch kein First-Purchase-Bonus gezahlt wurde
            let snapshot = try await db.collection("referrals")
                .whereField("referredUserId", isEqualTo: userId)
                .whereField("status", isEqualTo: Referral.ReferralStatus.verified.rawValue)
                .whereField("firstPurchaseBonusPaid", isEqualTo: false)
                .limit(to: 1)
                .getDocuments()
            
            guard let doc = snapshot.documents.first else {
                // Kein Referral gefunden oder Bonus bereits gezahlt
                return
            }
            
            let referralId = doc.documentID
            let referrerId = doc.data()["referrerId"] as? String ?? ""
            let referredUserName = doc.data()["referredUserName"] as? String ?? ""
            
            let coinManager = CoinManager.shared
            
            // Referrer bekommt 10 Bonus-Coins
            _ = await coinManager.adminAddCoins(
                userId: referrerId,
                amount: ReferralConfig.firstPurchaseBonusReferrer,
                reason: "Bonus: \(referredUserName) hat ersten Kauf getätigt"
            )
            
            // Referred User bekommt 10 Bonus-Coins
            _ = await coinManager.addCoins(
                ReferralConfig.firstPurchaseBonusReferred,
                reason: .referral,
                description: "Bonus für deinen ersten Kauf!"
            )
            
            // Update Referral auf "completed" und markiere Bonus als gezahlt
            let previousReferrerCoins = doc.data()["coinsEarnedReferrer"] as? Int ?? 0
            let previousReferredCoins = doc.data()["coinsEarnedReferred"] as? Int ?? 0
            
            try await db.collection("referrals").document(referralId).updateData([
                "status": Referral.ReferralStatus.completed.rawValue,
                "firstPurchaseBonusPaid": true,
                "firstPurchaseDate": Timestamp(date: Date()),
                "coinsEarnedReferrer": previousReferrerCoins + ReferralConfig.firstPurchaseBonusReferrer,
                "coinsEarnedReferred": previousReferredCoins + ReferralConfig.firstPurchaseBonusReferred
            ])
            
            print("✅ First-Purchase-Bonus gezahlt: 10 Coins für \(referredUserName) und Einladenden")
            
        } catch {
            print("❌ Fehler beim First-Purchase-Bonus: \(error)")
        }
    }
    
    // MARK: - Load Referrals
    
    func loadMyReferrals(userId: String) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let snapshot = try await db.collection("referrals")
                .whereField("referrerId", isEqualTo: userId)
                .order(by: "createdAt", descending: true)
                .getDocuments()
            
            myReferrals = snapshot.documents.compactMap { doc -> Referral? in
                let data = doc.data()
                return Referral(
                    id: data["id"] as? String ?? doc.documentID,
                    referrerId: data["referrerId"] as? String ?? "",
                    referredUserId: data["referredUserId"] as? String ?? "",
                    referredUserName: data["referredUserName"] as? String ?? "",
                    referredUserEmail: data["referredUserEmail"] as? String ?? "",
                    code: data["code"] as? String ?? "",
                    status: Referral.ReferralStatus(rawValue: data["status"] as? String ?? "pending") ?? .pending,
                    coinsEarnedReferrer: data["coinsEarnedReferrer"] as? Int ?? data["coinsEarned"] as? Int ?? 0,
                    coinsEarnedReferred: data["coinsEarnedReferred"] as? Int ?? 0,
                    createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                    completedAt: (data["completedAt"] as? Timestamp)?.dateValue(),
                    firstPurchaseBonusPaid: data["firstPurchaseBonusPaid"] as? Bool ?? false,
                    firstPurchaseDate: (data["firstPurchaseDate"] as? Timestamp)?.dateValue()
                )
            }
            updateStats()
            
        } catch {
            print("❌ Fehler beim Laden der Referrals: \(error)")
        }
    }
    
    private func updateStats() {
        stats = ReferralStats(
            totalReferrals: myReferrals.count,
            successfulReferrals: myReferrals.filter { $0.status == .verified || $0.status == .completed }.count,
            pendingReferrals: myReferrals.filter { $0.status == .pending }.count,
            totalCoinsEarned: myReferrals.reduce(0) { $0 + $1.coinsEarnedReferrer },
            firstPurchaseBonusCount: myReferrals.filter { $0.firstPurchaseBonusPaid }.count
        )
    }
    
    private func getMonthlyReferralCount(for userId: String) async -> Int {
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))!
        
        do {
            let snapshot = try await db.collection("referrals")
                .whereField("referrerId", isEqualTo: userId)
                .whereField("createdAt", isGreaterThan: Timestamp(date: startOfMonth))
                .getDocuments()
            return snapshot.documents.count
        } catch {
            return 0
        }
    }
    
    // MARK: - Share Link
    
    func getShareText() -> String {
        guard !myReferralCode.isEmpty else { return "" }
        return """
        🕺 Lerne Tanzen mit Tatiana Drexler!
        
        Nutze meinen Einladungscode und erhalte \(ReferralConfig.referredRewardOnSignup) DanceCoins geschenkt - ich bekomme auch \(ReferralConfig.referrerRewardOnSignup)!
        
        Bei deinem ersten Kauf bekommen wir BEIDE nochmal \(ReferralConfig.firstPurchaseBonusReferred) Bonus-Coins! 🎁
        
        Code: \(myReferralCode)
        
        Lade die App herunter und gib den Code bei der Registrierung ein!
        """
    }
    
    // MARK: - Seed Example Codes (Admin-Funktion)
    
    /// Erstellt Beispiel-Einladungscodes in Firebase (nur einmal ausführen)
    func seedExampleReferralCodes() async {
        let exampleCodes: [(userId: String, userName: String, code: String)] = [
            ("seed_tatiana_001", "Tatiana", "TATI-2026"),
            ("seed_demo_002", "DemoUser", "DEMO-1234"),
            ("seed_vip_003", "VIPUser", "VIP-9999"),
            ("seed_welcome_004", "Welcome", "WELC-2026"),
            ("seed_dance_005", "DanceApp", "DANC-5000")
        ]
        
        for example in exampleCodes {
            do {
                // Prüfe ob Code schon existiert
                let existing = try await db.collection("referralCodes")
                    .whereField("code", isEqualTo: example.code)
                    .getDocuments()
                
                if existing.documents.isEmpty {
                    try await db.collection("referralCodes").document(example.userId).setData([
                        "code": example.code,
                        "userId": example.userId,
                        "userName": example.userName,
                        "createdAt": Timestamp(date: Date()),
                        "usageCount": 0,
                        "isActive": true,
                        "isExampleCode": true
                    ])
                    print("✅ Beispiel-Code erstellt: \(example.code)")
                }
            } catch {
                print("❌ Fehler beim Erstellen von \(example.code): \(error)")
            }
        }
    }
    
    // MARK: - Local Persistence
    
    private func loadLocalData() {
        myReferralCode = UserDefaults.standard.string(forKey: localCodeKey) ?? ""
        usedReferralCode = UserDefaults.standard.string(forKey: usedCodeKey)
    }
    
    private func saveLocalData() {
        UserDefaults.standard.set(myReferralCode, forKey: localCodeKey)
        if let code = usedReferralCode {
            UserDefaults.standard.set(code, forKey: usedCodeKey)
        }
    }
}
