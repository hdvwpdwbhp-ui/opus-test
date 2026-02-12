//
//  FirebaseService.swift
//  Tanzen mit Tatiana Drexler
//
//  Firebase Backend Service für Echtzeit-Synchronisation
//  Ersetzt JSONBin.io für alle Cloud-Daten
//

import Foundation
import Combine
import FirebaseFirestore

@MainActor
class FirebaseService: ObservableObject {
    static let shared = FirebaseService()
    
    private let db = Firestore.firestore()
    
    @Published var isConnected = true
    @Published var isSyncing = false
    @Published var lastSync: Date?
    @Published var error: String?
    
    // Listeners
    private var coursesListener: ListenerRegistration?
    private var usersListener: ListenerRegistration?
    private var chatsListener: ListenerRegistration?
    private var commentsListener: ListenerRegistration?
    private var settingsListener: ListenerRegistration?
    
    private init() {
        print("🔥 Firebase Service initialisiert")
    }
    
    // MARK: - Collection Names
    private enum Collections {
        static let courses = "courses"
        static let lessons = "lessons"
        static let users = "users"
        static let editorAccounts = "editorAccounts"
        static let supportChats = "supportChats"
        static let supportMessages = "supportMessages"
        static let comments = "comments"
        static let appSettings = "appSettings"
        static let redemptionKeys = "redemptionKeys"
        static let changeRequests = "changeRequests"
    }
    
    // MARK: - Courses
    
    func loadCourses() async -> [Course] {
        isSyncing = true
        defer { isSyncing = false }
        
        do {
            let snapshot = try await db.collection("courses").getDocuments()
            let courses = snapshot.documents.compactMap { doc -> Course? in
                try? doc.data(as: Course.self)
            }
            lastSync = Date()
            print("🔥 \(courses.count) Kurse von Firebase geladen")
            return courses
        } catch {
            self.error = error.localizedDescription
            print("❌ Firebase Fehler beim Laden: \(error)")
            return []
        }
    }
    
    func saveCourse(_ course: Course) async -> Bool {
        isSyncing = true
        defer { isSyncing = false }
        
        do {
            try db.collection("courses").document(course.id).setData(from: course)
            print("🔥 Kurs gespeichert: \(course.title)")
            return true
        } catch {
            self.error = error.localizedDescription
            print("❌ Firebase Fehler beim Speichern: \(error)")
            return false
        }
    }
    
    func deleteCourse(_ courseId: String) async -> Bool {
        do {
            try await db.collection("courses").document(courseId).delete()
            let lessonsSnapshot = try await db.collection("lessons").document(courseId).collection("items").getDocuments()
            for doc in lessonsSnapshot.documents {
                try await doc.reference.delete()
            }
            print("🔥 Kurs gelöscht: \(courseId)")
            return true
        } catch {
            self.error = error.localizedDescription
            print("❌ Firebase Fehler beim Löschen: \(error)")
            return false
        }
    }
    
    // MARK: - Lessons
    
    func loadLessons(for courseId: String) async -> [Lesson] {
        do {
            let snapshot = try await db.collection("lessons").document(courseId).collection("items").getDocuments()
            let lessons = snapshot.documents.compactMap { doc -> Lesson? in
                try? doc.data(as: Lesson.self)
            }
            return lessons.sorted { $0.orderIndex < $1.orderIndex }
        } catch {
            print("❌ Firebase Fehler beim Laden der Lektionen: \(error)")
            return []
        }
    }
    
    func saveLessons(_ lessons: [Lesson], for courseId: String) async -> Bool {
        do {
            let oldSnapshot = try await db.collection("lessons").document(courseId).collection("items").getDocuments()
            for doc in oldSnapshot.documents {
                try await doc.reference.delete()
            }
            
            for lesson in lessons {
                try db.collection("lessons").document(courseId).collection("items").document(lesson.id).setData(from: lesson)
            }
            print("🔥 \(lessons.count) Lektionen gespeichert")
            return true
        } catch {
            self.error = error.localizedDescription
            print("❌ Firebase Fehler: \(error)")
            return false
        }
    }
    
    // MARK: - Realtime
    
    func startCoursesListener(onUpdate: @escaping ([Course]) -> Void) {
        coursesListener?.remove()
        
        coursesListener = db.collection("courses").addSnapshotListener { snapshot, error in
            guard let documents = snapshot?.documents else { return }
            let courses = documents.compactMap { doc -> Course? in
                try? doc.data(as: Course.self)
            }
            print("🔥 Echtzeit-Update: \(courses.count) Kurse")
            onUpdate(courses)
        }
    }
    
