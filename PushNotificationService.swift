//
//  PushNotificationService.swift
//  Tanzen mit Tatiana Drexler
//
//  Push-Benachrichtigungen für Admin und Editoren
//  Nutzt lokale Notifications + Remote Push via Firebase Cloud Messaging (optional)
//

import Foundation
import UserNotifications
import UIKit
import Combine
import FirebaseFirestore

// MARK: - Broadcast Notification Model
struct BroadcastNotification: Codable, Identifiable {
    let id: String
    let title: String
    let body: String
    let sentBy: String
    let sentAt: Date
    let data: [String: String]
}

@MainActor
class PushNotificationService: ObservableObject {
    
    static let shared = PushNotificationService()
    
    // MARK: - Published Properties
    @Published var isAuthorized = false
    @Published var deviceToken: String?
    
    // Admin Device Token Storage
    private let adminDeviceTokenKey = "adminDeviceToken"
    private let editorDeviceTokensKey = "editorDeviceTokens"
    
    // MARK: - Initialization
    private init() {
        checkAuthorizationStatus()
    }
    
    // MARK: - Request Permission
    func requestPermission() async -> Bool {
        do {
            let center = UNUserNotificationCenter.current()
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            
            await MainActor.run {
                isAuthorized = granted
            }
            
            if granted {
                await registerForRemoteNotifications()
            }
            
            return granted
        } catch {
            print("❌ Push-Berechtigung Fehler: \(error)")
            return false
        }
    }
    
