import Foundation
import FirebaseFirestore

struct TrainerChatConversation: Identifiable, Equatable {
    let id: String
    let userId: String
    let userName: String
    let trainerId: String
    let trainerName: String
    var createdAt: Date
    var lastMessageAt: Date
    var isClosed: Bool

    static func from(_ data: [String: Any], id: String) -> TrainerChatConversation? {
        guard
            let userId = data["userId"] as? String,
            let userName = data["userName"] as? String,
            let trainerId = data["trainerId"] as? String,
            let trainerName = data["trainerName"] as? String
        else { return nil }

        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let lastMessageAt = (data["lastMessageAt"] as? Timestamp)?.dateValue() ?? createdAt
        let isClosed = data["isClosed"] as? Bool ?? false

        return TrainerChatConversation(
            id: id,
            userId: userId,
            userName: userName,
            trainerId: trainerId,
            trainerName: trainerName,
            createdAt: createdAt,
            lastMessageAt: lastMessageAt,
            isClosed: isClosed
        )
    }

    var dictionary: [String: Any] {
        [
            "userId": userId,
            "userName": userName,
            "trainerId": trainerId,
            "trainerName": trainerName,
            "createdAt": Timestamp(date: createdAt),
            "lastMessageAt": Timestamp(date: lastMessageAt),
            "isClosed": isClosed
        ]
    }
}

enum TrainerChatSenderRole: String {
    case user
    case trainer
}

struct TrainerChatMessage: Identifiable, Equatable {
    let id: String
    let conversationId: String
    let senderId: String
    let senderName: String
    let senderRole: TrainerChatSenderRole
    let content: String
    let createdAt: Date
    var isRead: Bool

    static func from(_ data: [String: Any], id: String) -> TrainerChatMessage? {
        guard
            let conversationId = data["conversationId"] as? String,
            let senderId = data["senderId"] as? String,
            let senderName = data["senderName"] as? String,
            let senderRoleRaw = data["senderRole"] as? String,
            let content = data["content"] as? String
        else { return nil }

        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let isRead = data["isRead"] as? Bool ?? false
        let senderRole = TrainerChatSenderRole(rawValue: senderRoleRaw) ?? .user

        return TrainerChatMessage(
            id: id,
            conversationId: conversationId,
            senderId: senderId,
            senderName: senderName,
            senderRole: senderRole,
            content: content,
            createdAt: createdAt,
            isRead: isRead
        )
    }

    var dictionary: [String: Any] {
        [
            "conversationId": conversationId,
            "senderId": senderId,
            "senderName": senderName,
            "senderRole": senderRole.rawValue,
            "content": content,
            "createdAt": Timestamp(date: createdAt),
            "isRead": isRead
        ]
    }
}
