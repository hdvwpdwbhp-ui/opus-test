import Foundation
import Combine
import FirebaseFirestore

@MainActor
class PartnerMatchingManager: ObservableObject {
    static let shared = PartnerMatchingManager()

    @Published var myProfile: PartnerProfile?
    @Published var potentialPartners: [PartnerProfile] = []
    @Published var myRequests: [PartnerRequest] = []
    @Published var receivedRequests: [PartnerRequest] = []
    @Published var matches: [PartnerMatchSummary] = []
    @Published var messages: [String: [PartnerMessage]] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private let profilesCollection = "partnerProfiles"
    private let requestsCollection = "partnerRequests"
    private let matchesCollection = "partnerMatches"
    private let blocksCollection = "partnerBlocks"
    private let reportsCollection = "partnerReports"
    private var listeners: [ListenerRegistration] = []
    private var messageListeners: [String: ListenerRegistration] = [:]
    private let onlineWindowSeconds: TimeInterval = 60 * 60
    private let lastActiveUpdateInterval: TimeInterval = 15 * 60
    private let maxRequestMessageLength = 500
    private let maxChatMessageLength = 800

    private init() {}

    deinit {
        listeners.forEach { $0.remove() }
        messageListeners.values.forEach { $0.remove() }
    }

    func loadInitialData(for userId: String) async {
        isLoading = true
        defer { isLoading = false }
        _ = await loadMyProfile(for: userId)
        await loadRequests(for: userId)
        await loadMatches(for: userId)
        await searchPartners(styles: nil, level: nil, city: nil, gender: nil, lookingForGender: nil, minAge: nil, maxAge: nil, onlineOnly: false, requiresMutualPreference: false, sort: .lastActive)
    }

    func loadMyProfile(for userId: String) async -> PartnerProfile? {
        do {
            let doc = try await db.collection(profilesCollection).document(userId).getDocument()
            if let profile = try? doc.data(as: PartnerProfile.self) {
                myProfile = profile
                return profile
            }
        } catch {
            errorMessage = "Profil konnte nicht geladen werden"
        }
        return nil
    }

    func createOrUpdateProfile(_ profile: PartnerProfile) async -> Bool {
        do {
            try db.collection(profilesCollection).document(profile.userId).setData(from: profile)
            myProfile = profile
            return true
        } catch {
            errorMessage = "Profil konnte nicht gespeichert werden"
            return false
        }
    }

    func setVisibility(_ visible: Bool) async -> Bool {
        guard var profile = myProfile else { return false }
        profile.isVisible = visible
        profile.lastActive = Date()
        profile.updatedAt = Date()
        return await createOrUpdateProfile(profile)
    }

    func searchPartners(
        styles: [DanceStyle]?,
        level: PartnerProfile.SkillLevel?,
        city: String?,
        gender: PartnerProfile.Gender?,
        lookingForGender: PartnerProfile.Gender?,
        minAge: Int?,
        maxAge: Int?,
        onlineOnly: Bool,
        requiresMutualPreference: Bool,
        sort: PartnerSortOption
    ) async {
        guard let currentUserId = UserManager.shared.currentUser?.id else { return }
        let blockedIds = await loadBlockedUserIds(for: currentUserId)
        var query: Query = db.collection(profilesCollection)
            .whereField("isVisible", isEqualTo: true)

        if let level = level {
            query = query.whereField("skillLevel", isEqualTo: level.rawValue)
        }

        if let city = city, !city.isEmpty {
            let normalized = city.lowercased().trimmingCharacters(in: .whitespaces)
            let end = normalized + "\u{f8ff}"
            query = query.whereField("cityLowercased", isGreaterThanOrEqualTo: normalized)
                .whereField("cityLowercased", isLessThanOrEqualTo: end)
        }

        if let styles = styles, !styles.isEmpty {
            let rawStyles = styles.map { $0.rawValue }
            query = query.whereField("danceStyles", arrayContainsAny: rawStyles)
        }

        do {
            let snapshot = try await query.limit(to: 50).getDocuments()
            let profiles = snapshot.documents.compactMap { doc -> PartnerProfile? in
                try? doc.data(as: PartnerProfile.self)
            }
            let myGender = myProfile?.gender
            var filtered = profiles.filter {
                $0.userId != currentUserId && !blockedIds.contains($0.userId)
            }

            if let gender = gender {
                filtered = filtered.filter { $0.gender == gender }
            }

            if let lookingForGender = lookingForGender, lookingForGender != .any {
                filtered = filtered.filter { $0.gender == lookingForGender }
            }

            if let minAge = minAge {
                filtered = filtered.filter { ($0.age ?? 0) >= minAge }
            }

            if let maxAge = maxAge {
                filtered = filtered.filter { ($0.age ?? Int.max) <= maxAge }
            }

            if onlineOnly {
                filtered = filtered.filter { Date().timeIntervalSince($0.lastActive) <= onlineWindowSeconds }
            }

            if requiresMutualPreference, let myGender = myGender {
                filtered = filtered.filter {
                    $0.lookingForGender == .any || $0.lookingForGender == myGender
                }
            }

            potentialPartners = sortProfiles(filtered, sort: sort)
        } catch {
            errorMessage = "Partner konnten nicht geladen werden"
        }
    }

