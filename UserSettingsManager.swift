import Foundation
import Combine
import FirebaseFirestore

@MainActor
class UserSettingsManager: ObservableObject {
    static let shared = UserSettingsManager()

    @Published var settings: UserSettings?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var currentUserId: String?

    private init() {}

    func initialize(for userId: String) async {
        currentUserId = userId
        loadLocal(userId: userId)
        await loadFromCloud(userId: userId)
        startListener(userId: userId)
    }

    func cleanup() {
        listener?.remove()
        listener = nil
        currentUserId = nil
        settings = nil
    }

    func updatePushNotificationsEnabled(_ enabled: Bool) async {
        await update { $0.pushNotificationsEnabled = enabled }
    }

    func updateAutoplayVideos(_ enabled: Bool) async {
        await update { $0.autoplayVideos = enabled }
    }

    func updateDownloadOnWiFiOnly(_ enabled: Bool) async {
        await update { $0.downloadOnWiFiOnly = enabled }
    }

    func updateShowOnlineStatus(_ enabled: Bool) async {
        await update { $0.showOnlineStatus = enabled }
    }

    func updateAllowTrainerMessages(_ enabled: Bool) async {
        await update { $0.allowTrainerMessages = enabled }
    }

    func updateAllowPartnerRequests(_ enabled: Bool) async {
        await update { $0.allowPartnerRequests = enabled }
    }

    func updateAnalyticsOptIn(_ enabled: Bool) async {
        await update { $0.analyticsOptIn = enabled }
    }

    private func update(_ block: (inout UserSettings) -> Void) async {
        guard var settings = settings, let userId = currentUserId else { return }
        block(&settings)
        settings.updatedAt = Date()
        self.settings = settings
        saveLocal(userId: userId)
        await saveToCloud(settings: settings)
    }

    private func loadFromCloud(userId: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let doc = try await db.collection("userSettings").document(userId).getDocument()
            if doc.exists, let data = try? doc.data(as: UserSettings.self) {
                settings = data
                saveLocal(userId: userId)
            } else {
                let defaults = UserSettings.default(userId: userId)
                settings = defaults
                saveLocal(userId: userId)
                await saveToCloud(settings: defaults)
            }
        } catch {
            errorMessage = "Einstellungen konnten nicht geladen werden"
        }
    }

    private func saveToCloud(settings: UserSettings) async {
        do {
            try db.collection("userSettings").document(settings.id).setData(from: settings)
        } catch {
            errorMessage = "Einstellungen konnten nicht gespeichert werden"
        }
    }

    private func startListener(userId: String) {
        listener?.remove()
        listener = db.collection("userSettings").document(userId).addSnapshotListener { [weak self] snapshot, _ in
            guard let self = self, let doc = snapshot, doc.exists,
                  let data = try? doc.data(as: UserSettings.self) else { return }
            Task { @MainActor in
                self.settings = data
                self.saveLocal(userId: userId)
            }
        }
    }

    private func localKey(userId: String) -> String {
        "local_user_settings_\(userId)"
    }

    private func loadLocal(userId: String) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let data = UserDefaults.standard.data(forKey: localKey(userId: userId)),
           let local = try? decoder.decode(UserSettings.self, from: data) {
            settings = local
        }
    }

    private func saveLocal(userId: String) {
        guard let settings = settings else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(settings) {
            UserDefaults.standard.set(data, forKey: localKey(userId: userId))
        }
    }
}