    func stopCoursesListener() {
        coursesListener?.remove()
        coursesListener = nil
    }
    
    func saveAllData(courses: [Course], lessons: [String: [Lesson]]) async -> Bool {
        isSyncing = true
        defer { isSyncing = false }
        
        do {
            for course in courses {
                try db.collection("courses").document(course.id).setData(from: course)
            }
            
            for (courseId, courseLessons) in lessons {
                for lesson in courseLessons {
                    try db.collection("lessons").document(courseId).collection("items").document(lesson.id).setData(from: lesson)
                }
            }
            
            lastSync = Date()
            print("🔥 Alle Daten hochgeladen: \(courses.count) Kurse")
            return true
        } catch {
            self.error = error.localizedDescription
            print("❌ Firebase Bulk-Upload Fehler: \(error)")
            return false
        }
    }
    
    // MARK: - Users
    
    func loadUsers() async -> [AppUser] {
        do {
            let snapshot = try await db.collection(Collections.users).getDocuments()
            let users = snapshot.documents.compactMap { doc -> AppUser? in
                try? doc.data(as: AppUser.self)
            }
            print("🔥 \(users.count) Users von Firebase geladen")
            return users
        } catch {
            print("❌ Firebase Fehler beim Laden der Users: \(error)")
            return []
        }
    }
    
    func saveUser(_ user: AppUser) async -> Bool {
        do {
            try db.collection(Collections.users).document(user.id).setData(from: user)
            print("🔥 User gespeichert: \(user.name)")
            return true
        } catch {
            print("❌ Firebase Fehler beim Speichern des Users: \(error)")
            return false
        }
    }
    
    func saveAllUsers(_ users: [AppUser]) async -> Bool {
        do {
            for user in users {
                try db.collection(Collections.users).document(user.id).setData(from: user)
            }
            print("🔥 \(users.count) Users gespeichert")
            return true
        } catch {
            print("❌ Firebase Fehler beim Speichern der Users: \(error)")
            return false
        }
    }
    
    func deleteUser(_ userId: String) async -> Bool {
        do {
            try await db.collection(Collections.users).document(userId).delete()
            print("🔥 User gelöscht: \(userId)")
            return true
        } catch {
            print("❌ Firebase Fehler beim Löschen des Users: \(error)")
            return false
        }
    }
    
    func startUsersListener(onUpdate: @escaping ([AppUser]) -> Void) {
        usersListener?.remove()
        usersListener = db.collection(Collections.users).addSnapshotListener { snapshot, error in
            guard let documents = snapshot?.documents else { return }
            let users = documents.compactMap { doc -> AppUser? in
                try? doc.data(as: AppUser.self)
            }
            print("🔥 Echtzeit-Update: \(users.count) Users")
            onUpdate(users)
        }
    }
    
    func stopUsersListener() {
        usersListener?.remove()
        usersListener = nil
    }
    
    // MARK: - Editor Accounts
    
    func loadEditorAccounts() async -> [EditorAccount] {
        do {
            let snapshot = try await db.collection(Collections.editorAccounts).getDocuments()
            let accounts = snapshot.documents.compactMap { doc -> EditorAccount? in
                try? doc.data(as: EditorAccount.self)
            }
            print("🔥 \(accounts.count) Editor-Accounts von Firebase geladen")
            return accounts
        } catch {
            print("❌ Firebase Fehler beim Laden der Editor-Accounts: \(error)")
            return []
        }
    }
    
    func saveEditorAccount(_ account: EditorAccount) async -> Bool {
        do {
            try db.collection(Collections.editorAccounts).document(account.id).setData(from: account)
            print("🔥 Editor-Account gespeichert: \(account.username)")
            return true
        } catch {
            print("❌ Firebase Fehler beim Speichern des Editor-Accounts: \(error)")
            return false
        }
    }
    
    func saveAllEditorAccounts(_ accounts: [EditorAccount]) async -> Bool {
        do {
            for account in accounts {
                try db.collection(Collections.editorAccounts).document(account.id).setData(from: account)
            }
            print("🔥 \(accounts.count) Editor-Accounts gespeichert")
            return true
        } catch {
            print("❌ Firebase Fehler beim Speichern der Editor-Accounts: \(error)")
            return false
        }
    }
    
