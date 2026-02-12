//
//  PrivateLessonsView.swift
//  Tanzen mit Tatiana Drexler
//
//  Privatstunden buchen und verwalten
//

import SwiftUI
import AVKit

// MARK: - Teaching Languages Helper View
struct TeachingLanguagesView: View {
    let languageCodes: [String]
    
    private let languageInfo: [String: (flag: String, name: String)] = [
        "de": ("🇩🇪", "Deutsch"),
        "en": ("🇬🇧", "English"),
        "ru": ("🇷🇺", "Русский"),
        "sk": ("🇸🇰", "Slovenčina"),
        "cs": ("🇨🇿", "Čeština")
    ]
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(languageCodes, id: \.self) { code in
                if let info = languageInfo[code] {
                    Text(info.flag)
                        .font(.body)
                }
            }
        }
    }
    
    /// Gibt die Sprachnamen als Text zurück
    var languageNames: String {
        languageCodes.compactMap { languageInfo[$0]?.name }.joined(separator: ", ")
    }
}

// MARK: - User: Privatstunden buchen
struct BookPrivateLessonView: View {
    @StateObject private var lessonManager = PrivateLessonManager.shared
    @StateObject private var userManager = UserManager.shared
    @State private var selectedTrainerId: String?
    @State private var showBookingSheet = false
    @State private var showMyBookings = false
    
    var myBookingsCount: Int {
        guard let userId = userManager.currentUser?.id else { return 0 }
        return lessonManager.bookingsForUser(userId).count
    }
    
