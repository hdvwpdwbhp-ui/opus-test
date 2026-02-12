//
//  CalendarView.swift
//  Tanzen mit Tatiana Drexler
//
//  Kalender-Ansicht und Übungsplan
//

import SwiftUI
import EventKit

// MARK: - Calendar & Schedule View
struct CalendarScheduleView: View {
    @StateObject private var calendarManager = CalendarManager.shared
    @StateObject private var lessonManager = PrivateLessonManager.shared
    @StateObject private var userManager = UserManager.shared
    
    @State private var showAddSchedule = false
    @State private var selectedDate = Date()
    
    var upcomingBookings: [PrivateLessonBooking] {
        guard let userId = userManager.currentUser?.id else { return [] }
        return lessonManager.bookingsForUser(userId)
            .filter { $0.status == .confirmed || $0.status == .paid }
            .filter { ($0.confirmedDate ?? $0.requestedDate) > Date() }
            .sorted { ($0.confirmedDate ?? $0.requestedDate) < ($1.confirmedDate ?? $1.requestedDate) }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: TDSpacing.lg) {
                // Calendar Access Request
                if !calendarManager.hasCalendarAccess {
                    calendarAccessCard
                }
                
                // Upcoming Section
                upcomingSection
                
                // Practice Schedule
                practiceScheduleSection
                
                // Add to Calendar Button
                if calendarManager.hasCalendarAccess {
                    addScheduleButton
                }
            }
            .padding()
        }
        .background(TDGradients.mainBackground.ignoresSafeArea())
        .navigationTitle(T("Kalender"))
        .sheet(isPresented: $showAddSchedule) {
            AddPracticeScheduleView()
        }
        .onAppear {
            calendarManager.loadUpcomingEvents()
        }
    }
    
    // MARK: - Calendar Access Card
    private var calendarAccessCard: some View {
        VStack(spacing: TDSpacing.md) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 40))
                .foregroundColor(Color.accentGold)
            
            Text(T("Kalender verbinden"))
                .font(TDTypography.headline)
            
            Text(T("Erhalte Erinnerungen für deine Privatstunden und Übungszeiten direkt in deinem Kalender."))
                .font(TDTypography.caption1)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                Task {
                    await calendarManager.requestCalendarAccess()
                }
            } label: {
                Text(T("Kalender verbinden"))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentGold)
                    .cornerRadius(TDRadius.md)
            }
        }
        .padding()
        .glassBackground()
    }
    
    // MARK: - Upcoming Section
    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: TDSpacing.md) {
            Text(T("Anstehende Termine"))
                .font(TDTypography.headline)
            
            if upcomingBookings.isEmpty && calendarManager.upcomingEvents.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text(T("Keine anstehenden Termine"))
                            .font(TDTypography.caption1)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding()
            } else {
                // Private Lessons
                ForEach(upcomingBookings) { booking in
                    UpcomingBookingCard(booking: booking)
                }
                
                // Calendar Events
                ForEach(calendarManager.upcomingEvents.prefix(5), id: \.eventIdentifier) { event in
                    UpcomingEventCard(event: event)
                }
            }
        }
        .padding()
        .glassBackground()
    }
    
    // MARK: - Practice Schedule Section
    private var practiceScheduleSection: some View {
        VStack(alignment: .leading, spacing: TDSpacing.md) {
            HStack {
                Text(T("Übungsplan"))
                    .font(TDTypography.headline)
                Spacer()
                Button(T("Bearbeiten")) {
                    showAddSchedule = true
                }
                .font(TDTypography.caption1)
                .foregroundColor(Color.accentGold)
            }
            
            VStack(spacing: TDSpacing.sm) {
                PracticeScheduleRow(day: "Montag", time: "Nicht geplant", isActive: false)
                PracticeScheduleRow(day: "Dienstag", time: "Nicht geplant", isActive: false)
                PracticeScheduleRow(day: "Mittwoch", time: "Nicht geplant", isActive: false)
                PracticeScheduleRow(day: "Donnerstag", time: "Nicht geplant", isActive: false)
                PracticeScheduleRow(day: "Freitag", time: "Nicht geplant", isActive: false)
                PracticeScheduleRow(day: "Samstag", time: "Nicht geplant", isActive: false)
                PracticeScheduleRow(day: "Sonntag", time: "Nicht geplant", isActive: false)
            }
        }
        .padding()
        .glassBackground()
    }
    
    // MARK: - Add Schedule Button
    private var addScheduleButton: some View {
        Button {
            showAddSchedule = true
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text(T("Übungszeit hinzufügen"))
            }
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.accentGold)
            .cornerRadius(TDRadius.md)
        }
    }
}

// MARK: - Upcoming Booking Card
struct UpcomingBookingCard: View {
    let booking: PrivateLessonBooking
    @StateObject private var calendarManager = CalendarManager.shared
    @State private var addedToCalendar = false
    
    var eventDate: Date {
        booking.confirmedDate ?? booking.requestedDate
    }
    
