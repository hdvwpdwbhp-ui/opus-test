//
//  SaleEmailService.swift
//  Tanzen mit Tatiana Drexler
//
//  Service für Sale-Benachrichtigungen per E-Mail
//

import Foundation
import FirebaseFirestore
import Combine

@MainActor
class SaleEmailService: ObservableObject {
    static let shared = SaleEmailService()
    
    @Published var isSending = false
    @Published var lastSendResult: SendResult?
    
    private let db = Firestore.firestore()
    
    struct SendResult {
        let success: Bool
        let totalRecipients: Int
        let sentCount: Int
        let failedCount: Int
        let message: String
    }
    
    private init() {}
    
    // MARK: - Get Marketing Subscribers
    
    /// Holt alle User die Marketing-E-Mails erhalten möchten
    func getMarketingSubscribers() async -> [AppUser] {
        var subscribers: [AppUser] = []
        
        do {
            let snapshot = try await db.collection("users")
                .whereField("marketingConsent", isEqualTo: true)
                .whereField("isActive", isEqualTo: true)
                .getDocuments()
            
            for doc in snapshot.documents {
                do {
                    let data = try JSONSerialization.data(withJSONObject: doc.data())
                    let user = try JSONDecoder().decode(AppUser.self, from: data)
                    if user.isEmailVerified {
                        subscribers.append(user)
                    }
                } catch {
                    print("❌ Error decoding user: \(error)")
                }
            }
        } catch {
            print("❌ Error fetching subscribers: \(error)")
        }
        
        return subscribers
    }
    
    // MARK: - Send Sale Email
    
    /// Sendet Sale-Benachrichtigung an alle Marketing-Subscriber
    func sendSaleNotification(sale: Sale) async -> SendResult {
        isSending = true
        defer { isSending = false }
        
        let subscribers = await getMarketingSubscribers()
        
        guard !subscribers.isEmpty else {
            let result = SendResult(
                success: false,
                totalRecipients: 0,
                sentCount: 0,
                failedCount: 0,
                message: "Keine Empfänger mit Marketing-Zustimmung gefunden"
            )
            lastSendResult = result
            return result
        }
        
        var sentCount = 0
        var failedCount = 0
        
        // E-Mails an alle Subscriber senden
        for subscriber in subscribers {
            let success = await sendEmail(
                to: subscriber.email,
                name: subscriber.name,
                sale: sale
            )
            
            if success {
                sentCount += 1
            } else {
                failedCount += 1
            }
        }
        
        // Log the email campaign
        await logEmailCampaign(sale: sale, totalRecipients: subscribers.count, sentCount: sentCount)
        
        let result = SendResult(
            success: sentCount > 0,
            totalRecipients: subscribers.count,
            sentCount: sentCount,
            failedCount: failedCount,
            message: "E-Mail an \(sentCount) von \(subscribers.count) Empfängern gesendet"
        )
        lastSendResult = result
        return result
    }
    
    // MARK: - Send Individual Email
    
    private func sendEmail(to email: String, name: String, sale: Sale) async -> Bool {
        // Hier wird die E-Mail-Logik implementiert
        // Option 1: Firebase Cloud Functions (empfohlen)
        // Option 2: Externer E-Mail-Service (SendGrid, Mailgun, etc.)
        // Option 3: SMTP direkt (nicht empfohlen für iOS)
        
        // Für jetzt: Speichere die E-Mail in einer Queue für späteren Versand
        let emailData: [String: Any] = [
            "to": email,
            "toName": name,
            "subject": "🎉 \(sale.discountPercent)% Rabatt auf \(sale.title)!",
            "html": generateEmailHTML(name: name, sale: sale),
            "text": generateEmailText(name: name, sale: sale),
            "createdAt": Timestamp(date: Date()),
            "status": "pending",
            "saleId": sale.id
        ]
        
        do {
            try await db.collection("emailQueue").addDocument(data: emailData)
            return true
        } catch {
            print("❌ Error queuing email: \(error)")
            return false
        }
    }
    
    // MARK: - Email Templates
    
