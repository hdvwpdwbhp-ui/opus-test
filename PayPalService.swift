//
//  PayPalService.swift
//  Tanzen mit Tatiana Drexler
//
//  PayPal Integration für Privatstunden-Zahlungen
//  Siehe PAYPAL_SETUP.md für Einrichtungsanleitung
//

import Foundation
import SwiftUI
import Combine

// MARK: - PayPal Konfiguration
/// ⚠️ WICHTIG: Trage hier deine PayPal-Daten ein!
/// Siehe PAYPAL_SETUP.md für eine ausführliche Anleitung.
struct PayPalConfig {
    
    // ═══════════════════════════════════════════════════════════════════
    // TODO: SPÄTER AUSFÜLLEN - PayPal.me Username
    // ═══════════════════════════════════════════════════════════════════
    // Dein PayPal.me Link: paypal.me/DEIN_USERNAME
    // Beispiel: Wenn dein Link "paypal.me/TatianaDrexler" ist,
    // trage "TatianaDrexler" ein.
    
    static let paypalMeUsername = ""  // ← SPÄTER HIER EINTRAGEN
    
    // ═══════════════════════════════════════════════════════════════════
    // TODO: SPÄTER AUSFÜLLEN - PayPal Business E-Mail
    // ═══════════════════════════════════════════════════════════════════
    // Die E-Mail-Adresse deines PayPal Business-Kontos
    
    static let businessEmail = "info@dancewithtatiana.com"  // ← HIER EINGETRAGEN
    
    // ═══════════════════════════════════════════════════════════════════
    // OPTIONAL: PayPal API Credentials (nur für automatische Zahlungen)
    // ═══════════════════════════════════════════════════════════════════
    // Diese brauchst du NUR, wenn du automatische Zahlungsbestätigung willst.
    // Für den Start reicht PayPal.me (manuelle Bestätigung).
    
    static let clientId = "AVWmXUX0qJHiqVbZEfrqQlHAzkeLgaxhscZjdNiwfMjxWstVIBxmpLw7eInd7JMqXoXkCa_DQFJ-5arY"
    static let secretKey = "EL73dYVfzJhUc8flSm5xvq5p4BM3Dz-UXUBwopGzKxrTf6A4tq8b5AhpD7qum6eUzaeBYwfI3jAOxi8Q"
    
    // ═══════════════════════════════════════════════════════════════════
    // EINSTELLUNGEN
    // ═══════════════════════════════════════════════════════════════════
    
    /// Sandbox-Modus für Tests
    /// - true = Testmodus (kein echtes Geld)
    /// - false = Live-Modus (echte Zahlungen!)
    static let isSandbox = true  // Sandbox aktiviert
    
    /// Währung für Zahlungen
    static let currency = "EUR"
    
    // ═══════════════════════════════════════════════════════════════════
    // STATUS-PRÜFUNGEN (nicht ändern!)
    // ═══════════════════════════════════════════════════════════════════
    
    /// Prüft ob die vollständige PayPal API konfiguriert ist
    static var isFullyConfigured: Bool {
        return clientId != "DEINE_PAYPAL_CLIENT_ID_HIER" &&
               secretKey != "DEIN_PAYPAL_SECRET_KEY_HIER" &&
               businessEmail != "DEINE_PAYPAL_EMAIL_HIER"
    }
    
    /// Prüft ob PayPal.me konfiguriert ist (Mindestanforderung)
    static var isPayPalMeConfigured: Bool {
        return paypalMeUsername != "DEIN_PAYPALME_USERNAME_HIER" &&
               !paypalMeUsername.isEmpty
    }
    
    /// Prüft ob PayPal überhaupt nutzbar ist
    static var isConfigured: Bool {
        return isPayPalMeConfigured || isFullyConfigured
    }
    
    /// Base URL für PayPal API
    static var apiBaseURL: String {
        return isSandbox
            ? "https://api-m.sandbox.paypal.com"
            : "https://api-m.paypal.com"
    }
    
