//
//  VideoReviewManager.swift
//  Tanzen mit Tatiana Drexler
//
//  Service für Video-Einreichungen und Trainer-Reviews
//

import Foundation
import Combine
import FirebaseFirestore
import FirebaseStorage
import AVFoundation

@MainActor
class VideoReviewManager: ObservableObject {
    static let shared = VideoReviewManager()
    
    // MARK: - Published Properties
    
    @Published var trainerSettings: [String: TrainerReviewSettings] = [:]
    @Published var submissions: [VideoSubmission] = []
    @Published var feedbacks: [String: ReviewFeedback] = [:] // submissionId -> Feedback
    @Published var uploadProgress: [String: VideoUploadProgress] = [:] // submissionId -> Progress
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    private var listeners: [ListenerRegistration] = []
    
    private let settingsCollection = "trainerReviewSettings"
    private let submissionsCollection = "videoSubmissions"
    private let feedbacksCollection = "reviewFeedbacks"
    private let videosStoragePath = "video_submissions"
    private let audioStoragePath = "review_audio"
    private let trainerVideosPath = "trainer_examples"
    
    // MARK: - Initialization
    
    private init() {
        loadLocalCache()
    }
    
    deinit {
        listeners.forEach { $0.remove() }
    }
    
    // MARK: - Trainer Settings (Admin-only for prices)
    
    /// Lädt alle Trainer-Review-Settings
    func loadAllTrainerSettings() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let snapshot = try await db.collection(settingsCollection).getDocuments()
            var settings: [String: TrainerReviewSettings] = [:]
            
            for doc in snapshot.documents {
                if let setting = try? doc.data(as: TrainerReviewSettings.self) {
                    settings[setting.trainerId] = setting
                }
            }
            
