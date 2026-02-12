//
//  CommentManager.swift
//  Tanzen mit Tatiana Drexler
//
//  Service für Video-Kommentare und Moderation
//

import Foundation
import Combine

@MainActor
class CommentManager: ObservableObject {
    static let shared = CommentManager()
    
    @Published var comments: [VideoComment] = []
    @Published var isLoading = false
    
    private let localCommentsKey = "local_video_comments"
    
    private init() {
        loadLocal()
    }
    
    // MARK: - Comments
    
    /// Fügt einen Kommentar hinzu
    func addComment(lessonId: String, courseId: String, content: String) async -> Bool {
        guard let user = UserManager.shared.currentUser else { return false }
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        
        let comment = VideoComment.create(
            lessonId: lessonId,
            courseId: courseId,
            userId: user.id,
            userName: user.name,
            userGroup: user.group,
            content: content.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        
        comments.append(comment)
        saveLocal()
        await saveToCloud()
        
        return true
    }
    
    /// Bearbeitet einen eigenen Kommentar
    func editComment(commentId: String, newContent: String) async -> Bool {
        guard let user = UserManager.shared.currentUser else { return false }
        guard let index = comments.firstIndex(where: { $0.id == commentId }) else { return false }
        
        // Nur eigene Kommentare bearbeiten
        guard comments[index].userId == user.id else { return false }
        
        comments[index].content = newContent.trimmingCharacters(in: .whitespacesAndNewlines)
        comments[index].editedAt = Date()
        
        saveLocal()
        await saveToCloud()
        return true
    }
    
    /// Löscht einen eigenen Kommentar
    func deleteComment(commentId: String) async -> Bool {
        guard let user = UserManager.shared.currentUser else { return false }
        guard let comment = comments.first(where: { $0.id == commentId }) else { return false }
        
        // Eigene Kommentare oder Admin/Trainer des Kurses
        let canDelete = comment.userId == user.id ||
                       user.group.isAdmin ||
                       UserManager.shared.canModerateCourse(comment.courseId)
        
        guard canDelete else { return false }
        
        comments.removeAll { $0.id == commentId }
        saveLocal()
        await saveToCloud()
        return true
    }
    
    /// Versteckt einen Kommentar (Moderation)
    func hideComment(commentId: String, reason: String) async -> Bool {
        guard let user = UserManager.shared.currentUser else { return false }
        guard let index = comments.firstIndex(where: { $0.id == commentId }) else { return false }
        
        let comment = comments[index]
        
        // Nur Admin oder zugewiesener Trainer
        guard user.group.isAdmin || UserManager.shared.canModerateCourse(comment.courseId) else {
            return false
        }
        
        comments[index].isHidden = true
        comments[index].hiddenReason = reason
        comments[index].hiddenBy = user.id
        
        saveLocal()
        await saveToCloud()
        return true
    }
    
    /// Zeigt einen versteckten Kommentar wieder an
    func unhideComment(commentId: String) async -> Bool {
        guard let user = UserManager.shared.currentUser else { return false }
        guard let index = comments.firstIndex(where: { $0.id == commentId }) else { return false }
        
        let comment = comments[index]
        guard user.group.isAdmin || UserManager.shared.canModerateCourse(comment.courseId) else {
            return false
        }
        
        comments[index].isHidden = false
        comments[index].hiddenReason = nil
        comments[index].hiddenBy = nil
        
        saveLocal()
        await saveToCloud()
        return true
    }
    
    /// Liked einen Kommentar
    func toggleLike(commentId: String) async -> Bool {
        guard let user = UserManager.shared.currentUser else { return false }
        guard let index = comments.firstIndex(where: { $0.id == commentId }) else { return false }
        
        if comments[index].likedByUserIds.contains(user.id) {
            comments[index].likedByUserIds.removeAll { $0 == user.id }
            comments[index].likes -= 1
        } else {
            comments[index].likedByUserIds.append(user.id)
            comments[index].likes += 1
        }
        
        saveLocal()
        await saveToCloud()
        return true
    }
    
    // MARK: - Queries
    
    /// Kommentare für eine Lektion
    func commentsFor(lessonId: String) -> [VideoComment] {
        let user = UserManager.shared.currentUser
        let courseId = comments.first { $0.lessonId == lessonId }?.courseId ?? ""
        let canModerate = user?.group.isAdmin == true || UserManager.shared.canModerateCourse(courseId)
        
        return comments
            .filter { $0.lessonId == lessonId }
            .filter { !$0.isHidden || canModerate } // Versteckte nur für Moderatoren
            .sorted { $0.createdAt > $1.createdAt }
    }
    
    /// Kommentare für einen Kurs (alle Lektionen)
    func commentsFor(courseId: String) -> [VideoComment] {
        comments.filter { $0.courseId == courseId }
    }
    
    /// Anzahl sichtbarer Kommentare für eine Lektion
    func commentCountFor(lessonId: String) -> Int {
        comments.filter { $0.lessonId == lessonId && !$0.isHidden }.count
    }
    
    /// Versteckte Kommentare für einen Kurs (Moderation)
    func hiddenCommentsFor(courseId: String) -> [VideoComment] {
        comments.filter { $0.courseId == courseId && $0.isHidden }
    }
    
    /// Prüft ob der aktuelle User einen Kommentar geliked hat
    func hasLiked(commentId: String) -> Bool {
        guard let user = UserManager.shared.currentUser else { return false }
        return comments.first { $0.id == commentId }?.likedByUserIds.contains(user.id) ?? false
    }
    
    // MARK: - Local Storage
    
    private func saveLocal() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(comments) {
            UserDefaults.standard.set(data, forKey: localCommentsKey)
        }
    }
    
