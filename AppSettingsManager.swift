//
//  AppSettingsManager.swift
//  Tanzen mit Tatiana Drexler
//
//  Verwaltet globale App-Einstellungen wie kostenlose Kurse
//

import Foundation
import Combine

@MainActor
class AppSettingsManager: ObservableObject {
    static let shared = AppSettingsManager()

    @Published var settings: AppSettings = AppSettings.defaultSettings()
    @Published var supportChanges: [SupportChange] = []
    @Published var trainerEditRequests: [TrainerEditRequest] = []
    @Published var isLoading = false

    private let localSettingsKey = "local_app_settings"
    private let localSupportChangesKey = "local_support_changes"
    private let localTrainerRequestsKey = "local_trainer_requests"

    private init() {
        loadLocal()
        FirebaseService.shared.startSettingsListener { [weak self] settings in
            guard let self = self, let settings = settings else { return }
            Task { @MainActor in
                self.settings = settings
                self.saveLocal()
            }
        }
        Task { await loadFromCloud() }
    }

    // MARK: - Kostenlose Kurse

    /// Prüft ob ein Kurs kostenlos ist
    func isCourseFree(_ courseId: String) -> Bool {
        settings.freeCourseIds.contains(courseId)
    }

    /// Prüft ob eine Lektion kostenlos ist
    func isLessonFree(_ lessonId: String) -> Bool {
        settings.freeLessonIds.contains(lessonId)
    }

    /// Setzt kostenlose Kurse (Admin only)
    func setFreeCourses(_ courseIds: [String]) async -> Bool {
        guard UserManager.shared.currentUser?.group.isAdmin == true else { return false }

        settings.freeCourseIds = courseIds
        settings.lastUpdated = Date()

        saveLocal()
        await saveToCloud()
        return true
    }

    /// Setzt kostenlose Lektionen (Admin only)
    func setFreeLessons(_ lessonIds: [String]) async -> Bool {
        guard UserManager.shared.currentUser?.group.isAdmin == true else { return false }

        settings.freeLessonIds = lessonIds
        settings.lastUpdated = Date()

        saveLocal()
        await saveToCloud()
        return true
    }

    /// Fügt einen Kurs zu den kostenlosen hinzu
    func addFreeCourse(_ courseId: String) async -> Bool {
        guard UserManager.shared.currentUser?.group.isAdmin == true else { return false }
        guard !settings.freeCourseIds.contains(courseId) else { return true }

        settings.freeCourseIds.append(courseId)
        settings.lastUpdated = Date()

        saveLocal()
        await saveToCloud()
        return true
    }

    /// Entfernt einen Kurs aus den kostenlosen
    func removeFreeCourse(_ courseId: String) async -> Bool {
        guard UserManager.shared.currentUser?.group.isAdmin == true else { return false }

        settings.freeCourseIds.removeAll { $0 == courseId }
        settings.lastUpdated = Date()

        saveLocal()
        await saveToCloud()
        return true
    }

    // MARK: - Admin Purchase Notifications

    /// Aktiviert/Deaktiviert Admin-Kaufbenachrichtigungen
    func setAdminPurchaseNotifications(enabled: Bool) async {
        guard UserManager.shared.currentUser?.group.isAdmin == true else { return }

        settings.adminPurchaseNotificationsEnabled = enabled
        settings.lastUpdated = Date()

        saveLocal()
        await saveToCloud()

        print(enabled ? "✅ Kaufbenachrichtigungen aktiviert" : "❌ Kaufbenachrichtigungen deaktiviert")
    }

    /// Setzt die Admin-E-Mail für Benachrichtigungen
    func setAdminEmail(_ email: String?) async {
        guard UserManager.shared.currentUser?.group.isAdmin == true else { return }

        settings.adminEmail = email
        settings.lastUpdated = Date()

        saveLocal()
        await saveToCloud()
    }

    // MARK: - Sales Management

    /// Gibt alle aktiven Sales zurück
    var activeSales: [CourseSale] {
        settings.activeSales.filter { $0.isCurrentlyActive }
    }

    /// Gibt den Sale für einen Kurs zurück (falls vorhanden)
    func getSaleForCourse(_ courseId: String) -> CourseSale? {
        settings.activeSales.filter { $0.isCurrentlyActive }.first { sale in
            sale.courseIds.isEmpty || sale.courseIds.contains(courseId)
        }
    }