    var body: some View {
        List {
            // Info-Banner für Video-Calls
            Section {
                HStack(spacing: TDSpacing.md) {
                    Image(systemName: "video.fill")
                        .font(.title2)
                        .foregroundColor(Color.accentGold)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(T("Online Privatstunden"))
                            .font(TDTypography.headline)
                        Text(T("Alle Privatstunden finden als Video-Call direkt in der App statt. Keine externe Software nötig!"))
                            .font(TDTypography.caption1)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }
            
            // Meine Buchungen Button
            if myBookingsCount > 0 {
                Section {
                    Button { showMyBookings = true } label: {
                        HStack {
                            Image(systemName: "calendar.badge.clock")
                                .font(.title2)
                                .foregroundColor(Color.accentGold)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(T("Meine Privatstunden"))
                                    .font(TDTypography.headline)
                                    .foregroundColor(.primary)
                                Text("\(myBookingsCount) Buchungen")
                                    .font(TDTypography.caption1)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            if lessonManager.trainersWithPrivateLessons.isEmpty {
                ContentUnavailableView(
                    "Keine Trainer verfügbar",
                    systemImage: "person.slash",
                    description: Text(T("Aktuell bietet kein Trainer Privatstunden an"))
                )
            } else {
                Section {
                    ForEach(lessonManager.trainersWithPrivateLessons) { trainer in
                        TrainerPrivateLessonRow(trainer: trainer) {
                            selectedTrainerId = trainer.id
                            showBookingSheet = true
                        }
                    }
                } header: {
                    Text(T("Verfügbare Trainer"))
                }
            }
        }
        .navigationTitle(T("Privatstunden"))
        .sheet(isPresented: $showBookingSheet) {
            if let trainerId = selectedTrainerId {
                BookingFormView(trainerId: trainerId)
            }
        }
        .sheet(isPresented: $showMyBookings) {
            NavigationStack {
                MyPrivateLessonsView()
            }
        }
    }
}

// MARK: - User: Meine Privatstunden Übersicht
struct MyPrivateLessonsView: View {
    @StateObject private var lessonManager = PrivateLessonManager.shared
    @StateObject private var userManager = UserManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var selectedBooking: PrivateLessonBooking?
    @State private var showBookingDetail = false
    @State private var showCancelAlert = false
    @State private var bookingToCancel: PrivateLessonBooking?
    @State private var cancelMessage = ""
    @State private var showCancelResult = false
    @State private var cancelSuccess = false
    
    var myBookings: [PrivateLessonBooking] {
        guard let userId = userManager.currentUser?.id else { return [] }
        return lessonManager.bookingsForUser(userId)
    }
    
    var upcomingBookings: [PrivateLessonBooking] {
        myBookings.filter { $0.status == .pending || $0.status == .confirmed }
            .sorted { ($0.confirmedDate ?? $0.requestedDate) < ($1.confirmedDate ?? $1.requestedDate) }
    }
    
    var pastBookings: [PrivateLessonBooking] {
        myBookings.filter { $0.status == .completed || $0.status == .cancelled || $0.status == .rejected }
            .sorted { $0.updatedAt > $1.updatedAt }
    }
    
    var body: some View {
        List {
            if myBookings.isEmpty {
                ContentUnavailableView(
                    "Keine Buchungen",
                    systemImage: "calendar.badge.exclamationmark",
                    description: Text(T("Du hast noch keine Privatstunden gebucht"))
                )
            } else {
                // Anstehende Buchungen
                if !upcomingBookings.isEmpty {
                    Section(T("Anstehende Stunden")) {
                        ForEach(upcomingBookings) { booking in
                            UserBookingRow(booking: booking) {
                                selectedBooking = booking
                                showBookingDetail = true
                            } onCancel: {
                                bookingToCancel = booking
                                let canCancel = lessonManager.canCancelBooking(booking)
                                if canCancel.canCancel {
                                    showCancelAlert = true
                                } else {
                                    cancelMessage = canCancel.reason ?? "Stornierung nicht möglich"
                                    cancelSuccess = false
                                    showCancelResult = true
                                }
                            }
                        }
                    }
                }
                
                // Vergangene Buchungen
                if !pastBookings.isEmpty {
                    Section(T("Vergangene Stunden")) {
                        ForEach(pastBookings) { booking in
                            UserBookingRow(booking: booking) {
                                selectedBooking = booking
                                showBookingDetail = true
                            } onCancel: { }
                        }
                    }
                }
            }
        }
        .navigationTitle(T("Meine Privatstunden"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(T("Fertig")) { dismiss() }
            }
        }
        .sheet(isPresented: $showBookingDetail) {
            if let booking = selectedBooking {
                UserBookingDetailView(bookingId: booking.id, booking: booking)
            }
        }
        .alert(T("Buchung stornieren?"), isPresented: $showCancelAlert) {
            Button(T("Abbrechen"), role: .cancel) { }
            Button(T("Stornieren"), role: .destructive) {
                Task {
                    if let booking = bookingToCancel {
                        let result = await lessonManager.cancelBookingByUser(bookingId: booking.id)
                        cancelMessage = result.message
                        cancelSuccess = result.success
                        showCancelResult = true
                    }
                }
            }
        } message: {
            if let booking = bookingToCancel {
                Text(T("Möchtest du deine Privatstunde am %@ wirklich stornieren?", (booking.confirmedDate ?? booking.requestedDate).formatted(date: .abbreviated, time: .shortened)))
            }
        }
        .alert(cancelSuccess ? "✅ Erfolg" : "❌ Hinweis", isPresented: $showCancelResult) {
            Button(T("OK"), role: .cancel) { }
        } message: {
            Text(cancelMessage)
        }
    }
}

// MARK: - User Booking Row
struct UserBookingRow: View {
    let booking: PrivateLessonBooking
    let onTap: () -> Void
    let onCancel: () -> Void
    @StateObject private var lessonManager = PrivateLessonManager.shared
    
    var statusColor: Color {
        switch booking.status {
        case .pending: return .orange
        case .confirmed, .paid: return .green
        case .awaitingPayment: return .blue
        case .completed: return .blue
        case .cancelled, .rejected, .expired: return .red
        }
    }
    
    var canCancel: Bool {
        lessonManager.canCancelBooking(booking).canCancel
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: TDSpacing.sm) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(T("Mit %@", booking.trainerName))
                            .font(TDTypography.headline)
                            .foregroundColor(.primary)
                        
                        HStack {
                            Image(systemName: "calendar")
                            Text((booking.confirmedDate ?? booking.requestedDate).formatted(date: .abbreviated, time: .shortened))
                        }
                        .font(TDTypography.caption1)
                        .foregroundColor(.secondary)
                        
                        HStack {
                            Image(systemName: "clock")
                            Text("\(booking.duration) Min.")
                            Text(T("•"))
                            Text(booking.price.formatted(.currency(code: "EUR")))
                        }
                        .font(TDTypography.caption1)
                        .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(booking.status.rawValue)
                            .font(TDTypography.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(statusColor)
                            .cornerRadius(4)
                        
                        if booking.status == .confirmed || booking.status == .paid {
                            Image(systemName: "video.fill")
                                .foregroundColor(.green)
                        } else if booking.status == .awaitingPayment {
                            Image(systemName: "creditcard.fill")
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                // Stornierungsbutton für anstehende Buchungen
                if (booking.status == .pending || booking.status == .confirmed || booking.status == .awaitingPayment) {
                    if canCancel {
                        Button {
                            onCancel()
                        } label: {
                            HStack {
                                Image(systemName: "xmark.circle")
                                Text(T("Stornieren (bis 24h vorher)"))
                            }
                            .font(TDTypography.caption1)
                            .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    } else {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                            Text(T("Stornierung nicht mehr möglich (< 24h)"))
                        }
                        .font(TDTypography.caption2)
                        .foregroundColor(.orange)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - User Booking Detail View
struct UserBookingDetailView: View {
    let bookingId: String
    let initialBooking: PrivateLessonBooking?
    
    @StateObject private var lessonManager = PrivateLessonManager.shared
    @StateObject private var userManager = UserManager.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var newMessage = ""
    @State private var showCancelAlert = false
    @State private var cancelMessage = ""
    @State private var showCancelResult = false
    @State private var cancelSuccess = false
    
    init(bookingId: String, booking: PrivateLessonBooking? = nil) {
        self.bookingId = bookingId
        self.initialBooking = booking
    }
    
    var booking: PrivateLessonBooking? {
        if let initial = initialBooking, lessonManager.bookings.isEmpty {
            return initial
        }
        return lessonManager.bookings.first { $0.id == bookingId } ?? initialBooking
    }
    
    var canCancel: (canCancel: Bool, reason: String?) {
        guard let booking = booking else { return (false, nil) }
        return lessonManager.canCancelBooking(booking)
    }
    
    var body: some View {
        NavigationStack {
            if let booking = booking {
                List {
                    // Status & Details
                    Section(T("Buchungsdetails")) {
                        HStack {
                            Text(T("Status"))
                            Spacer()
                            Text(booking.status.rawValue)
                                .foregroundColor(statusColor(for: booking.status))
                                .fontWeight(.medium)
                        }
                        LabeledContent("Trainer", value: booking.trainerName)
                        LabeledContent("Angefragter Termin", value: booking.requestedDate.formatted(date: .long, time: .shortened))
                        if let confirmed = booking.confirmedDate {
                            LabeledContent("Bestätigter Termin", value: confirmed.formatted(date: .long, time: .shortened))
                        }
                        LabeledContent("Dauer", value: "\(booking.duration) Minuten")
                        LabeledContent("Preis", value: booking.price.formatted(.currency(code: "EUR")))
                    }
                    
                    if !booking.notes.isEmpty {
                        Section(T("Deine Anmerkungen")) {
                            Text(booking.notes)
                        }
                    }
                    
                    // Zahlungsinfo für awaitingPayment
                    if booking.status == .awaitingPayment {
                        Section(T("Zahlung erforderlich")) {
                            PaymentInfoCard(booking: booking)
                        }
                    }
                    
                    // Video-Call Section
                    if booking.status == .confirmed || booking.status == .paid {
                        Section(T("Video-Call")) {
                            VideoCallButton(booking: booking)
                        }
                    }
                    
                    // Stornieren
                    if booking.status == .pending || booking.status == .confirmed || booking.status == .awaitingPayment {
                        Section {
                            if canCancel.canCancel {
                                Button(role: .destructive) {
                                    showCancelAlert = true
                                } label: {
                                    HStack {
                                        Image(systemName: "xmark.circle.fill")
                                        Text(T("Privatstunde stornieren"))
                                    }
                                }
                            } else {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                    Text(canCancel.reason ?? "Stornierung nicht möglich")
                                        .font(TDTypography.caption1)
                                        .foregroundColor(.secondary)
                                }
                            }
                        } footer: {
                            Text(T("Stornierungen sind bis 24 Stunden vor dem Termin kostenlos möglich."))
                        }
                    }
                    
                    // Chat mit Trainer
                    Section(T("Nachrichten mit Trainer")) {
                        if booking.messages.isEmpty {
                            Text(T("Noch keine Nachrichten"))
                                .foregroundColor(.secondary)
                                .italic()
                        } else {
                            ForEach(booking.messages) { message in
                                VStack(alignment: message.senderId == userManager.currentUser?.id ? .trailing : .leading, spacing: 4) {
                                    Text(message.senderName)
                                        .font(TDTypography.caption2)
                                        .foregroundColor(.secondary)
                                    
                                    Text(message.content)
                                        .padding(8)
                                        .background(message.senderId == userManager.currentUser?.id ? Color.accentGold.opacity(0.2) : Color.gray.opacity(0.1))
                                        .cornerRadius(8)
                                    
                                    Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                                        .font(TDTypography.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: message.senderId == userManager.currentUser?.id ? .trailing : .leading)
                            }
                        }
                        
                        HStack {
                            TextField(T("Nachricht an Trainer..."), text: $newMessage)
                            Button {
                                Task {
                                    _ = await lessonManager.sendMessage(bookingId: bookingId, content: newMessage)
                                    newMessage = ""
                                }
                            } label: {
                                Image(systemName: "paperplane.fill")
                                    .foregroundColor(Color.accentGold)
                            }
                            .disabled(newMessage.isEmpty)
                        }
                    }
                }
                .navigationTitle(T("Buchung #%@", String(booking.id.prefix(8))))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(T("Fertig")) { dismiss() }
                    }
                }
                .alert(T("Buchung stornieren?"), isPresented: $showCancelAlert) {
                    Button(T("Abbrechen"), role: .cancel) { }
                    Button(T("Stornieren"), role: .destructive) {
                        Task {
                            let result = await lessonManager.cancelBookingByUser(bookingId: bookingId)
                            cancelMessage = result.message
                            cancelSuccess = result.success
                            showCancelResult = true
                        }
                    }
                } message: {
                    Text(T("Möchtest du deine Privatstunde wirklich stornieren? Diese Aktion kann nicht rückgängig gemacht werden."))
                }
                .alert(cancelSuccess ? "✅ Erfolgreich storniert" : "❌ Fehler", isPresented: $showCancelResult) {
                    Button(T("OK")) {
                        if cancelSuccess { dismiss() }
                    }
                } message: {
                    Text(cancelMessage)
                }
            } else {
                ContentUnavailableView("Buchung nicht gefunden", systemImage: "doc.questionmark")
            }
        }
    }
    
    private func statusColor(for status: PrivateLessonBooking.BookingStatus) -> Color {
        switch status {
        case .pending: return .orange
        case .confirmed, .paid: return .green
        case .awaitingPayment: return .blue
        case .completed: return .blue
        case .cancelled, .rejected, .expired: return .red
        }
    }
}

struct TrainerPrivateLessonRow: View {
    let trainer: AppUser
    let onBook: () -> Void
    @StateObject private var lessonManager = PrivateLessonManager.shared
    @State private var showIntroVideo = false
    
    var settings: PrivateLessonSettings? {
        lessonManager.trainerSettings[trainer.id]
    }
    
    // Sprach-Mapping für Flaggen
    private let languageFlags: [String: String] = [
        "de": "🇩🇪",
        "en": "🇬🇧",
        "ru": "🇷🇺",
        "sk": "🇸🇰",
        "cs": "🇨🇿"
    ]
    
    var teachingLanguageFlags: String {
        let languages = trainer.trainerProfile?.teachingLanguages ?? ["de"]
        return languages.compactMap { languageFlags[$0] }.joined(separator: " ")
    }
    
    var hasIntroVideo: Bool {
        guard let videoURL = trainer.trainerProfile?.introVideoURL, !videoURL.isEmpty else { return false }
        return true
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: TDSpacing.sm) {
            HStack(spacing: TDSpacing.md) {
                // Trainer Avatar
                ZStack {
                    Circle().fill(Color.blue.opacity(0.2)).frame(width: 60, height: 60)
                    if let imageURL = trainer.profileImageURL, !imageURL.isEmpty {
                        AsyncImage(url: URL(string: imageURL)) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Image(systemName: "person.fill").font(.title).foregroundColor(.blue)
                        }
                        .frame(width: 60, height: 60)
                        .clipShape(Circle())
                    } else {
                        Image(systemName: "person.fill").font(.title).foregroundColor(.blue)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(trainer.name)
                            .font(TDTypography.headline)
                        
                        // Video-Badge
                        if hasIntroVideo {
                            Image(systemName: "play.circle.fill")
                                .font(.caption)
                                .foregroundColor(Color.accentGold)
                        }
                    }
                    
                    if let bio = trainer.trainerProfile?.bio, !bio.isEmpty {
                        Text(bio)
                            .font(TDTypography.caption1)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    // Unterrichtssprachen
                    HStack(spacing: 4) {
                        Image(systemName: "globe")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(teachingLanguageFlags)
                            .font(TDTypography.caption1)
                    }
                    
                    if let settings = settings {
                        Text(T("Ab %@/Stunde", settings.pricePerHour.formatted(.currency(code: "EUR"))))
                            .font(TDTypography.subheadline)
                            .foregroundColor(Color.accentGold)
                    }
                }
                
                Spacer()
            }
            
            // Buttons
            HStack(spacing: TDSpacing.sm) {
                // Vorstellungsvideo Button (falls vorhanden)
                if hasIntroVideo {
                    Button {
                        showIntroVideo = true
                    } label: {
                        HStack {
                            Image(systemName: "play.circle")
                            Text(T("Vorstellung"))
                        }
                        .font(TDTypography.caption1)
                        .fontWeight(.medium)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .background(Color.gray.opacity(0.15))
                        .foregroundColor(.primary)
                        .cornerRadius(TDRadius.sm)
                    }
                }
                
                // Buchen Button
                Button(action: onBook) {
                    HStack {
                        Image(systemName: "video.fill")
                        Text(T("Video-Stunde buchen"))
                    }
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.accentGold)
                    .foregroundColor(.white)
                    .cornerRadius(TDRadius.sm)
                }
            }
        }
        .padding(.vertical, 8)
        .sheet(isPresented: $showIntroVideo) {
            if let videoURL = trainer.trainerProfile?.introVideoURL, let url = URL(string: videoURL) {
                TrainerIntroVideoPlayerView(trainerName: trainer.name, url: url)
            }
        }
    }
}

// MARK: - Trainer Intro Video Player
struct TrainerIntroVideoPlayerView: View {
    let trainerName: String
    let url: URL
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VideoPlayer(player: AVPlayer(url: url))
                    .ignoresSafeArea(edges: .bottom)
            }
            .navigationTitle(T("Vorstellung: %@", trainerName))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(T("Fertig")) { dismiss() }
                }
            }
        }
    }
}

struct BookingFormView: View {
    let trainerId: String
    @StateObject private var lessonManager = PrivateLessonManager.shared
    @StateObject private var userManager = UserManager.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedSlot: TrainerTimeSlot?
    @State private var selectedDate = Date().addingTimeInterval(24*60*60)
    @State private var duration = 60
    @State private var notes = ""
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertSuccess = false
    @State private var useCustomTime = false
    @State private var isDataLoaded = false
    