    var body: some View {
        HStack(spacing: TDSpacing.md) {
            // Date Box
            VStack(spacing: 2) {
                Text(dayOfMonth)
                    .font(.system(size: 24, weight: .bold))
                Text(monthShort)
                    .font(TDTypography.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 50)
            .padding(8)
            .background(Color.accentGold.opacity(0.1))
            .cornerRadius(TDRadius.sm)
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(T("Privatstunde"))
                    .font(TDTypography.headline)
                Text("mit \(booking.trainerName)")
                    .font(TDTypography.caption1)
                    .foregroundColor(.secondary)
                Text(timeString)
                    .font(TDTypography.caption1)
                    .foregroundColor(Color.accentGold)
            }
            
            Spacer()
            
            // Add to Calendar
            if calendarManager.hasCalendarAccess && !addedToCalendar {
                Button {
                    Task {
                        let success = await calendarManager.addPrivateLessonToCalendar(
                            booking: booking,
                            trainerName: booking.trainerName
                        )
                        if success {
                            addedToCalendar = true
                        }
                    }
                } label: {
                    Image(systemName: "calendar.badge.plus")
                        .foregroundColor(Color.accentGold)
                }
            } else if addedToCalendar {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(TDRadius.md)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    var dayOfMonth: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: eventDate)
    }
    
    var monthShort: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.string(from: eventDate)
    }
    
    var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: eventDate) + " Uhr • \(booking.duration) Min."
    }
}

// MARK: - Upcoming Event Card
struct UpcomingEventCard: View {
    let event: EKEvent
    
    var body: some View {
        HStack(spacing: TDSpacing.md) {
            // Date Box
            VStack(spacing: 2) {
                Text(dayOfMonth)
                    .font(.system(size: 24, weight: .bold))
                Text(monthShort)
                    .font(TDTypography.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 50)
            .padding(8)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(TDRadius.sm)
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title ?? "Termin")
                    .font(TDTypography.headline)
                Text(timeString)
                    .font(TDTypography.caption1)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "calendar")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(TDRadius.md)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    var dayOfMonth: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: event.startDate)
    }
    
    var monthShort: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.string(from: event.startDate)
    }
    
    var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let start = formatter.string(from: event.startDate)
        let end = formatter.string(from: event.endDate)
        return "\(start) - \(end) Uhr"
    }
}

// MARK: - Practice Schedule Row
struct PracticeScheduleRow: View {
    let day: String
    let time: String
    let isActive: Bool
    
    var body: some View {
        HStack {
            Text(day)
                .font(TDTypography.body)
                .frame(width: 100, alignment: .leading)
            
            Spacer()
            
            Text(time)
                .font(TDTypography.caption1)
                .foregroundColor(isActive ? Color.accentGold : .secondary)
            
            Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isActive ? Color.accentGold : .gray.opacity(0.3))
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Add Practice Schedule View
struct AddPracticeScheduleView: View {
    @StateObject private var calendarManager = CalendarManager.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedDays: Set<Int> = []
    @State private var practiceTime = Date()
    @State private var duration = 30
    @State private var title = "Tanzübung"
    @State private var isSaving = false
    
    let daysOfWeek = [
        (2, "Montag"),
        (3, "Dienstag"),
        (4, "Mittwoch"),
        (5, "Donnerstag"),
        (6, "Freitag"),
        (7, "Samstag"),
        (1, "Sonntag")
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section(T("Übungsdetails")) {
                    TextField(T("Titel"), text: $title)
                    
                    Picker("Dauer", selection: $duration) {
                        Text(T("15 Minuten")).tag(15)
                        Text(T("30 Minuten")).tag(30)
                        Text(T("45 Minuten")).tag(45)
                        Text(T("60 Minuten")).tag(60)
                    }
                    
                    DatePicker("Uhrzeit", selection: $practiceTime, displayedComponents: .hourAndMinute)
                }
                
                Section(T("Wochentage")) {
                    ForEach(daysOfWeek, id: \.0) { day, name in
                        Button {
                            if selectedDays.contains(day) {
                                selectedDays.remove(day)
                            } else {
                                selectedDays.insert(day)
                            }
                        } label: {
                            HStack {
                                Text(name)
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedDays.contains(day) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(Color.accentGold)
                                }
                            }
                        }
                    }
                }
                
                Section {
                    Button {
                        Task {
                            await saveSchedule()
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if isSaving {
                                ProgressView().tint(.white)
                            } else {
                                Text(T("Zum Kalender hinzufügen"))
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .listRowBackground(Color.accentGold)
                    .foregroundColor(.white)
                    .disabled(selectedDays.isEmpty || isSaving)
                }
            }
            .navigationTitle(T("Übungsplan"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(T("Abbrechen")) { dismiss() }
                }
            }
        }
    }
    
    private func saveSchedule() async {
        isSaving = true
        defer { isSaving = false }
        
        // Combine selected time with today's date
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: practiceTime)
        var startDateComponents = calendar.dateComponents([.year, .month, .day], from: Date())
        startDateComponents.hour = components.hour
        startDateComponents.minute = components.minute
        
        guard let startDate = calendar.date(from: startDateComponents) else { return }
        
        let success = await calendarManager.addRecurringPracticeSchedule(
            title: title,
            startDate: startDate,
            duration: duration,
            daysOfWeek: Array(selectedDays),
            endDate: nil
        )
        
        if success {
            dismiss()
        }
    }
}

#Preview {
    NavigationStack {
        CalendarScheduleView()
    }
}