    func deleteEditorAccount(_ accountId: String) async -> Bool {
        do {
            try await db.collection(Collections.editorAccounts).document(accountId).delete()
            print("🔥 Editor-Account gelöscht: \(accountId)")
            return true
        } catch {
            print("❌ Firebase Fehler beim Löschen des Editor-Accounts: \(error)")
            return false
        }
    }
    
    // MARK: - Support Chat
    
    func loadSupportConversations() async -> [SupportConversation] {
        do {
            let snapshot = try await db.collection(Collections.supportChats).getDocuments()
            let conversations = snapshot.documents.compactMap { doc -> SupportConversation? in
                try? doc.data(as: SupportConversation.self)
            }
            print("🔥 \(conversations.count) Support-Konversationen geladen")
            return conversations
        } catch {
            print("❌ Firebase Fehler beim Laden der Konversationen: \(error)")
            return []
        }
    }
    
    func loadSupportMessages(for conversationId: String) async -> [SupportMessage] {
        do {
            let snapshot = try await db.collection(Collections.supportMessages)
                .whereField("conversationId", isEqualTo: conversationId)
                .order(by: "timestamp")
                .getDocuments()
            let messages = snapshot.documents.compactMap { doc -> SupportMessage? in
                try? doc.data(as: SupportMessage.self)
            }
            return messages
        } catch {
            print("❌ Firebase Fehler beim Laden der Nachrichten: \(error)")
            return []
        }
    }
    
    func loadAllSupportMessages() async -> [String: [SupportMessage]] {
        do {
            let snapshot = try await db.collection(Collections.supportMessages).getDocuments()
            var messagesByConversation: [String: [SupportMessage]] = [:]
            
            for doc in snapshot.documents {
                if let message = try? doc.data(as: SupportMessage.self) {
                    if messagesByConversation[message.conversationId] == nil {
                        messagesByConversation[message.conversationId] = []
                    }
                    messagesByConversation[message.conversationId]?.append(message)
                }
            }
            
            // Sortieren nach Timestamp
            for key in messagesByConversation.keys {
                messagesByConversation[key]?.sort { $0.timestamp < $1.timestamp }
            }
            
            return messagesByConversation
        } catch {
            print("❌ Firebase Fehler beim Laden aller Nachrichten: \(error)")
            return [:]
        }
    }
    
    func saveSupportConversation(_ conversation: SupportConversation) async -> Bool {
        do {
            try db.collection(Collections.supportChats).document(conversation.id).setData(from: conversation)
            return true
        } catch {
            print("❌ Firebase Fehler beim Speichern der Konversation: \(error)")
            return false
        }
    }
    
    func saveSupportMessage(_ message: SupportMessage) async -> Bool {
        do {
            try db.collection(Collections.supportMessages).document(message.id).setData(from: message)
            return true
        } catch {
            print("❌ Firebase Fehler beim Speichern der Nachricht: \(error)")
            return false
        }
    }
    
    func saveAllSupportData(conversations: [SupportConversation], messages: [String: [SupportMessage]]) async -> Bool {
        do {
            for conversation in conversations {
                try db.collection(Collections.supportChats).document(conversation.id).setData(from: conversation)
            }
            for (_, msgs) in messages {
                for message in msgs {
                    try db.collection(Collections.supportMessages).document(message.id).setData(from: message)
                }
            }
            print("🔥 Support-Daten gespeichert")
            return true
        } catch {
            print("❌ Firebase Fehler beim Speichern der Support-Daten: \(error)")
            return false
        }
    }
    
    func startChatsListener(onUpdate: @escaping ([SupportConversation]) -> Void) {
        chatsListener?.remove()
        chatsListener = db.collection(Collections.supportChats).addSnapshotListener { snapshot, error in
            guard let documents = snapshot?.documents else { return }
            let conversations = documents.compactMap { doc -> SupportConversation? in
                try? doc.data(as: SupportConversation.self)
            }
            onUpdate(conversations)
        }
    }
    
    func stopChatsListener() {
        chatsListener?.remove()
        chatsListener = nil
    }
    
    // MARK: - Comments
    
    func loadComments() async -> [CourseComment] {
        do {
            let snapshot = try await db.collection(Collections.comments).getDocuments()
            let comments = snapshot.documents.compactMap { doc -> CourseComment? in
                try? doc.data(as: CourseComment.self)
            }
            print("🔥 \(comments.count) Kommentare geladen")
            return comments
        } catch {
            print("❌ Firebase Fehler beim Laden der Kommentare: \(error)")
            return []
        }
    }
    