    var trainer: AppUser? {
        // Erst in allUsers suchen, dann in trainersWithPrivateLessons
        if let user = userManager.allUsers.first(where: { $0.id == trainerId }) {
            return user
        }
        return lessonManager.trainersWithPrivateLessons.first { $0.id == trainerId }
    }
    
    var availableSlots: [TrainerTimeSlot] {
        lessonManager.availableSlotsForTrainer(trainerId)
    }
    
    var settings: PrivateLessonSettings? {
        lessonManager.trainerSettings[trainerId]
    }
    
    var price: Decimal {
        if let slot = selectedSlot { return slot.price }
        guard let settings = settings else { return 0 }
        return settings.pricePerHour * Decimal(duration) / 60
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if !isDataLoaded {
                    ProgressView("Lädt Trainerdaten...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if trainer == nil {
                    ContentUnavailableView(
                        "Trainer nicht gefunden",
                        systemImage: "person.slash",
                        description: Text(T("Der ausgewählte Trainer konnte nicht geladen werden"))
                    )
                } else {
                    bookingFormContent
                }
            }
            .navigationTitle(T("Privatstunde buchen"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button(T("Abbrechen")) { dismiss() } }
            }
            .alert(alertSuccess ? "✅ Erfolg" : "❌ Fehler", isPresented: $showAlert) {
                Button(T("OK")) { if alertSuccess { dismiss() } }
            } message: { Text(alertMessage) }
            .task {
                // Lade User-Daten falls nicht vorhanden
                if userManager.allUsers.isEmpty {
                    await userManager.loadFromCloud()
                }
                // Kurze Verzögerung um sicherzustellen dass Daten geladen sind
                try? await Task.sleep(nanoseconds: 300_000_000)
                isDataLoaded = true
            }
        }
    }
    
