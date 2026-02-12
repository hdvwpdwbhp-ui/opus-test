//
//  MyBookingsView.swift
//  Tanzen mit Tatiana Drexler
//
//  Übersicht aller Buchungen des Users (Privatstunden, etc.)
//

import SwiftUI

struct MyBookingsView: View {
    @StateObject private var lessonManager = PrivateLessonManager.shared
    @StateObject private var userManager = UserManager.shared
    @State private var selectedBooking: PrivateLessonBooking?
    @State private var showBookingDetail = false
    @State private var showCancelAlert = false
    @State private var bookingToCancel: PrivateLessonBooking?
    @State private var showCancelResult = false
    @State private var cancelSuccess = false
    @State private var cancelMessage = ""
    
    var myBookings: [PrivateLessonBooking] {
        guard let userId = userManager.currentUser?.id else { return [] }
        return lessonManager.bookingsForUser(userId)
    }
    
    var upcomingBookings: [PrivateLessonBooking] {
        myBookings.filter {
            $0.status == .pending ||
            $0.status == .confirmed ||
            $0.status == .awaitingPayment ||
            $0.status == .paid
        }
        .sorted { ($0.confirmedDate ?? $0.requestedDate) < ($1.confirmedDate ?? $1.requestedDate) }
    }
    
    var pastBookings: [PrivateLessonBooking] {
        myBookings.filter {
            $0.status == .completed ||
            $0.status == .cancelled ||
            $0.status == .rejected ||
            $0.status == .expired
        }
        .sorted { $0.updatedAt > $1.updatedAt }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                TDGradients.mainBackground
                    .ignoresSafeArea()
                
                if myBookings.isEmpty {
                    emptyStateView
                } else {
                    bookingsListView
                }
            }
            .navigationTitle(T("Meine Buchungen"))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        LiveClassesListView()
                    } label: {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .foregroundColor(Color.accentGold)
                    }
                }
            }
            .sheet(isPresented: $showBookingDetail) {
                if let booking = selectedBooking {
                    BookingDetailSheet(booking: booking)
                }
            }
            .alert(T("Buchung stornieren?"), isPresented: $showCancelAlert) {
                Button("Abbrechen", role: .cancel) { }
                Button("Stornieren", role: .destructive) {
                    if let booking = bookingToCancel {
                        Task {
                            let result = await lessonManager.cancelBookingByUser(bookingId: booking.id)
                            cancelSuccess = result.success
                            cancelMessage = result.message
                            showCancelResult = true
                        }
                    }
                }
            } message: {
                Text(T("Möchtest du diese Buchung wirklich stornieren?"))
            }
            .alert(cancelSuccess ? "✅ Erfolg" : "❌ Fehler", isPresented: $showCancelResult) {
                Button(T("OK")) { }
            } message: {
                Text(cancelMessage)
            }
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: TDSpacing.lg) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 60))
                .foregroundColor(Color.accentGold.opacity(0.6))
            
            Text(T("Keine Buchungen"))
                .font(TDTypography.title2)
                .foregroundColor(.primary)
            
            Text(T("Buche deine erste Privatstunde und sie erscheint hier"))
                .font(TDTypography.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, TDSpacing.xl)
            
            NavigationLink {
                BookPrivateLessonView()
            } label: {
                HStack {
                    Image(systemName: "person.fill.badge.plus")
                    Text(T("Privatstunde buchen"))
                }
                .font(TDTypography.headline)
                .foregroundColor(.black)
                .padding(.horizontal, TDSpacing.xl)
                .padding(.vertical, TDSpacing.md)
                .background(Color.accentGold)
                .cornerRadius(TDRadius.md)
            }
        }
    }
    
    // MARK: - Bookings List
    private var bookingsListView: some View {
        ScrollView {
            VStack(spacing: TDSpacing.lg) {
                LiveClassBookingsSection()

                // Quick Action: Neue Buchung
                NavigationLink {
                    BookPrivateLessonView()
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(Color.accentGold)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(T("Neue Privatstunde buchen"))
                                .font(TDTypography.headline)
                                .foregroundColor(.primary)
                            Text(T("Wähle einen Trainer und Termin"))
                                .font(TDTypography.caption1)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding(TDSpacing.md)
                    .glassBackground()
                }
                .padding(.horizontal, TDSpacing.md)
                
                // Anstehende Buchungen
                if !upcomingBookings.isEmpty {
                    VStack(alignment: .leading, spacing: TDSpacing.sm) {
                        Text(T("Anstehende Stunden"))
                            .font(TDTypography.headline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, TDSpacing.md)
                        
                        ForEach(upcomingBookings) { booking in
                            BookingCard(booking: booking) {
                                selectedBooking = booking
                                showBookingDetail = true
                            } onCancel: {
                                bookingToCancel = booking
                                showCancelAlert = true
                            }
                            .padding(.horizontal, TDSpacing.md)
                        }
                    }
                }
                
                // Vergangene Buchungen
                if !pastBookings.isEmpty {
                    VStack(alignment: .leading, spacing: TDSpacing.sm) {
                        Text(T("Vergangene Stunden"))
                            .font(TDTypography.headline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, TDSpacing.md)
                        
                        ForEach(pastBookings) { booking in
                            BookingCard(booking: booking, isPast: true) {
                                selectedBooking = booking
                                showBookingDetail = true
                            }
                            .padding(.horizontal, TDSpacing.md)
                        }
                    }
                }
            }
            .padding(.vertical, TDSpacing.md)
        }
    }
}