    /// Generiert einen PayPal.me Zahlungslink
    static func paypalMeLink(amount: Decimal, description: String) -> URL? {
        guard isPayPalMeConfigured else { return nil }
        let amountString = String(format: "%.2f", NSDecimalNumber(decimal: amount).doubleValue)
        // Description wird als Notiz in PayPal angezeigt
        let urlString = "https://paypal.me/\(paypalMeUsername)/\(amountString)\(currency)"
        return URL(string: urlString)
    }
}

// MARK: - Payment Status
enum PaymentStatus: String, Codable {
    case pending = "Ausstehend"           // Zahlung noch nicht angefordert
    case awaitingPayment = "Warte auf Zahlung"  // Zahlungslink gesendet
    case processing = "Wird verarbeitet"   // Zahlung eingegangen, wird geprüft
    case completed = "Bezahlt"            // Zahlung erfolgreich
    case failed = "Fehlgeschlagen"        // Zahlung fehlgeschlagen
    case refunded = "Erstattet"           // Zahlung zurückerstattet
    case expired = "Abgelaufen"           // Zahlungsfrist abgelaufen
    
    var icon: String {
        switch self {
        case .pending: return "clock"
        case .awaitingPayment: return "creditcard"
        case .processing: return "arrow.triangle.2.circlepath"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .refunded: return "arrow.uturn.backward.circle"
        case .expired: return "exclamationmark.triangle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .pending: return .gray
        case .awaitingPayment: return .orange
        case .processing: return .blue
        case .completed: return .green
        case .failed, .expired: return .red
        case .refunded: return .purple
        }
    }
}

// MARK: - PayPal Service
@MainActor
class PayPalService: ObservableObject {
    static let shared = PayPalService()
    
    @Published var isProcessing = false
    @Published var lastError: String?
    
    private var accessToken: String?
    private var tokenExpiry: Date?
    
    private init() {}
    
    // MARK: - Configuration Check
    
    /// Prüft ob PayPal bereit für Zahlungen ist
    var isReady: Bool {
        return PayPalConfig.isConfigured || PayPalConfig.isPayPalMeConfigured
    }
    
    /// Status-Nachricht für Admin-Dashboard
    var configurationStatus: String {
        if PayPalConfig.isConfigured {
            return "✅ PayPal vollständig konfiguriert"
        } else if PayPalConfig.isPayPalMeConfigured {
            return "⚠️ PayPal.me konfiguriert (nur manuelle Zahlungsbestätigung)"
        } else {
            return "❌ PayPal nicht konfiguriert - Bitte Credentials eintragen"
        }
    }
    
    // MARK: - PayPal.me Link Generation (Einfachste Lösung)
    
    /// Generiert einen PayPal.me Zahlungslink mit Buchungsnummer
    func generatePayPalMeLink(amount: Decimal, bookingNumber: String, description: String) -> String? {
        guard PayPalConfig.isPayPalMeConfigured else { return nil }
        
        let amountString = String(format: "%.2f", NSDecimalNumber(decimal: amount).doubleValue)
        // Buchungsnummer in Beschreibung für bessere Zuordnung
        let fullDescription = "\(bookingNumber) - \(description)"
        let encodedDescription = fullDescription.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        // PayPal.me Link Format: paypal.me/username/amount/EUR
        return "https://paypal.me/\(PayPalConfig.paypalMeUsername)/\(amountString)EUR?description=\(encodedDescription)"
    }
    
    /// Generiert einen PayPal.me Zahlungslink für eine Buchung
    func generatePaymentLink(for booking: PrivateLessonBooking) -> String? {
        generatePayPalMeLink(
            amount: booking.price,
            bookingNumber: booking.bookingNumber,
            description: booking.paypalDescription
        )
    }
    
    // MARK: - PayPal API Integration (Vollständige Lösung)
    