    private var bookingFormContent: some View {
        Form {
            // Video-Call Info
            Section {
                HStack(spacing: TDSpacing.sm) {
                    Image(systemName: "video.circle.fill")
                        .font(.title)
                        .foregroundColor(.green)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(T("Video-Call Privatstunde"))
                            .font(TDTypography.subheadline)
                            .fontWeight(.medium)
                        Text(T("Die Stunde findet online per Video-Call in der App statt"))
                            .font(TDTypography.caption1)
                            .foregroundColor(.secondary)
                    }
                }
            }
                
            if let trainer = trainer {
                Section {
                    LabeledContent("Trainer:", value: trainer.name)
                    
                    // Unterrichtssprachen anzeigen
                    if let languages = trainer.trainerProfile?.teachingLanguages, !languages.isEmpty {
                        HStack {
                            Text(T("Unterrichtssprachen:"))
                            Spacer()
                            TeachingLanguagesView(languageCodes: languages)
                        }
                    }
                }
            }
                
            // Verfügbare Termine des Trainers
            if !availableSlots.isEmpty {
                Section(T("Verfügbare Termine")) {
                        ForEach(availableSlots) { slot in
                            Button {
                                selectedSlot = slot
                                useCustomTime = false
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(slot.date.formatted(date: .abbreviated, time: .shortened))
                                            .font(TDTypography.headline)
                                            .foregroundColor(.primary)
                                        Text("\(slot.duration) " + T("Min") + " • \(slot.price.formatted(.currency(code: "EUR")))")
                                            .font(TDTypography.caption1)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    if selectedSlot?.id == slot.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(Color.accentGold)
                                    }
                                }
                            }
                        }
                        
                        Button {
                            selectedSlot = nil
                            useCustomTime = true
                        } label: {
                            HStack {
                                Image(systemName: "clock.badge.questionmark")
                                Text(T("Anderen Termin anfragen"))
                                Spacer()
                                if useCustomTime {
                                    Image(systemName: "checkmark.circle.fill").foregroundColor(Color.accentGold)
                                }
                            }
                        }
                    }
                }
                
                // Custom Termin (wenn keine Slots oder anderer Termin gewünscht)
                if useCustomTime || availableSlots.isEmpty {
                    Section(T("Wunschtermin")) {
                        DatePicker("Datum & Uhrzeit", selection: $selectedDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                        Text(T("Privatstunden muessen mindestens 24 Stunden vorher gebucht werden."))
                            .font(TDTypography.caption2)
                            .foregroundColor(.secondary)
                        Picker("Dauer", selection: $duration) {
                            Text(T("30 Min")).tag(30); Text(T("45 Min")).tag(45); Text(T("60 Min")).tag(60); Text(T("90 Min")).tag(90)
                        }
                    }
                }
                
                Section(T("Anmerkungen")) {
                    TextEditor(text: $notes).frame(minHeight: 60)
                }
                
                Section {
                    HStack {
                        Text(T("Preis:"))
                        Spacer()
                        Text(price.formatted(.currency(code: "EUR")))
                            .font(TDTypography.title2).foregroundColor(Color.accentGold)
                    }
                }
                
                Section {
                    Button { Task { await bookLesson() } } label: {
                        HStack {
                            Spacer()
                            if isLoading { ProgressView().tint(.white) }
                            else { Text(selectedSlot != nil ? "Termin buchen" : "Anfrage senden").fontWeight(.semibold) }
                            Spacer()
                        }
                    }
                    .listRowBackground(Color.accentGold)
                    .foregroundColor(.white)
                }
            }
        }
    
    private func bookLesson() async {
        isLoading = true
        defer { isLoading = false }
        
        // Wenn ein Slot ausgewählt wurde, diesen buchen
        if let slot = selectedSlot {
            let result = await lessonManager.bookTimeSlot(slotId: slot.id, notes: notes)
            alertMessage = result.message
            alertSuccess = result.success
        } else {
            // Sonst eine Anfrage senden
            let result = await lessonManager.createBooking(trainerId: trainerId, requestedDate: selectedDate, duration: duration, notes: notes)
            alertMessage = result.message
            alertSuccess = result.success
        }
        showAlert = true
    }
}

// MARK: - Trainer: Buchungen verwalten
struct TrainerBookingsView: View {
    @StateObject private var lessonManager = PrivateLessonManager.shared
    @StateObject private var userManager = UserManager.shared
    @State private var selectedBooking: PrivateLessonBooking?
    @State private var showBookingDetail = false
    @State private var showCreateSlot = false
    