    private func generateEmailHTML(name: String, sale: Sale) -> String {
        let endDateFormatted = formatDate(sale.endDate)
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(sale.title)</title>
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 0; padding: 0; background-color: #f5f5f5; }
                .container { max-width: 600px; margin: 0 auto; background: white; }
                .header { background: linear-gradient(135deg, #D4AF37, #FFD700); padding: 40px 20px; text-align: center; }
                .header h1 { color: white; margin: 0; font-size: 28px; text-shadow: 1px 1px 2px rgba(0,0,0,0.2); }
                .discount-badge { background: #FF4444; color: white; display: inline-block; padding: 10px 30px; border-radius: 30px; font-size: 32px; font-weight: bold; margin: 20px 0; }
                .content { padding: 30px 20px; }
                .content h2 { color: #333; margin-top: 0; }
                .content p { color: #666; line-height: 1.6; }
                .cta-button { display: inline-block; background: #D4AF37; color: white !important; text-decoration: none; padding: 15px 40px; border-radius: 8px; font-weight: bold; font-size: 18px; margin: 20px 0; }
                .deadline { background: #FFF3CD; border-left: 4px solid #FFD700; padding: 15px; margin: 20px 0; }
                .deadline strong { color: #856404; }
                .courses { background: #f9f9f9; padding: 20px; border-radius: 8px; margin: 20px 0; }
                .course-item { padding: 10px 0; border-bottom: 1px solid #eee; }
                .course-item:last-child { border-bottom: none; }
                .footer { background: #333; color: #999; padding: 20px; text-align: center; font-size: 12px; }
                .footer a { color: #D4AF37; }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>💃 Tanzen mit Tatiana Drexler</h1>
                    <div class="discount-badge">-\(sale.discountPercent)%</div>
                </div>
                
                <div class="content">
                    <h2>Hallo \(name)! 👋</h2>
                    
                    <p>Wir haben tolle Neuigkeiten für dich!</p>
                    
                    <h3 style="color: #D4AF37;">\(sale.title)</h3>
                    <p>\(sale.description)</p>
                    
                    <div class="deadline">
                        <strong>⏰ Nur noch bis \(endDateFormatted)!</strong><br>
                        Sichere dir jetzt \(sale.discountPercent)% Rabatt auf ausgewählte Kurse.
                    </div>
                    
                    \(sale.isAllCourses ? "<p>🌟 <strong>Gilt für alle Kurse!</strong></p>" : "")
                    
                    <center>
                        <a href="tanzen://sale/\(sale.id)" class="cta-button">Jetzt sparen! 🎉</a>
                    </center>
                    
                    <p style="color: #999; font-size: 14px; margin-top: 30px;">
                        Du erhältst diese E-Mail, weil du dich für Sale-Benachrichtigungen angemeldet hast.
                        Du kannst dies jederzeit in den App-Einstellungen ändern.
                    </p>
                </div>
                
                <div class="footer">
                    <p>© 2026 Tanzen mit Tatiana Drexler</p>
                    <p>
                        <a href="tanzen://settings/marketing">Benachrichtigungen verwalten</a> |
                        <a href="tanzen://privacy">Datenschutz</a>
                    </p>
                </div>
            </div>
        </body>
        </html>
        """
    }
    
    private func generateEmailText(name: String, sale: Sale) -> String {
        let endDateFormatted = formatDate(sale.endDate)
        
        return """
        Hallo \(name)!
        
        🎉 SALE ALERT: \(sale.discountPercent)% RABATT!
        
        \(sale.title)
        \(sale.description)
        
        ⏰ Nur noch bis \(endDateFormatted)!
        
        \(sale.isAllCourses ? "Gilt für alle Kurse!" : "")
        
        Öffne die App um dir den Rabatt zu sichern!
        
        ---
        Du erhältst diese E-Mail, weil du dich für Sale-Benachrichtigungen angemeldet hast.
        Du kannst dies jederzeit in den App-Einstellungen ändern.
        
        © 2026 Tanzen mit Tatiana Drexler
        """
    }
    
    // MARK: - Helpers
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.string(from: date)
    }
    
    private func logEmailCampaign(sale: Sale, totalRecipients: Int, sentCount: Int) async {
        let logData: [String: Any] = [
            "saleId": sale.id,
            "saleTitle": sale.title,
            "totalRecipients": totalRecipients,
            "sentCount": sentCount,
            "sentAt": Timestamp(date: Date())
        ]
        
        do {
            try await db.collection("emailCampaignLogs").addDocument(data: logData)
        } catch {
            print("❌ Error logging email campaign: \(error)")
        }
    }
    
    // MARK: - Update Marketing Consent
    
    func updateMarketingConsent(userId: String, consent: Bool) async -> Bool {
        do {
            try await db.collection("users").document(userId).updateData([
                "marketingConsent": consent
            ])
            return true
        } catch {
            print("❌ Error updating marketing consent: \(error)")
            return false
        }
    }
}

// MARK: - Sale Model Extension

extension Sale {
    /// Sendet Sale-Benachrichtigung an alle Marketing-Subscriber
    func notifySubscribers() async -> SaleEmailService.SendResult {
        return await SaleEmailService.shared.sendSaleNotification(sale: self)
    }
}
