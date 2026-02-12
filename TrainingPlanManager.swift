//
//  TrainingPlanManager.swift
//  Tanzen mit Tatiana Drexler
//
//  Created on 09.02.2026.
//

import Foundation
import FirebaseFirestore
import Combine

@MainActor
class TrainingPlanManager: ObservableObject {
    static let shared = TrainingPlanManager()
    
    @Published var orders: [TrainingPlanOrder] = []
    @Published var myOrders: [TrainingPlanOrder] = []
    @Published var trainerOrders: [TrainingPlanOrder] = []
    @Published var pricing: TrainingPlanPricing = TrainingPlanPricing()
    @Published var trainerSettings: [String: TrainerPlanSettings] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()
    private var trainerSettingsListener: ListenerRegistration?
    private var ordersListener: ListenerRegistration?
    
    private init() {
        loadPricing()
        startTrainerSettingsListener()
        Task {
            await loadAllTrainerSettings()
        }
    }
    
    // MARK: - Realtime Listeners
    
    private func startTrainerSettingsListener() {
        trainerSettingsListener?.remove()
        trainerSettingsListener = db.collection("trainerPlanSettings")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let docs = snapshot?.documents else { return }
 
                for doc in docs {
                    let trainerId = doc.documentID
                    let data = doc.data()
                    do {
                        let jsonData = try JSONSerialization.data(withJSONObject: data)
                        let settings = try JSONDecoder().decode(TrainerPlanSettings.self, from: jsonData)
                        Task { @MainActor in
                            self.trainerSettings[trainerId] = settings
                        }
                    } catch {
                        print("❌ Error decoding trainer settings: \(error)")
                    }
                 }
                 print("✅ TrainerPlanSettings aktualisiert: \(docs.count) Trainer")
             }
    }
    
    func startOrdersListener(for userId: String? = nil, trainerId: String? = nil) {
        ordersListener?.remove()
        
        var query: Query = db.collection("trainingPlanOrders")
        
        if let userId = userId {
            query = query.whereField("userId", isEqualTo: userId)
        } else if let trainerId = trainerId {
            query = query.whereField("trainerId", isEqualTo: trainerId)
        }
        
        ordersListener = query.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self, let docs = snapshot?.documents else { return }
            
            let orders = docs.compactMap { doc -> TrainingPlanOrder? in
                do {
                    let data = try JSONSerialization.data(withJSONObject: doc.data())
                    return try JSONDecoder().decode(TrainingPlanOrder.self, from: data)
                } catch {
                    print("❌ Error decoding order: \(error)")
                    return nil
                }
            }
            
            Task { @MainActor in
                if userId != nil {
                    self.myOrders = orders.sorted { $0.createdAt > $1.createdAt }
                } else if trainerId != nil {
                    self.trainerOrders = orders.sorted { $0.createdAt > $1.createdAt }
                } else {
                    self.orders = orders.sorted { $0.createdAt > $1.createdAt }
                }
            }
        }
    }
    
    func stopListeners() {
        trainerSettingsListener?.remove()
        ordersListener?.remove()
    }
    
    // MARK: - Pricing (Admin)
    
    func loadPricing() {
        db.collection("appSettings").document("trainingPlanPricing").getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
 
             if let data = snapshot?.data() {
                Task { @MainActor in
                    do {
                        let jsonData = try JSONSerialization.data(withJSONObject: data)
                        let pricing = try JSONDecoder().decode(TrainingPlanPricing.self, from: jsonData)
                        self.pricing = pricing
                    } catch {
                        print("❌ Error decoding pricing: \(error)")
                    }
                }
             }
         }
    }
    
    func updatePricing(_ pricing: TrainingPlanPricing, by adminId: String) async throws {
        var updatedPricing = pricing
        updatedPricing.lastUpdated = Date()
        updatedPricing.updatedBy = adminId
        
        let data = try JSONEncoder().encode(updatedPricing)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        
        try await db.collection("appSettings").document("trainingPlanPricing").setData(dict)
        
        DispatchQueue.main.async {
            self.pricing = updatedPricing
        }
    }
    
    func getPrice(for planType: TrainingPlanType) -> Double {
        return pricing.price(for: planType)
    }
    
    // MARK: - Orders (User)
    
    func createOrder(
        userId: String,
        userName: String,
        userEmail: String,
        trainerId: String,
        trainerName: String,
        formData: TrainingPlanFormData,
        planType: TrainingPlanType
    ) async throws -> TrainingPlanOrder {
        let price = getPrice(for: planType)
        let coinAmount = DanceCoinConfig.coinsForPrice(Decimal(price))
        
        let order = TrainingPlanOrder(
            userId: userId,
            userName: userName,
            userEmail: userEmail,
            trainerId: trainerId,
            trainerName: trainerName,
            formData: formData,
            planType: planType,
            price: price,
            coinAmount: coinAmount
        )
        
        let data = try JSONEncoder().encode(order)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        
        try await db.collection("trainingPlanOrders").document(order.id).setData(dict)
        
        DispatchQueue.main.async {
            self.myOrders.append(order)
        }
        
        // Admin über neue Trainingsplan-Bestellung benachrichtigen
        await PushNotificationService.shared.notifyAdminAboutPurchase(
            productName: "Trainingsplan: \(planType.displayName)",
            productId: order.id,
            buyerName: userName,
            buyerEmail: userEmail,
            price: "\(coinAmount) DanceCoins",
            paymentMethod: .coins
        )
        
        return order
    }
    
    func loadMyOrders(userId: String) async {
        isLoading = true
        
        do {
            let snapshot = try await db.collection("trainingPlanOrders")
                .whereField("userId", isEqualTo: userId)
                .order(by: "createdAt", descending: true)
                .getDocuments()
            
            let orders = snapshot.documents.compactMap { doc -> TrainingPlanOrder? in
                do {
                    let data = try JSONSerialization.data(withJSONObject: doc.data())
                    return try JSONDecoder().decode(TrainingPlanOrder.self, from: data)
                } catch {
                    print("❌ Error decoding order: \(error)")
                    return nil
                }
            }
            
            DispatchQueue.main.async {
                self.myOrders = orders
                self.isLoading = false
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    func markOrderAsPaid(orderId: String, transactionId: String) async throws {
        try await db.collection("trainingPlanOrders").document(orderId).updateData([
            "status": TrainingPlanOrderStatus.paid.rawValue,
            "paidAt": Timestamp(date: Date()),
            "transactionId": transactionId
        ])
        
        if let index = myOrders.firstIndex(where: { $0.id == orderId }) {
            DispatchQueue.main.async {
                var order = self.myOrders[index]
                order = TrainingPlanOrder(
                    id: order.id,
                    userId: order.userId,
                    userName: order.userName,
                    userEmail: order.userEmail,
                    trainerId: order.trainerId,
                    trainerName: order.trainerName,
                    formData: order.formData,
                    planType: order.planType,
                    price: order.price,
                    coinAmount: order.coinAmount
                )
                self.myOrders[index] = order
            }
        }
    }
    
    // MARK: - Orders (Trainer)
    
    func loadTrainerOrders(trainerId: String) async {
        isLoading = true
        
        do {
            let snapshot = try await db.collection("trainingPlanOrders")
                .whereField("trainerId", isEqualTo: trainerId)
                .order(by: "createdAt", descending: true)
                .getDocuments()
            
            let orders = snapshot.documents.compactMap { doc -> TrainingPlanOrder? in
                do {
                    let data = try JSONSerialization.data(withJSONObject: doc.data())
                    return try JSONDecoder().decode(TrainingPlanOrder.self, from: data)
                } catch {
                    print("❌ Error decoding order: \(error)")
                    return nil
                }
            }
            
            DispatchQueue.main.async {
                self.trainerOrders = orders
                self.isLoading = false
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    func updateOrderStatus(orderId: String, status: TrainingPlanOrderStatus, notes: String? = nil) async throws {
        var data: [String: Any] = ["status": status.rawValue]
        
        if let notes = notes {
            data["trainerNotes"] = notes
        }
        
        if status == .delivered {
            data["deliveredAt"] = Timestamp(date: Date())
        }
        
        try await db.collection("trainingPlanOrders").document(orderId).updateData(data)
    }
    
    func deliverPlan(orderId: String, plan: DeliveredTrainingPlan) async throws {
        let planData = try JSONEncoder().encode(plan)
        let planDict = try JSONSerialization.jsonObject(with: planData) as? [String: Any] ?? [:]
        
        try await db.collection("trainingPlanOrders").document(orderId).updateData([
            "status": TrainingPlanOrderStatus.delivered.rawValue,
            "deliveredAt": Timestamp(date: Date()),
            "deliveredPlan": planDict
        ])
    }
    
    // MARK: - User Feedback
    
    func submitFeedback(orderId: String, rating: Int, feedback: String) async throws {
        try await db.collection("trainingPlanOrders").document(orderId).updateData([
            "status": TrainingPlanOrderStatus.completed.rawValue,
            "rating": rating,
            "userFeedback": feedback
        ])
    }
    
    // MARK: - Admin
    
    func loadAllOrders() async {
        isLoading = true
        
        do {
            let snapshot = try await db.collection("trainingPlanOrders")
                .order(by: "createdAt", descending: true)
                .limit(to: 100)
                .getDocuments()
            
            let orders = snapshot.documents.compactMap { doc -> TrainingPlanOrder? in
                do {
                    let data = try JSONSerialization.data(withJSONObject: doc.data())
                    return try JSONDecoder().decode(TrainingPlanOrder.self, from: data)
                } catch {
                    print("❌ Error decoding order: \(error)")
                    return nil
                }
            }
            
            DispatchQueue.main.async {
                self.orders = orders
                self.isLoading = false
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Trainer Settings
    
    func loadTrainerPlanSettings(trainerId: String) async -> TrainerPlanSettings? {
        do {
            let doc = try await db.collection("trainerPlanSettings").document(trainerId).getDocument()
            
            if let data = doc.data() {
                let jsonData = try JSONSerialization.data(withJSONObject: data)
                let settings = try JSONDecoder().decode(TrainerPlanSettings.self, from: jsonData)
                self.trainerSettings[trainerId] = settings
                return settings
            }
        } catch {
            print("❌ Error loading trainer settings: \(error)")
        }
        
        return nil
    }
    
    func loadAllTrainerSettings() async {
        for trainer in UserManager.shared.trainers {
            _ = await loadTrainerPlanSettings(trainerId: trainer.id)
        }
    }
    
    func updateTrainerPlanSettings(trainerId: String, settings: TrainerPlanSettings) async throws {
        let data = try JSONEncoder().encode(settings)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        
        try await db.collection("trainerPlanSettings").document(trainerId).setData(dict)
    }
    
    func getTrainersOfferingPlans() async -> [(trainer: AppUser, settings: TrainerPlanSettings)] {
        var results: [(AppUser, TrainerPlanSettings)] = []
        
        do {
            // Get trainers who offer plans
            let settingsSnapshot = try await db.collection("trainerPlanSettings")
                .whereField("offersTrainingPlans", isEqualTo: true)
                .getDocuments()
            
            for doc in settingsSnapshot.documents {
                let trainerId = doc.documentID
                
                // Get trainer info
                let trainerDoc = try await db.collection("users").document(trainerId).getDocument()
                
                if let trainerData = trainerDoc.data() {
                    let trainerJson = try JSONSerialization.data(withJSONObject: trainerData)
                    let trainer = try JSONDecoder().decode(AppUser.self, from: trainerJson)
                    
                    let settingsJson = try JSONSerialization.data(withJSONObject: doc.data())
                    let settings = try JSONDecoder().decode(TrainerPlanSettings.self, from: settingsJson)
                    
                    results.append((trainer, settings))
                }
            }
        } catch {
            print("❌ Error getting trainers: \(error)")
        }
        
        return results
    }
    
    // MARK: - Convenience Methods
    
    /// Returns all orders for a specific trainer
    func ordersForTrainer(_ trainerId: String) -> [TrainingPlanOrder] {
        return orders.filter { $0.trainerId == trainerId }
    }
    
    /// Loads orders for a specific trainer (async for cloud sync)
    func loadOrdersForTrainer(_ trainerId: String) async {
        // Local data is already loaded, cloud sync could happen here
        // Currently using local data
    }
    
    /// Returns pending orders for a specific trainer
    func pendingOrdersForTrainer(_ trainerId: String) -> [TrainingPlanOrder] {
        return orders.filter { $0.trainerId == trainerId && ($0.status == .paid || $0.status == .inProgress) }
    }
}

// MARK: - Firestore Rules Extension

/*
 Add these rules to your Firestore.rules:
 
 match /trainingPlanOrders/{orderId} {
   allow read, write: if true;
 }
 
 match /trainerPlanSettings/{trainerId} {
   allow read, write: if true;
 }
*/
