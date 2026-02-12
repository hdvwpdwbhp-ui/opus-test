import Foundation
import Combine
import FirebaseFirestore

@MainActor
class TrainerChatManager: ObservableObject {
    static let shared = TrainerChatManager()

    @Published var conversations: [TrainerChatConversation] = []
    @Published var messages: [String: [TrainerChatMessage]] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private let conversationsCollection = "trainerChats"

    private var messageListeners: [String: ListenerRegistration] = [:]

    private init() {}

    func getOrCreateConversation(userId: String, userName: String, trainerId: String, trainerName: String) async -> TrainerChatConversation? {
        isLoading = true
        defer { isLoading = false }

        do {
            let snapshot = try await db.collection(conversationsCollection)
                .whereField("userId", isEqualTo: userId)
                .whereField("trainerId", isEqualTo: trainerId)
                .limit(to: 1)
                .getDocuments()

            if let doc = snapshot.documents.first,
               let convo = TrainerChatConversation.from(doc.data(), id: doc.documentID) {
                return convo
            }

            let now = Date()
            let newId = UUID().uuidString
            let convo = TrainerChatConversation(
                id: newId,
                userId: userId,
                userName: userName,
                trainerId: trainerId,
                trainerName: trainerName,
                createdAt: now,
                lastMessageAt: now,
                isClosed: false
            )

            try await db.collection(conversationsCollection).document(newId).setData(convo.dictionary)
            return convo
        } catch {
            errorMessage = "Chat konnte nicht erstellt werden"
            return nil
        }
    }

    func loadConversationsForUser(userId: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let snapshot = try await db.collection(conversationsCollection)
                .whereField("userId", isEqualTo: userId)
                .order(by: "lastMessageAt", descending: true)
                .getDocuments()
            conversations = snapshot.documents.compactMap { TrainerChatConversation.from($0.data(), id: $0.documentID) }
        } catch {
            errorMessage = "Chats konnten nicht geladen werden"
        }
    }

    func loadConversationsForTrainer(trainerId: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let snapshot = try await db.collection(conversationsCollection)
                .whereField("trainerId", isEqualTo: trainerId)
                .order(by: "lastMessageAt", descending: true)
                .getDocuments()
            conversations = snapshot.documents.compactMap { TrainerChatConversation.from($0.data(), id: $0.documentID) }
        } catch {
            errorMessage = "Chats konnten nicht geladen werden"
        }
    }

    func sendMessage(conversation: TrainerChatConversation, content: String) async -> Bool {
        guard let user = UserManager.shared.currentUser else { return false }

        let role: TrainerChatSenderRole = (user.group == .trainer || user.group.isAdmin) ? .trainer : .user
        let msg = TrainerChatMessage(
            id: UUID().uuidString,
            conversationId: conversation.id,
            senderId: user.id,
            senderName: user.name,
            senderRole: role,
            content: content,
            createdAt: Date(),
            isRead: false
        )

        do {
            let messagesRef = db.collection(conversationsCollection)
                .document(conversation.id)
                .collection("messages")

            try await messagesRef.document(msg.id).setData(msg.dictionary)

            try await db.collection(conversationsCollection)
                .document(conversation.id)
                .updateData([
                    "lastMessageAt": Timestamp(date: Date())
                ])

            if messages[conversation.id] == nil { messages[conversation.id] = [] }
            messages[conversation.id]?.append(msg)
            return true
        } catch {
            errorMessage = "Nachricht konnte nicht gesendet werden"
            return false
        }
    }

    func startListening(conversationId: String) {
        if messageListeners[conversationId] != nil { return }

        let listener = db.collection(conversationsCollection)
            .document(conversationId)
            .collection("messages")
            .order(by: "createdAt")
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self = self, let snapshot = snapshot else { return }
                let items = snapshot.documents.compactMap { TrainerChatMessage.from($0.data(), id: $0.documentID) }
                self.messages[conversationId] = items
            }

        messageListeners[conversationId] = listener
    }

    func stopListening(conversationId: String) {
        messageListeners[conversationId]?.remove()
        messageListeners.removeValue(forKey: conversationId)
    }
}
