//
//  PrivateLessonManager.swift
//  Tanzen mit Tatiana Drexler
//
//  Verwaltet Privatstunden-Buchungen
//

import Foundation
import Combine

/// Verfügbarer Termin-Slot eines Trainers
struct TrainerTimeSlot: Codable, Identifiable {
    let id: String
    let trainerId: String
    var date: Date
    var duration: Int // in Minuten
    var isBooked: Bool
    var bookedByUserId: String?
    var price: Decimal
    
    static func create(trainerId: String, date: Date, duration: Int, price: Decimal) -> TrainerTimeSlot {
        TrainerTimeSlot(id: UUID().uuidString, trainerId: trainerId, date: date, duration: duration, isBooked: false, bookedByUserId: nil, price: price)
    }
}

@MainActor
class PrivateLessonManager: ObservableObject {
    static let shared = PrivateLessonManager()

    @Published var bookings: [PrivateLessonBooking] = []
    @Published var trainerSettings: [String: PrivateLessonSettings] = [:]
    @Published var timeSlots: [TrainerTimeSlot] = [] // Verfügbare Termine
    @Published var isLoading = false

    private let localBookingsKey = "local_private_bookings"
    private let localSettingsKey = "local_trainer_settings"
    private let localSlotsKey = "local_trainer_slots"

    private let minimumBookingLeadTime: TimeInterval = 24 * 60 * 60 // 24 Stunden

    private init() {
        loadLocal()
        startCallReminder()
    }
    
    // MARK: - Time Slot Management (Trainer kann Termine anlegen)
    
    /// Trainer legt einen neuen verfügbaren Termin an
    func createTimeSlot(date: Date, duration: Int) async -> Bool {
        guard let trainer = UserManager.shared.currentUser,
              trainer.group == .trainer || trainer.group.isAdmin else { return false }
        
        let settings = trainerSettings[trainer.id] ?? PrivateLessonSettings(trainerId: trainer.id, isEnabled: true, pricePerHour: 50, minDuration: 30, maxDuration: 120, availabilities: [], description: "")
        let price = settings.pricePerHour * Decimal(duration) / 60
        
        let slot = TrainerTimeSlot.create(trainerId: trainer.id, date: date, duration: duration, price: price)
        timeSlots.append(slot)
        saveLocal()
        return true
    }
    
    /// Trainer löscht einen Termin
    func deleteTimeSlot(slotId: String) async -> Bool {
        guard let user = UserManager.shared.currentUser else { return false }
        guard let index = timeSlots.firstIndex(where: { $0.id == slotId }) else { return false }
        guard timeSlots[index].trainerId == user.id || user.group.isAdmin else { return false }
        guard !timeSlots[index].isBooked else { return false } // Gebuchte Termine können nicht gelöscht werden
        
        timeSlots.remove(at: index)
        saveLocal()
        return true
    }
    
    /// Gibt verfügbare Termine für einen Trainer zurück
    func availableSlotsForTrainer(_ trainerId: String) -> [TrainerTimeSlot] {
        let minDate = Date().addingTimeInterval(minimumBookingLeadTime)
        return timeSlots.filter { $0.trainerId == trainerId && !$0.isBooked && $0.date >= minDate }
            .sorted { $0.date < $1.date }
    }