    var myBookings: [PrivateLessonBooking] {
        guard let userId = userManager.currentUser?.id else { return [] }
        if userManager.currentUser?.group.isAdmin == true {
            return lessonManager.bookings.sorted { $0.createdAt > $1.createdAt }
        }
        return lessonManager.bookingsForTrainer(userId)
    }
    
    var mySlots: [TrainerTimeSlot] {
        guard let userId = userManager.currentUser?.id else { return [] }
        return lessonManager.timeSlots.filter { $0.trainerId == userId && !$0.isBooked && $0.date > Date() }
            .sorted { $0.date < $1.date }
    }
    
    var pendingBookings: [PrivateLessonBooking] {
        myBookings.filter { $0.status == .pending }
    }
    
    var confirmedBookings: [PrivateLessonBooking] {
        myBookings.filter { $0.status == .confirmed }
    }
    
    var body: some View {
        List {
            // Verfügbare Termine (vom Trainer angelegt)
            Section {
                ForEach(mySlots) { slot in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(slot.date.formatted(date: .abbreviated, time: .shortened))
                                .font(TDTypography.headline)
                            Text("\(slot.duration) " + T("Min") + " • \(slot.price.formatted(.currency(code: "EUR")))")
                                .font(TDTypography.caption1)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(T("Frei"))
                            .font(TDTypography.caption1)
                            .foregroundColor(.green)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            Task { _ = await lessonManager.deleteTimeSlot(slotId: slot.id) }
                        } label: {
                            Label(T("Löschen"), systemImage: "trash")
                        }
                    }
                }
            } header: {
                HStack {
                    Text(T("Meine verfügbaren Termine"))
                    Spacer()
                    Button { showCreateSlot = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(Color.accentGold)
                    }
                }
            }
            
            if !pendingBookings.isEmpty {
                Section {
                    ForEach(pendingBookings) { booking in
                        BookingRow(booking: booking) {
                            selectedBooking = booking
                            showBookingDetail = true
                        }
                    }
                } header: {
                    HStack {
                        Text(T("Ausstehende Anfragen"))
                        Spacer()
                        Text("\(pendingBookings.count)")
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .background(Color.orange)
                            .cornerRadius(8)
                    }
                }
            }
            
            if !confirmedBookings.isEmpty {
                Section(T("Bestätigte Termine")) {
                    ForEach(confirmedBookings) { booking in
                        BookingRow(booking: booking) {
                            selectedBooking = booking
                            showBookingDetail = true
                        }
                    }
                }
            }
            
            Section(T("Alle Buchungen")) {
                ForEach(myBookings.filter { $0.status != .pending && $0.status != .confirmed }) { booking in
                    BookingRow(booking: booking) {
                        selectedBooking = booking
                        showBookingDetail = true
                    }
                }
            }
            