    /// Erstellt einen neuen Sale (Admin only)
    func createSale(courseIds: [String], discountPercent: Int, title: String, description: String, startDate: Date, endDate: Date) async -> CourseSale? {
        guard UserManager.shared.currentUser?.group.isAdmin == true else { return nil }

        let sale = CourseSale.create(
            courseIds: courseIds,
            discountPercent: discountPercent,
            title: title,
            description: description,
            startDate: startDate,
            endDate: endDate
        )

        settings.activeSales.append(sale)
        settings.lastUpdated = Date()

        saveLocal()
        await saveToCloud()

        // Push-Benachrichtigungen an User senden (die den Kurs nicht haben)
        await sendSaleNotifications(sale: sale)

        return sale
    }

    /// Deaktiviert einen Sale
    func deactivateSale(saleId: String) async -> Bool {
        guard UserManager.shared.currentUser?.group.isAdmin == true else { return false }
        guard let index = settings.activeSales.firstIndex(where: { $0.id == saleId }) else { return false }

        settings.activeSales[index].isActive = false
        settings.lastUpdated = Date()

        saveLocal()
        await saveToCloud()
        return true
    }

    /// Löscht einen Sale
    func deleteSale(saleId: String) async -> Bool {
        guard UserManager.shared.currentUser?.group.isAdmin == true else { return false }

        settings.activeSales.removeAll { $0.id == saleId }
        settings.lastUpdated = Date()

        saveLocal()
        await saveToCloud()
        return true
    }

    /// Sendet Push-Benachrichtigungen für einen Sale
    private func sendSaleNotifications(sale: CourseSale) async {
        // Lokale Benachrichtigung für alle User die den Kurs nicht haben
        await PushNotificationService.shared.sendLocalNotification(
            title: "🎉 \(sale.title)",
            body: "\(sale.discountPercent)% Rabatt! \(sale.description)"
        )
    }

    // MARK: - Legal Documents

    /// Aktualisiert rechtliche Dokumente (Admin only)
    func updateLegalDocuments(privacyPolicy: String? = nil, termsOfService: String? = nil, impressum: String? = nil) async -> Bool {
        guard UserManager.shared.currentUser?.group.isAdmin == true else { return false }

        if let privacy = privacyPolicy {
            settings.legalDocuments.privacyPolicy = privacy
        }
        if let terms = termsOfService {
            settings.legalDocuments.termsOfService = terms
        }
        if let imprint = impressum {
            settings.legalDocuments.impressum = imprint
        }
        settings.legalDocuments.lastUpdated = Date()
        settings.lastUpdated = Date()

        saveLocal()
        await saveToCloud()
        return true
    }

    // MARK: - Support-Änderungen Dokumentation

    /// Dokumentiert eine Support-Änderung
    func logSupportChange(targetUserId: String, targetUserName: String, changeType: SupportChange.ChangeType, description: String, oldValue: String? = nil, newValue: String? = nil) async {
        guard let supporter = UserManager.shared.currentUser, supporter.group.isSupport else { return }

        let change = SupportChange.create(
            supportUserId: supporter.id,
            supportUserName: supporter.name,
            targetUserId: targetUserId,
            targetUserName: targetUserName,
            changeType: changeType,
            description: description,
            oldValue: oldValue,
            newValue: newValue
        )

        supportChanges.append(change)
        saveLocal()
        await saveToCloud()
    }

    /// Macht eine Support-Änderung rückgängig (Admin only)
    func revertSupportChange(changeId: String) async -> Bool {
        guard let admin = UserManager.shared.currentUser, admin.group.isAdmin else { return false }
        guard let index = supportChanges.firstIndex(where: { $0.id == changeId }) else { return false }

        supportChanges[index].isReverted = true
        supportChanges[index].revertedBy = admin.id
        supportChanges[index].revertedAt = Date()

        // TODO: Hier müsste die tatsächliche Änderung rückgängig gemacht werden
        // basierend auf changeType, oldValue, newValue

        saveLocal()
        await saveToCloud()
        return true
    }

    // MARK: - Trainer Edit Requests

    /// Fügt eine Änderungsanfrage direkt hinzu
    func addTrainerEditRequest(_ request: TrainerEditRequest) async {
        trainerEditRequests.append(request)
        saveLocal()
        await saveToCloud()
    }