    /// User bucht einen verfügbaren Termin
    func bookTimeSlot(slotId: String, notes: String) async -> (success: Bool, message: String, bookingNumber: String?) {
        guard let user = UserManager.shared.currentUser else { return (false, "Du musst eingeloggt sein", nil) }
        guard let slotIndex = timeSlots.firstIndex(where: { $0.id == slotId }) else { return (false, "Termin nicht gefunden", nil) }
        guard !timeSlots[slotIndex].isBooked else { return (false, "Dieser Termin ist bereits gebucht", nil) }

        let slot = timeSlots[slotIndex]
        let minDate = Date().addingTimeInterval(minimumBookingLeadTime)
        if slot.date < minDate {
            return (false, "Privatstunden muessen mindestens 24 Stunden vorher gebucht werden. Dieser Termin ist verfallen.", nil)
        }

        guard let trainer = UserManager.shared.allUsers.first(where: { $0.id == slot.trainerId }) else {
            return (false, "Trainer nicht gefunden", nil)
        }
        
        // Slot als gebucht markieren
        timeSlots[slotIndex].isBooked = true
        timeSlots[slotIndex].bookedByUserId = user.id
        
        // Buchung erstellen mit eindeutiger Buchungsnummer
        let booking = PrivateLessonBooking.create(
            trainerId: slot.trainerId,
            trainerName: trainer.name,
            userId: user.id,
            userName: user.name,
            userEmail: user.email,
            requestedDate: slot.date,
            duration: slot.duration,
            price: slot.price,
            notes: notes
        )
        bookings.append(booking)
        saveLocal()
        await saveToCloud()
        
        // Benachrichtigung an Trainer mit Buchungsnummer
        await PushNotificationService.shared.sendLocalNotification(
            title: "📅 Neue Buchung \(booking.bookingNumber)!",
            body: "\(user.name) hat eine Privatstunde am \(slot.date.formatted(date: .abbreviated, time: .shortened)) gebucht"
        )
        
        return (true, "Termin gebucht! Buchungsnummer: \(booking.bookingNumber)", booking.bookingNumber)
    }
    
    // MARK: - Call Reminder (10 Minuten vor Start)
    