    func saveComment(_ comment: CourseComment) async -> Bool {
        do {
            try db.collection(Collections.comments).document(comment.id).setData(from: comment)
            return true
        } catch {
            print("❌ Firebase Fehler beim Speichern des Kommentars: \(error)")
            return false
        }
    }
    
    func saveAllComments(_ comments: [CourseComment]) async -> Bool {
        do {
            for comment in comments {
                try db.collection(Collections.comments).document(comment.id).setData(from: comment)
            }
            print("🔥 \(comments.count) Kommentare gespeichert")
            return true
        } catch {
            print("❌ Firebase Fehler beim Speichern der Kommentare: \(error)")
            return false
        }
    }
    
    func deleteComment(_ commentId: String) async -> Bool {
        do {
            try await db.collection(Collections.comments).document(commentId).delete()
            return true
        } catch {
            print("❌ Firebase Fehler beim Löschen des Kommentars: \(error)")
            return false
        }
    }
    
    func startCommentsListener(onUpdate: @escaping ([CourseComment]) -> Void) {
        commentsListener?.remove()
        commentsListener = db.collection(Collections.comments).addSnapshotListener { snapshot, error in
            guard let documents = snapshot?.documents else { return }
            let comments = documents.compactMap { doc -> CourseComment? in
                try? doc.data(as: CourseComment.self)
            }
            onUpdate(comments)
        }
    }
    
    func stopCommentsListener() {
        commentsListener?.remove()
        commentsListener = nil
    }
    
    // MARK: - App Settings
    
    func loadAppSettings() async -> AppSettings? {
        do {
            let doc = try await db.collection(Collections.appSettings).document("global").getDocument()
            let settings = try? doc.data(as: AppSettings.self)
            print("🔥 App-Einstellungen geladen")
            return settings
        } catch {
            print("❌ Firebase Fehler beim Laden der Einstellungen: \(error)")
            return nil
        }
    }
    
    func saveAppSettings(_ settings: AppSettings) async -> Bool {
        do {
            try db.collection(Collections.appSettings).document("global").setData(from: settings)
            print("🔥 App-Einstellungen gespeichert")
            return true
        } catch {
            print("❌ Firebase Fehler beim Speichern der Einstellungen: \(error)")
            return false
        }
    }
    
    func startSettingsListener(onUpdate: @escaping (AppSettings?) -> Void) {
        settingsListener?.remove()
        settingsListener = db.collection(Collections.appSettings).document("global").addSnapshotListener { snapshot, error in
            guard let doc = snapshot else { return }
            let settings = try? doc.data(as: AppSettings.self)
            onUpdate(settings)
        }
    }
    
    func stopSettingsListener() {
        settingsListener?.remove()
        settingsListener = nil
    }
    
    // MARK: - Redemption Keys
    
    func loadRedemptionKeys() async -> [RedemptionKey] {
        do {
            let snapshot = try await db.collection(Collections.redemptionKeys).getDocuments()
            let keys = snapshot.documents.compactMap { doc -> RedemptionKey? in
                try? doc.data(as: RedemptionKey.self)
            }
            print("🔥 \(keys.count) Einlöse-Codes geladen")
            return keys
        } catch {
            print("❌ Firebase Fehler beim Laden der Einlöse-Codes: \(error)")
            return []
        }
    }
    
    func saveRedemptionKey(_ key: RedemptionKey) async -> Bool {
        do {
            try db.collection(Collections.redemptionKeys).document(key.id).setData(from: key)
            return true
        } catch {
            print("❌ Firebase Fehler beim Speichern des Einlöse-Codes: \(error)")
            return false
        }
    }
    
    func saveAllRedemptionKeys(_ keys: [RedemptionKey]) async -> Bool {
        do {
            for key in keys {
                try db.collection(Collections.redemptionKeys).document(key.id).setData(from: key)
            }
            print("🔥 \(keys.count) Einlöse-Codes gespeichert")
            return true
        } catch {
            print("❌ Firebase Fehler beim Speichern der Einlöse-Codes: \(error)")
            return false
        }
    }
    
    func deleteRedemptionKey(_ keyId: String) async -> Bool {
        do {
            try await db.collection(Collections.redemptionKeys).document(keyId).delete()
            return true
        } catch {
            print("❌ Firebase Fehler beim Löschen des Einlöse-Codes: \(error)")
            return false
        }
    }
    