    private func sortProfiles(_ profiles: [PartnerProfile], sort: PartnerSortOption) -> [PartnerProfile] {
        switch sort {
        case .lastActive:
            return profiles.sorted { $0.lastActive > $1.lastActive }
        case .newest:
            return profiles.sorted { $0.createdAt > $1.createdAt }
        case .ageAscending:
            return profiles.sorted { ($0.age ?? Int.max) < ($1.age ?? Int.max) }
        case .ageDescending:
            return profiles.sorted { ($0.age ?? 0) > ($1.age ?? 0) }
        }
    }

    func sendRequest(to partnerId: String, partnerName: String, message: String) async -> Bool {
        guard let myProfile = myProfile else { return false }
        guard partnerId != myProfile.userId else { return false }
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard trimmed.count <= maxRequestMessageLength else {
            errorMessage = "Nachricht zu lang"
            return false
        }

        if await isBlocked(userId: partnerId, by: myProfile.userId) { return false }
        if await hasExistingMatch(with: partnerId, userId: myProfile.userId) {
            errorMessage = "Ihr seid bereits gematcht"
            return false
        }
        if await hasPendingRequest(with: partnerId, userId: myProfile.userId) {
            errorMessage = "Es gibt bereits eine offene Anfrage"
            return false
        }

        let now = Date()
        let request = PartnerRequest(
            id: UUID().uuidString,
            fromUserId: myProfile.userId,
            fromUserName: myProfile.displayName,
            toUserId: partnerId,
            toUserName: partnerName,
            message: trimmed,
            status: .pending,
            createdAt: now,
            updatedAt: now
        )

        do {
            try db.collection(requestsCollection).document(request.id).setData(from: request)
            myRequests.append(request)
            await updateLastActiveIfNeeded()
            return true
        } catch {
            errorMessage = "Anfrage konnte nicht gesendet werden"
            return false
        }
    }

    func cancelRequest(_ requestId: String) async -> Bool {
        guard let index = myRequests.firstIndex(where: { $0.id == requestId }) else { return false }
        var request = myRequests[index]
        request.status = .cancelled
        request.updatedAt = Date()

        do {
            try db.collection(requestsCollection).document(requestId).setData(from: request)
            myRequests[index] = request
            return true
        } catch {
            errorMessage = "Anfrage konnte nicht storniert werden"
            return false
        }
    }

    func respondToRequest(_ requestId: String, accept: Bool) async -> Bool {
        guard let index = receivedRequests.firstIndex(where: { $0.id == requestId }) else { return false }
        var request = receivedRequests[index]
        request.status = accept ? .accepted : .declined
        request.updatedAt = Date()

        do {
            try db.collection(requestsCollection).document(requestId).setData(from: request)
            receivedRequests[index] = request

            if accept {
                _ = await createMatchIfNeeded(userIdA: request.fromUserId, userIdB: request.toUserId)
                await loadMatches(for: request.toUserId)
            }
            await updateLastActiveIfNeeded()
            return true
        } catch {
            errorMessage = "Antwort konnte nicht gespeichert werden"
            return false
        }
    }

    func removeMatch(matchId: String) async -> Bool {
        do {
            try await db.collection(matchesCollection).document(matchId).delete()
            matches.removeAll { $0.id == matchId }
            messages.removeValue(forKey: matchId)
            return true
        } catch {
            errorMessage = "Match konnte nicht entfernt werden"
            return false
        }
    }

    func loadRequests(for userId: String) async {
        do {
            let sent = try await db.collection(requestsCollection)
                .whereField("fromUserId", isEqualTo: userId)
                .order(by: "createdAt", descending: true)
                .getDocuments()

            let received = try await db.collection(requestsCollection)
                .whereField("toUserId", isEqualTo: userId)
                .order(by: "createdAt", descending: true)
                .getDocuments()

            myRequests = sent.documents.compactMap { try? $0.data(as: PartnerRequest.self) }
            receivedRequests = received.documents.compactMap { try? $0.data(as: PartnerRequest.self) }
        } catch {
            errorMessage = "Anfragen konnten nicht geladen werden"
        }
    }