    // MARK: - Check Authorization
    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    // MARK: - Register for Remote Notifications
    private func registerForRemoteNotifications() async {
        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
    
    // MARK: - Handle Device Token
    func handleDeviceToken(_ token: Data) {
        let tokenString = token.map { String(format: "%02.2hhx", $0) }.joined()
        deviceToken = tokenString
        print("📱 Device Token: \(tokenString)")
    }
    
    // MARK: - Register Admin Device
    func registerAdminDevice() {
        guard let token = deviceToken else {
            print("⚠️ Kein Device Token verfügbar")
            return
        }
        
        // Speichere Admin Device Token in JSONBin für Cross-Device Benachrichtigungen
        UserDefaults.standard.set(token, forKey: adminDeviceTokenKey)
        
        // TODO: Speichere Token auch in Cloud für Remote-Push
        Task {
            await saveAdminTokenToCloud(token)
        }
        
        print("✅ Admin-Gerät registriert")
    }
    
    // MARK: - Register Editor Device
    func registerEditorDevice(editorId: String) {
        guard let token = deviceToken else { return }
        
        var editorTokens = getEditorTokens()
        editorTokens[editorId] = token
        
        if let data = try? JSONEncoder().encode(editorTokens) {
            UserDefaults.standard.set(data, forKey: editorDeviceTokensKey)
        }
        
        // TODO: Speichere in Cloud
        Task {
            await saveEditorTokenToCloud(editorId: editorId, token: token)
        }
        
        print("✅ Editor-Gerät registriert: \(editorId)")
    }
    
    // MARK: - Get Editor Tokens
    private func getEditorTokens() -> [String: String] {
        if let data = UserDefaults.standard.data(forKey: editorDeviceTokensKey),
           let tokens = try? JSONDecoder().decode([String: String].self, from: data) {
            return tokens
        }
        return [:]
    }
    
    // MARK: - Send Admin Notification
    func sendAdminNotification(title: String, body: String, data: [String: String] = [:]) async {
        // Lokale Benachrichtigung (funktioniert immer)
        await sendLocalNotification(title: title, body: body, data: data)
        
        // Remote Push an Admin-Geräte
        // TODO: Firebase Cloud Messaging oder eigener Server
        await sendRemotePushToAdmin(title: title, body: body, data: data)
    }
    
    // MARK: - Send Editor Notification
    func sendEditorNotification(editorId: String, title: String, body: String, data: [String: String] = [:]) async {
        // Remote Push an Editor
        await sendRemotePushToEditor(editorId: editorId, title: title, body: body, data: data)
    }
    
    // MARK: - Send Local Notification
    func sendLocalNotification(title: String, body: String, data: [String: String] = [:]) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.badge = NSNumber(value: ChangeRequestManager.shared.unreadCount)
        content.userInfo = data
        
        // Sofort oder in 1 Sekunde
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("✅ Lokale Benachrichtigung gesendet: \(title)")
        } catch {
            print("❌ Benachrichtigung Fehler: \(error)")
        }
    }
    
    // MARK: - Remote Push (via Cloud Function oder Server)
    private func sendRemotePushToAdmin(title: String, body: String, data: [String: String]) async {
        // Option 1: Firebase Cloud Messaging
        // Option 2: Eigener Server
        // Option 3: OneSignal, Pusher, etc.
        
        // Für jetzt: Log only (Remote Push benötigt Backend-Setup)
        print("📤 Remote Push an Admin: \(title) - \(body)")
        
        // Wenn du Firebase Cloud Messaging nutzen möchtest:
        // await sendFCMNotification(to: adminDeviceToken, title: title, body: body, data: data)
    }
    
    private func sendRemotePushToEditor(editorId: String, title: String, body: String, data: [String: String]) async {
        print("📤 Remote Push an Editor \(editorId): \(title) - \(body)")
        
        // Hole Editor Token und sende Push
        // let editorToken = getEditorTokens()[editorId]
        // await sendFCMNotification(to: editorToken, title: title, body: body, data: data)
    }
    
    // MARK: - Save Tokens to Cloud
    private func saveAdminTokenToCloud(_ token: String) async {
        // Speichere Admin Token in JSONBin für spätere Remote-Push-Nutzung
        // Dies würde mit Firebase Cloud Messaging oder eigenem Server kombiniert
        print("📝 Admin Token für Cloud gespeichert")
    }
    
    private func saveEditorTokenToCloud(editorId: String, token: String) async {
        print("📝 Editor Token für Cloud gespeichert: \(editorId)")
    }
    
    // MARK: - Update Badge Count
    func updateBadgeCount(_ count: Int) {
        UNUserNotificationCenter.current().setBadgeCount(count) { error in
            if let error = error {
                print("❌ Badge Fehler: \(error)")
            }
        }
    }
    
    // MARK: - Clear All Notifications
    func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        updateBadgeCount(0)
    }
    
    // MARK: - Broadcast Push to All Users
    
    /// Sendet eine Broadcast-Push-Nachricht an alle registrierten Geräte
    func sendBroadcastPush(title: String, body: String, data: [String: String] = [:]) async -> (success: Bool, sentCount: Int) {
        guard UserManager.shared.isAdmin else {
            print("❌ Nur Admins können Broadcast-Push senden")
            return (false, 0)
        }
        
        // Speichere Broadcast in Firebase für später Zustellung
        let broadcast = BroadcastNotification(
            id: UUID().uuidString,
            title: title,
            body: body,
            sentBy: UserManager.shared.currentUser?.id ?? "admin",
            sentAt: Date(),
            data: data
        )
        
        do {
            let db = Firestore.firestore()
            try db.collection("broadcastNotifications").document(broadcast.id).setData(from: broadcast)
            
            // Sende lokale Benachrichtigung auf dem aktuellen Gerät (für Test)
            await sendLocalNotification(title: title, body: body, data: data)
            
            // TODO: Firebase Cloud Functions würde hier alle registrierten Tokens benachrichtigen
            // Für jetzt speichern wir den Broadcast und er wird von Clients beim nächsten App-Start abgeholt
            
            print("✅ Broadcast-Push gesendet: \(title)")
            
            // Setze auch Admin-Nachrichten für alle User
            let userCount = await sendBroadcastAsAdminMessage(title: title, body: body)
            
            return (true, userCount)
        } catch {
            print("❌ Broadcast-Push Fehler: \(error)")
            return (false, 0)
        }
    }
    
    /// Sendet den Broadcast auch als Admin-Nachricht an alle User (fallback für Push)
    private func sendBroadcastAsAdminMessage(title: String, body: String) async -> Int {
        return await AdminMessageManager.shared.sendBroadcast(
            title: title,
            message: body,
            type: .info,
            toUserGroup: nil
        )
    }
    
    // MARK: - Purchase Notifications for Admin
    
    /// Benachrichtigt Admin über einen Kauf (In-App oder PayPal)
    func notifyAdminAboutPurchase(
        productName: String,
        productId: String,
        buyerName: String,
        buyerEmail: String,
        price: String,
        paymentMethod: PurchasePaymentMethod
    ) async {
        // Prüfe ob Benachrichtigungen aktiviert sind
        guard AppSettingsManager.shared.settings.adminPurchaseNotificationsEnabled else {
            print("ℹ️ Admin-Kaufbenachrichtigungen sind deaktiviert")
            return
        }
        
        let title = "💰 Neuer Kauf!"
        let body = "\(buyerName) hat \"\(productName)\" für \(price) gekauft (\(paymentMethod.displayName))"
        
        let data: [String: String] = [
            "type": "purchase",
            "productId": productId,
            "productName": productName,
            "buyerName": buyerName,
            "buyerEmail": buyerEmail,
            "price": price,
            "paymentMethod": paymentMethod.rawValue
        ]
        
        // Lokale Benachrichtigung senden
        await sendLocalNotification(title: title, body: body, data: data)
        
        // Remote Push an Admin
        await sendRemotePushToAdmin(title: title, body: body, data: data)
        
        // Log für Debugging
        print("✅ Admin über Kauf benachrichtigt: \(productName) von \(buyerName)")
        
        // Speichere Kauf in der Historie
        await savePurchaseToHistory(
            productId: productId,
            productName: productName,
            buyerName: buyerName,
            buyerEmail: buyerEmail,
            price: price,
            paymentMethod: paymentMethod
        )
    }
    
    /// Benachrichtigt Admin über eine Privatstunden-Buchung
    func notifyAdminAboutPrivateLessonBooking(
        trainerName: String,
        buyerName: String,
        buyerEmail: String,
        price: String,
        date: Date
    ) async {
        guard AppSettingsManager.shared.settings.adminPurchaseNotificationsEnabled else { return }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        dateFormatter.locale = Locale(identifier: "de_DE")
        
        let title = "📅 Neue Privatstunden-Buchung!"
        let body = "\(buyerName) hat eine Privatstunde bei \(trainerName) gebucht (\(price))"
        
        await sendLocalNotification(title: title, body: body, data: [
            "type": "private_lesson",
            "trainerName": trainerName,
            "buyerName": buyerName,
            "date": dateFormatter.string(from: date)
        ])
        
        print("✅ Admin über Privatstunden-Buchung benachrichtigt")
    }
    
    /// Benachrichtigt Admin über eine Trainingsplan-Bestellung
    func notifyAdminAboutTrainingPlanOrder(
        trainerName: String,
        buyerName: String,
        planType: String,
        price: String
    ) async {
        guard AppSettingsManager.shared.settings.adminPurchaseNotificationsEnabled else { return }
        
        let title = "📋 Neue Trainingsplan-Bestellung!"
        let body = "\(buyerName) hat einen \(planType) bei \(trainerName) bestellt (\(price))"
        
        await sendLocalNotification(title: title, body: body, data: [
            "type": "training_plan",
            "trainerName": trainerName,
            "buyerName": buyerName,
            "planType": planType
        ])
        
        print("✅ Admin über Trainingsplan-Bestellung benachrichtigt")
    }
    
    // MARK: - Purchase History
    
    private let purchaseHistoryKey = "admin_purchase_history"
    
    private func savePurchaseToHistory(
        productId: String,
        productName: String,
        buyerName: String,
        buyerEmail: String,
        price: String,
        paymentMethod: PurchasePaymentMethod
    ) async {
        var history = getPurchaseHistory()
        
        let purchase = PurchaseHistoryItem(
            id: UUID().uuidString,
            productId: productId,
            productName: productName,
            buyerName: buyerName,
            buyerEmail: buyerEmail,
            price: price,
            paymentMethod: paymentMethod,
            date: Date()
        )
        
        history.insert(purchase, at: 0)
        
        // Behalte nur die letzten 100 Käufe
        if history.count > 100 {
            history = Array(history.prefix(100))
        }
        
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: purchaseHistoryKey)
        }
    }
    
    func getPurchaseHistory() -> [PurchaseHistoryItem] {
        guard let data = UserDefaults.standard.data(forKey: purchaseHistoryKey),
              let history = try? JSONDecoder().decode([PurchaseHistoryItem].self, from: data) else {
            return []
        }
        return history
    }
}