    // MARK: - Change Requests
    
    func loadChangeRequests() async -> [ChangeRequest] {
        do {
            let snapshot = try await db.collection(Collections.changeRequests).getDocuments()
            let requests = snapshot.documents.compactMap { doc -> ChangeRequest? in
                try? doc.data(as: ChangeRequest.self)
            }
            print("🔥 \(requests.count) Änderungsanfragen geladen")
            return requests
        } catch {
            print("❌ Firebase Fehler beim Laden der Änderungsanfragen: \(error)")
            return []
        }
    }
    
    func saveChangeRequest(_ request: ChangeRequest) async -> Bool {
        do {
            try db.collection(Collections.changeRequests).document(request.id).setData(from: request)
            return true
        } catch {
            print("❌ Firebase Fehler beim Speichern der Änderungsanfrage: \(error)")
            return false
        }
    }
    
    func saveAllChangeRequests(_ requests: [ChangeRequest]) async -> Bool {
        do {
            for request in requests {
                try db.collection(Collections.changeRequests).document(request.id).setData(from: request)
            }
            print("🔥 \(requests.count) Änderungsanfragen gespeichert")
            return true
        } catch {
            print("❌ Firebase Fehler beim Speichern der Änderungsanfragen: \(error)")
            return false
        }
    }
    
    func deleteChangeRequest(_ requestId: String) async -> Bool {
        do {
            try await db.collection(Collections.changeRequests).document(requestId).delete()
            return true
        } catch {
            print("❌ Firebase Fehler beim Löschen der Änderungsanfrage: \(error)")
            return false
        }
    }
    
    // MARK: - Private Lesson Bookings
    
    func loadPrivateLessonBookings() async -> [PrivateLessonBooking] {
        do {
            let snapshot = try await db.collection("privateLessonBookings").getDocuments()
            let bookings = snapshot.documents.compactMap { doc -> PrivateLessonBooking? in
                try? doc.data(as: PrivateLessonBooking.self)
            }
            print("🔥 \(bookings.count) Privatstunden-Buchungen geladen")
            return bookings
        } catch {
            print("❌ Firebase Fehler beim Laden der Buchungen: \(error)")
            return []
        }
    }
    
    func savePrivateLessonBooking(_ booking: PrivateLessonBooking) async -> Bool {
        do {
            try db.collection("privateLessonBookings").document(booking.id).setData(from: booking)
            print("🔥 Buchung \(booking.bookingNumber) gespeichert")
            return true
        } catch {
            print("❌ Firebase Fehler beim Speichern der Buchung: \(error)")
            return false
        }
    }
    
    func saveAllPrivateLessonBookings(_ bookings: [PrivateLessonBooking]) async -> Bool {
        do {
            for booking in bookings {
                try db.collection("privateLessonBookings").document(booking.id).setData(from: booking)
            }
            print("🔥 \(bookings.count) Privatstunden-Buchungen gespeichert")
            return true
        } catch {
            print("❌ Firebase Fehler beim Speichern der Buchungen: \(error)")
            return false
        }
    }
    
    func loadBookingsForTrainer(_ trainerId: String) async -> [PrivateLessonBooking] {
        do {
            let snapshot = try await db.collection("privateLessonBookings")
                .whereField("trainerId", isEqualTo: trainerId)
                .getDocuments()
            let bookings = snapshot.documents.compactMap { doc -> PrivateLessonBooking? in
                try? doc.data(as: PrivateLessonBooking.self)
            }
            return bookings.sorted { $0.createdAt > $1.createdAt }
        } catch {
            print("❌ Firebase Fehler beim Laden der Trainer-Buchungen: \(error)")
            return []
        }
    }
    
    func loadBookingByNumber(_ bookingNumber: String) async -> PrivateLessonBooking? {
        do {
            let snapshot = try await db.collection("privateLessonBookings")
                .whereField("bookingNumber", isEqualTo: bookingNumber)
                .limit(to: 1)
                .getDocuments()
            return snapshot.documents.first.flatMap { try? $0.data(as: PrivateLessonBooking.self) }
        } catch {
            print("❌ Firebase Fehler beim Laden der Buchung: \(error)")
            return nil
        }
    }
    
    // MARK: - Stop All Listeners
    
    func stopAllListeners() {
        stopCoursesListener()
        stopUsersListener()
        stopChatsListener()
        stopCommentsListener()
        stopSettingsListener()
    }
}
