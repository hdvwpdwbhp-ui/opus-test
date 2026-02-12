//
//  CoinManager.swift
//  Tanzen mit Tatiana Drexler
//
//  Verwaltet DanceCoins - Virtuelle Währung mit Cloud-Sync
//

import Foundation
import Combine
import FirebaseFirestore

@MainActor
class CoinManager: ObservableObject {
    static let shared = CoinManager()
    
    // MARK: - Published Properties
    @Published var wallet: CoinWallet?
    @Published var coinKeys: [CoinRedemptionKey] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Private
    private let db = Firestore.firestore()
    private var walletListener: ListenerRegistration?
    private let localWalletKey = "local_coin_wallet"
    
    // MARK: - Computed
    var balance: Int { wallet?.balance ?? 0 }
    var canClaimDailyBonus: Bool { wallet?.canClaimDailyBonus ?? false }
    
    private init() {
        loadLocalWallet()
    }
    
    // MARK: - Initialization
    func initialize(for userId: String) async {
        await loadWallet(userId: userId)
        startWalletListener(userId: userId)
    }
    
    func cleanup() {
        walletListener?.remove()
        walletListener = nil
    }
    
    // MARK: - Load Wallet
    func loadWallet(userId: String) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let doc = try await db.collection("coinWallets").document(userId).getDocument()
            
