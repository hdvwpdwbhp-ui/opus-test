//
//  FeedbackManager.swift
//  Tanzen mit Tatiana Drexler
//
//  Manager für User-Feedback mit Firebase-Integration
//

import Foundation
import Combine
import FirebaseFirestore

@MainActor
class FeedbackManager: ObservableObject {
    static let shared = FeedbackManager()
    
    // MARK: - Published Properties
    @Published var feedbacks: [UserFeedback] = []
    @Published var myFeedbacks: [UserFeedback] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var statistics: FeedbackStatistics = .empty
    
    // MARK: - Private
    private let db = Firestore.firestore()
    private var feedbackListener: ListenerRegistration?
    private let feedbackCollection = "userFeedback"
    
    private init() {}
    
    // MARK: - Submit Feedback (User)
    func submitFeedback(
        type: FeedbackType,
        rating: Int?,
        title: String,
        message: String,
        category: FeedbackCategory
    ) async -> Bool {
        guard let user = UserManager.shared.currentUser else {
            errorMessage = "Bitte melde dich zuerst an"
            return false
        }
        
        let feedback = UserFeedback(
            userId: user.id,
            userName: user.name,
            userEmail: user.email,
            type: type,
            rating: rating,
            title: title,
            message: message,
            category: category
        )
        
        do {
            try db.collection(feedbackCollection).document(feedback.id).setData(from: feedback)
            myFeedbacks.insert(feedback, at: 0)
            print("✅ Feedback eingereicht: \(feedback.title)")
            return true
        } catch {
            print("❌ Fehler beim Einreichen des Feedbacks: \(error)")
            errorMessage = "Feedback konnte nicht gesendet werden"
            return false
        }
    }
    
    // MARK: - Load My Feedbacks (User)
    func loadMyFeedbacks() async {
        guard let userId = UserManager.shared.currentUser?.id else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let snapshot = try await db.collection(feedbackCollection)
                .whereField("userId", isEqualTo: userId)
                .order(by: "createdAt", descending: true)
                .limit(to: 50)
                .getDocuments()
            
            myFeedbacks = snapshot.documents.compactMap { doc in
                try? doc.data(as: UserFeedback.self)
            }
        } catch {
            print("❌ Fehler beim Laden der Feedbacks: \(error)")
        }
    }
    
    // MARK: - Load All Feedbacks (Admin)
    func loadAllFeedbacks() async {
        guard UserManager.shared.isAdmin else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let snapshot = try await db.collection(feedbackCollection)
                .order(by: "createdAt", descending: true)
                .limit(to: 200)
                .getDocuments()
            
            feedbacks = snapshot.documents.compactMap { doc in
                try? doc.data(as: UserFeedback.self)
            }
            
            calculateStatistics()
        } catch {
            print("❌ Fehler beim Laden aller Feedbacks: \(error)")
        }
    }
    
    // MARK: - Start Realtime Listener (Admin)
    func startListeningToFeedbacks() {
        guard UserManager.shared.isAdmin else { return }
        
        feedbackListener?.remove()
        feedbackListener = db.collection(feedbackCollection)
            .order(by: "createdAt", descending: true)
            .limit(to: 100)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let docs = snapshot?.documents else { return }
                
                let items = docs.compactMap { doc in
                    try? doc.data(as: UserFeedback.self)
                }
                
                Task { @MainActor in
                    self.feedbacks = items
                    self.calculateStatistics()
                }
            }
    }
    
    func stopListening() {
        feedbackListener?.remove()
        feedbackListener = nil
    }
    
    // MARK: - Update Feedback Status (Admin)
    func updateStatus(feedbackId: String, status: FeedbackStatus) async -> Bool {
        guard UserManager.shared.isAdmin else { return false }
        
        do {
            try await db.collection(feedbackCollection).document(feedbackId).updateData([
                "status": status.rawValue,
                "updatedAt": Date()
            ])
            
            if let index = feedbacks.firstIndex(where: { $0.id == feedbackId }) {
                feedbacks[index].updatedAt = Date()
            }
            
            return true
        } catch {
            print("❌ Fehler beim Aktualisieren des Status: \(error)")
            return false
        }
    }
    
    // MARK: - Respond to Feedback (Admin)
    func respondToFeedback(feedbackId: String, response: String) async -> Bool {
        guard UserManager.shared.isAdmin,
              let adminId = UserManager.shared.currentUser?.id else { return false }
        
        do {
            try await db.collection(feedbackCollection).document(feedbackId).updateData([
                "adminResponse": response,
                "adminRespondedAt": Date(),
                "adminRespondedBy": adminId,
                "status": FeedbackStatus.responded.rawValue,
                "updatedAt": Date()
            ])
            
            if let index = feedbacks.firstIndex(where: { $0.id == feedbackId }) {
                feedbacks[index].adminResponse = response
                feedbacks[index].adminRespondedAt = Date()
                feedbacks[index].adminRespondedBy = adminId
            }
            
            return true
        } catch {
            print("❌ Fehler beim Antworten: \(error)")
            return false
        }
    }
    
    // MARK: - Delete Feedback (Admin)
    func deleteFeedback(feedbackId: String) async -> Bool {
        guard UserManager.shared.isAdmin else { return false }
        
        do {
            try await db.collection(feedbackCollection).document(feedbackId).delete()
            feedbacks.removeAll { $0.id == feedbackId }
            return true
        } catch {
            print("❌ Fehler beim Löschen: \(error)")
            return false
        }
    }
    
    // MARK: - Calculate Statistics
    private func calculateStatistics() {
        let newCount = feedbacks.filter { $0.status == .new }.count
        let inReviewCount = feedbacks.filter { $0.status == .inReview }.count
        let respondedCount = feedbacks.filter { $0.status == .responded }.count
        let resolvedCount = feedbacks.filter { $0.status == .resolved }.count
        
        let ratings = feedbacks.compactMap { $0.rating }
        let averageRating = ratings.isEmpty ? 0 : Double(ratings.reduce(0, +)) / Double(ratings.count)
        
        var byType: [FeedbackType: Int] = [:]
        for type in FeedbackType.allCases {
            byType[type] = feedbacks.filter { $0.type == type }.count
        }
        
        var byCategory: [FeedbackCategory: Int] = [:]
        for cat in FeedbackCategory.allCases {
            byCategory[cat] = feedbacks.filter { $0.category == cat }.count
        }
        
        statistics = FeedbackStatistics(
            totalCount: feedbacks.count,
            newCount: newCount,
            inReviewCount: inReviewCount,
            respondedCount: respondedCount,
            resolvedCount: resolvedCount,
            averageRating: averageRating,
            byType: byType,
            byCategory: byCategory
        )
    }
    
    // MARK: - Filtered Feedbacks
    func filteredFeedbacks(status: FeedbackStatus? = nil, type: FeedbackType? = nil) -> [UserFeedback] {
        var result = feedbacks
        
        if let status = status {
            result = result.filter { $0.status == status }
        }
        
        if let type = type {
            result = result.filter { $0.type == type }
        }
        
        return result
    }
    
    // MARK: - Unread Count
    var unreadCount: Int {
        feedbacks.filter { $0.status == .new }.count
    }
}