            self.trainerSettings = settings
            saveLocalCache()
            print("✅ \(settings.count) Trainer-Review-Settings geladen")
        } catch {
            print("❌ Fehler beim Laden der Trainer-Settings: \(error)")
            errorMessage = "Fehler beim Laden der Einstellungen"
        }
    }
    
    /// Lädt Settings für einen einzelnen Trainer
    func loadSettingsForTrainer(_ trainerId: String) async -> TrainerReviewSettings? {
        do {
            let doc = try await db.collection(settingsCollection).document(trainerId).getDocument()
            if let settings = try? doc.data(as: TrainerReviewSettings.self) {
                trainerSettings[trainerId] = settings
                return settings
            }
        } catch {
            print("❌ Fehler beim Laden der Settings für Trainer \(trainerId): \(error)")
        }
        return nil
    }
    
    /// Trainer aktiviert/deaktiviert Video-Submissions (Trainer darf nur dieses Flag ändern)
    func toggleAcceptsSubmissions(trainerId: String, accepts: Bool) async -> Bool {
        guard let user = UserManager.shared.currentUser,
              user.id == trainerId || user.group.isAdmin else {
            errorMessage = "Keine Berechtigung"
            return false
        }
        
        var settings = trainerSettings[trainerId] ?? TrainerReviewSettings(trainerId: trainerId)
        settings.acceptsVideoSubmissions = accepts
        settings.updatedAt = Date()
        
        return await saveTrainerSettings(settings)
    }
    
    /// Admin setzt Preis und Limits für einen Trainer
    func updateTrainerPricing(
        trainerId: String,
        pricePerMinute: Decimal,
        minMinutes: Int,
        maxMinutes: Int,
        avgDeliveryDays: Int,
        description: String
    ) async -> Bool {
        guard let user = UserManager.shared.currentUser, user.group.isAdmin else {
            errorMessage = "Nur Admins können Preise festlegen"
            return false
        }
        
        var settings = trainerSettings[trainerId] ?? TrainerReviewSettings(trainerId: trainerId)
        settings.reviewPricePerMinute = pricePerMinute
        settings.minMinutes = minMinutes
        settings.maxMinutes = maxMinutes
        settings.avgDeliveryDays = avgDeliveryDays
        settings.description = description
        settings.updatedAt = Date()
        settings.updatedBy = user.id
        
        return await saveTrainerSettings(settings)
    }
    
    private func saveTrainerSettings(_ settings: TrainerReviewSettings) async -> Bool {
        do {
            try db.collection(settingsCollection).document(settings.trainerId).setData(from: settings)
            trainerSettings[settings.trainerId] = settings
            saveLocalCache()
            print("✅ Trainer-Review-Settings gespeichert")
            return true
        } catch {
            print("❌ Fehler beim Speichern der Settings: \(error)")
            errorMessage = "Fehler beim Speichern"
            return false
        }
    }
    
    /// Gibt alle Trainer zurück, die Video-Submissions akzeptieren
    func trainersAcceptingSubmissions() -> [AppUser] {
        let acceptingTrainerIds = trainerSettings
            .filter { $0.value.acceptsVideoSubmissions }
            .keys
        
        return UserManager.shared.allUsers.filter {
            $0.group == .trainer && acceptingTrainerIds.contains($0.id)
        }
    }
    
    // MARK: - Video Submissions (User)
    
    /// Erstellt eine neue Video-Einreichung (Draft)
    func createSubmission(
        trainerId: String,
        requestedMinutes: Int,
        userNotes: String
    ) async -> VideoSubmission? {
        guard let user = UserManager.shared.currentUser else {
            errorMessage = "Du musst eingeloggt sein"
            return nil
        }
        
        guard let settings = trainerSettings[trainerId],
              settings.acceptsVideoSubmissions else {
            errorMessage = "Dieser Trainer akzeptiert keine Video-Einreichungen"
            return nil
        }
        
        // Minuten validieren
        let minutes = max(settings.minMinutes, min(settings.maxMinutes, requestedMinutes))
        
        guard let trainer = UserManager.shared.allUsers.first(where: { $0.id == trainerId }) else {
            errorMessage = "Trainer nicht gefunden"
            return nil
        }
        
        let submission = VideoSubmission(
            userId: user.id,
            userName: user.name,
            userEmail: user.email,
            trainerId: trainerId,
            trainerName: trainer.name,
            requestedMinutes: minutes,
            reviewPricePerMinute: settings.reviewPricePerMinute,
            userNotes: userNotes
        )
        
        // In Firestore speichern
        do {
            try db.collection(submissionsCollection).document(submission.id).setData(from: submission)
            submissions.append(submission)
            saveLocalCache()
            print("✅ Submission erstellt: \(submission.submissionNumber)")
            return submission
        } catch {
            print("❌ Fehler beim Erstellen der Submission: \(error)")
            errorMessage = "Fehler beim Erstellen der Einreichung"
            return nil
        }
    }
    
    /// Aktualisiert den Status einer Einreichung
    func updateSubmissionStatus(_ submissionId: String, to status: VideoSubmissionStatus) async -> Bool {
        guard var submission = submissions.first(where: { $0.id == submissionId }) else {
            return false
        }
        
        guard submission.updateStatus(to: status) else {
            errorMessage = "Ungültiger Statuswechsel"
            return false
        }
        
        do {
            try db.collection(submissionsCollection).document(submissionId).setData(from: submission)
            if let index = submissions.firstIndex(where: { $0.id == submissionId }) {
                submissions[index] = submission
            }
            
            // Push-Benachrichtigung senden
            await sendStatusNotification(submission: submission, newStatus: status)
            
            saveLocalCache()
            return true
        } catch {
            print("❌ Fehler beim Status-Update: \(error)")
            return false
        }
    }
    
    /// Markiert Zahlung als abgeschlossen (nach StoreKit Purchase)
    func markAsPaid(submissionId: String, transactionId: String) async -> Bool {
        guard var submission = submissions.first(where: { $0.id == submissionId }) else {
            return false
        }
        
        submission.paymentStatus = .completed
        submission.storeKitTransactionId = transactionId
        submission.paidAt = Date()
        
        guard submission.updateStatus(to: .paid) else {
            return false
        }
        
        do {
            try db.collection(submissionsCollection).document(submissionId).setData(from: submission)
            if let index = submissions.firstIndex(where: { $0.id == submissionId }) {
                submissions[index] = submission
            }
            saveLocalCache()
            
            // Benachrichtigung
            await PushNotificationService.shared.sendLocalNotification(
                title: "✅ Zahlung erfolgreich",
                body: "Du kannst jetzt dein Video hochladen."
            )
            
            return true
        } catch {
            print("❌ Fehler beim Markieren als bezahlt: \(error)")
            return false
        }
    }
    
    // MARK: - Video Upload
    
    /// Lädt ein Video für eine Einreichung hoch
    func uploadVideo(
        submissionId: String,
        videoURL: URL,
        onProgress: @escaping (Double) -> Void
    ) async -> Result<String, Error> {
        guard var submission = submissions.first(where: { $0.id == submissionId }) else {
            return .failure(VideoReviewError.submissionNotFound)
        }
        
        guard submission.submissionStatus == .paid else {
            return .failure(VideoReviewError.invalidStatus)
        }
        
        // Video validieren
        let validation = await validateVideo(at: videoURL)
        guard validation.isValid else {
            return .failure(VideoReviewError.validationFailed(validation.errors.joined(separator: ", ")))
        }
        
        // Status auf "uploading" setzen
        _ = await updateSubmissionStatus(submissionId, to: .uploading)
        
        // Upload starten
        let storagePath = "\(videosStoragePath)/\(submission.userId)/\(submissionId).mp4"
        let storageRef = storage.reference().child(storagePath)
        
        // Upload-Progress tracken
        var progress = VideoUploadProgress(
            id: UUID().uuidString,
            submissionId: submissionId,
            bytesUploaded: 0,
            totalBytes: 0,
            state: .preparing
        )
        uploadProgress[submissionId] = progress
        
        do {
            // Dateigröße ermitteln
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: videoURL.path)
            let fileSize = fileAttributes[.size] as? Int64 ?? 0
            progress.totalBytes = fileSize
            progress.state = .uploading
            uploadProgress[submissionId] = progress
            
            // Metadaten
            let metadata = StorageMetadata()
            metadata.contentType = "video/mp4"
            metadata.customMetadata = [
                "submissionId": submissionId,
                "userId": submission.userId,
                "trainerId": submission.trainerId
            ]
            
            // Upload Task
            let uploadTask = storageRef.putFile(from: videoURL, metadata: metadata)
            
            // Progress Observer
            uploadTask.observe(.progress) { snapshot in
                if let bytesTransferred = snapshot.progress?.completedUnitCount,
                   let totalBytes = snapshot.progress?.totalUnitCount {
                    Task { @MainActor in
                        self.uploadProgress[submissionId]?.bytesUploaded = bytesTransferred
                        self.uploadProgress[submissionId]?.totalBytes = totalBytes
                        onProgress(Double(bytesTransferred) / Double(totalBytes))
                    }
                }
            }
            
            // Auf Completion warten
            try await awaitUpload(uploadTask)
            
            // Download-URL holen
            let downloadURL = try await storageRef.downloadURL()
            
            // Video-Dauer ermitteln
            let asset = AVAsset(url: videoURL)
            let duration = try await asset.load(.duration)
            let durationSeconds = CMTimeGetSeconds(duration)
            
            // Submission aktualisieren
            submission.userVideoURL = downloadURL.absoluteString
            submission.userVideoDurationSeconds = durationSeconds
            submission.userVideoSizeBytes = fileSize
            submission.uploadedAt = Date()
            
            try db.collection(submissionsCollection).document(submissionId).setData(from: submission)
            if let index = submissions.firstIndex(where: { $0.id == submissionId }) {
                submissions[index] = submission
            }
            
            // Status auf "submitted" setzen
            _ = await updateSubmissionStatus(submissionId, to: .submitted)
            
            // Progress abschließen
            uploadProgress[submissionId]?.state = .completed
            
            saveLocalCache()
            
            // Benachrichtigung an Trainer
            await PushNotificationService.shared.sendLocalNotification(
                title: "📹 Neues Video zur Bewertung",
                body: "\(submission.userName) hat ein Video eingereicht (\(submission.requestedMinutes) Min.)"
            )
            
            return .success(downloadURL.absoluteString)
            
        } catch {
            uploadProgress[submissionId]?.state = .failed
            uploadProgress[submissionId]?.error = error.localizedDescription
            
            // Zurück auf "paid" setzen für Retry
            _ = await updateSubmissionStatus(submissionId, to: .paid)
            
            print("❌ Upload fehlgeschlagen: \(error)")
            return .failure(error)
        }
    }
    
    /// Validiert ein Video vor dem Upload
    func validateVideo(at url: URL) async -> VideoValidationResult {
        do {
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = fileAttributes[.size] as? Int64 ?? 0
            
            let asset = AVAsset(url: url)
            let duration = try await asset.load(.duration)
            let durationSeconds = CMTimeGetSeconds(duration)
            
            let fileExtension = url.pathExtension
            
            return VideoUploadLimits.validate(
                fileSize: fileSize,
                duration: durationSeconds,
                format: fileExtension
            )
        } catch {
            return VideoValidationResult(isValid: false, errors: ["Fehler beim Lesen der Video-Datei"])
        }
    }
    
    // MARK: - Trainer: Review & Feedback
    
    /// Lädt alle Einreichungen für einen Trainer
    func loadSubmissionsForTrainer(_ trainerId: String) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let snapshot = try await db.collection(submissionsCollection)
                .whereField("trainerId", isEqualTo: trainerId)
                .order(by: "createdAt", descending: true)
                .getDocuments()
            
            var trainerSubmissions: [VideoSubmission] = []
            for doc in snapshot.documents {
                if let submission = try? doc.data(as: VideoSubmission.self) {
                    trainerSubmissions.append(submission)
                }
            }
            
            // Bestehende Submissions aktualisieren/ergänzen
            for submission in trainerSubmissions {
                if let index = submissions.firstIndex(where: { $0.id == submission.id }) {
                    submissions[index] = submission
                } else {
                    submissions.append(submission)
                }
            }
            
            saveLocalCache()
            print("✅ \(trainerSubmissions.count) Einreichungen für Trainer geladen")
        } catch {
            print("❌ Fehler beim Laden der Einreichungen: \(error)")
            errorMessage = "Fehler beim Laden der Einreichungen"
        }
    }
    
    /// Lädt Einreichungen für einen User
    func loadSubmissionsForUser(_ userId: String) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let snapshot = try await db.collection(submissionsCollection)
                .whereField("userId", isEqualTo: userId)
                .order(by: "createdAt", descending: true)
                .getDocuments()
            
            var userSubmissions: [VideoSubmission] = []
            for doc in snapshot.documents {
                if let submission = try? doc.data(as: VideoSubmission.self) {
                    userSubmissions.append(submission)
                }
            }
            
            // Bestehende Submissions aktualisieren/ergänzen
            for submission in userSubmissions {
                if let index = submissions.firstIndex(where: { $0.id == submission.id }) {
                    submissions[index] = submission
                } else {
                    submissions.append(submission)
                }
            }
            
            saveLocalCache()
            print("✅ \(userSubmissions.count) Einreichungen für User geladen")
        } catch {
            print("❌ Fehler beim Laden der Einreichungen: \(error)")
        }
    }
    
    /// Trainer beginnt mit dem Review
    func startReview(submissionId: String) async -> Bool {
        guard let user = UserManager.shared.currentUser else { return false }
        guard let submission = submissions.first(where: { $0.id == submissionId }) else { return false }
        guard user.id == submission.trainerId || user.group.isAdmin else { return false }
        guard submission.submissionStatus == .submitted else { return false }
        
        // Feedback-Objekt erstellen falls noch nicht vorhanden
        if feedbacks[submissionId] == nil {
            let feedback = ReviewFeedback(submissionId: submissionId, trainerId: user.id)
            do {
                try db.collection(feedbacksCollection).document(feedback.id).setData(from: feedback)
                feedbacks[submissionId] = feedback
                
                // Feedback-ID in Submission speichern
                try await db.collection(submissionsCollection).document(submissionId)
                    .updateData(["feedbackId": feedback.id])
                
                if let index = submissions.firstIndex(where: { $0.id == submissionId }) {
                    submissions[index].feedbackId = feedback.id
                }
            } catch {
                print("❌ Fehler beim Erstellen des Feedbacks: \(error)")
                return false
            }
        }
        
        return await updateSubmissionStatus(submissionId, to: .inReview)
    }
    
    /// Speichert Feedback-Änderungen (Draft)
    func saveFeedbackDraft(_ feedback: ReviewFeedback) async -> Bool {
        guard let user = UserManager.shared.currentUser else { return false }
        guard user.id == feedback.trainerId || user.group.isAdmin else { return false }
        
        var updatedFeedback = feedback
        updatedFeedback.updatedAt = Date()
        updatedFeedback.isDraft = true
        
        do {
            try db.collection(feedbacksCollection).document(feedback.id).setData(from: updatedFeedback)
            feedbacks[feedback.submissionId] = updatedFeedback
            saveLocalCache()
            return true
        } catch {
            print("❌ Fehler beim Speichern des Feedback-Drafts: \(error)")
            return false
        }
    }
    
    /// Trainer sendet Feedback ab
    func deliverFeedback(submissionId: String) async -> Bool {
        guard let user = UserManager.shared.currentUser else { return false }
        guard var feedback = feedbacks[submissionId] else {
            errorMessage = "Kein Feedback gefunden"
            return false
        }
        guard user.id == feedback.trainerId || user.group.isAdmin else { return false }
        
        // Prüfen ob mindestens etwas vorhanden ist
        guard feedback.comments.hasContent || !feedback.annotations.isEmpty || !feedback.audioTracks.isEmpty else {
            errorMessage = "Bitte füge mindestens einen Kommentar oder eine Annotation hinzu"
            return false
        }
        
        feedback.isDraft = false
        feedback.deliveredAt = Date()
        feedback.updatedAt = Date()
        
        do {
            try db.collection(feedbacksCollection).document(feedback.id).setData(from: feedback)
            feedbacks[submissionId] = feedback
            
            // Submission-Status aktualisieren
            _ = await updateSubmissionStatus(submissionId, to: .feedbackDelivered)
            
            saveLocalCache()
            return true
        } catch {
            print("❌ Fehler beim Senden des Feedbacks: \(error)")
            return false
        }
    }
    
    /// Lädt Feedback für eine Submission
    func loadFeedback(submissionId: String) async -> ReviewFeedback? {
        if let cached = feedbacks[submissionId] {
            return cached
        }
        
        do {
            let snapshot = try await db.collection(feedbacksCollection)
                .whereField("submissionId", isEqualTo: submissionId)
                .limit(to: 1)
                .getDocuments()
            
            if let doc = snapshot.documents.first,
               let feedback = try? doc.data(as: ReviewFeedback.self) {
                feedbacks[submissionId] = feedback
                return feedback
            }
        } catch {
            print("❌ Fehler beim Laden des Feedbacks: \(error)")
        }
        
        return nil
    }
    
    // MARK: - Audio Recording Upload
    
    /// Lädt eine Audio-Aufnahme hoch
    func uploadAudioTrack(
        feedbackId: String,
        localURL: URL,
        startTime: Double,
        duration: Double
    ) async -> AudioTrack? {
        let trackId = UUID().uuidString
        let storagePath = "\(audioStoragePath)/\(feedbackId)/\(trackId).m4a"
        let storageRef = storage.reference().child(storagePath)
        
        do {
            let metadata = StorageMetadata()
            metadata.contentType = "audio/m4a"
            
            let uploadTask = storageRef.putFile(from: localURL, metadata: metadata)
            try await awaitUpload(uploadTask)
            let downloadURL = try await storageRef.downloadURL()
            
            let track = AudioTrack(
                id: trackId,
                url: downloadURL.absoluteString,
                startTime: startTime,
                duration: duration
            )
            
            return track
        } catch {
            print("❌ Audio-Upload fehlgeschlagen: \(error)")
            return nil
        }
    }
    
    // MARK: - Trainer Example Video Upload
    
    /// Lädt ein Beispielvideo des Trainers hoch
    func uploadTrainerExampleVideo(
        feedbackId: String,
        localURL: URL,
        title: String,
        relatedTimestamp: Double?
    ) async -> TrainerExampleVideo? {
        let videoId = UUID().uuidString
        let storagePath = "\(trainerVideosPath)/\(feedbackId)/\(videoId).mp4"
        let storageRef = storage.reference().child(storagePath)
        
        do {
            let metadata = StorageMetadata()
            metadata.contentType = "video/mp4"
            
            let uploadTask = storageRef.putFile(from: localURL, metadata: metadata)
            try await awaitUpload(uploadTask)
            let downloadURL = try await storageRef.downloadURL()
            
            // Dauer ermitteln
            let asset = AVAsset(url: localURL)
            let duration = try await asset.load(.duration)
            let durationSeconds = CMTimeGetSeconds(duration)
            
            let video = TrainerExampleVideo(
                id: videoId,
                url: downloadURL.absoluteString,
                title: title,
                relatedTimestamp: relatedTimestamp,
                durationSeconds: durationSeconds
            )
            
            return video
        } catch {
            print("❌ Beispielvideo-Upload fehlgeschlagen: \(error)")
            return nil
        }
    }
    
    // MARK: - User: Mark as Complete
    
    /// User markiert Feedback als gesehen/abgeschlossen
    func markAsCompleted(submissionId: String) async -> Bool {
        guard let user = UserManager.shared.currentUser else { return false }
        guard let submission = submissions.first(where: { $0.id == submissionId }) else { return false }
        guard user.id == submission.userId else { return false }
        guard submission.submissionStatus == .feedbackDelivered else { return false }
        
        return await updateSubmissionStatus(submissionId, to: .completed)
    }
    
    // MARK: - Notifications
    
    private func sendStatusNotification(submission: VideoSubmission, newStatus: VideoSubmissionStatus) async {
        let title: String
        let body: String
        
        switch newStatus {
        case .submitted:
            title = "📹 Video eingereicht"
            body = "Dein Video wurde erfolgreich eingereicht. \(submission.trainerName) wird es bald bearbeiten."
        case .inReview:
            title = "👀 Review gestartet"
            body = "\(submission.trainerName) arbeitet jetzt an deinem Feedback."
        case .feedbackDelivered:
            title = "🎉 Feedback bereit!"
            body = "Dein Video-Feedback von \(submission.trainerName) ist da!"
        case .cancelled:
            title = "❌ Einreichung abgebrochen"
            body = "Deine Video-Einreichung wurde abgebrochen."
        case .refunded:
            title = "💸 Erstattung"
            body = "Du erhältst eine Erstattung für deine Video-Einreichung."
        default:
            return
        }
        
        await PushNotificationService.shared.sendLocalNotification(title: title, body: body)
    }
    
    // MARK: - Local Cache
    
    private let cacheKey = "videoReviewCache"
    
    private func saveLocalCache() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        struct CacheData: Codable {
            var settings: [String: TrainerReviewSettings]
            var submissions: [VideoSubmission]
            var feedbacks: [String: ReviewFeedback]
        }
        
        let cache = CacheData(settings: trainerSettings, submissions: submissions, feedbacks: feedbacks)
        
        if let data = try? encoder.encode(cache) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }
    
    private func loadLocalCache() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        struct CacheData: Codable {
            var settings: [String: TrainerReviewSettings]
            var submissions: [VideoSubmission]
            var feedbacks: [String: ReviewFeedback]
        }
        
        if let cache = try? decoder.decode(CacheData.self, from: data) {
            self.trainerSettings = cache.settings
            self.submissions = cache.submissions
            self.feedbacks = cache.feedbacks
        }
    }
    
    // MARK: - Queries
    
    /// Alle Einreichungen eines Users
    func submissionsForUser(_ userId: String) -> [VideoSubmission] {
        submissions.filter { $0.userId == userId }.sorted { $0.createdAt > $1.createdAt }
    }
    
    /// Alle Einreichungen für einen Trainer
    func submissionsForTrainer(_ trainerId: String) -> [VideoSubmission] {
        submissions.filter { $0.trainerId == trainerId }.sorted { $0.createdAt > $1.createdAt }
    }
    
    /// Offene Einreichungen für Trainer (submitted, inReview)
    func pendingSubmissionsForTrainer(_ trainerId: String) -> [VideoSubmission] {
        submissions.filter {
            $0.trainerId == trainerId &&
            ($0.submissionStatus == .submitted || $0.submissionStatus == .inReview)
        }.sorted { $0.createdAt < $1.createdAt } // Älteste zuerst
    }
    
    /// Einreichungen mit Feedback bereit für User
    func feedbackReadyForUser(_ userId: String) -> [VideoSubmission] {
        submissions.filter {
            $0.userId == userId && $0.submissionStatus == .feedbackDelivered
        }
    }
}

// MARK: - Errors

enum VideoReviewError: LocalizedError {
    case submissionNotFound
    case invalidStatus
    case validationFailed(String)
    case uploadFailed
    case unauthorized
    
    var errorDescription: String? {
        switch self {
        case .submissionNotFound:
            return "Einreichung nicht gefunden"
        case .invalidStatus:
            return "Ungültiger Status für diese Aktion"
        case .validationFailed(let message):
            return "Video-Validierung fehlgeschlagen: \(message)"
        case .uploadFailed:
            return "Upload fehlgeschlagen"
        case .unauthorized:
            return "Keine Berechtigung"
        }
    }
}

private func awaitUpload(_ task: StorageUploadTask) async throws {
    try await withCheckedThrowingContinuation { continuation in
        var didResume = false
        task.observe(.success) { _ in
            guard !didResume else { return }
            didResume = true
            continuation.resume()
        }
        task.observe(.failure) { snapshot in
            guard !didResume else { return }
            didResume = true
            continuation.resume(throwing: snapshot.error ?? NSError(domain: "storage.upload", code: -1))
        }
    }
}