    /// Holt einen Access Token von PayPal
    private func getAccessToken() async throws -> String {
        // Prüfe ob existierender Token noch gültig
        if let token = accessToken, let expiry = tokenExpiry, expiry > Date() {
            return token
        }
        
        guard PayPalConfig.isConfigured else {
            throw PayPalError.notConfigured
        }
        
        let url = URL(string: "\(PayPalConfig.apiBaseURL)/v1/oauth2/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Basic Auth mit Client ID und Secret
        let credentials = "\(PayPalConfig.clientId):\(PayPalConfig.secretKey)"
        let credentialsData = credentials.data(using: .utf8)!
        let base64Credentials = credentialsData.base64EncodedString()
        
        request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "grant_type=client_credentials".data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw PayPalError.authenticationFailed
        }
        
        let tokenResponse = try JSONDecoder().decode(PayPalTokenResponse.self, from: data)
        
        accessToken = tokenResponse.accessToken
        tokenExpiry = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn - 60))
        
        return tokenResponse.accessToken
    }
    
    /// Erstellt eine PayPal Order
    func createOrder(amount: Decimal, bookingNumber: String, description: String) async -> Result<PayPalOrder, PayPalError> {
        isProcessing = true
        defer { isProcessing = false }
        
        // Fallback auf PayPal.me wenn API nicht konfiguriert
        guard PayPalConfig.isConfigured else {
            if let paypalMeLink = generatePayPalMeLink(amount: amount, bookingNumber: bookingNumber, description: description) {
                let order = PayPalOrder(
                    id: "MANUAL_\(bookingNumber)",
                    status: "CREATED",
                    approvalURL: paypalMeLink,
                    captureURL: nil
                )
                return .success(order)
            }
            return .failure(.notConfigured)
        }
        
        do {
            let token = try await getAccessToken()
            
            let url = URL(string: "\(PayPalConfig.apiBaseURL)/v2/checkout/orders")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let orderRequest = PayPalOrderRequest(
                intent: "CAPTURE",
                purchaseUnits: [
                    PayPalPurchaseUnit(
                        referenceId: bookingNumber,
                        description: description,
                        amount: PayPalAmount(
                            currencyCode: "EUR",
                            value: String(format: "%.2f", NSDecimalNumber(decimal: amount).doubleValue)
                        )
                    )
                ],
                applicationContext: PayPalApplicationContext(
                    brandName: "Tanzen mit Tatiana Drexler",
                    locale: "de-DE",
                    landingPage: "BILLING",
                    userAction: "PAY_NOW",
                    returnUrl: "tanzen://payment/success",
                    cancelUrl: "tanzen://payment/cancel"
                )
            )
            
            request.httpBody = try JSONEncoder().encode(orderRequest)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201 else {
                lastError = "PayPal Order konnte nicht erstellt werden"
                return .failure(.orderCreationFailed)
            }
            
            let orderResponse = try JSONDecoder().decode(PayPalOrderResponse.self, from: data)
            
            let approvalURL = orderResponse.links.first { $0.rel == "approve" }?.href
            let captureURL = orderResponse.links.first { $0.rel == "capture" }?.href
            
            let order = PayPalOrder(
                id: orderResponse.id,
                status: orderResponse.status,
                approvalURL: approvalURL,
                captureURL: captureURL
            )
            
            return .success(order)
            
        } catch {
            lastError = error.localizedDescription
            return .failure(.networkError(error.localizedDescription))
        }
    }
    
    /// Bestätigt eine Zahlung (Capture)
    func capturePayment(orderId: String) async -> Result<PayPalCaptureResult, PayPalError> {
        isProcessing = true
        defer { isProcessing = false }
        
        // Manuelle Zahlungen können nicht automatisch captured werden
        if orderId.hasPrefix("MANUAL_") {
            return .failure(.manualPaymentRequired)
        }
        
        guard PayPalConfig.isConfigured else {
            return .failure(.notConfigured)
        }
        
        do {
            let token = try await getAccessToken()
            
            let url = URL(string: "\(PayPalConfig.apiBaseURL)/v2/checkout/orders/\(orderId)/capture")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201 else {
                lastError = "Zahlung konnte nicht bestätigt werden"
                return .failure(.captureFaile)
            }
            
            let captureResponse = try JSONDecoder().decode(PayPalCaptureResponse.self, from: data)
            
            let transactionId = captureResponse.purchaseUnits.first?.payments?.captures?.first?.id
            
            let result = PayPalCaptureResult(
                orderId: orderId,
                transactionId: transactionId,
                status: captureResponse.status,
                amount: captureResponse.purchaseUnits.first?.payments?.captures?.first?.amount?.value
            )
            
            // Admin über erfolgreiche PayPal-Zahlung benachrichtigen
            if let amount = result.amount {
                await notifyAdminAboutPayPalPayment(orderId: orderId, amount: amount)
            }
            
            return .success(result)
            
        } catch {
            lastError = error.localizedDescription
            return .failure(.networkError(error.localizedDescription))
        }
    }
    
    // MARK: - PayPal Return URL Handling
    /// Verarbeitet die Rückgabe-URL von PayPal (tanzen://payment/success?token=ORDER_ID)
    func handleReturnURL(_ url: URL) async -> Result<PayPalCaptureResult, PayPalError>? {
        guard url.scheme == "tanzen" else { return nil }
        guard url.host == "payment" else { return nil }
        guard url.path == "/success" else { return nil }
        
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let token = components?.queryItems?.first(where: { $0.name.lowercased() == "token" })?.value
        guard let orderId = token, !orderId.isEmpty else { return nil }
        
        return await capturePayment(orderId: orderId)
    }
    
    /// Erstattet eine Zahlung
    func refundPayment(transactionId: String, amount: Decimal?, reason: String) async -> Result<String, PayPalError> {
        isProcessing = true
        defer { isProcessing = false }
        
        guard PayPalConfig.isConfigured else {
            return .failure(.notConfigured)
        }
        
        do {
            let token = try await getAccessToken()
            
            let url = URL(string: "\(PayPalConfig.apiBaseURL)/v2/payments/captures/\(transactionId)/refund")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            var refundRequest: [String: Any] = ["note_to_payer": reason]
            if let amount = amount {
                refundRequest["amount"] = [
                    "currency_code": "EUR",
                    "value": String(format: "%.2f", NSDecimalNumber(decimal: amount).doubleValue)
                ]
            }
            
            request.httpBody = try JSONSerialization.data(withJSONObject: refundRequest)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201 else {
                return .failure(.refundFailed)
            }
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let refundId = json["id"] as? String {
                return .success(refundId)
            }
            
            return .failure(.refundFailed)
            
        } catch {
            return .failure(.networkError(error.localizedDescription))
        }
    }
    
    // MARK: - Manual Payment Confirmation (für PayPal.me)
    
    /// Bestätigt eine manuelle Zahlung (Admin-Funktion)
    func confirmManualPayment(bookingId: String, transactionId: String) async -> Bool {
        // Diese Funktion wird vom Admin aufgerufen, nachdem er die Zahlung auf PayPal überprüft hat
        // Die eigentliche Aktualisierung erfolgt im PrivateLessonManager
        return true
    }
    
    // MARK: - Payment Deadline Check
    
    /// Berechnet die Zahlungsfrist (24 Stunden vor Terminbeginn)
    func calculatePaymentDeadline(lessonDate: Date) -> Date {
        return lessonDate.addingTimeInterval(-24 * 60 * 60) // 24 Stunden vorher
    }
    
    /// Prüft ob die Zahlungsfrist abgelaufen ist
    func isPaymentDeadlineExpired(deadline: Date) -> Bool {
        return Date() > deadline
    }
    
    /// Formatiert die verbleibende Zeit bis zur Deadline
    func formatTimeRemaining(until deadline: Date) -> String {
        let remaining = deadline.timeIntervalSince(Date())
        
        if remaining <= 0 {
            return "Abgelaufen"
        }
        
        let hours = Int(remaining / 3600)
        let minutes = Int((remaining.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours > 24 {
            let days = hours / 24
            return "\(days) Tag\(days == 1 ? "" : "e")"
        } else if hours > 0 {
            return "\(hours) Std. \(minutes) Min."
        } else {
            return "\(minutes) Minuten"
        }
    }
}

// MARK: - PayPal Errors
enum PayPalError: Error, LocalizedError {
    case notConfigured
    case authenticationFailed
    case orderCreationFailed
    case captureFaile
    case refundFailed
    case manualPaymentRequired
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "PayPal ist nicht konfiguriert. Bitte Credentials eintragen."
        case .authenticationFailed:
            return "PayPal Authentifizierung fehlgeschlagen."
        case .orderCreationFailed:
            return "PayPal Order konnte nicht erstellt werden."
        case .captureFaile:
            return "Zahlung konnte nicht bestätigt werden."
        case .refundFailed:
            return "Erstattung fehlgeschlagen."
        case .manualPaymentRequired:
            return "Diese Zahlung muss manuell bestätigt werden."
        case .networkError(let message):
            return "Netzwerkfehler: \(message)"
        }
    }
}