    private func loadLocal() {
        guard let data = UserDefaults.standard.data(forKey: localCommentsKey) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let comments = try? decoder.decode([VideoComment].self, from: data) {
            self.comments = comments
        }
    }
    
    // MARK: - Cloud Sync
    
    func loadFromCloud() async {
        isLoading = true
        defer { isLoading = false }
        
        let firebaseComments = await FirebaseService.shared.loadComments()
        
        // Konvertiere CourseComment zu VideoComment
        let videoComments = firebaseComments.map { comment in
            VideoComment(
                id: comment.id,
                lessonId: comment.lessonId,
                courseId: comment.courseId,
                userId: comment.userId,
                userName: comment.userName,
                userGroup: comment.userGroup,
                content: comment.content,
                createdAt: comment.createdAt,
                updatedAt: comment.editedAt ?? comment.createdAt,
                editedAt: comment.editedAt,
                isDeleted: false,
                isHidden: comment.isHidden,
                hiddenReason: comment.hiddenReason,
                hiddenBy: comment.hiddenBy,
                replyToId: nil,
                likes: comment.likes,
                likedByUserIds: comment.likedByUserIds
            )
        }
        
        if !videoComments.isEmpty {
            self.comments = videoComments
            saveLocal()
            print("✅ \(comments.count) Kommentare von Firebase geladen")
        }
    }
    
    private func saveToCloud() async {
        // Konvertiere VideoComment zu CourseComment für Firebase
        let courseComments = comments.map { comment in
            CourseComment(
                id: comment.id,
                lessonId: comment.lessonId,
                courseId: comment.courseId,
                userId: comment.userId,
                userName: comment.userName,
                userGroup: comment.userGroup,
                content: comment.content,
                createdAt: comment.createdAt,
                editedAt: comment.editedAt,
                likes: comment.likes,
                likedByUserIds: comment.likedByUserIds,
                isHidden: comment.isHidden,
                hiddenReason: comment.hiddenReason,
                hiddenBy: comment.hiddenBy
            )
        }
        
        let success = await FirebaseService.shared.saveAllComments(courseComments)
        if success {
            print("✅ Kommentare zu Firebase gespeichert")
        }
    }
}