            // Umsatzübersicht Section
            Section {
                NavigationLink(destination: TrainerRevenueView()) {
                    HStack {
                        Image(systemName: "chart.bar.fill")
                            .foregroundColor(Color.accentGold)
                        Text(T("Umsatzübersicht & Zahlungen"))
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle(T("Meine Buchungen"))
        .sheet(isPresented: $showBookingDetail) {
            if let booking = selectedBooking {
                BookingDetailView(bookingId: booking.id, booking: booking)
            }
        }
        .sheet(isPresented: $showCreateSlot) {
            CreateTimeSlotView()
        }
    }
}

// MARK: - Trainer: Umsatzübersicht mit Buchungsnummern
struct TrainerRevenueView: View {
    @StateObject private var lessonManager = PrivateLessonManager.shared
    @StateObject private var userManager = UserManager.shared
    
    var trainerId: String {
        userManager.currentUser?.id ?? ""
    }
    
    var paidBookings: [PrivateLessonBooking] {
        lessonManager.paidBookingsForTrainer(trainerId)
    }
    
    var totalRevenue: Decimal {
        lessonManager.totalRevenueForTrainer(trainerId)
    }
    
    var body: some View {
        List {
            // Zusammenfassung
            Section {
                VStack(spacing: TDSpacing.md) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(T("Gesamtumsatz"))
                                .font(TDTypography.caption1)
                                .foregroundColor(.secondary)
                            Text(totalRevenue.formatted(.currency(code: "EUR")))
                                .font(TDTypography.title1)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
                        Spacer()
                        Image(systemName: "eurosign.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(Color.accentGold)
                    }
                    
                    Text(T("Bei PayPal-Zahlungen erhältst du 100% des Betrags direkt auf dein Konto."))
                        .font(TDTypography.caption1)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
            
            // Info für PayPal-Zuordnung
            Section {
                HStack(spacing: TDSpacing.sm) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                    Text(T("Die Buchungsnummer erscheint in der PayPal-Beschreibung jeder Zahlung. So kannst du Zahlungen auf deinem PayPal-Konto leicht zuordnen."))
                        .font(TDTypography.caption1)
                        .foregroundColor(.secondary)
                }
            }
            
            // Einzelne Zahlungen
            Section {
                if paidBookings.isEmpty {
                    ContentUnavailableView(
                        "Keine Zahlungen",
                        systemImage: "creditcard.trianglebadge.exclamationmark",
                        description: Text(T("Du hast noch keine bezahlten Buchungen"))
                    )
                } else {
                    ForEach(paidBookings) { booking in
                        VStack(alignment: .leading, spacing: 10) {
                            // Buchungsnummer & Betrag
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(booking.bookingNumber)
                                        .font(TDTypography.headline)
                                        .foregroundColor(Color.accentGold)
                                    Text(booking.userName)
                                        .font(TDTypography.body)
                                    Text(T("Trainer: %@", booking.trainerName))
                                        .font(TDTypography.caption1)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(booking.price.formatted(.currency(code: "EUR")))
                                    .font(TDTypography.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                            }
                            
                            Divider()
                            
                            // Termin der Privatstunde
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundColor(Color.accentGold)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(T("Privatstunde"))
                                        .font(TDTypography.caption2)
                                        .foregroundColor(.secondary)
                                    if let confirmedDate = booking.confirmedDate {
                                        Text(confirmedDate.formatted(date: .long, time: .shortened))
                                            .font(TDTypography.caption1)
                                    } else {
                                        Text(booking.requestedDate.formatted(date: .long, time: .shortened))
                                            .font(TDTypography.caption1)
                                    }
                                }
                                Spacer()
                                Text("\(booking.duration) Min")
                                    .font(TDTypography.caption1)
                                    .foregroundColor(.secondary)
                            }
                            
                            // Buchungs- und Zahlungsdatum
                            HStack {
                                // Buchungsdatum
                                HStack {
                                    Image(systemName: "clock")
                                        .foregroundColor(.secondary)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(T("Gebucht"))
                                            .font(TDTypography.caption2)
                                            .foregroundColor(.secondary)
                                        Text(booking.createdAt.formatted(date: .abbreviated, time: .shortened))
                                            .font(TDTypography.caption1)
                                    }
                                }
                                
                                Spacer()
                                
                                // Zahlungsdatum
                                if let paidAt = booking.paidAt {
                                    HStack {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text(T("Bezahlt"))
                                                .font(TDTypography.caption2)
                                                .foregroundColor(.secondary)
                                            Text(paidAt.formatted(date: .abbreviated, time: .shortened))
                                                .font(TDTypography.caption1)
                                        }
                                    }
                                }
                            }
                            
                            // PayPal Transaktions-ID falls vorhanden
                            if let transactionId = booking.paypalTransactionId, !transactionId.isEmpty {
                                HStack {
                                    Image(systemName: "creditcard")
                                        .foregroundColor(.blue)
                                    Text(T("PayPal: %@", transactionId))
                                        .font(TDTypography.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            } header: {
                HStack {
                    Text(T("Bezahlte Buchungen"))
                    Spacer()
                    Text("\(paidBookings.count)")
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .background(Color.green)
                        .cornerRadius(8)
                }
            }
        }
        .navigationTitle(T("Umsatzübersicht"))
    }
}

// MARK: - Trainer: Termin anlegen
struct CreateTimeSlotView: View {
    @StateObject private var lessonManager = PrivateLessonManager.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedDate = Date().addingTimeInterval(24*60*60)
    @State private var duration = 60
    @State private var isCreating = false
    @State private var showSuccess = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section(T("Termin")) {
                    DatePicker("Datum & Uhrzeit", selection: $selectedDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                    
                    Picker("Dauer", selection: $duration) {
                        Text(T("30 Minuten")).tag(30)
                        Text(T("45 Minuten")).tag(45)
                        Text(T("60 Minuten")).tag(60)
                        Text(T("90 Minuten")).tag(90)
                        Text(T("120 Minuten")).tag(120)
                    }
                }
                
                Section {
                    Button {
                        Task { await createSlot() }
                    } label: {
                        HStack {
                            Spacer()
                            if isCreating { ProgressView().tint(.white) }
                            else { Text(T("Termin erstellen")).fontWeight(.semibold) }
                            Spacer()
                        }
                    }
                    .listRowBackground(Color.accentGold)
                    .foregroundColor(.white)
                    .disabled(isCreating)
                }
            }
            .navigationTitle(T("Neuer Termin"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(T("Abbrechen")) { dismiss() }
                }
            }
            .alert(T("✅ Termin erstellt"), isPresented: $showSuccess) {
                Button(T("OK")) { dismiss() }
            } message: {
                Text(T("Der Termin ist jetzt für Buchungen verfügbar."))
            }
        }
    }
    
    private func createSlot() async {
        isCreating = true
        defer { isCreating = false }
        
        if await lessonManager.createTimeSlot(date: selectedDate, duration: duration) {
            showSuccess = true
        }
    }
}

struct BookingRow: View {
    let booking: PrivateLessonBooking
    let onTap: () -> Void
    
    var statusColor: Color {
        switch booking.status {
        case .pending: return .orange
        case .confirmed, .paid: return .green
        case .awaitingPayment: return .blue
        case .completed: return .blue
        case .cancelled, .rejected, .expired: return .red
        }
    }
    
    var lessonDate: Date {
        booking.confirmedDate ?? booking.requestedDate
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    // Buchungsnummer prominent anzeigen
                    Text(booking.bookingNumber)
                        .font(TDTypography.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.accentGold)
                    
                    Text(booking.userName)
                        .font(TDTypography.headline)
                        .foregroundColor(.primary)
                    
                    // Trainername
                    Text(T("Trainer: %@", booking.trainerName))
                        .font(TDTypography.caption1)
                        .foregroundColor(.secondary)
                    
                    // Termin der Privatstunde
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                        Text(lessonDate.formatted(date: .abbreviated, time: .shortened))
                    }
                    .font(TDTypography.caption1)
                    .foregroundColor(.secondary)
                    
                    // Buchungsdatum
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text(T("Gebucht: %@", booking.createdAt.formatted(date: .abbreviated, time: .omitted)))
                    }
                    .font(TDTypography.caption2)
                    .foregroundColor(.secondary.opacity(0.8))
                    
                    Text("\(booking.duration) " + T("Min.") + " • \(booking.price.formatted(.currency(code: "EUR")))")
                        .font(TDTypography.caption1)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(booking.status.rawValue)
                        .font(TDTypography.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusColor)
                        .cornerRadius(4)
                    
                    if booking.paymentStatus == .completed {
                        HStack(spacing: 2) {
                            Image(systemName: "checkmark.circle.fill")
                            Text(T("Bezahlt"))
                        }
                        .font(.caption2)
                        .foregroundColor(.green)
                    }
                }
            }
        }
    }
}

struct BookingDetailView: View {
    let bookingId: String
    let initialBooking: PrivateLessonBooking? // Optional: Buchung direkt übergeben
    
    @StateObject private var lessonManager = PrivateLessonManager.shared
    @StateObject private var userManager = UserManager.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var newMessage = ""
    @State private var confirmedDate = Date()
    @State private var rejectReason = ""
    @State private var showRejectAlert = false
    @State private var isLoaded = false
    
    init(bookingId: String, booking: PrivateLessonBooking? = nil) {
        self.bookingId = bookingId
        self.initialBooking = booking
    }
    
    var booking: PrivateLessonBooking? {
        // Erst die übergebene Buchung, dann aus dem Manager suchen
        if let initial = initialBooking, lessonManager.bookings.isEmpty {
            return initial
        }
        return lessonManager.bookings.first { $0.id == bookingId } ?? initialBooking
    }
    
    var canManage: Bool {
        guard let user = userManager.currentUser, let booking = booking else { return false }
        return user.group.isAdmin || user.id == booking.trainerId
    }
    