struct LiveClassBookingsSection: View {
    @StateObject private var liveManager = LiveClassManager.shared
    @StateObject private var userManager = UserManager.shared

    private var bookedEvents: [LiveClassEvent] {
        let bookedIds = Set(liveManager.myBookings.filter { $0.status == .paid }.map { $0.eventId })
        return liveManager.events.filter { bookedIds.contains($0.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TDSpacing.sm) {
            Text(T("Livestreams"))
                .font(TDTypography.headline)
                .foregroundColor(.secondary)
                .padding(.horizontal, TDSpacing.md)

            if bookedEvents.isEmpty {
                Text(T("Keine Livestream-Buchungen"))
                    .font(TDTypography.caption1)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, TDSpacing.md)
            } else {
                ForEach(bookedEvents) { event in
                    NavigationLink {
                        LiveClassDetailView(event: event)
                    } label: {
                        LiveClassCard(event: event)
                            .padding(.horizontal, TDSpacing.md)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .task {
            liveManager.startListeningToEvents()
            if let userId = userManager.currentUser?.id {
                liveManager.startListeningToBookings(userId: userId)
            }
        }
    }
}

// MARK: - Booking Card
struct BookingCard: View {
    let booking: PrivateLessonBooking
    var isPast: Bool = false
    let onTap: () -> Void
    var onCancel: (() -> Void)? = nil
    
    @StateObject private var userManager = UserManager.shared
    
    var trainerName: String {
        userManager.allUsers.first { $0.id == booking.trainerId }?.name ?? "Trainer"
    }
    
    var statusColor: Color {
        switch booking.status {
        case .pending: return .orange
        case .confirmed, .paid: return .green
        case .awaitingPayment: return .blue
        case .completed: return .blue
        case .cancelled, .rejected, .expired: return .red
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: TDSpacing.sm) {
                // Header mit Trainer und Status
                HStack {
                    Image(systemName: "person.circle.fill")
                        .font(.title2)
                        .foregroundColor(Color.accentGold)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(trainerName)
                            .font(TDTypography.headline)
                            .foregroundColor(.primary)
                        Text(T("Privatstunde"))
                            .font(TDTypography.caption1)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(T(booking.status.rawValue))
                        .font(TDTypography.caption1)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusColor.opacity(0.2))
                        .foregroundColor(statusColor)
                        .cornerRadius(TDRadius.sm)
                }
                
                Divider()
                
                // Termin-Info
                HStack(spacing: TDSpacing.md) {
                    Label {
                        Text((booking.confirmedDate ?? booking.requestedDate).formatted(date: .abbreviated, time: .shortened))
                            .font(TDTypography.body)
                    } icon: {
                        Image(systemName: "calendar")
                            .foregroundColor(Color.accentGold)
                    }
                    
                    Spacer()
                    
                    Label {
                        Text("\(booking.duration) " + T("Min"))
                            .font(TDTypography.body)
                    } icon: {
                        Image(systemName: "clock")
                            .foregroundColor(Color.accentGold)
                    }
                }
                .foregroundColor(.primary)
                
                // Zahlungsstatus anzeigen (wenn relevant)
                if booking.status == .awaitingPayment {
                    // Zahlungsfrist anzeigen
                    if let deadline = booking.paymentDeadline {
                        PaymentDeadlineView(deadline: deadline)
                            .padding(.top, 4)
                    }
                    
                    // PayPal Button
                    PayPalPaymentButton(booking: booking)
                        .padding(.top, 4)
                } else if booking.status == .paid {
                    // Bezahlt-Status anzeigen
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(T("Bezahlt"))
                            .font(TDTypography.caption1)
                            .foregroundColor(.green)
                        
                        if let paidAt = booking.paidAt {
                            Text(T("• %@", paidAt.formatted(date: .abbreviated, time: .omitted)))
                                .font(TDTypography.caption1)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 4)
                    
                    // Video-Call Hinweis
                    HStack {
                        Image(systemName: "video.fill")
                            .foregroundColor(.green)
                        Text(T("Video-Call wird vor Termin freigeschaltet"))
                            .font(TDTypography.caption1)
                            .foregroundColor(.green)
                    }
                    .padding(.top, 4)
                } else if booking.status == .confirmed && !isPast {
                    // Video-Call Hinweis für bestätigte Buchungen (alte Logik als Fallback)
                    HStack {
                        Image(systemName: "video.fill")
                            .foregroundColor(.green)
                        Text(T("Video-Call wird vor Termin freigeschaltet"))
                            .font(TDTypography.caption1)
                            .foregroundColor(.green)
                    }
                    .padding(.top, 4)
                } else if booking.status == .expired {
                    // Abgelaufen-Hinweis
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(T("Zahlungsfrist abgelaufen - Buchung storniert"))
                            .font(TDTypography.caption1)
                            .foregroundColor(.red)
                    }
                    .padding(.top, 4)
                }
                
                // Cancel Button für anstehende Buchungen
                if !isPast && (booking.status == .pending || booking.status == .confirmed || booking.status == .awaitingPayment), let onCancel = onCancel {
                    Button {
                        onCancel()
                    } label: {
                        HStack {
                            Image(systemName: "xmark.circle")
                            Text(T("Stornieren"))
                        }
                        .font(TDTypography.caption1)
                        .foregroundColor(.red)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(TDSpacing.md)
            .glassBackground()
        }
        .buttonStyle(.plain)
        .opacity(isPast ? 0.7 : 1.0)
    }
}

// MARK: - Booking Detail Sheet
struct BookingDetailSheet: View {
    let booking: PrivateLessonBooking
    @StateObject private var userManager = UserManager.shared
    @StateObject private var lessonManager = PrivateLessonManager.shared
    @Environment(\.dismiss) var dismiss
    
    var trainerName: String {
        userManager.allUsers.first { $0.id == booking.trainerId }?.name ?? "Trainer"
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: TDSpacing.md) {
                    // Buchungsdetails
                    VStack(alignment: .leading, spacing: TDSpacing.sm) {
                        Text(T("Buchungsdetails"))
                            .font(TDTypography.headline)
                            .foregroundColor(.secondary)
                        
                        VStack(spacing: TDSpacing.sm) {
                            BookingDetailRow(label: "Trainer", value: trainerName)
                            BookingDetailRow(label: "Status", value: booking.status.rawValue, color: statusColor)
                            BookingDetailRow(label: "Datum", value: (booking.confirmedDate ?? booking.requestedDate).formatted(date: .long, time: .shortened))
                            BookingDetailRow(label: "Dauer", value: "\(booking.duration) Minuten")
                            BookingDetailRow(label: "Preis", value: booking.price.formatted(.currency(code: "EUR")))
                        }
                        .padding(TDSpacing.md)
                        .glassBackground()
                    }
                    
                    // Zahlungsinformationen (wenn relevant)
                    if booking.status == .awaitingPayment || booking.status == .paid || booking.paymentStatus != .pending {
                        PaymentInfoCard(booking: booking)
                    }
                    
                    // Anmerkungen
                    if !booking.notes.isEmpty {
                        VStack(alignment: .leading, spacing: TDSpacing.sm) {
                            Text(T("Anmerkungen"))
                                .font(TDTypography.headline)
                                .foregroundColor(.secondary)
                            
                            Text(booking.notes)
                                .font(TDTypography.body)
                                .padding(TDSpacing.md)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .glassBackground()
                        }
                    }
                    
                    // Video-Call Info
                    if booking.status == .paid || booking.status == .confirmed {
                        VStack(alignment: .leading, spacing: TDSpacing.sm) {
                            Text(T("Video-Call"))
                                .font(TDTypography.headline)
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: TDSpacing.md) {
                                Image(systemName: "video.circle.fill")
                                    .font(.title)
                                    .foregroundColor(.green)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(T("Video-Call verfügbar"))
                                        .font(TDTypography.subheadline)
                                        .fontWeight(.medium)
                                    Text(T("Der Video-Call wird 10 Minuten vor Beginn freigeschaltet"))
                                        .font(TDTypography.caption1)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(TDSpacing.md)
                            .glassBackground()
                        }
                    }
                    
                    // Buchungs-ID
                    VStack(alignment: .leading, spacing: TDSpacing.sm) {
                        Text(T("Buchungs-ID"))
                            .font(TDTypography.headline)
                            .foregroundColor(.secondary)
                        
                        Text(booking.id)
                            .font(TDTypography.caption1)
                            .foregroundColor(.secondary)
                            .padding(TDSpacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .glassBackground()
                    }
                }
                .padding(TDSpacing.md)
            }
            .background(TDGradients.mainBackground.ignoresSafeArea())
            .navigationTitle(T("Buchungsdetails"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(T("Fertig")) { dismiss() }
                }
            }
        }
    }
    
    var statusColor: Color {
        switch booking.status {
        case .pending: return .orange
        case .confirmed, .paid: return .green
        case .awaitingPayment: return .blue
        case .completed: return .blue
        case .cancelled, .rejected, .expired: return .red
        }
    }
}

// MARK: - Detail Row Helper
struct BookingDetailRow: View {
    let label: String
    let value: String
    var color: Color? = nil
    
    var body: some View {
        HStack {
            Text(label)
                .font(TDTypography.body)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(TDTypography.body)
                .fontWeight(.medium)
                .foregroundColor(color ?? .primary)
        }
    }
}

#Preview {
    MyBookingsView()
}