    func loadMatches(for userId: String) async {
        do {
            let snapshot = try await db.collection(matchesCollection)
                .whereField("userIds", arrayContains: userId)
                .getDocuments()

            let matchDocs = snapshot.documents.compactMap { try? $0.data(as: PartnerMatch.self) }
            let partnerIds = matchDocs.compactMap { match in
                match.userIds.first { $0 != userId }
            }

            let partnerProfiles = await loadProfiles(for: partnerIds)
            let summaries = matchDocs.compactMap { match -> PartnerMatchSummary? in
                guard let partnerId = match.userIds.first(where: { $0 != userId }),
                      let partner = partnerProfiles[partnerId] else { return nil }
                return PartnerMatchSummary(id: match.id, match: match, partner: partner)
            }

            matches = summaries.sorted { ($0.match.lastMessageAt ?? $0.match.createdAt) > ($1.match.lastMessageAt ?? $1.match.createdAt) }
        } catch {
            errorMessage = "Matches konnten nicht geladen werden"
        }
    }

    func loadMessages(matchId: String) async {
        do {
            let snapshot = try await db.collection(matchesCollection)
                .document(matchId)
                .collection("messages")
                .order(by: "createdAt")
                .limit(to: 200)
                .getDocuments()
            messages[matchId] = snapshot.documents.compactMap { try? $0.data(as: PartnerMessage.self) }
        } catch {
            errorMessage = "Nachrichten konnten nicht geladen werden"
        }
    }