    /// Trainer erstellt eine Änderungsanfrage
    func createTrainerEditRequest(courseId: String, courseName: String, fieldName: String, oldValue: String, newValue: String) async -> Bool {
        guard let trainer = UserManager.shared.currentUser, trainer.group == .trainer else { return false }

        let request = TrainerEditRequest.create(
            trainerId: trainer.id,
            trainerName: trainer.name,
            courseId: courseId,
            courseName: courseName,
            fieldName: fieldName,
            oldValue: oldValue,
            newValue: newValue
        )

        trainerEditRequests.append(request)
        saveLocal()
        await saveToCloud()

        // Push-Benachrichtigung an Admin
        await PushNotificationService.shared.sendLocalNotification(
            title: "Neue Änderungsanfrage",
            body: "\(trainer.name) möchte \(fieldName) in \(courseName) ändern"
        )

        return true
    }

    /// Admin genehmigt eine Änderungsanfrage
    func approveTrainerEditRequest(requestId: String, note: String? = nil) async -> Bool {
        guard let admin = UserManager.shared.currentUser, admin.group.isAdmin else { return false }
        guard let index = trainerEditRequests.firstIndex(where: { $0.id == requestId }) else { return false }

        trainerEditRequests[index].status = .approved
        trainerEditRequests[index].reviewedBy = admin.id
        trainerEditRequests[index].reviewedAt = Date()
        trainerEditRequests[index].reviewNote = note

        // TODO: Tatsächliche Änderung am Kurs durchführen

        saveLocal()
        await saveToCloud()
        return true
    }

    /// Admin lehnt eine Änderungsanfrage ab
    func rejectTrainerEditRequest(requestId: String, note: String? = nil) async -> Bool {
        guard let admin = UserManager.shared.currentUser, admin.group.isAdmin else { return false }
        guard let index = trainerEditRequests.firstIndex(where: { $0.id == requestId }) else { return false }

        trainerEditRequests[index].status = .rejected
        trainerEditRequests[index].reviewedBy = admin.id
        trainerEditRequests[index].reviewedAt = Date()
        trainerEditRequests[index].reviewNote = note

        saveLocal()
        await saveToCloud()
        return true
    }

    /// Gibt alle offenen Trainer-Anfragen zurück
    var pendingTrainerRequests: [TrainerEditRequest] {
        trainerEditRequests.filter { $0.status == .pending }
    }

    // MARK: - Legal Documents Accessors

    /// Gibt die rechtlichen Dokumente zurück
    var legalDocuments: LegalDocuments {
        settings.legalDocuments
    }

    /// Aktualisiert alle rechtlichen Dokumente
    func updateLegalDocuments(_ documents: LegalDocuments) async {
        settings.legalDocuments = documents
        settings.lastUpdated = Date()
        saveLocal()
        await saveToCloud()
    }

    // MARK: - Local Persistence

    private func saveLocal() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        if let data = try? encoder.encode(settings) {
            UserDefaults.standard.set(data, forKey: localSettingsKey)
        }
        if let data = try? encoder.encode(supportChanges) {
            UserDefaults.standard.set(data, forKey: localSupportChangesKey)
        }
        if let data = try? encoder.encode(trainerEditRequests) {
            UserDefaults.standard.set(data, forKey: localTrainerRequestsKey)
        }
    }

    private func loadLocal() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let data = UserDefaults.standard.data(forKey: localSettingsKey),
           let settings = try? decoder.decode(AppSettings.self, from: data) {
            self.settings = settings
        }
        if let data = UserDefaults.standard.data(forKey: localSupportChangesKey),
           let changes = try? decoder.decode([SupportChange].self, from: data) {
            self.supportChanges = changes
        }
        if let data = UserDefaults.standard.data(forKey: localTrainerRequestsKey),
           let requests = try? decoder.decode([TrainerEditRequest].self, from: data) {
            self.trainerEditRequests = requests
        }
    }

    // MARK: - Cloud Sync

    func loadFromCloud() async {
        isLoading = true
        defer { isLoading = false }

        if let firebaseSettings = await FirebaseService.shared.loadAppSettings() {
            self.settings = firebaseSettings
            saveLocal()
            print("✅ App-Settings von Firebase geladen")
        }
    }

    private func saveToCloud() async {
        let success = await FirebaseService.shared.saveAppSettings(settings)
        if success {
            print("✅ App-Settings zu Firebase gespeichert")
        }
    }
}
