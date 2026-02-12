//
//  StoreViewModel.swift
//  Tanzen mit Tatiana Drexler
//
//  ViewModel for StoreKit 2 In-App Purchases & Subscriptions
//

import Foundation
import StoreKit
import Combine

@MainActor
class StoreViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var products: [Product] = []
    @Published var subscriptions: [Product] = []
    @Published var coinProducts: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showPurchaseSuccess = false
    @Published var hasActiveSubscription = false
    @Published var currentSubscriptionType: SubscriptionType? = nil
    
    // Key für manuell freigeschaltete Käufe (UserDefaults)
    private let manualUnlocksKey = "manuallyUnlockedProducts"
    
    // MARK: - Subscription Types
    enum SubscriptionType: String {
        case monthly = "monthly"
        case yearly = "yearly"
        
        var displayName: String {
            switch self {
            case .monthly: return "Monatlich"
            case .yearly: return "Jährlich"
            }
        }
    }
    
    // MARK: - Product IDs
    // Einzelne Kurse
    private var courseProductIDs: Set<String> = []
    
    // Abonnements
    static let monthlySubscriptionID = "com.tatianadrexler.dance.subscription.monthly"
    static let yearlySubscriptionID = "com.tatianadrexler.dance.subscription.yearly"
    
    private var subscriptionProductIDs: Set<String> = [
        monthlySubscriptionID,
        yearlySubscriptionID
    ]
    
    // Coin-Pakete
    private var coinProductIDs: Set<String> = Set(DanceCoinConfig.coinPackages.map { $0.productId })
    
    // Video-Review Credits (consumable)
    private var videoReviewProductIDs: Set<String> = []
    
    private var allProductIDs: Set<String> {
        subscriptionProductIDs.union(coinProductIDs)
    }
    
    private var updateListenerTask: Task<Void, Error>?
    
    // MARK: - Initialization
    init() {
        // Lade manuell freigeschaltete Käufe aus UserDefaults
        loadManualUnlocks()
        
        updateListenerTask = listenForTransactions()
        
        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Transaction Listener
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached { [weak self] in
            for await result in Transaction.updates {
                do {
                    let transaction = try await self?.checkVerifiedAsync(result)
                    
                    if let transaction = transaction {
                        await self?.updatePurchasedProducts()
                        await transaction.finish()
                    }
                } catch {
                    print("Transaction verification failed: \(error)")
                }
            }
        }
    }
    
    // MARK: - Async version of checkVerified for detached task
    nonisolated private func checkVerifiedAsync<T>(_ result: VerificationResult<T>) async throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
    
    // MARK: - Load Products
    func loadProducts() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let storeProducts = try await Product.products(for: allProductIDs)
            
            // Trenne Kurse und Abos
            var courseProducts: [Product] = []
            var subscriptionProducts: [Product] = []
            var coinStoreProducts: [Product] = []
            
            for product in storeProducts {
                if subscriptionProductIDs.contains(product.id) {
                    subscriptionProducts.append(product)
                } else if coinProductIDs.contains(product.id) {
                    coinStoreProducts.append(product)
                } else {
                    courseProducts.append(product)
                }
            }
            
            // Sortiere nach Preis
            products = courseProducts.sorted { $0.price < $1.price }
            subscriptions = subscriptionProducts.sorted { $0.price < $1.price }
            coinProducts = coinStoreProducts.sorted { $0.price < $1.price }
            
            isLoading = false
        } catch {
            errorMessage = "Produkte konnten nicht geladen werden: \(error.localizedDescription)"
            isLoading = false
            print("Failed to load products: \(error)")
        }
    }
    
    // MARK: - Get Subscription Products
    var monthlySubscription: Product? {
        subscriptions.first { $0.id == Self.monthlySubscriptionID }
    }
    
    var yearlySubscription: Product? {
        subscriptions.first { $0.id == Self.yearlySubscriptionID }
    }
    
    /// Berechnet den monatlichen Preis des Jahresabos
    var yearlyMonthlyPrice: Decimal? {
        guard let yearly = yearlySubscription else { return nil }
        return yearly.price / 12
    }
    
    /// Berechnet die Ersparnis in Prozent beim Jahresabo
    var yearlySavingsPercent: Int {
        return 40 // 40% Rabatt für jährliches Abo
    }
    
    // MARK: - Get Product for Course
    func product(for productId: String) -> Product? {
        products.first { $0.id == productId }
    }
    
    // MARK: - Purchase Product
    func purchase(_ product: Product) async -> Bool {
        // WICHTIG: User muss eingeloggt sein für Käufe
        guard UserManager.shared.isLoggedIn else {
            errorMessage = "Bitte erstelle zuerst einen Account, um Käufe zu tätigen."
            return false
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                
                // Coin-Pakete: Coins gutschreiben
                if coinProductIDs.contains(product.id) {
                    if let package = DanceCoinConfig.coinPackages.first(where: { $0.productId == product.id }) {
                        _ = await CoinManager.shared.addCoins(
                            package.totalCoins,
                            reason: .purchase,
                            description: "Coin-Paket \(package.coins) + \(package.bonusCoins) Bonus"
                        )
                        if let userId = UserManager.shared.currentUser?.id {
                            await ReferralManager.shared.checkAndAwardFirstPurchaseBonus(userId: userId)
                        }
                    }
                } else {
                    // Update purchased products (Apple)
                    await updatePurchasedProducts()
                    
                    // WICHTIG: Auch im User-Account speichern für Cloud-Sync
                    await savePurchaseToUserAccount(productId: product.id)
                    
                    // Admin über Kauf benachrichtigen
                    await notifyAdminAboutPurchase(product: product)
                }
                
                // Finish the transaction
                await transaction.finish()
                
                isLoading = false
                showPurchaseSuccess = true
                return true
                
            case .userCancelled:
                isLoading = false
                return false
                
            case .pending:
                isLoading = false
                errorMessage = "Kauf wird bearbeitet. Bitte warten Sie."
                return false
                
            @unknown default:
                isLoading = false
                return false
            }
        } catch StoreKitError.userCancelled {
            isLoading = false
            return false
        } catch {
            isLoading = false
            errorMessage = "Kauf fehlgeschlagen: \(error.localizedDescription)"
            print("Purchase failed: \(error)")
            return false
        }
    }
    
    // MARK: - Notify Admin About Purchase
    private func notifyAdminAboutPurchase(product: Product) async {
        let buyerName = UserManager.shared.currentUser?.name ?? "Unbekannt"
        let buyerEmail = UserManager.shared.currentUser?.email ?? ""
        
        await PushNotificationService.shared.notifyAdminAboutPurchase(
            productName: product.displayName,
            productId: product.id,
            buyerName: buyerName,
            buyerEmail: buyerEmail,
            price: product.displayPrice,
            paymentMethod: .inAppPurchase
        )
    }
    
    // MARK: - Purchase Course
    func purchaseCourse(productId: String) async -> Bool {
        errorMessage = "Kurse werden nur mit DanceCoins freigeschaltet."
        return false
    }
    
    // MARK: - Purchase Subscription
    func purchaseSubscription(_ type: SubscriptionType) async -> Bool {
        let productId = type == .monthly ? Self.monthlySubscriptionID : Self.yearlySubscriptionID
        guard let product = subscriptions.first(where: { $0.id == productId }) else {
            errorMessage = "Abo-Produkt nicht gefunden"
            return false
        }
        return await purchase(product)
    }
    
    // MARK: - Purchase Coin Package
    func purchaseCoinPackage(_ package: CoinPackage) async -> Bool {
        guard let product = coinProducts.first(where: { $0.id == package.productId }) else {
            errorMessage = "Coin-Produkt nicht gefunden"
            return false
        }
        return await purchase(product)
    }
    
    /// Kündigt das Abo (öffnet App Store Einstellungen)
    func manageSubscription() async {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            do {
                try await AppStore.showManageSubscriptions(in: windowScene)
            } catch {
                print("Failed to show manage subscriptions: \(error)")
            }
        }
    }
    
    // MARK: - Check if Purchased
    func isPurchased(_ productId: String) -> Bool {
        // Wenn Abo aktiv ist, sind alle Kurse freigeschaltet
        if hasActiveSubscription {
            return true
        }
        return purchasedProductIDs.contains(productId)
    }
    
    /// Prüft ob ein spezifisches Produkt (ohne Abo-Check) gekauft wurde
    func isProductPurchased(_ productId: String) -> Bool {
        purchasedProductIDs.contains(productId)
    }
    
    // MARK: - Restore Purchases
    func restorePurchases() async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = "Käufe konnten nicht wiederhergestellt werden: \(error.localizedDescription)"
            print("Restore failed: \(error)")
        }
    }
    
    // MARK: - Update Purchased Products
    func updatePurchasedProducts() async {
        var purchased: Set<String> = []
        var activeSubscription = false
        var subscriptionType: SubscriptionType? = nil
        
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                if transaction.revocationDate == nil {
                    purchased.insert(transaction.productID)
                    
                    // Prüfe auf aktives Abo
                    if transaction.productID == Self.monthlySubscriptionID {
                        activeSubscription = true
                        subscriptionType = .monthly
                    } else if transaction.productID == Self.yearlySubscriptionID {
                        activeSubscription = true
                        subscriptionType = .yearly
                    }
                }
            } catch {
                print("Failed to verify transaction: \(error)")
            }
        }
        
        purchasedProductIDs = purchased
        hasActiveSubscription = activeSubscription
        currentSubscriptionType = subscriptionType
        
        // Manuell freigeschaltete Produkte wieder hinzufügen
        let manualUnlocks = getManuallyUnlockedProducts()
        for id in manualUnlocks {
            purchasedProductIDs.insert(id)
        }
    }
    
    // MARK: - Verify Transaction
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
    
    // MARK: - Manual Unlock Functions (für Admin/Tests)
    
    /// Lädt manuell freigeschaltete Produkte aus UserDefaults
    private func loadManualUnlocks() {
        if let saved = UserDefaults.standard.array(forKey: manualUnlocksKey) as? [String] {
            for productId in saved {
                purchasedProductIDs.insert(productId)
            }
        }
    }
    
    /// Speichert manuell freigeschaltete Produkte in UserDefaults
    private func saveManualUnlocks() {
        let manualUnlocks = getManuallyUnlockedProducts()
        UserDefaults.standard.set(Array(manualUnlocks), forKey: manualUnlocksKey)
    }
    
    /// Gibt alle manuell freigeschalteten Produkt-IDs zurück
    func getManuallyUnlockedProducts() -> Set<String> {
        if let saved = UserDefaults.standard.array(forKey: manualUnlocksKey) as? [String] {
            return Set(saved)
        }
        return []
    }
    
    /// Prüft ob ein Produkt manuell freigeschaltet wurde
    func isManuallyUnlocked(_ productId: String) -> Bool {
        getManuallyUnlockedProducts().contains(productId)
    }
    
    /// Schaltet einen Kurs manuell frei (ohne echten Kauf)
    func unlockCourse(_ productId: String) {
        purchasedProductIDs.insert(productId)
        
        // In UserDefaults speichern
        var manualUnlocks = getManuallyUnlockedProducts()
        manualUnlocks.insert(productId)
        UserDefaults.standard.set(Array(manualUnlocks), forKey: manualUnlocksKey)
        
        showPurchaseSuccess = true
    }
    
    /// Sperrt einen manuell freigeschalteten Kurs wieder
    func lockCourse(_ productId: String) {
        // Nur manuell freigeschaltete Kurse können gesperrt werden
        var manualUnlocks = getManuallyUnlockedProducts()
        manualUnlocks.remove(productId)
        UserDefaults.standard.set(Array(manualUnlocks), forKey: manualUnlocksKey)
        
        // Aus purchasedProductIDs entfernen (nur wenn nicht echt gekauft)
        Task {
            await updatePurchasedProducts()
            // Manuell freigeschaltete wieder hinzufügen
            for id in manualUnlocks {
                purchasedProductIDs.insert(id)
            }
        }
    }
    
    /// Schaltet alle Kurse manuell frei
    func unlockAllCourses() {
        // Kurse werden nicht mehr via StoreKit freigeschaltet.
    }
    
    /// Sperrt alle manuell freigeschalteten Kurse
    func lockAllManualUnlocks() {
        UserDefaults.standard.removeObject(forKey: manualUnlocksKey)
        Task {
            await updatePurchasedProducts()
        }
    }
    
    // MARK: - Cloud Sync (User Account)
    
    /// Speichert einen Kauf auch im User-Account für Cloud-Sync
    private func savePurchaseToUserAccount(productId: String) async {
        guard UserManager.shared.currentUser != nil else { return }
        _ = await UserManager.shared.savePurchase(productId: productId)
        print("✅ Kauf auch im User-Account gespeichert: \(productId)")
    }
    
    /// Lädt Käufe aus dem User-Account (bei Login)
    func loadPurchasesFromUserAccount() async {
        guard let user = UserManager.shared.currentUser,
              let purchases = user.purchasedProductIds else { return }
        
        for productId in purchases {
            purchasedProductIDs.insert(productId)
        }
        print("✅ \(purchases.count) Käufe aus User-Account geladen")
    }
}