    var body: some View {
        NavigationStack {
            if let booking = booking {
                List {
                    // Buchungsnummer prominent oben
                    Section {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(T("Buchungsnummer"))
                                    .font(TDTypography.caption1)
                                    .foregroundColor(.secondary)
                                Text(booking.bookingNumber)
                                    .font(TDTypography.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(Color.accentGold)
                            }
                            Spacer()
                            // Copy Button
                            Button {
                                UIPasteboard.general.string = booking.bookingNumber
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .foregroundColor(Color.accentGold)
                            }
                        }
                    }
                    
                    // Status & Details
                    Section(T("Buchungsdetails")) {
                        LabeledContent("Status", value: booking.status.rawValue)
                        LabeledContent("Trainer", value: booking.trainerName)
                        LabeledContent("Kunde", value: booking.userName)
                        if !booking.userEmail.isEmpty {
                            LabeledContent("E-Mail", value: booking.userEmail)
                        }
                        LabeledContent("Dauer", value: "\(booking.duration) Minuten")
                        LabeledContent("Preis", value: booking.price.formatted(.currency(code: "EUR")))
                    }
                    
                    // Termine
                    Section(T("Termine")) {
                        LabeledContent {
                            Text(booking.requestedDate.formatted(date: .long, time: .shortened))
                        } label: {
                            Label(T("Angefragter Termin"), systemImage: "calendar.badge.clock")
                        }
                        
                        if let confirmed = booking.confirmedDate {
                            LabeledContent {
                                Text(confirmed.formatted(date: .long, time: .shortened))
                                    .foregroundColor(.green)
                            } label: {
                                Label(T("Bestätigter Termin"), systemImage: "calendar.badge.checkmark")
                            }
                        }
                        
                        LabeledContent {
                            Text(booking.createdAt.formatted(date: .long, time: .shortened))
                        } label: {
                            Label(T("Buchung erstellt"), systemImage: "clock")
                        }
                        
                        if let paidAt = booking.paidAt {
                            LabeledContent {
                                Text(paidAt.formatted(date: .long, time: .shortened))
                                    .foregroundColor(.green)
                            } label: {
                                Label(T("Bezahlt am"), systemImage: "creditcard")
                            }
                        }
                    }
                    
                    if !booking.notes.isEmpty {
                        Section(T("Anmerkungen")) {
                            Text(booking.notes)
                        }
                    }
                    
                    // Video-Call Section (nur bei bestätigten/bezahlten Buchungen)
                    if booking.status == .confirmed || booking.status == .paid {
                        Section(T("Video-Call")) {
                            VideoCallButton(booking: booking)
                        }
                    }
                    
                    // Aktionen für Trainer
                    if canManage && booking.status == .pending {
                        Section(T("Aktionen")) {
                            DatePicker("Termin bestätigen für", selection: $confirmedDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                            
                            Button {
                                Task {
                                    _ = await lessonManager.confirmBooking(bookingId: bookingId, confirmedDate: confirmedDate)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text(T("Bestätigen"))
                                }
                                .foregroundColor(.green)
                            }
                            
                            Button { showRejectAlert = true } label: {
                                HStack {
                                    Image(systemName: "xmark.circle.fill")
                                    Text(T("Ablehnen"))
                                }
                                .foregroundColor(.red)
                            }
                        }
                    }
                    
                    // Zahlungs-Section (für awaiting payment Status)
                    if booking.status == .awaitingPayment && canManage {
                        Section(T("Zahlungsstatus")) {
                            HStack {
                                Text(T("Status:"))
                                Spacer()
                                PaymentStatusBadge(status: booking.paymentStatus)
                            }
                            
                            if let deadline = booking.paymentDeadline {
                                PaymentDeadlineView(deadline: deadline)
                            }
                            
                            NavigationLink {
                                AdminPaymentConfirmationView(booking: booking)
                            } label: {
                                HStack {
                                    Image(systemName: "creditcard.fill")
                                        .foregroundColor(Color.accentGold)
                                    Text(T("Zahlung bestätigen"))
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                    }
                    
                    // Bezahlt-Status anzeigen
                    if booking.status == .paid {
                        Section(T("Zahlungsstatus")) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text(T("Bezahlt"))
                                Spacer()
                                if let paidAt = booking.paidAt {
                                    Text(paidAt.formatted(date: .abbreviated, time: .shortened))
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            if let transactionId = booking.paypalTransactionId {
                                LabeledContent("Transaktions-ID", value: transactionId)
                                    .font(TDTypography.caption1)
                            }
                        }
                    }
                    
                    if canManage && (booking.status == .paid || booking.status == .confirmed) {
                        Section {
                            Button {
                                Task {
                                    _ = await lessonManager.completeBooking(bookingId: bookingId)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "checkmark.seal.fill")
                                    Text(T("Als abgeschlossen markieren"))
                                }
                                .foregroundColor(.blue)
                            }
                        }
                    }
                    
                    // Chat
                    Section(T("Nachrichten")) {
                        ForEach(booking.messages) { message in
                            VStack(alignment: message.senderId == userManager.currentUser?.id ? .trailing : .leading, spacing: 4) {
                                Text(message.senderName)
                                    .font(TDTypography.caption2)
                                    .foregroundColor(.secondary)
                                
                                Text(message.content)
                                    .padding(8)
                                    .background(message.senderId == userManager.currentUser?.id ? Color.accentGold.opacity(0.2) : Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                                
                                Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                                    .font(TDTypography.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: message.senderId == userManager.currentUser?.id ? .trailing : .leading)
                        }
                        
                        HStack {
                            TextField(T("Nachricht..."), text: $newMessage)
                            Button {
                                Task {
                                    _ = await lessonManager.sendMessage(bookingId: bookingId, content: newMessage)
                                    newMessage = ""
                                }
                            } label: {
                                Image(systemName: "paperplane.fill")
                                    .foregroundColor(Color.accentGold)
                            }
                            .disabled(newMessage.isEmpty)
                        }
                    }
                }
                .navigationTitle(T("Buchung #%@", String(booking.id.prefix(8))))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(T("Fertig")) { dismiss() }
                    }
                }
                .alert(T("Buchung ablehnen"), isPresented: $showRejectAlert) {
                    TextField(T("Grund"), text: $rejectReason)
                    Button(T("Abbrechen"), role: .cancel) { }
                    Button(T("Ablehnen"), role: .destructive) {
                        Task {
                            _ = await lessonManager.rejectBooking(bookingId: bookingId, reason: rejectReason)
                        }
                    }
                }
                .onAppear {
                    confirmedDate = booking.requestedDate
                }
            } else {
                ContentUnavailableView("Buchung nicht gefunden", systemImage: "doc.questionmark")
            }
        }
    }
}

// MARK: - Admin: Privatstunden-Einstellungen
struct PrivateLessonsAdminView: View {
    @StateObject private var lessonManager = PrivateLessonManager.shared
    @StateObject private var userManager = UserManager.shared
    
    var trainers: [AppUser] {
        userManager.allUsers.filter { $0.group == .trainer }
    }
    
    var body: some View {
        List {
            Section(T("Trainer-Einstellungen")) {
                ForEach(trainers) { trainer in
                    NavigationLink(destination: TrainerLessonSettingsView(trainerId: trainer.id)) {
                        HStack {
                            Text(trainer.name)
                            Spacer()
                            if let settings = lessonManager.trainerSettings[trainer.id], settings.isEnabled {
                                Text("\(settings.pricePerHour.formatted(.currency(code: "EUR")))" + T("/h"))
                                    .font(TDTypography.caption1)
                                    .foregroundColor(.secondary)
                            } else {
                                Text(T("Deaktiviert"))
                                    .font(TDTypography.caption1)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
            }
            
            Section(T("Alle Buchungen")) {
                NavigationLink(destination: TrainerBookingsView()) {
                    HStack {
                        Text(T("Buchungen anzeigen"))
                        Spacer()
                        Text("\(lessonManager.bookings.count)")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle(T("Privatstunden"))
    }
}

struct TrainerLessonSettingsView: View {
    let trainerId: String
    @StateObject private var lessonManager = PrivateLessonManager.shared
    @StateObject private var userManager = UserManager.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var isEnabled = false
    @State private var pricePerHour: Decimal = 50
    @State private var minDuration = 30
    @State private var maxDuration = 120
    @State private var description = ""
    @State private var isLoading = false
    
    var trainer: AppUser? {
        userManager.allUsers.first { $0.id == trainerId }
    }
    
    var body: some View {
        Form {
            Section {
                Toggle("Privatstunden aktiviert", isOn: $isEnabled)
            }
            
            if isEnabled {
                Section(T("Preisgestaltung")) {
                    HStack {
                        Text(T("Preis pro Stunde:"))
                        Spacer()
                        TextField(T("Preis"), value: $pricePerHour, format: .currency(code: "EUR"))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                Section(T("Dauer")) {
                    Picker("Minimum", selection: $minDuration) {
                        Text(T("30 Min")).tag(30)
                        Text(T("45 Min")).tag(45)
                        Text(T("60 Min")).tag(60)
                    }
                    
                    Picker("Maximum", selection: $maxDuration) {
                        Text(T("60 Min")).tag(60)
                        Text(T("90 Min")).tag(90)
                        Text(T("120 Min")).tag(120)
                    }
                }
                
                Section(T("Beschreibung")) {
                    TextEditor(text: $description)
                        .frame(minHeight: 100)
                }
            }
            
            Section {
                Button { Task { await saveSettings() } } label: {
                    HStack {
                        Spacer()
                        if isLoading { ProgressView().tint(.white) }
                        else { Text(T("Speichern")).fontWeight(.semibold) }
                        Spacer()
                    }
                }
                .listRowBackground(Color.accentGold)
                .foregroundColor(.white)
            }
        }
        .navigationTitle(trainer?.name ?? "Trainer")
        .onAppear { loadSettings() }
    }
    
    private func loadSettings() {
        if let settings = lessonManager.trainerSettings[trainerId] {
            isEnabled = settings.isEnabled
            pricePerHour = settings.pricePerHour
            minDuration = settings.minDuration
            maxDuration = settings.maxDuration
            description = settings.description
        }
    }
    
    private func saveSettings() async {
        isLoading = true
        defer { isLoading = false }
        
        _ = await lessonManager.updateTrainerSettings(
            trainerId: trainerId,
            isEnabled: isEnabled,
            pricePerHour: pricePerHour,
            minDuration: minDuration,
            maxDuration: maxDuration,
            description: description
        )
        
        dismiss()
    }
}

// MARK: - Video Call Button mit 10-Minuten-Regel
struct VideoCallButton: View {
    let booking: PrivateLessonBooking
    @StateObject private var lessonManager = PrivateLessonManager.shared
    @StateObject private var userManager = UserManager.shared
    @State private var showVideoCall = false
    
    var isTrainer: Bool {
        userManager.currentUser?.id == booking.trainerId
    }
    
    var isUser: Bool {
        userManager.currentUser?.id == booking.userId
    }
    
    var canStartCall: Bool {
        // Trainer kann 10 Min vorher starten, User kann erst wenn Trainer startet
        if isTrainer {
            return lessonManager.canStartCall(for: booking)
        }
        // User kann immer beitreten wenn Termin bestätigt/bezahlt ist
        return booking.status == .confirmed || booking.status == .paid
    }
    
    var timeUntilStart: String? {
        guard let confirmedDate = booking.confirmedDate else { return nil }
        let now = Date()
        let diff = confirmedDate.timeIntervalSince(now)
        
        if diff > 0 {
            let minutes = Int(diff / 60)
            let hours = minutes / 60
            if hours > 0 {
                return "Startet in \(hours)h \(minutes % 60)min"
            } else if minutes > 0 {
                return "Startet in \(minutes) Minuten"
            }
        }
        return nil
    }
    
    var body: some View {
        VStack(spacing: TDSpacing.sm) {
            if let timeInfo = timeUntilStart {
                HStack {
                    Image(systemName: "clock")
                    Text(timeInfo)
                }
                .font(TDTypography.caption1)
                .foregroundColor(.secondary)
            }
            
            if canStartCall {
                Button { showVideoCall = true } label: {
                    HStack {
                        Image(systemName: "video.fill")
                        Text(isTrainer ? "Video-Call starten" : "Video-Call beitreten")
                    }
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(TDRadius.md)
                }
            } else if isTrainer {
                HStack {
                    Image(systemName: "clock.badge.exclamationmark")
                    Text(T("Video-Call kann 10 Min. vor Start gestartet werden"))
                }
                .font(TDTypography.caption1)
                .foregroundColor(.orange)
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(TDRadius.sm)
            }
        }
        .sheet(isPresented: $showVideoCall) {
            VideoCallView(bookingId: booking.id)
        }
    }
}

// MARK: - Video Call View (Placeholder - muss mit VideoCallService verbunden werden)
struct VideoCallView: View {
    let bookingId: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: TDSpacing.lg) {
                Image(systemName: "video.fill")
                    .font(.system(size: 80))
                    .foregroundColor(Color.accentGold)
                
                Text(T("Video-Call"))
                    .font(TDTypography.title1)
                
                Text(T("Video-Call-Funktion wird hier angezeigt."))
                    .font(TDTypography.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Button { dismiss() } label: {
                    HStack {
                        Image(systemName: "phone.down.fill")
                        Text(T("Anruf beenden"))
                    }
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(TDRadius.md)
                }
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle(T("Video-Call"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}
