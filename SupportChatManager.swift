//
//  SupportChatManager.swift
//  Tanzen mit Tatiana Drexler
//
//  Service für Support-Chat zwischen Usern und Admin
//

import Foundation
import Combine

@MainActor
class SupportChatManager: ObservableObject {
    static let shared = SupportChatManager()
    
    @Published var conversations: [SupportConversation] = []
    @Published var messages: [String: [SupportMessage]] = [:] // conversationId -> messages
    @Published var isLoading = false
    @Published var unreadCount = 0
    
    private let localConversationsKey = "local_support_conversations"
    private let localMessagesKey = "local_support_messages"
    
    private init() {
        loadLocal()
    }
    
    // MARK: - Conversations
    
    /// Erstellt eine neue Konversation (User)
    func createConversation(subject: String, initialMessage: String) async -> SupportConversation? {
        guard let user = UserManager.shared.currentUser else { return nil }
        
        let conversation = SupportConversation.create(
            userId: user.id,
            userName: user.name,
            userEmail: user.email,
            subject: subject
        )
        
        conversations.append(conversation)
        
        // Erste Nachricht hinzufügen
        let message = SupportMessage.create(
            conversationId: conversation.id,
            senderId: user.id,
            senderName: user.name,
            senderGroup: user.group,
            content: initialMessage
        )
        
        if messages[conversation.id] == nil {
            messages[conversation.id] = []
        }
        messages[conversation.id]?.append(message)
        
        saveLocal()
        await saveToCloud()
        updateUnreadCount()
        
        // Push NUR an Admin und Support-Rolle senden
        await sendNotificationToSupportTeam(
            title: "Neue Support-Anfrage",
            body: "\(user.name): \(subject)"
        )
        
        return conversation
    }
    
    /// Sendet eine Benachrichtigung nur an Admin und Support-Mitglieder
    private func sendNotificationToSupportTeam(title: String, body: String) async {
        let currentUser = UserManager.shared.currentUser
        
        // Nur senden wenn der aktuelle User KEIN Admin/Support ist
        // (damit Admin/Support nicht sich selbst benachrichtigt)
        if currentUser?.group.isAdmin == true || currentUser?.group.isSupport == true {
            return
        }
        
        // Lokale Benachrichtigung für Admin/Support-Geräte
        await PushNotificationService.shared.sendLocalNotification(
            title: title,
            body: body
        )
    }
    
    /// Sendet eine Nachricht
    func sendMessage(conversationId: String, content: String) async -> Bool {
        guard let user = UserManager.shared.currentUser else { return false }
        guard let index = conversations.firstIndex(where: { $0.id == conversationId }) else { return false }
        
        let message = SupportMessage.create(
            conversationId: conversationId,
            senderId: user.id,
            senderName: user.name,
            senderGroup: user.group,
            content: content
        )
        
        if messages[conversationId] == nil {
            messages[conversationId] = []
        }
        messages[conversationId]?.append(message)
        
        // Konversation aktualisieren
        conversations[index].lastMessageAt = Date()
        if conversations[index].status == .resolved {
            conversations[index].status = .open
        }
        
        saveLocal()
        await saveToCloud()
        
        // Push an den anderen Teilnehmer senden
        _ = conversations[index] // Conversation wird hier für zukünftige Features verwendet
        if user.group.isAdmin || user.group.isSupport {
            // Admin/Support antwortet -> Push an User (normaler User bekommt Nachricht)
            await PushNotificationService.shared.sendLocalNotification(
                title: "Neue Nachricht vom Support",
                body: String(content.prefix(50)) + (content.count > 50 ? "..." : "")
            )
        } else {
            // User antwortet -> Push NUR an Admin/Support Team
            await sendNotificationToSupportTeam(
                title: "Neue Support-Nachricht von \(user.name)",
                body: String(content.prefix(50)) + (content.count > 50 ? "..." : "")
            )
        }
        
        return true
    }
    