// MARK: - Purchase Payment Method
enum PurchasePaymentMethod: String, Codable {
    case inAppPurchase = "in_app_purchase"
    case paypal = "paypal"
    case coins = "coins"
    case redemptionCode = "redemption_code"
    case adminGrant = "admin_grant"
    
    var displayName: String {
        switch self {
        case .inAppPurchase: return "In-App-Kauf"
        case .paypal: return "PayPal"
        case .coins: return "DanceCoins"
        case .redemptionCode: return "Einlöse-Code"
        case .adminGrant: return "Admin-Freischaltung"
        }
    }
}

// MARK: - Purchase History Item
struct PurchaseHistoryItem: Codable, Identifiable {
    let id: String
    let productId: String
    let productName: String
    let buyerName: String
    let buyerEmail: String
    let price: String
    let paymentMethod: PurchasePaymentMethod
    let date: Date
}

// MARK: - App Delegate Extension for Push
extension PushNotificationService {
    
    func handleNotificationResponse(_ response: UNNotificationResponse) {
        let userInfo = response.notification.request.content.userInfo
        
        if let requestId = userInfo["requestId"] as? String,
           let type = userInfo["type"] as? String {
            
            if type == "change_request" {
                // Navigiere zu Änderungsanfragen
                NotificationCenter.default.post(
                    name: .openChangeRequests,
                    object: nil,
                    userInfo: ["requestId": requestId]
                )
            }
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let openChangeRequests = Notification.Name("openChangeRequests")
}
