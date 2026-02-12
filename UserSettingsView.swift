import SwiftUI

struct UserSettingsView: View {
    @StateObject private var settingsManager = UserSettingsManager.shared
    @StateObject private var userManager = UserManager.shared

    var body: some View {
        Group {
            if let user = userManager.currentUser {
                Form {
                    Section(T("Benachrichtigungen")) {
                        Toggle("Push-Benachrichtigungen", isOn: binding(
                            get: { $0.pushNotificationsEnabled },
                            set: { await settingsManager.updatePushNotificationsEnabled($0) }
                        ))
                    }

                    Section(T("Wiedergabe")) {
                        Toggle("Videos automatisch abspielen", isOn: binding(
                            get: { $0.autoplayVideos },
                            set: { await settingsManager.updateAutoplayVideos($0) }
                        ))
                    }

                    Section(T("Downloads")) {
                        Toggle("Nur über WLAN herunterladen", isOn: binding(
                            get: { $0.downloadOnWiFiOnly },
                            set: { await settingsManager.updateDownloadOnWiFiOnly($0) }
                        ))
                        Text(T("Spart mobile Daten bei großen Videos."))
                            .font(TDTypography.caption2)
                            .foregroundColor(.secondary)
                    }

                    Section(T("Privatsphäre")) {
                        Toggle("Online-Status anzeigen", isOn: binding(
                            get: { $0.showOnlineStatus },
                            set: { await settingsManager.updateShowOnlineStatus($0) }
                        ))
                        Toggle("Partneranfragen erlauben", isOn: binding(
                            get: { $0.allowPartnerRequests },
                            set: { await settingsManager.updateAllowPartnerRequests($0) }
                        ))
                    }

                    Section(T("Nachrichten")) {
                        Toggle("Trainer-Nachrichten erlauben", isOn: binding(
                            get: { $0.allowTrainerMessages },
                            set: { await settingsManager.updateAllowTrainerMessages($0) }
                        ))
                    }

                    Section(T("Analytics")) {
                        Toggle("Anonyme Nutzungsdaten teilen", isOn: binding(
                            get: { $0.analyticsOptIn },
                            set: { await settingsManager.updateAnalyticsOptIn($0) }
                        ))
                        Text(T("Hilft uns, die App zu verbessern."))
                            .font(TDTypography.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .navigationTitle(T("Einstellungen"))
                .navigationBarTitleDisplayMode(.inline)
                .task {
                    await settingsManager.initialize(for: user.id)
                }
            } else {
                VStack(spacing: TDSpacing.md) {
                    Image(systemName: "person.crop.circle.badge.exclamationmark")
                        .font(.system(size: 40))
                        .foregroundColor(Color.accentGold)
                    Text(T("Bitte melde dich an, um Einstellungen zu ändern."))
                        .font(TDTypography.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
        }
    }

    private func binding(
        get: @escaping (UserSettings) -> Bool,
        set: @escaping (Bool) async -> Void
    ) -> Binding<Bool> {
        Binding(
            get: { settingsManager.settings.map(get) ?? true },
            set: { newValue in
                Task { await set(newValue) }
            }
        )
    }
}

#Preview {
    NavigationStack {
        UserSettingsView()
    }
}
