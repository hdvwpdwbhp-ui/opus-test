//
//  LiveClassManager.swift
//  Tanzen mit Tatiana Drexler
//
//  Service for live class events, bookings, and chat
//

import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

@MainActor
class LiveClassManager: ObservableObject {
    static let shared = LiveClassManager()

    @Published var events: [LiveClassEvent] = []
    @Published var myBookings: [LiveClassBooking] = []
    @Published var trainerSettings: [String: LiveClassTrainerSettings] = [:]
    @Published var globalSettings: LiveClassGlobalSettings = .defaults()
    @Published var chatMessages: [String: [LiveClassChatMessage]] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private var eventListener: ListenerRegistration?
    private var bookingListener: ListenerRegistration?
    private var chatListeners: [String: ListenerRegistration] = [:]

    private let eventsCollection = "liveClassEvents"
    private let bookingsCollection = "liveClassBookings"
    private let trainerSettingsCollection = "liveClassTrainerSettings"
    private let globalSettingsCollection = "liveClassGlobalSettings"
    private let chatCollectionRoot = "liveClassChatMessages"

    private init() {}

    deinit {
        eventListener?.remove()
        bookingListener?.remove()
        chatListeners.values.forEach { $0.remove() }
    }

    func startListeningToEvents() {
        eventListener?.remove()
        eventListener = db.collection(eventsCollection)
            .order(by: "startTime", descending: false)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self = self, let snapshot = snapshot else { return }
                let items = snapshot.documents.compactMap { try? $0.data(as: LiveClassEvent.self) }
                self.events = items
            }
    }

    func startListeningToBookings(userId: String) {
        bookingListener?.remove()
        bookingListener = db.collection(bookingsCollection)
            .whereField("userId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self = self, let snapshot = snapshot else { return }
                let items = snapshot.documents.compactMap { try? $0.data(as: LiveClassBooking.self) }
                self.myBookings = items
            }
    }

    func loadTrainerSettings(trainerId: String) async {
        do {
            let doc = try await db.collection(trainerSettingsCollection).document(trainerId).getDocument()
            if let data = try? doc.data(as: LiveClassTrainerSettings.self) {
                trainerSettings[trainerId] = data
            }
        } catch {
            errorMessage = "Trainer-Einstellungen konnten nicht geladen werden"
        }
    }

    func loadGlobalSettings() async {
        do {
            let doc = try await db.collection(globalSettingsCollection).document("global").getDocument()
            if let data = try? doc.data(as: LiveClassGlobalSettings.self) {
                globalSettings = data
            }
        } catch {
            errorMessage = "Globale Einstellungen konnten nicht geladen werden"
        }
    }

    func sendChatMessage(eventId: String, content: String) async -> Bool {
        guard let user = UserManager.shared.currentUser else { return false }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let message = LiveClassChatMessage.create(eventId: eventId, user: user, content: trimmed)
        do {
            let ref = db.collection(chatCollectionRoot).document(eventId).collection("messages").document(message.id)
            try ref.setData(from: message)
            return true
        } catch {
            errorMessage = "Nachricht konnte nicht gesendet werden"
            return false
        }
    }

    func startListeningToChat(eventId: String) {
        if chatListeners[eventId] != nil { return }
        let listener = db.collection(chatCollectionRoot)
            .document(eventId)
            .collection("messages")
            .order(by: "createdAt")
            .limit(to: 300)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self = self, let snapshot = snapshot else { return }
                let items = snapshot.documents.compactMap { try? $0.data(as: LiveClassChatMessage.self) }
                self.chatMessages[eventId] = items
            }
        chatListeners[eventId] = listener
    }

    func stopListeningToChat(eventId: String) {
        chatListeners[eventId]?.remove()
        chatListeners.removeValue(forKey: eventId)
    }

    func createEvent(payload: [String: Any]) async -> Bool {
        return await callFunction(path: "createLiveClassEvent", payload: payload)
    }

    func updateEvent(payload: [String: Any]) async -> Bool {
        return await callFunction(path: "updateLiveClassEvent", payload: payload)
    }

    func bookEvent(eventId: String) async -> Bool {
        return await callFunction(path: "bookEventWithCoins", payload: ["eventId": eventId])
    }

    func requestJoinToken(eventId: String) async -> JoinTokenResponse? {
        guard let url = LiveClassAPIConfig.endpoint("getJoinToken") else { return nil }
        guard let token = await fetchIdToken() else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["eventId": eventId])

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoded = try JSONDecoder().decode(JoinTokenResponse.self, from: data)
            return decoded
        } catch {
            errorMessage = "Join-Token konnte nicht geladen werden"
            return nil
        }
    }

    func deleteChatMessage(eventId: String, messageId: String) async -> Bool {
        return await callFunction(path: "deleteLiveClassChatMessage", payload: ["eventId": eventId, "messageId": messageId])
    }

    private func callFunction(path: String, payload: [String: Any]) async -> Bool {
        guard let url = LiveClassAPIConfig.endpoint(path) else { return false }
        guard let token = await fetchIdToken() else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            if json?["error"] != nil {
                errorMessage = "Server-Fehler"
                return false
            }
            return true
        } catch {
            errorMessage = "Server-Verbindung fehlgeschlagen"
            return false
        }
    }

    private func fetchIdToken() async -> String? {
        guard let user = Auth.auth().currentUser else { return nil }
        do {
            return try await user.getIDToken()
        } catch {
            errorMessage = "Auth-Token fehlgeschlagen"
            return nil
        }
    }
}

struct JoinTokenResponse: Codable {
    let token: String
    let channelName: String
    let uid: Int
    let expiresAt: Int
}
