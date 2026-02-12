//
//  CommunityManager.swift
//  Tanzen mit Tatiana Drexler
//
//  Community Features: Bewertungen, Shares, Likes
//

import Foundation
import Combine

// MARK: - Models

struct CourseRating: Codable, Identifiable {
    let id: String
    let courseId: String
    let userId: String
    let userName: String
    var rating: Int // 1-5 Sterne
    var review: String?
    let createdAt: Date
    var updatedAt: Date
    var helpfulCount: Int
    var reportCount: Int
    
    static func create(courseId: String, userId: String, userName: String, rating: Int, review: String?) -> CourseRating {
        CourseRating(
            id: UUID().uuidString,
            courseId: courseId,
            userId: userId,
            userName: userName,
            rating: rating,
            review: review,
            createdAt: Date(),
            updatedAt: Date(),
            helpfulCount: 0,
            reportCount: 0
        )
    }
}

struct CourseShare: Codable, Identifiable {
    let id: String
    let courseId: String
    let userId: String
    let platform: SharePlatform
    let timestamp: Date
    
    enum SharePlatform: String, Codable {
        case whatsapp, instagram, facebook, twitter, copyLink, other
    }
}

struct CourseLike: Codable, Identifiable {
    let id: String
    let courseId: String
    let lessonId: String?
    let userId: String
    let timestamp: Date
}

// MARK: - Community Manager

@MainActor
class CommunityManager: ObservableObject {
    static let shared = CommunityManager()
    
    @Published var ratings: [String: [CourseRating]] = [:] // courseId -> ratings
    @Published var userLikes: Set<String> = [] // lessonId or courseId
    @Published var shareCount: [String: Int] = [:] // courseId -> count
    
    private let ratingsKey = "course_ratings"
    private let likesKey = "user_likes"
    private let firebase = FirebaseService.shared
    
    private init() {
        loadLocalData()
    }
    
    // MARK: - Ratings
    
    func getRatings(for courseId: String) -> [CourseRating] {
        return ratings[courseId] ?? []
    }
    
    func getAverageRating(for courseId: String) -> Double {
        let courseRatings = ratings[courseId] ?? []
        guard !courseRatings.isEmpty else { return 0 }
        let sum = courseRatings.reduce(0) { $0 + $1.rating }
        return Double(sum) / Double(courseRatings.count)
    }
    
    func getRatingCount(for courseId: String) -> Int {
        return ratings[courseId]?.count ?? 0
    }
    
    func getUserRating(for courseId: String, userId: String) -> CourseRating? {
        return ratings[courseId]?.first { $0.userId == userId }
    }
    
    func submitRating(courseId: String, userId: String, userName: String, rating: Int, review: String?) async -> Bool {
        // Check if user already rated
        if let existingIndex = ratings[courseId]?.firstIndex(where: { $0.userId == userId }) {
            // Update existing rating
            ratings[courseId]?[existingIndex].rating = rating
            ratings[courseId]?[existingIndex].review = review
            ratings[courseId]?[existingIndex].updatedAt = Date()
        } else {
            // Add new rating
            let newRating = CourseRating.create(
                courseId: courseId,
                userId: userId,
                userName: userName,
                rating: rating,
                review: review
            )
            if ratings[courseId] == nil {
                ratings[courseId] = []
            }
            ratings[courseId]?.append(newRating)
        }
        
        saveAndSync()
        return true
    }
    
    func markRatingHelpful(ratingId: String, courseId: String) {
        if let index = ratings[courseId]?.firstIndex(where: { $0.id == ratingId }) {
            ratings[courseId]?[index].helpfulCount += 1
            saveAndSync()
        }
    }
    
    func reportRating(ratingId: String, courseId: String) {
        if let index = ratings[courseId]?.firstIndex(where: { $0.id == ratingId }) {
            ratings[courseId]?[index].reportCount += 1
            saveAndSync()
        }
    }
    
    func deleteRating(ratingId: String, courseId: String, userId: String) async -> Bool {
        // Only allow user to delete their own rating
        if let index = ratings[courseId]?.firstIndex(where: { $0.id == ratingId && $0.userId == userId }) {
            ratings[courseId]?.remove(at: index)
            saveAndSync()
            return true
        }
        return false
    }
    
    // MARK: - Likes
    
    func isLiked(_ id: String) -> Bool {
        userLikes.contains(id)
    }
    
    func toggleLike(_ id: String) {
        if userLikes.contains(id) {
            userLikes.remove(id)
        } else {
            userLikes.insert(id)
        }
        saveAndSync()
    }
    
    func getLikeCount(for id: String) -> Int {
        // In real app, this would come from server
        return userLikes.contains(id) ? 1 : 0
    }
    
    // MARK: - Sharing
    
    func recordShare(courseId: String, userId: String, platform: CourseShare.SharePlatform) {
        shareCount[courseId, default: 0] += 1
        saveAndSync()
    }
    
    func getShareCount(for courseId: String) -> Int {
        return shareCount[courseId] ?? 0
    }
    
    // MARK: - Persistence
    
    private func loadLocalData() {
        if let data = UserDefaults.standard.data(forKey: ratingsKey),
           let saved = try? JSONDecoder().decode([String: [CourseRating]].self, from: data) {
            ratings = saved
        }
        
        if let data = UserDefaults.standard.data(forKey: likesKey),
           let saved = try? JSONDecoder().decode(Set<String>.self, from: data) {
            userLikes = saved
        }
    }
    
    private func saveAndSync() {
        if let data = try? JSONEncoder().encode(ratings) {
            UserDefaults.standard.set(data, forKey: ratingsKey)
        }
        if let data = try? JSONEncoder().encode(userLikes) {
            UserDefaults.standard.set(data, forKey: likesKey)
        }
    }
}
