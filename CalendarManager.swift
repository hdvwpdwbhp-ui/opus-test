//
//  CalendarManager.swift
//  Tanzen mit Tatiana Drexler
//
//  Kalender-Integration für Privatstunden und Lernpläne
//

import Foundation
import EventKit
import Combine
import UIKit

@MainActor
class CalendarManager: ObservableObject {
    static let shared = CalendarManager()
    
    @Published var hasCalendarAccess = false
    @Published var upcomingEvents: [EKEvent] = []
    @Published var lastError: String?
    
    private let eventStore = EKEventStore()
    private let calendarIdentifierKey = "dance_app_calendar_id"
    
    private init() {
        checkCalendarAccess()
    }
    
    // MARK: - Permissions
    
    func requestCalendarAccess() async -> Bool {
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            await MainActor.run {
                hasCalendarAccess = granted
            }
            return granted
        } catch {
            await MainActor.run {
                lastError = error.localizedDescription
            }
            return false
        }
    }
    
    private func checkCalendarAccess() {
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(iOS 17.0, *) {
            hasCalendarAccess = status == .fullAccess || status == .writeOnly
        } else {
            hasCalendarAccess = status == .authorized
        }
    }
    
    // MARK: - Get/Create App Calendar
    
    private func getOrCreateAppCalendar() -> EKCalendar? {
        // Check if we have a saved calendar ID
        if let calendarId = UserDefaults.standard.string(forKey: calendarIdentifierKey),
           let calendar = eventStore.calendar(withIdentifier: calendarId) {
            return calendar
        }
        
        // Create new calendar
        let newCalendar = EKCalendar(for: .event, eventStore: eventStore)
        newCalendar.title = "Tanzen mit Tatiana"
        newCalendar.cgColor = UIColor.systemOrange.cgColor
        
        // Find a source
        if let localSource = eventStore.sources.first(where: { $0.sourceType == .local }) {
            newCalendar.source = localSource
        } else if let iCloudSource = eventStore.sources.first(where: { $0.sourceType == .calDAV && $0.title == "iCloud" }) {
            newCalendar.source = iCloudSource
        } else if let source = eventStore.defaultCalendarForNewEvents?.source {
            newCalendar.source = source
        } else {
            return nil
        }
        
        do {
            try eventStore.saveCalendar(newCalendar, commit: true)
            UserDefaults.standard.set(newCalendar.calendarIdentifier, forKey: calendarIdentifierKey)
            return newCalendar
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }
    
    // MARK: - Add Events
    
    /// Fügt eine Privatstunde zum Kalender hinzu
    func addPrivateLessonToCalendar(
        booking: PrivateLessonBooking,
        trainerName: String
    ) async -> Bool {
        if !hasCalendarAccess {
            let granted = await requestCalendarAccess()
            if !granted { return false }
        }
        
        guard let calendar = getOrCreateAppCalendar(),
              let eventDate = booking.confirmedDate ?? Optional(booking.requestedDate) else {
            return false
        }
        
        let event = EKEvent(eventStore: eventStore)
        event.title = "🩰 Privatstunde mit \(trainerName)"
        event.startDate = eventDate
        event.endDate = eventDate.addingTimeInterval(Double(booking.duration) * 60)
        event.calendar = calendar
        event.notes = """
        Buchungsnummer: \(booking.bookingNumber)
        Dauer: \(booking.duration) Minuten
        Preis: \(booking.price.formatted(.currency(code: "EUR")))
        
        Öffne die App um den Video-Call zu starten.
        """
        
        // Add reminder 30 minutes before
        let alarm30Min = EKAlarm(relativeOffset: -30 * 60)
        let alarm1Hour = EKAlarm(relativeOffset: -60 * 60)
        event.alarms = [alarm30Min, alarm1Hour]
        
        // Add URL to app
        event.url = URL(string: "tanzen-app://booking/\(booking.id)")
        
        do {
            try eventStore.save(event, span: .thisEvent)
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }
    
    /// Fügt einen Übungsplan zum Kalender hinzu
    func addPracticeSchedule(
        title: String,
        date: Date,
        duration: Int, // in Minuten
        courseId: String,
        lessonId: String?
    ) async -> Bool {
        if !hasCalendarAccess {
            let granted = await requestCalendarAccess()
            if !granted { return false }
        }
        
        guard let calendar = getOrCreateAppCalendar() else { return false }
        
        let event = EKEvent(eventStore: eventStore)
        event.title = "💃 Übung: \(title)"
        event.startDate = date
        event.endDate = date.addingTimeInterval(Double(duration) * 60)
        event.calendar = calendar
        event.notes = "Öffne die App um mit dem Üben zu beginnen."
        
        // Add reminder
        let alarm = EKAlarm(relativeOffset: -15 * 60)
        event.alarms = [alarm]
        
        // Deep link
        if let lessonId = lessonId {
            event.url = URL(string: "tanzen-app://lesson/\(courseId)/\(lessonId)")
        } else {
            event.url = URL(string: "tanzen-app://course/\(courseId)")
        }
        
        do {
            try eventStore.save(event, span: .thisEvent)
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }
    
    /// Fügt wiederkehrende Übungszeiten hinzu
    func addRecurringPracticeSchedule(
        title: String,
        startDate: Date,
        duration: Int,
        daysOfWeek: [Int], // 1 = Sonntag, 2 = Montag, etc.
        endDate: Date?
    ) async -> Bool {
        if !hasCalendarAccess {
            let granted = await requestCalendarAccess()
            if !granted { return false }
        }
        
        guard let calendar = getOrCreateAppCalendar() else { return false }
        
        let event = EKEvent(eventStore: eventStore)
        event.title = "💃 \(title)"
        event.startDate = startDate
        event.endDate = startDate.addingTimeInterval(Double(duration) * 60)
        event.calendar = calendar
        
        // Create recurrence rule
        let daysOfWeekEK = daysOfWeek.compactMap { EKRecurrenceDayOfWeek(EKWeekday(rawValue: $0)!) }
        let recurrenceEnd = endDate != nil ? EKRecurrenceEnd(end: endDate!) : nil
        
        let rule = EKRecurrenceRule(
            recurrenceWith: .weekly,
            interval: 1,
            daysOfTheWeek: daysOfWeekEK,
            daysOfTheMonth: nil,
            monthsOfTheYear: nil,
            weeksOfTheYear: nil,
            daysOfTheYear: nil,
            setPositions: nil,
            end: recurrenceEnd
        )
        
        event.recurrenceRules = [rule]
        
        // Add reminder
        let alarm = EKAlarm(relativeOffset: -15 * 60)
        event.alarms = [alarm]
        
        do {
            try eventStore.save(event, span: .futureEvents)
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }
    
    // MARK: - Load Events
    
    func loadUpcomingEvents() {
        guard hasCalendarAccess else { return }
        
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .month, value: 1, to: startDate) ?? startDate
        
        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: nil
        )
        
        let events = eventStore.events(matching: predicate)
            .filter { $0.title?.contains("Privatstunde") == true || $0.title?.contains("Übung") == true }
            .sorted { $0.startDate < $1.startDate }
        
        upcomingEvents = events
    }
    
    // MARK: - Delete Events
    
    func deleteEvent(for bookingId: String) async -> Bool {
        guard hasCalendarAccess else { return false }
        
        let startDate = Date().addingTimeInterval(-30 * 24 * 60 * 60) // 30 days ago
        let endDate = Date().addingTimeInterval(365 * 24 * 60 * 60) // 1 year ahead
        
        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: nil
        )
        
        let events = eventStore.events(matching: predicate)
        
        for event in events {
            if event.notes?.contains(bookingId) == true {
                do {
                    try eventStore.remove(event, span: .thisEvent)
                    return true
                } catch {
                    lastError = error.localizedDescription
                    return false
                }
            }
        }
        
        return false
    }
}