// MARK: - PayPal API Models
struct PayPalTokenResponse: Codable {
    let accessToken: String
    let expiresIn: Int
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
    }
}

struct PayPalOrderRequest: Codable {
    let intent: String
    let purchaseUnits: [PayPalPurchaseUnit]
    let applicationContext: PayPalApplicationContext
    
    enum CodingKeys: String, CodingKey {
        case intent
        case purchaseUnits = "purchase_units"
        case applicationContext = "application_context"
    }
}

struct PayPalPurchaseUnit: Codable {
    let referenceId: String
    let description: String
    let amount: PayPalAmount
    
    enum CodingKeys: String, CodingKey {
        case referenceId = "reference_id"
        case description
        case amount
    }
}

struct PayPalAmount: Codable {
    let currencyCode: String
    let value: String
    
    enum CodingKeys: String, CodingKey {
        case currencyCode = "currency_code"
        case value
    }
}

struct PayPalApplicationContext: Codable {
    let brandName: String
    let locale: String
    let landingPage: String
    let userAction: String
    let returnUrl: String
    let cancelUrl: String
    
    enum CodingKeys: String, CodingKey {
        case brandName = "brand_name"
        case locale
        case landingPage = "landing_page"
        case userAction = "user_action"
        case returnUrl = "return_url"
        case cancelUrl = "cancel_url"
    }
}

