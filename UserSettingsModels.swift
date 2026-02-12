import Foundation

struct UserSettings: Codable, Identifiable {
    let id: String // = userId
    var pushNotificationsEnabled: Bool
    var autoplayVideos: Bool
    var downloadOnWiFiOnly: Bool
    var showOnlineStatus: Bool
    var allowTrainerMessages: Bool
    var allowPartnerRequests: Bool
    var analyticsOptIn: Bool
    var createdAt: Date
    var updatedAt: Date

    static func `default`(userId: String) -> UserSettings {
        UserSettings(
            id: userId,
            pushNotificationsEnabled: true,
            autoplayVideos: true,
            downloadOnWiFiOnly: true,
            showOnlineStatus: true,
            allowTrainerMessages: true,
            allowPartnerRequests: true,
            analyticsOptIn: true,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}