    private func startCallReminder() {
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkUpcomingLessons()
                await self?.checkExpiredPayments()
            }
        }
    }
    
    private func checkUpcomingLessons() {
        let now = Date()
        let tenMinutesFromNow = now.addingTimeInterval(10 * 60)
        
        for booking in bookings where booking.status == .confirmed || booking.status == .paid {
            guard let confirmedDate = booking.confirmedDate else { continue }
            
            // Prüfe ob der Termin in 10 Minuten beginnt
            if confirmedDate > now && confirmedDate <= tenMinutesFromNow {
                // Benachrichtigung nur einmal senden (prüfe ob schon benachrichtigt)
                let notificationKey = "notified_\(booking.id)"
                if UserDefaults.standard.bool(forKey: notificationKey) == false {
                    UserDefaults.standard.set(true, forKey: notificationKey)
                    
                    Task {
                        await PushNotificationService.shared.sendLocalNotification(
                            title: "⏰ Privatstunde in 10 Minuten!",
                            body: "Deine Privatstunde mit \(booking.userName) beginnt bald. Du kannst jetzt den Video-Call starten."
                        )
                    }
                }
            }
        }
    }
    
    /// Prüft ob der Trainer jetzt anrufen darf (10 Min vor Start bis Ende)
    func canStartCall(for booking: PrivateLessonBooking) -> Bool {
        guard booking.status == .confirmed || booking.status == .paid,
              let confirmedDate = booking.confirmedDate else { return false }
        
        let now = Date()
        let tenMinutesBefore = confirmedDate.addingTimeInterval(-10 * 60)
        let endTime = confirmedDate.addingTimeInterval(Double(booking.duration) * 60)
        
        return now >= tenMinutesBefore && now <= endTime
    }
    
    // MARK: - Booking Management
    
    /// Erstellt eine neue Buchungsanfrage
    func createBooking(trainerId: String, requestedDate: Date, duration: Int, notes: String) async -> (success: Bool, message: String) {
        guard let user = UserManager.shared.currentUser else {
            return (false, "Du musst eingeloggt sein")
        }

        guard let trainer = UserManager.shared.allUsers.first(where: { $0.id == trainerId }) else {
            return (false, "Trainer nicht gefunden")
        }

        guard let settings = trainerSettings[trainerId], settings.isEnabled else {
            return (false, "Dieser Trainer bietet keine Privatstunden an")
        }

        let minDate = Date().addingTimeInterval(minimumBookingLeadTime)
        if requestedDate < minDate {
            return (false, "Privatstunden muessen mindestens 24 Stunden vorher gebucht werden. Diese Anfrage ist verfallen.")
        }

        let price = settings.pricePerHour * Decimal(duration) / 60
        
        let booking = PrivateLessonBooking.create(
            trainerId: trainerId,
            trainerName: trainer.name,
            userId: user.id,
            userName: user.name,
            userEmail: user.email,
            requestedDate: requestedDate,
            duration: duration,
            price: price,
            notes: notes
        )
        
        bookings.append(booking)
        saveLocal()
        await saveToCloud()
        
        // Benachrichtigung an Trainer
        await PushNotificationService.shared.sendLocalNotification(
            title: "Neue Privatstunden-Anfrage",
            body: "\(user.name) möchte eine Privatstunde buchen"
        )
        
        return (true, "Anfrage gesendet! Der Trainer wird sich melden.")
    }
    
    /// Trainer bestätigt eine Buchung - sendet automatisch Zahlungsaufforderung
    func confirmBooking(bookingId: String, confirmedDate: Date) async -> Bool {
        guard let user = UserManager.shared.currentUser else { return false }
        guard let index = bookings.firstIndex(where: { $0.id == bookingId }) else { return false }
        
        // Nur Trainer oder Admin kann bestätigen
        guard user.group.isAdmin || bookings[index].trainerId == user.id else { return false }
        
        bookings[index].confirmedDate = confirmedDate
        bookings[index].updatedAt = Date()
        
        // Zahlungsfrist berechnen (24 Stunden vor Termin)
        let paymentDeadline = confirmedDate.addingTimeInterval(-24 * 60 * 60)
        bookings[index].paymentDeadline = paymentDeadline
        
        // PayPal Zahlungslink erstellen mit Buchungsnummer
        let paypalService = PayPalService.shared
        let bookingNumber = bookings[index].bookingNumber
        let description = bookings[index].paypalDescription
        
        let result = await paypalService.createOrder(
            amount: bookings[index].price,
            bookingNumber: bookingNumber,
            description: description
        )
        
        switch result {
        case .success(let order):
            bookings[index].paypalOrderId = order.id
            bookings[index].paymentLink = order.approvalURL
            bookings[index].paymentStatus = .awaitingPayment
            bookings[index].status = .awaitingPayment
            
            // Benachrichtigung an User mit Zahlungsaufforderung
            await PushNotificationService.shared.sendLocalNotification(
                title: "💳 Privatstunde bestätigt - Zahlung erforderlich",
                body: "Bitte bezahle deine Privatstunde mit \(bookings[index].trainerName) bis \(paymentDeadline.formatted(date: .abbreviated, time: .shortened))"
            )
            
        case .failure:
            // Auch ohne PayPal-Link bestätigen, aber Status auf awaiting payment setzen
            bookings[index].paymentStatus = .awaitingPayment
            bookings[index].status = .awaitingPayment
            
            await PushNotificationService.shared.sendLocalNotification(
                title: "✅ Privatstunde bestätigt!",
                body: "Deine Privatstunde mit \(bookings[index].trainerName) wurde bestätigt. Bitte kontaktiere den Trainer für Zahlungsdetails."
            )
        }
        
        saveLocal()
        await saveToCloud()
        
        return true
    }
    
    // MARK: - Payment Methods
    
    /// User hat bezahlt - aktualisiert den Status
    func markAsPaid(bookingId: String, transactionId: String? = nil) async -> Bool {
        guard let index = bookings.firstIndex(where: { $0.id == bookingId }) else { return false }
        
        bookings[index].paymentStatus = .completed
        bookings[index].paidAt = Date()
        bookings[index].status = .paid
        if let transactionId = transactionId {
            bookings[index].paypalTransactionId = transactionId
        }
        bookings[index].updatedAt = Date()
        
        saveLocal()
        await saveToCloud()
        
        // Benachrichtigung an Trainer
        await PushNotificationService.shared.sendLocalNotification(
            title: "✅ Zahlung erhalten",
            body: "Die Privatstunde von \(bookings[index].userName) wurde bezahlt."
        )
        
        return true
    }
    
    /// Verarbeitet die PayPal-Rückgabe-URL und markiert die Buchung als bezahlt
    func handlePayPalReturnURL(_ url: URL) async -> Bool {
        guard let result = await PayPalService.shared.handleReturnURL(url) else { return false }
        switch result {
        case .success(let capture):
            guard let booking = bookings.first(where: { $0.paypalOrderId == capture.orderId }) else { return false }
            return await markAsPaid(bookingId: booking.id, transactionId: capture.transactionId)
        case .failure:
            return false
        }
    }
    
    /// Admin/Trainer bestätigt manuelle Zahlung (für PayPal.me)
    func confirmManualPayment(bookingId: String, transactionId: String) async -> (success: Bool, message: String) {
        guard let user = UserManager.shared.currentUser else {
            return (false, "Nicht eingeloggt")
        }
        
        guard let index = bookings.firstIndex(where: { $0.id == bookingId }) else {
            return (false, "Buchung nicht gefunden")
        }
        
        // Nur Admin oder der zuständige Trainer kann bestätigen
        guard user.group.isAdmin || bookings[index].trainerId == user.id else {
            return (false, "Keine Berechtigung")
        }
        
        let success = await markAsPaid(bookingId: bookingId, transactionId: transactionId)
        
        if success {
            return (true, "Zahlung bestätigt! Der User wurde benachrichtigt.")
        } else {
            return (false, "Fehler beim Bestätigen der Zahlung")
        }
    }
    
    /// Prüft abgelaufene Zahlungsfristen und storniert automatisch
    func checkExpiredPayments() async {
        let now = Date()
        
        for (index, booking) in bookings.enumerated() {
            // Nur Buchungen die auf Zahlung warten prüfen
            guard booking.status == .awaitingPayment,
                  booking.paymentStatus == .awaitingPayment else { continue }
            
            // Prüfe ob Zahlungsfrist abgelaufen
            if let deadline = booking.paymentDeadline, now > deadline {
                // Automatisch stornieren
                bookings[index].status = .expired
                bookings[index].paymentStatus = .expired
                bookings[index].updatedAt = now
                
                // Nachricht hinzufügen
                let message = PrivateLessonMessage(
                    id: UUID().uuidString,
                    senderId: "SYSTEM",
                    senderName: "System",
                    content: "Buchung automatisch storniert: Zahlungsfrist abgelaufen",
                    timestamp: now,
                    isRead: false
                )
                bookings[index].messages.append(message)
                
                // Slot wieder freigeben wenn vorhanden
                if let slotIndex = timeSlots.firstIndex(where: { $0.bookedByUserId == booking.userId && $0.isBooked }) {
                    timeSlots[slotIndex].isBooked = false
                    timeSlots[slotIndex].bookedByUserId = nil
                }
                
                // Benachrichtigungen senden
                await PushNotificationService.shared.sendLocalNotification(
                    title: "⚠️ Buchung storniert",
                    body: "Deine Privatstunde wurde storniert, da die Zahlungsfrist abgelaufen ist"
                )
            }
        }
        
        saveLocal()
        await saveToCloud()
    }
    
    /// Sendet Zahlungserinnerung
    func sendPaymentReminder(bookingId: String) async -> Bool {
        guard let index = bookings.firstIndex(where: { $0.id == bookingId }) else { return false }
        guard bookings[index].status == .awaitingPayment else { return false }
        
        let booking = bookings[index]
        
        if let deadline = booking.paymentDeadline {
            let remaining = PayPalService.shared.formatTimeRemaining(until: deadline)
            
            await PushNotificationService.shared.sendLocalNotification(
                title: "⏰ Zahlungserinnerung",
                body: "Bitte bezahle deine Privatstunde. Noch \(remaining) verbleibend."
            )
        }
        
        return true
    }
    
    /// Gibt den PayPal-Zahlungslink für eine Buchung zurück
    func getPaymentLink(bookingId: String) -> String? {
        guard let booking = bookings.first(where: { $0.id == bookingId }) else { return nil }
        return booking.paymentLink
    }
    
    /// Storniert eine bezahlte Buchung und markiert sie für Erstattung
    func cancelPaidBooking(bookingId: String, byTrainer: Bool = false) async -> (success: Bool, message: String, needsRefund: Bool) {
        guard let index = bookings.firstIndex(where: { $0.id == bookingId }) else {
            return (false, "Buchung nicht gefunden", false)
        }
        
        let booking = bookings[index]
        
        // Nur bezahlte Buchungen können hier storniert werden
        guard booking.status == .paid else {
            return (false, "Diese Buchung ist nicht bezahlt oder wurde bereits storniert", false)
        }
        
        // Stornierung durchführen
        bookings[index].status = .cancelled
        bookings[index].paymentStatus = .refunded
        bookings[index].updatedAt = Date()
        
        // Nachricht hinzufügen
        let reason = byTrainer ? "Vom Trainer storniert - Erstattung wird veranlasst" : "Vom User storniert - Erstattung wird veranlasst"
        let message = PrivateLessonMessage(
            id: UUID().uuidString,
            senderId: "SYSTEM",
            senderName: "System",
            content: reason,
            timestamp: Date(),
            isRead: false
        )
        bookings[index].messages.append(message)
        
        // Slot wieder freigeben
        if let slotIndex = timeSlots.firstIndex(where: { $0.bookedByUserId == booking.userId && $0.isBooked }) {
            timeSlots[slotIndex].isBooked = false
            timeSlots[slotIndex].bookedByUserId = nil
        }
        
        saveLocal()
        await saveToCloud()
        
        // Benachrichtigung
        await PushNotificationService.shared.sendLocalNotification(
            title: "💸 Buchung storniert",
            body: "Die Privatstunde wurde storniert. Die Erstattung wird in Kürze veranlasst."
        )
        
        return (true, "Buchung storniert. Die Erstattung muss manuell über PayPal erfolgen.", true)
    }

    /// Trainer lehnt eine Buchung ab
    func rejectBooking(bookingId: String, reason: String) async -> Bool {
        guard let user = UserManager.shared.currentUser else { return false }
        guard let index = bookings.firstIndex(where: { $0.id == bookingId }) else { return false }
        
        guard user.group.isAdmin || bookings[index].trainerId == user.id else { return false }
        
        bookings[index].status = .rejected
        bookings[index].updatedAt = Date()
        
        // Nachricht hinzufügen
        let message = PrivateLessonMessage(
            id: UUID().uuidString,
            senderId: user.id,
            senderName: user.name,
            content: "Buchung abgelehnt: \(reason)",
            timestamp: Date(),
            isRead: false
        )
        bookings[index].messages.append(message)
        
        saveLocal()
        await saveToCloud()
        
        return true
    }
    
    /// Buchung abschließen
    func completeBooking(bookingId: String) async -> Bool {
        guard let user = UserManager.shared.currentUser else { return false }
        guard let index = bookings.firstIndex(where: { $0.id == bookingId }) else { return false }
        
        guard user.group.isAdmin || bookings[index].trainerId == user.id else { return false }
        
        bookings[index].status = .completed
        bookings[index].updatedAt = Date()
        
        saveLocal()
        await saveToCloud()
        
        return true
    }
    
    // MARK: - User Cancellation (24h Rule)
    
    /// User storniert seine Buchung (nur wenn mindestens 24h vor Termin)
    func cancelBookingByUser(bookingId: String) async -> (success: Bool, message: String) {
        guard let user = UserManager.shared.currentUser else {
            return (false, "Du musst eingeloggt sein")
        }
        
        guard let index = bookings.firstIndex(where: { $0.id == bookingId }) else {
            return (false, "Buchung nicht gefunden")
        }
        
        let booking = bookings[index]
        
        // Prüfen ob der User der Buchende ist
        guard booking.userId == user.id else {
            return (false, "Du kannst nur deine eigenen Buchungen stornieren")
        }
        
        // Prüfen ob Buchung noch stornierbar ist (pending, confirmed, oder awaitingPayment)
        guard booking.status == .pending || booking.status == .confirmed || booking.status == .awaitingPayment else {
            return (false, "Diese Buchung kann nicht mehr storniert werden")
        }
        
        // Prüfen ob mindestens 24 Stunden vor dem Termin
        let targetDate = booking.confirmedDate ?? booking.requestedDate
        let hoursUntilLesson = targetDate.timeIntervalSince(Date()) / 3600
        
        guard hoursUntilLesson >= 24 else {
            let remainingHours = Int(hoursUntilLesson)
            return (false, "Stornierung nur bis 24 Stunden vor dem Termin möglich. Noch \(remainingHours) Stunden bis zum Termin.")
        }
        
        // Buchung stornieren
        bookings[index].status = .cancelled
        bookings[index].updatedAt = Date()
        
        // Wenn es ein gebuchter Slot war, diesen wieder freigeben
        if let slotIndex = timeSlots.firstIndex(where: { $0.bookedByUserId == user.id && $0.isBooked }) {
            timeSlots[slotIndex].isBooked = false
            timeSlots[slotIndex].bookedByUserId = nil
        }
        
        // Nachricht hinzufügen
        let message = PrivateLessonMessage(
            id: UUID().uuidString,
            senderId: user.id,
            senderName: user.name,
            content: "Buchung vom User storniert",
            timestamp: Date(),
            isRead: false
        )
        bookings[index].messages.append(message)
        
        saveLocal()
        await saveToCloud()
        
        // Benachrichtigung an Trainer
        await PushNotificationService.shared.sendLocalNotification(
            title: "📅 Buchung storniert",
            body: "\(user.name) hat die Privatstunde am \(targetDate.formatted(date: .abbreviated, time: .shortened)) storniert"
        )
        
        return (true, "Buchung erfolgreich storniert")
    }
    
    /// Prüft ob eine Buchung vom User storniert werden kann (24h Regel)
    func canCancelBooking(_ booking: PrivateLessonBooking) -> (canCancel: Bool, reason: String?) {
        guard booking.status == .pending || booking.status == .confirmed || booking.status == .awaitingPayment else {
            return (false, "Diese Buchung kann nicht mehr storniert werden")
        }
        
        let targetDate = booking.confirmedDate ?? booking.requestedDate
        let hoursUntilLesson = targetDate.timeIntervalSince(Date()) / 3600
        
        if hoursUntilLesson >= 24 {
            return (true, nil)
        } else {
            let remainingHours = max(0, Int(hoursUntilLesson))
            return (false, "Stornierung nur bis 24 Stunden vor dem Termin möglich (noch \(remainingHours)h)")
        }
    }
    
    /// Sendet eine Nachricht
    func sendMessage(bookingId: String, content: String) async -> Bool {
        guard let user = UserManager.shared.currentUser else { return false }
        guard let index = bookings.firstIndex(where: { $0.id == bookingId }) else { return false }
        
        // Nur Beteiligte können schreiben
        guard user.id == bookings[index].userId || user.id == bookings[index].trainerId || user.group.isAdmin else {
            return false
        }
        
        let message = PrivateLessonMessage(
            id: UUID().uuidString,
            senderId: user.id,
            senderName: user.name,
            content: content,
            timestamp: Date(),
            isRead: false
        )
        
        bookings[index].messages.append(message)
        bookings[index].updatedAt = Date()
        
        saveLocal()
        await saveToCloud()
        
        return true
    }
    
    // MARK: - Trainer Settings
    
    /// Aktiviert/Konfiguriert Privatstunden für einen Trainer
    func updateTrainerSettings(trainerId: String, isEnabled: Bool, pricePerHour: Decimal, minDuration: Int, maxDuration: Int, description: String) async -> Bool {
        guard let user = UserManager.shared.currentUser else { return false }
        guard user.group.isAdmin || user.id == trainerId else { return false }
        
        var settings = trainerSettings[trainerId] ?? PrivateLessonSettings(
            trainerId: trainerId,
            isEnabled: false,
            pricePerHour: 50,
            minDuration: 30,
            maxDuration: 120,
            availabilities: [],
            description: ""
        )
        
        settings.isEnabled = isEnabled
        settings.pricePerHour = pricePerHour
        settings.minDuration = minDuration
        settings.maxDuration = maxDuration
        settings.description = description
        
        trainerSettings[trainerId] = settings
        
        saveLocal()
        await saveToCloud()
        
        return true
    }
    
    /// Admin setzt den Preis für einen Trainer
    func setTrainerPrice(trainerId: String, pricePerHour: Decimal) async -> Bool {
        guard UserManager.shared.currentUser?.group.isAdmin == true else { return false }
        
        if var settings = trainerSettings[trainerId] {
            settings.pricePerHour = pricePerHour
            trainerSettings[trainerId] = settings
        } else {
            trainerSettings[trainerId] = PrivateLessonSettings(
                trainerId: trainerId,
                isEnabled: true,
                pricePerHour: pricePerHour,
                minDuration: 30,
                maxDuration: 120,
                availabilities: [],
                description: ""
            )
        }
        
        saveLocal()
        await saveToCloud()
        
        return true
    }
    
    // MARK: - Queries
    
    /// Buchungen für einen User
    func bookingsForUser(_ userId: String) -> [PrivateLessonBooking] {
        bookings.filter { $0.userId == userId }.sorted { $0.createdAt > $1.createdAt }
    }
    
    /// Buchungen für einen Trainer
    func bookingsForTrainer(_ trainerId: String) -> [PrivateLessonBooking] {
        bookings.filter { $0.trainerId == trainerId }.sorted { $0.createdAt > $1.createdAt }
    }
    
    /// Lädt Buchungen für einen Trainer (async für Cloud-Sync)
    func loadBookingsForTrainer(_ trainerId: String) async {
        // Lokale Daten sind bereits geladen, hier könnte Cloud-Sync stattfinden
        // Aktuell verwenden wir lokale Daten
        isLoading = true
        // Simuliere kurze Ladezeit
        try? await Task.sleep(nanoseconds: 100_000_000)
        isLoading = false
    }
    
    /// Ausstehende Buchungen für Trainer
    func pendingBookingsForTrainer(_ trainerId: String) -> [PrivateLessonBooking] {
        bookings.filter { $0.trainerId == trainerId && $0.status == .pending }
    }
    
    /// Alle Trainer die Privatstunden anbieten
    var trainersWithPrivateLessons: [AppUser] {
        let enabledTrainerIds = trainerSettings.filter { $0.value.isEnabled }.keys
        return UserManager.shared.allUsers.filter { enabledTrainerIds.contains($0.id) && $0.group == .trainer }
    }
    
    // MARK: - Local Storage
    
    private func saveLocal() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        if let data = try? encoder.encode(bookings) {
            UserDefaults.standard.set(data, forKey: localBookingsKey)
        }
        if let data = try? encoder.encode(trainerSettings) {
            UserDefaults.standard.set(data, forKey: localSettingsKey)
        }
        if let data = try? encoder.encode(timeSlots) {
            UserDefaults.standard.set(data, forKey: localSlotsKey)
        }
    }
    
    private func loadLocal() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        if let data = UserDefaults.standard.data(forKey: localBookingsKey),
           let bookings = try? decoder.decode([PrivateLessonBooking].self, from: data) {
            self.bookings = bookings
        }
        if let data = UserDefaults.standard.data(forKey: localSettingsKey),
           let settings = try? decoder.decode([String: PrivateLessonSettings].self, from: data) {
            self.trainerSettings = settings
        }
        if let data = UserDefaults.standard.data(forKey: localSlotsKey),
           let slots = try? decoder.decode([TrainerTimeSlot].self, from: data) {
            self.timeSlots = slots
        }
    }
    
    // MARK: - Cloud Sync
    
    func loadFromCloud() async {
        isLoading = true
        defer { isLoading = false }
        
        let firebaseBookings = await FirebaseService.shared.loadPrivateLessonBookings()
        if !firebaseBookings.isEmpty {
            self.bookings = firebaseBookings
            saveLocal()
            print("✅ \(bookings.count) Privatstunden-Buchungen von Firebase geladen")
        }
    }
    
    func saveToCloud() async {
        let success = await FirebaseService.shared.saveAllPrivateLessonBookings(bookings)
        if success {
            print("✅ Privatstunden-Buchungen zu Firebase gespeichert")
        }
    }
    
    /// Gibt eine Buchung anhand der Buchungsnummer zurück
    func booking(byNumber bookingNumber: String) -> PrivateLessonBooking? {
        bookings.first { $0.bookingNumber == bookingNumber }
    }
    
    /// Gibt alle bezahlten Buchungen für einen Trainer zurück (für Umsatzübersicht)
    func paidBookingsForTrainer(_ trainerId: String) -> [PrivateLessonBooking] {
        bookings.filter { $0.trainerId == trainerId && $0.paymentStatus == .completed }
            .sorted { $0.paidAt ?? $0.createdAt > $1.paidAt ?? $1.createdAt }
    }
    
    /// Berechnet den Gesamtumsatz eines Trainers
    func totalRevenueForTrainer(_ trainerId: String) -> Decimal {
        paidBookingsForTrainer(trainerId).reduce(0) { $0 + ($1.trainerRevenue ?? 0) }
    }
}