    /// Markiert Nachrichten als gelesen
    func markAsRead(conversationId: String) async {
        guard let user = UserManager.shared.currentUser else { return }
        
        if var msgs = messages[conversationId] {
            for i in msgs.indices {
                if msgs[i].senderId != user.id {
                    msgs[i].isRead = true
                }
            }
            messages[conversationId] = msgs
        }
        
        saveLocal()
        await saveToCloud()
        updateUnreadCount()
    }
    
    /// Ändert den Status einer Konversation (Admin)
    func updateStatus(conversationId: String, status: SupportConversation.ConversationStatus) async -> Bool {
        guard UserManager.shared.isAdmin else { return false }
        guard let index = conversations.firstIndex(where: { $0.id == conversationId }) else { return false }
        
        conversations[index].status = status
        
        saveLocal()
        await saveToCloud()
        return true
    }
    
    /// Weist sich selbst eine Konversation zu (Admin)
    func assignToSelf(conversationId: String) async -> Bool {
        guard let admin = UserManager.shared.currentUser, admin.group.isAdmin else { return false }
        guard let index = conversations.firstIndex(where: { $0.id == conversationId }) else { return false }
        
        conversations[index].assignedAdminId = admin.id
        conversations[index].status = .inProgress
        
        saveLocal()
        await saveToCloud()
        return true
    }
    
    // MARK: - Queries
    
    /// Konversationen für den aktuellen User
    var myConversations: [SupportConversation] {
        guard let user = UserManager.shared.currentUser else { return [] }
        if user.group.isAdmin {
            return conversations.sorted { $0.lastMessageAt > $1.lastMessageAt }
        }
        return conversations.filter { $0.userId == user.id }.sorted { $0.lastMessageAt > $1.lastMessageAt }
    }
    
    /// Offene Konversationen (Admin)
    var openConversations: [SupportConversation] {
        conversations.filter { $0.status == .open || $0.status == .inProgress }
            .sorted { $0.lastMessageAt > $1.lastMessageAt }
    }
    
    /// Nachrichten für eine Konversation
    func messagesFor(conversationId: String) -> [SupportMessage] {
        (messages[conversationId] ?? []).sorted { $0.timestamp < $1.timestamp }
    }
    
    /// Aktualisiert die Anzahl ungelesener Nachrichten
    private func updateUnreadCount() {
        guard let user = UserManager.shared.currentUser else {
            unreadCount = 0
            return
        }
        
        var count = 0
        for conversation in myConversations {
            if let msgs = messages[conversation.id] {
                count += msgs.filter { !$0.isRead && $0.senderId != user.id }.count
            }
        }
        unreadCount = count
    }
    
    // MARK: - Local Storage
    
    private func saveLocal() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        if let data = try? encoder.encode(conversations) {
            UserDefaults.standard.set(data, forKey: localConversationsKey)
        }
        
        if let data = try? encoder.encode(messages) {
            UserDefaults.standard.set(data, forKey: localMessagesKey)
        }
    }
    
    private func loadLocal() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        if let data = UserDefaults.standard.data(forKey: localConversationsKey),
           let convs = try? decoder.decode([SupportConversation].self, from: data) {
            self.conversations = convs
        }
        
        if let data = UserDefaults.standard.data(forKey: localMessagesKey),
           let msgs = try? decoder.decode([String: [SupportMessage]].self, from: data) {
            self.messages = msgs
        }
        
        updateUnreadCount()
    }
    
    // MARK: - Cloud Sync
    
    func loadFromCloud() async {
        isLoading = true
        defer { isLoading = false }
        
        let firebaseConversations = await FirebaseService.shared.loadSupportConversations()
        let firebaseMessages = await FirebaseService.shared.loadAllSupportMessages()
        
        if !firebaseConversations.isEmpty {
            self.conversations = firebaseConversations
            self.messages = firebaseMessages
            saveLocal()
            updateUnreadCount()
            print("✅ Support-Chats von Firebase geladen")
        }
    }
    
    private func saveToCloud() async {
        let success = await FirebaseService.shared.saveAllSupportData(
            conversations: conversations,
            messages: messages
        )
        if success {
            print("✅ Support-Chats zu Firebase gespeichert")
        }
    }
}