            if doc.exists, let data = try? doc.data(as: CoinWallet.self) {
                self.wallet = data
                saveLocalWallet()
                print("✅ Coin-Wallet geladen: \(data.balance) DanceCoins")
            } else {
                // Neues Wallet erstellen
                let newWallet = CoinWallet(userId: userId)
                try db.collection("coinWallets").document(userId).setData(from: newWallet)
                self.wallet = newWallet
                saveLocalWallet()
                print("✅ Neues Coin-Wallet erstellt")
            }
        } catch {
            print("❌ Fehler beim Laden des Wallets: \(error)")
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Realtime Listener
    private func startWalletListener(userId: String) {
        walletListener?.remove()
        walletListener = db.collection("coinWallets").document(userId).addSnapshotListener { [weak self] snapshot, error in
            guard let self = self, let doc = snapshot, doc.exists else { return }
            if let wallet = try? doc.data(as: CoinWallet.self) {
                Task { @MainActor in
                    self.wallet = wallet
                    self.saveLocalWallet()
                }
            }
        }
    }
    
    // MARK: - Daily Bonus
    func claimDailyBonus() async -> Bool {
        guard var wallet = wallet, wallet.canClaimDailyBonus else { return false }
        
        let success = wallet.claimDailyBonus()
        if success {
            self.wallet = wallet
            await saveWalletToCloud()
            print("✅ Täglicher Bonus abgeholt: +\(DanceCoinConfig.dailyLoginBonus) DanceCoin")
        }
        return success
    }
    
    // MARK: - Check Daily Bonus on Login
    func checkDailyBonusOnLogin() async {
        guard wallet?.canClaimDailyBonus == true else { return }
        _ = await claimDailyBonus()
    }
    
    // MARK: - Add Coins (Purchase, Key, Admin)
    func addCoins(_ amount: Int, reason: CoinTransactionType, description: String? = nil) async -> Bool {
        guard var wallet = wallet else { return false }
        
        wallet.addCoins(amount, reason: reason, description: description)
        self.wallet = wallet
        await saveWalletToCloud()
        
        print("✅ +\(amount) DanceCoins hinzugefügt (\(reason.rawValue))")
        return true
    }
    
    // MARK: - Spend Coins (Course Unlock)
    func spendCoins(_ amount: Int, reason: CoinTransactionType, description: String? = nil) async -> Bool {
        guard var wallet = wallet, wallet.hasEnoughCoins(amount) else {
            errorMessage = "Nicht genug DanceCoins"
            return false
        }
        
        let success = wallet.spendCoins(amount, reason: reason, description: description)
        if success {
            self.wallet = wallet
            await saveWalletToCloud()
            print("✅ -\(amount) DanceCoins ausgegeben (\(reason.rawValue))")
        }
        return success
    }
    
    // MARK: - Unlock Course with Coins
    func unlockCourseWithCoins(course: Course) async -> Bool {
        let coinsNeeded = DanceCoinConfig.coinsForPrice(course.price)
        
        guard balance >= coinsNeeded else {
            errorMessage = "Du brauchst \(coinsNeeded) DanceCoins für diesen Kurs. Du hast nur \(balance)."
            return false
        }
        
        let success = await spendCoins(coinsNeeded, reason: .courseUnlock, description: "Kurs: \(course.title)")
        
        if success {
            // Kurs für User freischalten
            if let userId = wallet?.id {
                _ = await UserManager.shared.addUnlockedCourse(userId: userId, courseId: course.id)
                await ReferralManager.shared.checkAndAwardFirstPurchaseBonus(userId: userId)
                
                // TRAINER-WALLET: Automatisch Coins gutschreiben
                // Trainer erhält seinen prozentualen Anteil aus den Kursverkäufen
                if let trainerId = course.trainerId {
                    let buyerName = UserManager.shared.currentUser?.name ?? "Unbekannt"
                    _ = await TrainerWalletManager.shared.addCourseSaleEarnings(
                        trainerId: trainerId,
                        courseId: course.id,
                        courseName: course.title,
                        buyerUserId: userId,
                        buyerUserName: buyerName,
                        userPaidCoins: coinsNeeded
                    )
                }
            }
            
            // Admin benachrichtigen - Coin-Freischaltung zählt als Verkauf!
            // (Coins können gekauft werden, daher ist es ein monetärer Wert)
            let buyerName = UserManager.shared.currentUser?.name ?? "Unbekannt"
            let buyerEmail = UserManager.shared.currentUser?.email ?? ""
            let coinValue = String(format: "%.2f €", Double(coinsNeeded) * 0.50) // 1 Coin = 0.50€
            
            await PushNotificationService.shared.notifyAdminAboutPurchase(
                productName: course.title,
                productId: course.productId,
                buyerName: buyerName,
                buyerEmail: buyerEmail,
                price: "\(coinsNeeded) Coins (\(coinValue))",
                paymentMethod: .coins
            )
        }
        
        return success
    }
    
    // MARK: - Redeem Key
    func redeemCoinKey(code: String) async -> (success: Bool, message: String) {
        let normalizedCode = code.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Stelle sicher, dass User eingeloggt ist
        guard let userId = UserManager.shared.currentUser?.id else {
            return (false, "Bitte melde dich zuerst an")
        }
        
        // Stelle sicher, dass Wallet existiert - erstelle es falls nötig
        if wallet == nil {
            print("🔄 Wallet nicht vorhanden, lade/erstelle für User: \(userId)")
            await loadWallet(userId: userId)
        }
        
        // Falls Wallet immer noch nil, erstelle es direkt
        if wallet == nil {
            print("⚠️ Wallet konnte nicht geladen werden, erstelle neues...")
            do {
                let newWallet = CoinWallet(userId: userId)
                try db.collection("coinWallets").document(userId).setData(from: newWallet)
                self.wallet = newWallet
                saveLocalWallet()
                print("✅ Neues Wallet erstellt für Code-Einlösung")
            } catch {
                print("❌ Fehler beim Erstellen des Wallets: \(error)")
                return (false, "Wallet konnte nicht erstellt werden. Bitte versuche es später erneut.")
            }
        }
        
        guard wallet != nil else {
            return (false, "Wallet konnte nicht initialisiert werden. Bitte starte die App neu.")
        }
        
        do {
            let snapshot = try await db.collection("coinKeys")
                .whereField("code", isEqualTo: normalizedCode)
                .limit(to: 1)
                .getDocuments()
            
            guard let doc = snapshot.documents.first,
                  var key = try? doc.data(as: CoinRedemptionKey.self) else {
                return (false, "Ungültiger Code")
            }
            
            guard key.isValid else {
                return (false, "Dieser Code ist abgelaufen oder wurde bereits verwendet")
            }
            
            // Prüfe ob User diesen Key bereits verwendet hat
            if let usedBy = key.usedBy, usedBy == userId {
                return (false, "Du hast diesen Code bereits eingelöst")
            }
            
            // Key als verwendet markieren
            key.currentUses += 1
            if key.maxUses == 1 {
                key.isUsed = true
                key.usedBy = userId
                key.usedAt = Date()
            }
            
            try db.collection("coinKeys").document(key.id).setData(from: key)
            
            // Coins gutschreiben
            let success = await addCoins(key.coinAmount, reason: .keyRedemption, description: "Code: \(normalizedCode)")
            
            if success {
                return (true, "🎉 \(key.coinAmount) DanceCoins gutgeschrieben!")
            } else {
                return (false, "Fehler beim Gutschreiben der Coins")
            }
            
        } catch {
            print("❌ Fehler beim Einlösen: \(error)")
            return (false, "Fehler: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Admin Functions
    
    /// Admin: Coins zu User hinzufügen
    func adminAddCoins(userId: String, amount: Int, reason: String) async -> Bool {
        guard UserManager.shared.currentUser?.group.isAdmin == true else { return false }
        
        do {
            let doc = try await db.collection("coinWallets").document(userId).getDocument()
            
            var wallet: CoinWallet
            if doc.exists, let existing = try? doc.data(as: CoinWallet.self) {
                wallet = existing
            } else {
                wallet = CoinWallet(userId: userId)
            }
            
            wallet.addCoins(amount, reason: .adminGrant, description: reason)
            try db.collection("coinWallets").document(userId).setData(from: wallet)
            
            print("✅ Admin: +\(amount) DanceCoins für User \(userId)")
            return true
        } catch {
            print("❌ Admin Fehler: \(error)")
            return false
        }
    }
    
    /// Admin: Coins von User entfernen
    func adminRemoveCoins(userId: String, amount: Int, reason: String) async -> Bool {
        guard UserManager.shared.currentUser?.group.isAdmin == true else { return false }
        
        do {
            let doc = try await db.collection("coinWallets").document(userId).getDocument()
            guard doc.exists, var wallet = try? doc.data(as: CoinWallet.self) else { return false }
            
            let success = wallet.spendCoins(amount, reason: .adminRemove, description: reason)
            if success {
                try db.collection("coinWallets").document(userId).setData(from: wallet)
                print("✅ Admin: -\(amount) DanceCoins für User \(userId)")
            }
            return success
        } catch {
            print("❌ Admin Fehler: \(error)")
            return false
        }
    }
    
    /// Admin: Coins direkt setzen
    func adminSetCoins(userId: String, newBalance: Int) async -> Bool {
        guard UserManager.shared.currentUser?.group.isAdmin == true else { return false }
        
        do {
            let doc = try await db.collection("coinWallets").document(userId).getDocument()
            
            var wallet: CoinWallet
            if doc.exists, let existing = try? doc.data(as: CoinWallet.self) {
                wallet = existing
            } else {
                wallet = CoinWallet(userId: userId)
            }
            
            let difference = newBalance - wallet.balance
            if difference > 0 {
                wallet.addCoins(difference, reason: .adminGrant, description: "Balance auf \(newBalance) gesetzt")
            } else if difference < 0 {
                _ = wallet.spendCoins(abs(difference), reason: .adminRemove, description: "Balance auf \(newBalance) gesetzt")
            }
            
            try db.collection("coinWallets").document(userId).setData(from: wallet)
            return true
        } catch {
            print("❌ Admin Fehler: \(error)")
            return false
        }
    }
    
    /// Admin: Coin-Key erstellen
    func adminCreateCoinKey(code: String, coinAmount: Int, maxUses: Int = 1, expiresInDays: Int? = nil) async -> CoinRedemptionKey? {
        guard let admin = UserManager.shared.currentUser, admin.group.isAdmin else { return nil }
        
        let expiresIn: TimeInterval? = expiresInDays.map { Double($0) * 24 * 60 * 60 }
        let key = CoinRedemptionKey.create(
            code: code,
            coinAmount: coinAmount,
            createdBy: admin.id,
            maxUses: maxUses,
            expiresIn: expiresIn
        )
        
        do {
            try db.collection("coinKeys").document(key.id).setData(from: key)
            coinKeys.append(key)
            print("✅ Coin-Key erstellt: \(code) für \(coinAmount) Coins")
            return key
        } catch {
            print("❌ Fehler beim Erstellen des Keys: \(error)")
            return nil
        }
    }
    
    /// Admin: Alle Coin-Keys laden
    func adminLoadCoinKeys() async {
        guard UserManager.shared.currentUser?.group.isAdmin == true else { return }
        
        do {
            let snapshot = try await db.collection("coinKeys")
                .order(by: "createdAt", descending: true)
                .limit(to: 100)
                .getDocuments()
            
            coinKeys = snapshot.documents.compactMap { try? $0.data(as: CoinRedemptionKey.self) }
            print("✅ \(coinKeys.count) Coin-Keys geladen")
        } catch {
            print("❌ Fehler beim Laden der Keys: \(error)")
        }
    }
    
    /// Admin: Wallet eines Users laden
    func adminGetUserWallet(userId: String) async -> CoinWallet? {
        guard UserManager.shared.currentUser?.group.isAdmin == true else { return nil }
        
        do {
            let doc = try await db.collection("coinWallets").document(userId).getDocument()
            return try? doc.data(as: CoinWallet.self)
        } catch {
            return nil
        }
    }
    
    // MARK: - Cloud Sync
    private func saveWalletToCloud() async {
        guard let wallet = wallet else { return }
        
        do {
            try db.collection("coinWallets").document(wallet.id).setData(from: wallet)
            saveLocalWallet()
        } catch {
            print("❌ Fehler beim Speichern des Wallets: \(error)")
        }
    }
    
    // MARK: - Local Persistence
    private func saveLocalWallet() {
        guard let wallet = wallet else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(wallet) {
            UserDefaults.standard.set(data, forKey: localWalletKey)
        }
    }
    
    private func loadLocalWallet() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let data = UserDefaults.standard.data(forKey: localWalletKey),
           let wallet = try? decoder.decode(CoinWallet.self, from: data) {
            self.wallet = wallet
        }
    }
    
    // MARK: - Helpers
    func coinsNeededForCourse(_ course: Course) -> Int {
        DanceCoinConfig.coinsForPrice(course.price)
    }
    
    func canAffordCourse(_ course: Course) -> Bool {
        balance >= coinsNeededForCourse(course)
    }

    func coinsNeededForTrainingPlan(priceEUR: Double) -> Int {
        DanceCoinConfig.coinsForPrice(Decimal(priceEUR))
    }

    func coinsNeededForVideoReview(priceEUR: Decimal) -> Int {
        DanceCoinConfig.coinsForPrice(priceEUR)
    }

    func canAffordTrainingPlan(priceEUR: Double) -> Bool {
        balance >= coinsNeededForTrainingPlan(priceEUR: priceEUR)
    }

    func canAffordVideoReview(priceEUR: Decimal) -> Bool {
        balance >= coinsNeededForVideoReview(priceEUR: priceEUR)
    }

    func chargeTrainingPlan(orderNumber: String, coinAmount: Int) async -> Bool {
        await spendCoins(coinAmount, reason: .trainingPlanCharge, description: "Trainingsplan: \(orderNumber)")
    }

    func chargeVideoReview(submissionNumber: String, coinAmount: Int) async -> Bool {
        await spendCoins(coinAmount, reason: .videoReviewCharge, description: "Video-Review: \(submissionNumber)")
    }
}
