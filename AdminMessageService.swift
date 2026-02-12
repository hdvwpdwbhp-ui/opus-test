//
//  AdminMessageService.swift
//  Tanzen mit Tatiana Drexler
//
//  Service für Admin-Nachrichten an User als Popup
//

import Foundation
import FirebaseFirestore
import Combine

// MARK: - Admin Message Model

struct AdminMessage: Codable, Identifiable {
    let id: String
    let title: String
    let message: String
    let fromAdminId: String
    let fromAdminName: String
    let toUserId: String
    let toUserName: String
    let createdAt: Date
    var readAt: Date?
    var dismissed: Bool
    var messageType: AdminMessageType
    var actionUrl: String?  // Optional: Link zu einem Bereich in der App
    
    var isRead: Bool { readAt != nil }
    
    init(
        title: String,
        message: String,
        fromAdminId: String,
        fromAdminName: String,
        toUserId: String,
        toUserName: String,
        messageType: AdminMessageType = .info,
        actionUrl: String? = nil
    ) {
        self.id = UUID().uuidString
        self.title = title
        self.message = message
        self.fromAdminId = fromAdminId
        self.fromAdminName = fromAdminName
        self.toUserId = toUserId
        self.toUserName = toUserName
        self.createdAt = Date()
        self.readAt = nil
        self.dismissed = false
        self.messageType = messageType
        self.actionUrl = actionUrl
    }
}

enum AdminMessageType: String, Codable, CaseIterable {
    case info = "info"
    case warning = "warning"
    case alert = "alert"
    case promotion = "promotion"
    case update = "update"
    
    var icon: String {
        switch self {
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .alert: return "bell.fill"
        case .promotion: return "gift.fill"
        case .update: return "arrow.up.circle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .info: return "blue"
        case .warning: return "orange"
        case .alert: return "red"
        case .promotion: return "purple"
        case .update: return "green"
        }
    }
    
    var displayName: String {
        switch self {
        case .info: return "Information"
        case .warning: return "Warnung"
        case .alert: return "Wichtig"
        case .promotion: return "Angebot"
        case .update: return "Update"
        }
    }
}

// MARK: - Admin Message Manager

@MainActor
class AdminMessageManager: ObservableObject {
    static let shared = AdminMessageManager()
    
    @Published var unreadMessages: [AdminMessage] = []
    @Published var currentPopupMessage: AdminMessage?
    @Published var allMessages: [AdminMessage] = []  // Für Admin-Dashboard
    @Published var isLoading = false
    
    private let db = Firestore.firestore()
    private let collection = "adminMessages"
    private var listener: ListenerRegistration?
    
    private init() {}
    
    // MARK: - User Functions
    
    /// Startet Listener für Nachrichten an den aktuellen User
    func startListening(for userId: String) {
        listener?.remove()
        
        listener = db.collection(collection)
            .whereField("toUserId", isEqualTo: userId)
            .whereField("dismissed", isEqualTo: false)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let documents = snapshot?.documents else { return }
                
                Task { @MainActor in
                    self.unreadMessages = documents.compactMap { doc in
                        try? doc.data(as: AdminMessage.self)
                    }
                    
                    // Zeige die neueste ungelesene Nachricht als Popup
                    if let newest = self.unreadMessages.first(where: { !$0.isRead }) {
                        self.currentPopupMessage = newest
                    }
                }
            }
    }
    
    /// Stoppt den Listener
    func stopListening() {
        listener?.remove()
        listener = nil
        unreadMessages = []
        currentPopupMessage = nil
    }
    
    /// Markiert eine Nachricht als gelesen
    func markAsRead(_ messageId: String) async {
        do {
            try await db.collection(collection).document(messageId).updateData([
                "readAt": Date()
            ])
            
            if let index = unreadMessages.firstIndex(where: { $0.id == messageId }) {
                unreadMessages[index].readAt = Date()
            }
        } catch {
            print("❌ Fehler beim Markieren als gelesen: \(error)")
        }
    }
    
    /// Schließt eine Nachricht (wird nicht mehr angezeigt)
    func dismissMessage(_ messageId: String) async {
        do {
            try await db.collection(collection).document(messageId).updateData([
                "dismissed": true,
                "readAt": Date()
            ])
            
            unreadMessages.removeAll { $0.id == messageId }
            if currentPopupMessage?.id == messageId {
                currentPopupMessage = nil
                // Zeige nächste ungelesene Nachricht
                if let next = unreadMessages.first(where: { !$0.isRead }) {
                    currentPopupMessage = next
                }
            }
        } catch {
            print("❌ Fehler beim Schließen der Nachricht: \(error)")
        }
    }
    
    // MARK: - Admin Functions
    
    /// Sendet eine Nachricht an einen User (nur Admin)
    func sendMessage(
        to user: AppUser,
        title: String,
        message: String,
        type: AdminMessageType = .info,
        actionUrl: String? = nil
    ) async -> Bool {
        guard let admin = UserManager.shared.currentUser,
              UserManager.shared.isAdmin else {
            print("❌ Nur Admins können Nachrichten senden")
            return false
        }
        
        let adminMessage = AdminMessage(
            title: title,
            message: message,
            fromAdminId: admin.id,
            fromAdminName: admin.name,
            toUserId: user.id,
            toUserName: user.name,
            messageType: type,
            actionUrl: actionUrl
        )
        
        do {
            try db.collection(collection).document(adminMessage.id).setData(from: adminMessage)
            print("✅ Nachricht an \(user.name) gesendet")
            return true
        } catch {
            print("❌ Fehler beim Senden: \(error)")
            return false
        }
    }
    
    /// Sendet eine Nachricht an alle User (Broadcast)
    func sendBroadcast(
        title: String,
        message: String,
        type: AdminMessageType = .info,
        toUserGroup: UserGroup? = nil
    ) async -> Int {
        guard let admin = UserManager.shared.currentUser,
              UserManager.shared.isAdmin else {
            return 0
        }
        
        let users: [AppUser]
        if let group = toUserGroup {
            users = UserManager.shared.allUsers.filter { $0.group == group }
        } else {
            users = UserManager.shared.allUsers.filter { $0.group == .user }
        }
        
        var sentCount = 0
        for user in users {
            let success = await sendMessage(to: user, title: title, message: message, type: type)
            if success { sentCount += 1 }
        }
        
        return sentCount
    }
    
    /// Lädt alle Nachrichten (für Admin-Dashboard)
    func loadAllMessages() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let snapshot = try await db.collection(collection)
                .order(by: "createdAt", descending: true)
                .limit(to: 100)
                .getDocuments()
            
            allMessages = snapshot.documents.compactMap { doc in
                try? doc.data(as: AdminMessage.self)
            }
        } catch {
            print("❌ Fehler beim Laden aller Nachrichten: \(error)")
        }
    }
    
    /// Löscht eine Nachricht (Admin)
    func deleteMessage(_ messageId: String) async -> Bool {
        guard UserManager.shared.isAdmin else { return false }
        
        do {
            try await db.collection(collection).document(messageId).delete()
            allMessages.removeAll { $0.id == messageId }
            return true
        } catch {
            print("❌ Fehler beim Löschen: \(error)")
            return false
        }
    }
}