struct PayPalOrderResponse: Codable {
    let id: String
    let status: String
    let links: [PayPalLink]
}

struct PayPalLink: Codable {
    let href: String
    let rel: String
    let method: String?
}

struct PayPalOrder {
    let id: String
    let status: String
    let approvalURL: String?
    let captureURL: String?
}

struct PayPalCaptureResponse: Codable {
    let id: String
    let status: String
    let purchaseUnits: [PayPalCapturedPurchaseUnit]
    
    enum CodingKeys: String, CodingKey {
        case id, status
        case purchaseUnits = "purchase_units"
    }
}

struct PayPalCapturedPurchaseUnit: Codable {
    let payments: PayPalPayments?
}

struct PayPalPayments: Codable {
    let captures: [PayPalCapture]?
}

struct PayPalCapture: Codable {
    let id: String
    let status: String
    let amount: PayPalAmount?
}

struct PayPalCaptureResult {
    let orderId: String
    let transactionId: String?
    let status: String
    let amount: String?
}

// MARK: - Admin Notification Extension
extension PayPalService {
    
    /// Benachrichtigt Admin über erfolgreiche PayPal-Zahlung
    func notifyAdminAboutPayPalPayment(orderId: String, amount: String) async {
        let buyerName = UserManager.shared.currentUser?.name ?? "Unbekannt"
        let buyerEmail = UserManager.shared.currentUser?.email ?? ""
        
        await PushNotificationService.shared.notifyAdminAboutPurchase(
            productName: "PayPal-Zahlung",
            productId: orderId,
            buyerName: buyerName,
            buyerEmail: buyerEmail,
            price: "\(amount) EUR",
            paymentMethod: .paypal
        )
    }
}
