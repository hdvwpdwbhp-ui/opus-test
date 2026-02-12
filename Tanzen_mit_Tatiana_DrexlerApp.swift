//
//  Tanzen_mit_Tatiana_DrexlerApp.swift
//  Tanzen mit Tatiana Drexler
//
//  Created by App on 07.02.26.
//

import SwiftUI
import UserNotifications
import FirebaseCore

@main
struct Tanzen_mit_Tatiana_DrexlerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var courseViewModel = CourseViewModel()
    @StateObject private var storeViewModel = StoreViewModel()
    
    init() {
        // Firebase initialisieren
        FirebaseApp.configure()
        
        // App immer im Light Mode anzeigen
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            windowScene.windows.forEach { window in
                window.overrideUserInterfaceStyle = .light
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(courseViewModel)
                .environmentObject(storeViewModel)
                .preferredColorScheme(.light) // Light Mode erzwingen
                .onAppear {
                    setupApp()
                }
                .onOpenURL { url in
                    Task { await PrivateLessonManager.shared.handlePayPalReturnURL(url) }
                }
        }
    }
    
    private func setupApp() {
        // Request push notification permission
        Task {
            await PushNotificationService.shared.requestPermission()
        }
        
        // Starte Echtzeit Cloud-Sync Service
        Task {
            CloudSyncService.shared.startAutoSync()
        }
        
        // Lade Redemption Keys von Firebase
        Task {
            await RedemptionKeyManager.shared.loadFromCloud()
        }
        
        // Lade User-Daten von Firebase
        Task {
            await UserManager.shared.loadFromCloud()
        }
        
        // Lade AppSettings von Firebase
        Task {
            await AppSettingsManager.shared.loadFromCloud()
        }
    }
}

// MARK: - App Delegate for Push Notifications
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // Set notification delegate
        UNUserNotificationCenter.current().delegate = self
        
        // Light Mode für alle Windows erzwingen
        DispatchQueue.main.async {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .forEach { $0.overrideUserInterfaceStyle = .light }
        }
        
        return true
    }
    
    // Handle device token for remote push
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in
            PushNotificationService.shared.handleDeviceToken(deviceToken)
        }
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ Push registration failed: \(error)")
    }
    
    // Handle notification when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is open
        completionHandler([.banner, .badge, .sound])
    }
    
    // Handle notification tap
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        Task { @MainActor in
            PushNotificationService.shared.handleNotificationResponse(response)
        }
        completionHandler()
    }
}