    func startListeningForMessages(matchId: String) {
        if messageListeners[matchId] != nil { return }
        let listener = db.collection(matchesCollection)
            .document(matchId)
            .collection("messages")
            .order(by: "createdAt")
            .limit(to: 200)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self = self, let snapshot = snapshot else { return }
                let items = snapshot.documents.compactMap { try? $0.data(as: PartnerMessage.self) }
                self.messages[matchId] = items
            }
        messageListeners[matchId] = listener
    }
    
    func stopListeningForMessages(matchId: String) {
        messageListeners[matchId]?.remove()
        messageListeners.removeValue(forKey: matchId)
    }

    func sendMessage(matchId: String, content: String) async -> Bool {
        guard let userId = UserManager.shared.currentUser?.id else { return false }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= maxChatMessageLength else { return false }
        let message = PartnerMessage(
            id: UUID().uuidString,
            matchId: matchId,
            senderId: userId,
            content: trimmed,
            createdAt: Date(),
            readBy: [userId]
        )
        do {
            let messageRef = db.collection(matchesCollection)
                .document(matchId)
                .collection("messages")
                .document(message.id)
            try messageRef.setData(from: message)
            try await db.collection(matchesCollection).document(matchId).updateData([
                "lastMessageAt": Date()
            ])
            return true
        } catch {
            errorMessage = "Nachricht konnte nicht gesendet werden"
            return false
        }
    }

    func markMessagesAsRead(matchId: String) async {
        guard let userId = UserManager.shared.currentUser?.id else { return }
        do {
            let snapshot = try await db.collection(matchesCollection)
                .document(matchId)
                .collection("messages")
                .whereField("readBy", arrayContains: userId)
                .getDocuments()
            if snapshot.documents.isEmpty { return }
            let batch = db.batch()
            snapshot.documents.forEach { doc in
                batch.updateData(["readBy": FieldValue.arrayUnion([userId])], forDocument: doc.reference)
            }
            try await batch.commit()
        } catch {
            errorMessage = "Nachrichten konnten nicht aktualisiert werden"
        }
    }

    func blockUser(_ blockedId: String) async -> Bool {
        guard let blockerId = UserManager.shared.currentUser?.id else { return false }
        let block = PartnerBlock(
            id: "\(blockerId)_\(blockedId)",
            blockerId: blockerId,
            blockedId: blockedId,
            createdAt: Date()
        )

        do {
            try db.collection(blocksCollection).document(block.id).setData(from: block)
            _ = await cleanupRelation(userIdA: blockerId, userIdB: blockedId)
            potentialPartners.removeAll { $0.userId == blockedId }
            matches.removeAll { $0.partner.userId == blockedId }
            receivedRequests.removeAll { $0.fromUserId == blockedId }
            myRequests.removeAll { $0.toUserId == blockedId }
            await updateLastActiveIfNeeded()
            return true
        } catch {
            errorMessage = "User konnte nicht blockiert werden"
            return false
        }
    }

    func reportUser(reportedUserId: String, reason: String, details: String) async -> Bool {
        guard let reporterId = UserManager.shared.currentUser?.id else { return false }
        let report = PartnerReport(
            id: UUID().uuidString,
            reporterId: reporterId,
            reportedUserId: reportedUserId,
            reason: reason,
            details: details,
            createdAt: Date(),
            status: .open
        )

        do {
            try db.collection(reportsCollection).document(report.id).setData(from: report)
            return true
        } catch {
            errorMessage = "Meldung konnte nicht gespeichert werden"
            return false
        }
    }

    private func createMatchIfNeeded(userIdA: String, userIdB: String) async -> PartnerMatch? {
        let sorted = [userIdA, userIdB].sorted()
        let matchId = "match_\(sorted.joined(separator: "_"))"
        let matchRef = db.collection(matchesCollection).document(matchId)

        do {
            let doc = try await matchRef.getDocument()
            if let existing = try? doc.data(as: PartnerMatch.self) {
                return existing
            }
            let match = PartnerMatch(id: matchId, userIds: sorted, createdAt: Date(), lastMessageAt: nil)
            try matchRef.setData(from: match)
            return match
        } catch {
            errorMessage = "Match konnte nicht erstellt werden"
            return nil
        }
    }

    private func hasExistingMatch(with partnerId: String, userId: String) async -> Bool {
        let sorted = [partnerId, userId].sorted()
        let matchId = "match_\(sorted.joined(separator: "_"))"
        do {
            let doc = try await db.collection(matchesCollection).document(matchId).getDocument()
            return doc.exists
        } catch {
            return false
        }
    }

    private func hasPendingRequest(with partnerId: String, userId: String) async -> Bool {
        do {
            let sentSnap = try await db.collection(requestsCollection)
                .whereField("fromUserId", isEqualTo: userId)
                .whereField("toUserId", isEqualTo: partnerId)
                .whereField("status", isEqualTo: PartnerRequest.RequestStatus.pending.rawValue)
                .limit(to: 1)
                .getDocuments()
            if !sentSnap.isEmpty { return true }

            let receivedSnap = try await db.collection(requestsCollection)
                .whereField("fromUserId", isEqualTo: partnerId)
                .whereField("toUserId", isEqualTo: userId)
                .whereField("status", isEqualTo: PartnerRequest.RequestStatus.pending.rawValue)
                .limit(to: 1)
                .getDocuments()
            return !receivedSnap.isEmpty
        } catch {
            return false
        }
    }

    private func cleanupRelation(userIdA: String, userIdB: String) async -> Bool {
        let sorted = [userIdA, userIdB].sorted()
        let matchId = "match_\(sorted.joined(separator: "_"))"
        do {
            try await db.collection(matchesCollection).document(matchId).delete()
        } catch {
            // Match kann fehlen; kein Abbruch
        }

        do {
            let sent = try await db.collection(requestsCollection)
                .whereField("fromUserId", isEqualTo: userIdA)
                .whereField("toUserId", isEqualTo: userIdB)
                .getDocuments()

            let received = try await db.collection(requestsCollection)
                .whereField("fromUserId", isEqualTo: userIdB)
                .whereField("toUserId", isEqualTo: userIdA)
                .getDocuments()

            let batch = db.batch()
            (sent.documents + received.documents).forEach { batch.deleteDocument($0.reference) }
            try await batch.commit()
            return true
        } catch {
            return false
        }
    }

    private func updateLastActiveIfNeeded() async {
        guard var profile = myProfile else { return }
        let now = Date()
        if now.timeIntervalSince(profile.lastActive) < lastActiveUpdateInterval {
            return
        }
        profile.lastActive = now
        profile.updatedAt = now
        _ = await createOrUpdateProfile(profile)
    }

    private func loadProfiles(for userIds: [String]) async -> [String: PartnerProfile] {
        var result: [String: PartnerProfile] = [:]
        guard !userIds.isEmpty else { return result }

        for chunk in userIds.chunked(into: 10) {
            do {
                let snapshot = try await db.collection(profilesCollection)
                    .whereField("userId", in: chunk)
                    .getDocuments()
                for doc in snapshot.documents {
                    if let profile = try? doc.data(as: PartnerProfile.self) {
                        result[profile.userId] = profile
                    }
                }
            } catch {
                errorMessage = "Profile konnten nicht geladen werden"
            }
        }
        return result
    }

    private func loadBlockedUserIds(for userId: String) async -> Set<String> {
        do {
            let snapshot = try await db.collection(blocksCollection)
                .whereField("blockerId", isEqualTo: userId)
                .getDocuments()
            let blocked = snapshot.documents.compactMap { doc -> String? in
                (try? doc.data(as: PartnerBlock.self))?.blockedId
            }
            return Set(blocked)
        } catch {
            return []
        }
    }

    private func isBlocked(userId: String, by blockerId: String) async -> Bool {
        let blockId = "\(blockerId)_\(userId)"
        do {
            let doc = try await db.collection(blocksCollection).document(blockId).getDocument()
            return doc.exists
        } catch {
            return false
        }
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [] }
        var result: [[Element]] = []
        var index = startIndex
        while index < endIndex {
            let end = self.index(index, offsetBy: size, limitedBy: endIndex) ?? endIndex
            result.append(Array(self[index..<end]))
            index = end
        }
        return result
    }
}
