//
//  TrainerDashboardView.swift
//  Tanzen mit Tatiana Drexler
//
//  Übersichtliches Trainer-Dashboard mit allen Trainer-Funktionen
//

import SwiftUI

// MARK: - Trainer Dashboard
struct TrainerDashboardView: View {
    @StateObject private var userManager = UserManager.shared
    @StateObject private var lessonManager = PrivateLessonManager.shared
    @StateObject private var liveManager = LiveClassManager.shared
    @StateObject private var planManager = TrainingPlanManager.shared
    @StateObject private var reviewManager = VideoReviewManager.shared
    @StateObject private var chatManager = TrainerChatManager.shared
    @StateObject private var trainerWalletManager = TrainerWalletManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedCategory: TrainerCategory = .overview
    
    private var trainerId: String {
        userManager.currentUser?.id ?? ""
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                TDGradients.mainBackground.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Kategorie-Auswahl
                    categoryPicker
                    
                    // Inhalt basierend auf Kategorie
                    ScrollView {
                        VStack(spacing: TDSpacing.lg) {
                            switch selectedCategory {
                            case .overview:
                                overviewSection
                            case .bookings:
                                bookingsSection
                            case .liveClasses:
                                liveClassesSection
                            case .content:
                                contentSection
                            case .reviews:
                                reviewsSection
                            case .earnings:
                                earningsSection
                            }
                        }
                        .padding(TDSpacing.md)
                    }
                }
            }
            .navigationTitle(T("Trainer-Bereich"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(T("Schließen")) { dismiss() }
                        .foregroundColor(Color.accentGold)
                }
            }
            .onAppear {
                guard userManager.currentUser?.group == .trainer else {
                    dismiss()
                    return
                }
                Task {
                    liveManager.startListeningToEvents()
                    await lessonManager.loadBookingsForTrainer(trainerId)
                    await planManager.loadOrdersForTrainer(trainerId)
                    await reviewManager.loadSubmissionsForTrainer(trainerId)
                    await trainerWalletManager.initializeForTrainer(trainerId)
                }
            }
        }
    }
    
    // MARK: - Category Picker
    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: TDSpacing.sm) {
                ForEach(TrainerCategory.allCases, id: \.self) { category in
                    TrainerCategoryTab(
                        category: category,
                        isSelected: selectedCategory == category,
                        badge: badgeCount(for: category)
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCategory = category
                        }
                    }
                }
            }
            .padding(.horizontal, TDSpacing.md)
            .padding(.vertical, TDSpacing.sm)
        }
        .background(Color(.systemBackground).opacity(0.9))
    }
    
    private func badgeCount(for category: TrainerCategory) -> Int {
        switch category {
        case .overview:
            return pendingBookingsCount + pendingReviewsCount
        case .bookings:
            return pendingBookingsCount
        case .liveClasses:
            return upcomingLiveClassesCount
        case .content:
            return 0
        case .reviews:
            return pendingReviewsCount
        case .earnings:
            return 0
        }
    }
    
    private var pendingBookingsCount: Int {
        lessonManager.pendingBookingsForTrainer(trainerId).count
    }
    
    private var pendingReviewsCount: Int {
        reviewManager.submissionsForTrainer(trainerId).filter { $0.submissionStatus == .submitted }.count
    }
    
    private var upcomingLiveClassesCount: Int {
        liveManager.events.filter { $0.trainerId == trainerId && $0.startTime > Date() }.count
    }
    
    // MARK: - Overview Section
    private var overviewSection: some View {
        VStack(spacing: TDSpacing.lg) {
            welcomeCard
            if hasAlerts { alertsCard }
            quickStatsGrid
            quickAccessGrid
            upcomingEventsCard
        }
    }
    
    private var hasAlerts: Bool {
        pendingBookingsCount > 0 || pendingReviewsCount > 0
    }
    
    private var welcomeCard: some View {
        HStack(spacing: TDSpacing.md) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color.accentGold, Color.accentGoldLight], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 60, height: 60)
                Text(userManager.currentUser?.name.prefix(1).uppercased() ?? "T")
                    .font(.title).fontWeight(.bold).foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(T("Hallo, %@", userManager.currentUser?.name.components(separatedBy: " ").first ?? "Trainer"))
                    .font(TDTypography.title3).fontWeight(.bold)
                Text(Date(), style: .date)
                    .font(TDTypography.caption1).foregroundColor(.secondary)
            }
            Spacer()
            VStack {
                Image(systemName: "figure.dance")
                    .foregroundColor(Color.accentGold)
                Text(T("Trainer"))
                    .font(TDTypography.caption2).foregroundColor(.secondary)
            }
        }
        .padding(TDSpacing.md)
        .glassBackground()
    }
    
    private var alertsCard: some View {
        VStack(spacing: TDSpacing.sm) {
            if pendingBookingsCount > 0 {
                TrainerAlertRow(
                    icon: "calendar.badge.clock",
                    title: "\(pendingBookingsCount) Privatstunden-Anfragen",
                    color: .orange
                ) {
                    selectedCategory = .bookings
                }
            }
            if pendingReviewsCount > 0 {
                TrainerAlertRow(
                    icon: "video.badge.ellipsis",
                    title: "\(pendingReviewsCount) Video-Reviews ausstehend",
                    color: .blue
                ) {
                    selectedCategory = .reviews
                }
            }
        }
        .padding(TDSpacing.md)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(TDRadius.md)
        .overlay(RoundedRectangle(cornerRadius: TDRadius.md).stroke(Color.orange.opacity(0.3), lineWidth: 1))
    }
    
    private var quickStatsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: TDSpacing.md) {
            TrainerStatCard(title: "Privatstunden", value: "\(lessonManager.bookingsForTrainer(trainerId).filter { $0.status == .confirmed }.count)", icon: "video.fill", color: .green)
            TrainerStatCard(title: "Livestreams", value: "\(upcomingLiveClassesCount)", icon: "dot.radiowaves.left.and.right", color: .orange)
            TrainerStatCard(title: "Trainingspläne", value: "\(planManager.ordersForTrainer(trainerId).count)", icon: "doc.text.fill", color: .purple)
            TrainerStatCard(title: "Reviews", value: "\(reviewManager.submissionsForTrainer(trainerId).count)", icon: "play.rectangle.fill", color: .blue)
        }
    }
    
    private var quickAccessGrid: some View {
        VStack(alignment: .leading, spacing: TDSpacing.sm) {
            Text(T("Schnellzugriff")).font(TDTypography.headline).foregroundColor(.secondary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: TDSpacing.md) {
                TrainerQuickButton(icon: "plus.circle.fill", title: "Livestream", color: .orange) {
                    selectedCategory = .liveClasses
                }
                TrainerQuickButton(icon: "calendar.badge.plus", title: "Zeiten", color: .green) {
                    selectedCategory = .bookings
                }
                TrainerQuickButton(icon: "play.rectangle.fill", title: "Reviews", color: .blue) {
                    selectedCategory = .reviews
                }
                TrainerQuickButton(icon: "person.text.rectangle", title: "Profil", color: .purple) {
                    selectedCategory = .content
                }
                TrainerQuickButton(icon: "eurosign.circle.fill", title: "Umsatz", color: .yellow) {
                    selectedCategory = .earnings
                }
                TrainerQuickButton(icon: "message.fill", title: "Chat", color: .teal) {
                    selectedCategory = .bookings
                }
            }
        }
    }
    
    private var upcomingEventsCard: some View {
        VStack(alignment: .leading, spacing: TDSpacing.sm) {
            HStack {
                Text(T("Anstehende Termine")).font(TDTypography.headline).foregroundColor(.secondary)
                Spacer()
            }
            
            let upcomingBookings = lessonManager.bookingsForTrainer(trainerId)
                .filter { $0.status == .confirmed && ($0.confirmedDate ?? $0.requestedDate) > Date() }
                .sorted { ($0.confirmedDate ?? $0.requestedDate) < ($1.confirmedDate ?? $1.requestedDate) }
                .prefix(3)
            
            let upcomingLive = liveManager.events
                .filter { $0.trainerId == trainerId && $0.startTime > Date() }
                .sorted { $0.startTime < $1.startTime }
                .prefix(2)
            
            if upcomingBookings.isEmpty && upcomingLive.isEmpty {
                Text(T("Keine anstehenden Termine")).font(TDTypography.body).foregroundColor(.secondary).frame(maxWidth: .infinity).padding()
            } else {
                ForEach(Array(upcomingLive), id: \.id) { event in
                    HStack {
                        Circle().fill(Color.orange.opacity(0.3)).frame(width: 8, height: 8)
                        Image(systemName: "dot.radiowaves.left.and.right").foregroundColor(.orange)
                        Text(event.title).font(TDTypography.caption1).lineLimit(1)
                        Spacer()
                        Text(event.startTime, style: .date).font(TDTypography.caption2).foregroundColor(.secondary)
                    }
                }
                ForEach(Array(upcomingBookings), id: \.id) { booking in
                    HStack {
                        Circle().fill(Color.green.opacity(0.3)).frame(width: 8, height: 8)
                        Image(systemName: "video.fill").foregroundColor(.green)
                        Text(booking.userName).font(TDTypography.caption1).lineLimit(1)
                        Spacer()
                        Text(booking.confirmedDate ?? booking.requestedDate, style: .date).font(TDTypography.caption2).foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(TDSpacing.md)
        .glassBackground()
    }
    
    // MARK: - Bookings Section
    private var bookingsSection: some View {
        VStack(spacing: TDSpacing.lg) {
            TrainerMenuCard(title: "Privatstunden", items: [
                TrainerMenuItem(icon: "calendar.badge.clock", title: "Anfragen", subtitle: "\(pendingBookingsCount) ausstehend", color: .orange, badge: pendingBookingsCount, destination: AnyView(TrainerBookingsView())),
                TrainerMenuItem(icon: "clock.fill", title: "Verfügbarkeit", subtitle: "Zeitfenster verwalten", color: .green, destination: AnyView(TrainerAvailabilityView())),
                TrainerMenuItem(icon: "eurosign.circle", title: "Preise", subtitle: "Stundensätze festlegen", color: .blue, destination: AnyView(TrainerPricingView()))
            ])
            
            TrainerMenuCard(title: "Kommunikation", items: [
                TrainerMenuItem(icon: "bubble.left.and.bubble.right.fill", title: "Trainer-Postfach", subtitle: "Nachrichten von Schülern", color: .teal, destination: AnyView(TrainerChatInboxView()))
            ])
        }
    }
    
    // MARK: - Live Classes Section
    private var liveClassesSection: some View {
        VStack(spacing: TDSpacing.lg) {
            // Neuen Livestream erstellen
            createLiveClassCard
            
            TrainerMenuCard(title: "Livestreams", items: [
                TrainerMenuItem(icon: "calendar", title: "Meine Livestreams", subtitle: "\(upcomingLiveClassesCount) geplant", color: .orange, badge: upcomingLiveClassesCount, destination: AnyView(TrainerLiveClassesView())),
                TrainerMenuItem(icon: "clock.arrow.circlepath", title: "Vergangene Streams", subtitle: "Archiv ansehen", color: .gray, destination: AnyView(TrainerPastLiveClassesView()))
            ])
            
            // Kommende Livestreams
            upcomingLiveClassesCard
        }
    }
    
    private var createLiveClassCard: some View {
        VStack(alignment: .leading, spacing: TDSpacing.md) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(Color.accentGold)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(T("Neuen Livestream planen"))
                        .font(TDTypography.headline)
                    Text(T("Gruppenstunde für deine Schüler erstellen"))
                        .font(TDTypography.caption1)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            NavigationLink(destination: LiveClassEditorView()) {
                Text(T("Livestream erstellen"))
                    .font(TDTypography.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentGold)
                    .cornerRadius(TDRadius.md)
            }
        }
        .padding(TDSpacing.md)
        .glassBackground()
    }
    
    private var upcomingMyEvents: [LiveClassEvent] {
        liveManager.events
            .filter { $0.trainerId == trainerId && $0.startTime > Date() }
            .sorted { $0.startTime < $1.startTime }
    }
    
    private var upcomingLiveClassesCard: some View {
        VStack(alignment: .leading, spacing: TDSpacing.sm) {
            Text(T("Geplante Livestreams")).font(TDTypography.headline).foregroundColor(.secondary)
            
            if upcomingMyEvents.isEmpty {
                VStack(spacing: TDSpacing.md) {
                    Image(systemName: "video.slash")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text(T("Keine Livestreams geplant"))
                        .font(TDTypography.body)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(TDSpacing.xl)
            } else {
                ForEach(Array(upcomingMyEvents.prefix(5)), id: \.id) { event in
                    NavigationLink(destination: LiveClassDetailView(event: event)) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(event.title)
                                    .font(TDTypography.headline)
                                    .foregroundColor(.primary)
                                HStack {
                                    Image(systemName: "calendar")
                                    Text(event.startTime, style: .date)
                                    Image(systemName: "clock")
                                    Text(event.startTime, style: .time)
                                }
                                .font(TDTypography.caption1)
                                .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("\(event.confirmedParticipants)/\(event.maxParticipants)")
                                .font(TDTypography.caption1)
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding(TDSpacing.sm)
                    }
                    if event.id != upcomingMyEvents.prefix(5).last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding(TDSpacing.md)
        .glassBackground()
    }
    
    // MARK: - Content Section
    private var contentSection: some View {
        VStack(spacing: TDSpacing.lg) {
            TrainerMenuCard(title: "Mein Profil", items: [
                TrainerMenuItem(icon: "person.text.rectangle", title: "Öffentliches Profil", subtitle: "Bio, Spezialisierungen, Social Media", color: .purple, destination: AnyView(TrainerPublicProfileEditView())),
                TrainerMenuItem(icon: "photo.fill", title: "Profilbild & Medien", subtitle: "Fotos und Videos", color: .pink, destination: AnyView(TrainerMediaView()))
            ])
            
            TrainerMenuCard(title: "Kurse", items: [
                TrainerMenuItem(icon: "book.fill", title: "Meine Kurse", subtitle: "Kurse bearbeiten & Statistiken", color: .blue, destination: AnyView(TrainerCoursesView()))
            ])
            
            TrainerMenuCard(title: "Video-Review Einstellungen", items: [
                TrainerMenuItem(icon: "video.badge.checkmark", title: "Reviews aktivieren", subtitle: "Video-Einreichungen annehmen", color: .orange, destination: AnyView(TrainerReviewSettingsView()))
            ])
        }
    }
    
    // MARK: - Reviews Section
    private var reviewsSection: some View {
        VStack(spacing: TDSpacing.lg) {
            reviewStatsCard
            
            TrainerMenuCard(title: "Video-Reviews", items: [
                TrainerMenuItem(icon: "video.badge.ellipsis", title: "Offene Reviews", subtitle: "\(pendingReviewsCount) zu bearbeiten", color: .orange, badge: pendingReviewsCount, destination: AnyView(TrainerSubmissionsView())),
                TrainerMenuItem(icon: "checkmark.circle.fill", title: "Abgeschlossene Reviews", subtitle: "Feedback-Archiv", color: .green, destination: AnyView(TrainerCompletedReviewsView()))
            ])
            
            // Review Studio Schnellzugriff
            if pendingReviewsCount > 0 {
                pendingReviewsCard
            }
        }
    }
    
    private var reviewStatsCard: some View {
        VStack(spacing: TDSpacing.md) {
            HStack { Text(T("Review-Statistiken")).font(TDTypography.headline); Spacer() }
            let submissions = reviewManager.submissionsForTrainer(trainerId)
            HStack(spacing: TDSpacing.lg) {
                VStack(spacing: 4) {
                    Text("\(submissions.filter { $0.submissionStatus == .submitted }.count)")
                        .font(.title2).fontWeight(.bold).foregroundColor(.orange)
                    Text(T("Offen")).font(TDTypography.caption2).foregroundColor(.secondary)
                }
                Divider().frame(height: 40)
                VStack(spacing: 4) {
                    Text("\(submissions.filter { $0.submissionStatus == .inReview }.count)")
                        .font(.title2).fontWeight(.bold).foregroundColor(.blue)
                    Text(T("In Arbeit")).font(TDTypography.caption2).foregroundColor(.secondary)
                }
                Divider().frame(height: 40)
                VStack(spacing: 4) {
                    Text("\(submissions.filter { $0.submissionStatus == .feedbackDelivered || $0.submissionStatus == .completed }.count)")
                        .font(.title2).fontWeight(.bold).foregroundColor(.green)
                    Text(T("Fertig")).font(TDTypography.caption2).foregroundColor(.secondary)
                }
            }
        }
        .padding(TDSpacing.md)
        .glassBackground()
    }
    
    private var pendingReviewsCard: some View {
        VStack(alignment: .leading, spacing: TDSpacing.sm) {
            Text(T("Nächste Reviews")).font(TDTypography.headline).foregroundColor(.secondary)
            
            let pendingSubmissions = reviewManager.submissionsForTrainer(trainerId)
                .filter { $0.submissionStatus == .submitted }
                .prefix(3)
            
            ForEach(Array(pendingSubmissions)) { submission in
                NavigationLink(destination: ReviewStudioView(submission: submission)) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(submission.userName)
                                .font(TDTypography.headline)
                                .foregroundColor(.primary)
                            Text("\(submission.requestedMinutes) Min Review")
                                .font(TDTypography.caption1)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(submission.formattedPrice)
                            .font(TDTypography.caption1)
                            .foregroundColor(.green)
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding(TDSpacing.sm)
                }
                if submission.id != pendingSubmissions.last?.id {
                    Divider()
                }
            }
        }
        .padding(TDSpacing.md)
        .glassBackground()
    }
    
    // MARK: - Earnings Section
    private var earningsSection: some View {
        VStack(spacing: TDSpacing.lg) {
            // Trainer-Wallet für Kurs-Coins
            trainerWalletCard
            
            // Privatstunden-Übersicht (nur Stunden, kein Geld)
            privateLessonHoursCard
            
            TrainerMenuCard(title: "Details", items: [
                TrainerMenuItem(icon: "bitcoinsign.circle.fill", title: "Coin-Wallet", subtitle: "Transaktionshistorie", color: .orange, destination: AnyView(TrainerWalletTransactionsView())),
                TrainerMenuItem(icon: "video.fill", title: "Privatstunden", subtitle: "Geleistete Stunden", color: .green, destination: AnyView(TrainerPrivateLessonHoursView())),
                TrainerMenuItem(icon: "chart.bar.fill", title: "Statistiken", subtitle: "Detaillierte Übersicht", color: .blue, destination: AnyView(TrainerStatsDetailView()))
            ])
        }
    }
    
    // MARK: - Trainer Wallet Card (für Kurs-Coins)
    private var trainerWalletCard: some View {
        VStack(spacing: TDSpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(T("Trainer-Wallet"))
                        .font(TDTypography.headline)
                    Text(T("Einnahmen aus Kursverkäufen"))
                        .font(TDTypography.caption1)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "bitcoinsign.circle.fill")
                    .font(.title)
                    .foregroundColor(Color.accentGold)
            }
            
            Divider()
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(T("Aktuelles Guthaben"))
                        .font(TDTypography.caption1)
                        .foregroundColor(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(trainerWalletManager.balance)")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(Color.accentGold)
                        Text(T("DC"))
                            .font(TDTypography.headline)
                            .foregroundColor(Color.accentGold)
                    }
                    Text(trainerWalletManager.wallet?.formattedBalanceEUR ?? "€0,00")
                        .font(TDTypography.caption1)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 8) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(T("Gesamt verdient"))
                            .font(TDTypography.caption2)
                            .foregroundColor(.secondary)
                        Text("\(trainerWalletManager.wallet?.totalEarned ?? 0) DC")
                            .font(TDTypography.headline)
                            .foregroundColor(.green)
                    }
                }
            }
            
            // Info-Banner
            HStack(spacing: TDSpacing.sm) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text(T("Coins werden automatisch bei Kursverkäufen gutgeschrieben"))
                    .font(TDTypography.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(TDSpacing.sm)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(TDRadius.sm)
        }
        .padding(TDSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: TDRadius.md)
                .fill(Color.accentGold.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: TDRadius.md)
                        .stroke(Color.accentGold.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Private Lesson Hours Card (nur Stunden, kein Geld)
    private var privateLessonHoursCard: some View {
        VStack(spacing: TDSpacing.md) {
            HStack {
                Text(T("Privatstunden-Übersicht"))
                    .font(TDTypography.headline)
                Spacer()
                Text(T("Dieser Monat"))
                    .font(TDTypography.caption1)
                    .foregroundColor(.secondary)
            }
            
            let monthStats = calculatePrivateLessonStats()
            
            HStack(spacing: TDSpacing.lg) {
                VStack(spacing: 4) {
                    Text(String(format: "%.1f", monthStats.totalHours))
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    Text(T("Stunden"))
                        .font(TDTypography.caption2)
                        .foregroundColor(.secondary)
                }
                
                Divider().frame(height: 40)
                
                VStack(spacing: 4) {
                    Text("\(monthStats.completedCount)")
                        .font(.title)
                        .fontWeight(.bold)
                    Text(T("Abgeschlossen"))
                        .font(TDTypography.caption2)
                        .foregroundColor(.secondary)
                }
                
                Divider().frame(height: 40)
                
                VStack(spacing: 4) {
                    Text("\(monthStats.pendingCount)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    Text(T("Ausstehend"))
                        .font(TDTypography.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Wichtiger Hinweis
            HStack(spacing: TDSpacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text(T("Die Abrechnung der Privatstunden erfolgt extern. Hier siehst du nur die geleisteten Stunden."))
                    .font(TDTypography.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(TDSpacing.sm)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(TDRadius.sm)
        }
        .padding(TDSpacing.md)
        .glassBackground()
    }
    
    private func calculatePrivateLessonStats() -> (totalHours: Double, completedCount: Int, pendingCount: Int) {
        let monthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        let bookings = lessonManager.bookingsForTrainer(trainerId)
            .filter { $0.requestedDate >= monthAgo }
        
        let completedBookings = bookings.filter { $0.status == .completed }
        let totalMinutes = completedBookings.reduce(into: 0) { $0 + $1.duration }
        let pendingCount = bookings.filter { $0.status == .pending || $0.status == .confirmed }.count
        
        return (
            totalHours: Double(totalMinutes) / 60.0,
            completedCount: completedBookings.count,
            pendingCount: pendingCount
        )
    }
}

// MARK: - Trainer Category Enum
enum TrainerCategory: String, CaseIterable {
    case overview = "Übersicht"
    case bookings = "Buchungen"
    case liveClasses = "Livestreams"
    case content = "Inhalte"
    case reviews = "Reviews"
    case earnings = "Umsatz"
    
    var icon: String {
        switch self {
        case .overview: return "square.grid.2x2"
        case .bookings: return "calendar"
        case .liveClasses: return "dot.radiowaves.left.and.right"
        case .content: return "person.text.rectangle"
        case .reviews: return "play.rectangle"
        case .earnings: return "eurosign.circle"
        }
    }
}

// MARK: - Supporting Views
struct TrainerCategoryTab: View {
    let category: TrainerCategory
    let isSelected: Bool
    let badge: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: category.icon).font(.system(size: 14))
                Text(category.rawValue).font(TDTypography.caption1).fontWeight(isSelected ? .semibold : .regular)
                if badge > 0 {
                    Text("\(badge)").font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                        .padding(.horizontal, 5).padding(.vertical, 2).background(Color.red).clipShape(Capsule())
                }
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(isSelected ? Color.accentGold : Color.gray.opacity(0.15))
            .cornerRadius(20)
        }
    }
}

struct TrainerMenuCard: View {
    let title: String
    let items: [TrainerMenuItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: TDSpacing.sm) {
            Text(title).font(TDTypography.headline).foregroundColor(.secondary).padding(.leading, TDSpacing.sm)
            VStack(spacing: 0) {
                ForEach(items.indices, id: \.self) { i in
                    NavigationLink(destination: items[i].destination) {
                        HStack(spacing: TDSpacing.md) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8).fill(items[i].color.opacity(0.15)).frame(width: 36, height: 36)
                                Image(systemName: items[i].icon).font(.system(size: 16)).foregroundColor(items[i].color)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(items[i].title).font(TDTypography.body).foregroundColor(.primary)
                                Text(items[i].subtitle).font(TDTypography.caption1).foregroundColor(.secondary)
                            }
                            Spacer()
                            if items[i].badge > 0 {
                                Text("\(items[i].badge)").font(TDTypography.caption2).fontWeight(.bold).foregroundColor(.white)
                                    .padding(.horizontal, 8).padding(.vertical, 4).background(Color.red).clipShape(Capsule())
                            }
                            Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
                        }
                        .padding(TDSpacing.md)
                    }
                    if i < items.count - 1 { Divider().padding(.leading, 56) }
                }
            }
            .glassBackground()
        }
    }
}

struct TrainerMenuItem {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    var badge: Int = 0
    let destination: AnyView
}

struct TrainerAlertRow: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: TDSpacing.md) {
                Image(systemName: icon).foregroundColor(color)
                Text(title).font(TDTypography.body).foregroundColor(.primary)
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
            }
            .padding(TDSpacing.sm)
        }
    }
}

struct TrainerStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: TDSpacing.xs) {
            Image(systemName: icon).font(.title3).foregroundColor(color)
            Text(value).font(TDTypography.title2).fontWeight(.bold)
            Text(title).font(TDTypography.caption1).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(TDSpacing.md)
        .glassBackground()
    }
}

struct TrainerQuickButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(color.opacity(0.15)).frame(width: 50, height: 50)
                    Image(systemName: icon).font(.system(size: 22)).foregroundColor(color)
                }
                Text(title).font(TDTypography.caption2).foregroundColor(.primary).lineLimit(1)
            }
        }
    }
}

// MARK: - Placeholder Views for Missing Destinations

struct TrainerAvailabilityView: View {
    @StateObject private var lessonManager = PrivateLessonManager.shared
    @StateObject private var userManager = UserManager.shared
    
    var body: some View {
        List {
            Section(T("Verfügbare Zeiten")) {
                Text(T("Hier kannst du deine verfügbaren Zeitfenster verwalten"))
                    .foregroundColor(.secondary)
            }
            
            // Placeholder - Link zu den echten Privatstunden-Einstellungen
            NavigationLink(destination: TrainerBookingsView()) {
                Label(T("Zeitfenster in Buchungen verwalten"), systemImage: "calendar")
            }
        }
        .navigationTitle(T("Verfügbarkeit"))
    }
}

struct TrainerPricingView: View {
    var body: some View {
        List {
            Section(T("Privatstunden-Preise")) {
                Text(T("Preise werden in den Privatstunden-Einstellungen festgelegt"))
                    .foregroundColor(.secondary)
            }
            
            NavigationLink(destination: TrainerBookingsView()) {
                Label(T("Zu den Einstellungen"), systemImage: "eurosign.circle")
            }
        }
        .navigationTitle(T("Preise"))
    }
}

struct TrainerMediaView: View {
    var body: some View {
        List {
            Section(T("Profilbilder")) {
                Text(T("Profilbilder werden im öffentlichen Profil verwaltet"))
                    .foregroundColor(.secondary)
            }
            
            NavigationLink(destination: TrainerPublicProfileEditView()) {
                Label(T("Zum Profil"), systemImage: "person.crop.circle")
            }
        }
        .navigationTitle(T("Medien"))
    }
}

struct TrainerPastLiveClassesView: View {
    @StateObject private var liveManager = LiveClassManager.shared
    @StateObject private var userManager = UserManager.shared
    
    private var pastEvents: [LiveClassEvent] {
        guard let trainerId = userManager.currentUser?.id else { return [] }
        return liveManager.events
            .filter { $0.trainerId == trainerId && $0.endTime < Date() }
            .sorted { $0.startTime > $1.startTime }
    }
    
    var body: some View {
        List {
            if pastEvents.isEmpty {
                ContentUnavailableView(
                    "Keine vergangenen Streams",
                    systemImage: "video.slash",
                    description: Text(T("Du hast noch keine Livestreams durchgeführt"))
                )
            } else {
                ForEach(pastEvents, id: \.id) { (event: LiveClassEvent) in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.title)
                            .font(TDTypography.headline)
                        HStack {
                            Text(event.startTime, style: .date)
                            Text(T("•"))
                            Text("\(event.confirmedParticipants) Teilnehmer")
                        }
                        .font(TDTypography.caption1)
                        .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle(T("Vergangene Streams"))
    }
}

struct TrainerReviewSettingsView: View {
    @StateObject private var userManager = UserManager.shared
    @State private var acceptsReviews = true
    @State private var maxMinutes = 30
    @State private var pricePerMinute = 50 // Coins
    
    var body: some View {
        Form {
            Section(T("Video-Reviews")) {
                Toggle("Video-Reviews annehmen", isOn: $acceptsReviews)
                
                if acceptsReviews {
                    Stepper("Max. Minuten: \(maxMinutes)", value: $maxMinutes, in: 5...120, step: 5)
                    Stepper("Coins/Minute: \(pricePerMinute)", value: $pricePerMinute, in: 10...200, step: 10)
                }
            }
            
            Section {
                Text(T("Schüler können dir Videos zur Analyse schicken. Du erhältst Coins für jedes abgeschlossene Review."))
                    .font(TDTypography.caption1)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle(T("Review-Einstellungen"))
    }
}

struct TrainerCompletedReviewsView: View {
    @StateObject private var reviewManager = VideoReviewManager.shared
    @StateObject private var userManager = UserManager.shared
    
    private var completedSubmissions: [VideoSubmission] {
        guard let trainerId = userManager.currentUser?.id else { return [] }
        return reviewManager.submissionsForTrainer(trainerId)
            .filter { $0.submissionStatus == .feedbackDelivered || $0.submissionStatus == .completed }
            .sorted { ($0.submittedAt ?? .distantPast) > ($1.submittedAt ?? .distantPast) }
    }
    
    var body: some View {
        List {
            if completedSubmissions.isEmpty {
                ContentUnavailableView(
                    "Keine abgeschlossenen Reviews",
                    systemImage: "checkmark.circle",
                    description: Text(T("Hier erscheinen deine abgeschlossenen Video-Reviews"))
                )
            } else {
                ForEach(completedSubmissions) { submission in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(submission.userName)
                            .font(TDTypography.headline)
                        HStack {
                            Text(submission.submittedAt ?? Date(), style: .date)
                            Text(T("•"))
                            Text("\(submission.requestedMinutes) Min")
                            Text(T("•"))
                            Text(submission.formattedPrice)
                                .foregroundColor(.green)
                        }
                        .font(TDTypography.caption1)
                        .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle(T("Abgeschlossene Reviews"))
    }
}

enum EarningsType {
    case privateLessons
    case trainingPlans
    case videoReviews
    case liveClasses
    
    var title: String {
        switch self {
        case .privateLessons: return "Privatstunden"
        case .trainingPlans: return "Trainingspläne"
        case .videoReviews: return "Video-Reviews"
        case .liveClasses: return "Livestreams"
        }
    }
}

struct TrainerEarningsDetailView: View {
    let type: EarningsType
    @StateObject private var lessonManager = PrivateLessonManager.shared
    @StateObject private var planManager = TrainingPlanManager.shared
    @StateObject private var reviewManager = VideoReviewManager.shared
    @StateObject private var userManager = UserManager.shared
    
    private var trainerId: String {
        userManager.currentUser?.id ?? ""
    }
    
    var body: some View {
        List {
            Section(T("Umsatz") + " - " + type.title) {
                switch type {
                case .privateLessons:
                    privateLessonsEarnings
                case .trainingPlans:
                    trainingPlansEarnings
                case .videoReviews:
                    videoReviewsEarnings
                case .liveClasses:
                    liveClassesEarnings
                }
            }
        }
        .navigationTitle(type.title)
    }
    
    @ViewBuilder
    private var privateLessonsEarnings: some View {
        let completedBookings = lessonManager.bookingsForTrainer(trainerId)
            .filter { $0.status == .completed }
            .sorted { $0.requestedDate > $1.requestedDate }
        
        if completedBookings.isEmpty {
            Text(T("Keine abgeschlossenen Privatstunden"))
                .foregroundColor(.secondary)
        } else {
            ForEach(completedBookings) { booking in
                HStack {
                    VStack(alignment: .leading) {
                        Text(booking.userName)
                            .font(TDTypography.headline)
                        Text(booking.requestedDate, style: .date)
                            .font(TDTypography.caption1)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(String(format: "%.2f €", NSDecimalNumber(decimal: booking.price).doubleValue))
                        .foregroundColor(.green)
                }
            }
        }
    }
    
    @ViewBuilder
    private var trainingPlansEarnings: some View {
        let completedOrders = planManager.ordersForTrainer(trainerId)
            .filter { $0.status == .completed }
            .sorted { $0.createdAt > $1.createdAt }
        
        if completedOrders.isEmpty {
            Text(T("Keine abgeschlossenen Trainingspläne"))
                .foregroundColor(.secondary)
        } else {
            ForEach(completedOrders) { order in
                HStack {
                    VStack(alignment: .leading) {
                        Text(order.userName)
                            .font(TDTypography.headline)
                        Text(order.createdAt, style: .date)
                            .font(TDTypography.caption1)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(String(format: "%.2f €", order.price))
                        .foregroundColor(.green)
                }
            }
        }
    }
    
    @ViewBuilder
    private var videoReviewsEarnings: some View {
        let completedReviews = reviewManager.submissionsForTrainer(trainerId)
            .filter { $0.submissionStatus == .feedbackDelivered || $0.submissionStatus == .completed }
            .sorted { ($0.submittedAt ?? .distantPast) > ($1.submittedAt ?? .distantPast) }
        
        if completedReviews.isEmpty {
            Text(T("Keine abgeschlossenen Video-Reviews"))
                .foregroundColor(.secondary)
        } else {
            ForEach(completedReviews) { submission in
                HStack {
                    VStack(alignment: .leading) {
                        Text(submission.userName)
                            .font(TDTypography.headline)
                        Text(submission.submittedAt ?? Date(), style: .date)
                            .font(TDTypography.caption1)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(submission.formattedPrice)
                        .foregroundColor(.green)
                }
            }
        }
    }
    
    @ViewBuilder
    private var liveClassesEarnings: some View {
        Text(T("Livestream-Einnahmen werden hier angezeigt"))
            .foregroundColor(.secondary)
    }
}

// MARK: - Trainer Wallet Transactions View
struct TrainerWalletTransactionsView: View {
    @StateObject private var walletManager = TrainerWalletManager.shared
    @StateObject private var userManager = UserManager.shared
    
    private var trainerId: String {
        userManager.currentUser?.id ?? ""
    }
    
    var body: some View {
        List {
            // Wallet-Übersicht
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(T("Aktuelles Guthaben"))
                            .font(TDTypography.caption1)
                            .foregroundColor(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(walletManager.balance)")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(Color.accentGold)
                            Text(T("DanceCoins"))
                                .font(TDTypography.caption1)
                                .foregroundColor(Color.accentGold)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text(walletManager.wallet?.formattedBalanceEUR ?? "€0,00")
                            .font(TDTypography.headline)
                            .foregroundColor(.secondary)
                        Text(T("Gegenwert"))
                            .font(TDTypography.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Transaktionen
            Section {
                if walletManager.transactions.isEmpty {
                    ContentUnavailableView(
                        "Keine Transaktionen",
                        systemImage: "clock.arrow.circlepath",
                        description: Text(T("Noch keine Coin-Einnahmen aus Kursverkäufen"))
                    )
                } else {
                    ForEach(walletManager.transactions) { transaction in
                        TrainerTransactionRow(transaction: transaction)
                    }
                }
            } header: {
                Text(T("Transaktionshistorie"))
            }
        }
        .navigationTitle(T("Coin-Wallet"))
        .refreshable {
            await walletManager.loadTransactions(trainerId: trainerId)
        }
        .task {
            await walletManager.loadTransactions(trainerId: trainerId)
        }
    }
}

struct TrainerTransactionRow: View {
    let transaction: TrainerWalletTransaction
    
    var body: some View {
        HStack(spacing: TDSpacing.md) {
            // Icon
            ZStack {
                Circle()
                    .fill(transaction.isPositive ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: transaction.icon)
                    .foregroundColor(transaction.isPositive ? .green : .red)
            }
            
            // Details
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.description)
                    .font(TDTypography.headline)
                    .lineLimit(1)
                
                HStack {
                    Text(transaction.createdAt, style: .date)
                    if let courseName = transaction.courseName {
                        Text(T("•"))
                        Text(courseName)
                            .lineLimit(1)
                    }
                }
                .font(TDTypography.caption2)
                .foregroundColor(.secondary)
                
                if let percent = transaction.percentageApplied,
                   let original = transaction.originalCoins {
                    Text("\(percent)% von \(original) DC")
                        .font(TDTypography.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Betrag
            VStack(alignment: .trailing, spacing: 2) {
                Text(transaction.formattedAmount)
                    .font(TDTypography.headline)
                    .foregroundColor(transaction.isPositive ? .green : .red)
                Text(transaction.formattedAmountEUR)
                    .font(TDTypography.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Trainer Private Lesson Hours View
struct TrainerPrivateLessonHoursView: View {
    @StateObject private var lessonManager = PrivateLessonManager.shared
    @StateObject private var userManager = UserManager.shared
    @State private var selectedPeriod: StatsPeriod = .thisMonth
    
    private var trainerId: String {
        userManager.currentUser?.id ?? ""
    }
    
    enum StatsPeriod: String, CaseIterable {
        case thisWeek = "Diese Woche"
        case thisMonth = "Dieser Monat"
        case lastMonth = "Letzter Monat"
        case thisYear = "Dieses Jahr"
        case allTime = "Gesamt"
        
        var dateRange: (start: Date, end: Date) {
            let calendar = Calendar.current
            let now = Date()
            
            switch self {
            case .thisWeek:
                let start = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
                return (start, now)
            case .thisMonth:
                let start = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
                return (start, now)
            case .lastMonth:
                let lastMonth = calendar.date(byAdding: .month, value: -1, to: now)!
                let start = calendar.date(from: calendar.dateComponents([.year, .month], from: lastMonth))!
                let end = calendar.date(byAdding: .day, value: -1, to: calendar.date(from: calendar.dateComponents([.year, .month], from: now))!)!
                return (start, end)
            case .thisYear:
                let start = calendar.date(from: calendar.dateComponents([.year], from: now))!
                return (start, now)
            case .allTime:
                return (Date.distantPast, now)
            }
        }
    }
    
    private var filteredBookings: [PrivateLessonBooking] {
        let range = selectedPeriod.dateRange
        return lessonManager.bookingsForTrainer(trainerId)
            .filter { $0.requestedDate >= range.start && $0.requestedDate <= range.end }
            .sorted { $0.requestedDate > $1.requestedDate }
    }
    
    private var completedBookings: [PrivateLessonBooking] {
        filteredBookings.filter { $0.status == .completed }
    }
    
    private var totalMinutes: Int {
        completedBookings.reduce(into: 0) { $0 + $1.duration }
    }
    
    var body: some View {
        List {
            // Statistik-Karte
            Section {
                VStack(spacing: TDSpacing.md) {
                    HStack(spacing: TDSpacing.xl) {
                        VStack(spacing: 4) {
                            Text(String(format: "%.1f", Double(totalMinutes) / 60.0))
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.green)
                            Text(T("Stunden"))
                                .font(TDTypography.caption1)
                                .foregroundColor(.secondary)
                        }
                        
                        Divider().frame(height: 50)
                        
                        VStack(spacing: 4) {
                            Text("\(completedBookings.count)")
                                .font(.system(size: 32, weight: .bold))
                            Text(T("Termine"))
                                .font(TDTypography.caption1)
                                .foregroundColor(.secondary)
                        }
                        
                        Divider().frame(height: 50)
                        
                        VStack(spacing: 4) {
                            Text("\(filteredBookings.filter { $0.status == .pending || $0.status == .confirmed }.count)")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.orange)
                            Text(T("Offen"))
                                .font(TDTypography.caption1)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, TDSpacing.sm)
            }
            
            // Zeitraum-Picker
            Section {
                Picker("Zeitraum", selection: $selectedPeriod) {
                    ForEach(StatsPeriod.allCases, id: \.self) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.menu)
            }
            
            // Hinweis
            Section {
                HStack(spacing: TDSpacing.sm) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                    Text(T("Die Bezahlung der Privatstunden erfolgt extern. Diese Übersicht zeigt nur deine geleisteten Stunden."))
                        .font(TDTypography.caption1)
                        .foregroundColor(.secondary)
                }
            }
            
            // Buchungsliste
            Section {
                if completedBookings.isEmpty {
                    ContentUnavailableView(
                        "Keine Privatstunden",
                        systemImage: "video.slash",
                        description: Text(T("Keine abgeschlossenen Privatstunden im gewählten Zeitraum"))
                    )
                } else {
                    ForEach(completedBookings) { booking in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(booking.userName)
                                    .font(TDTypography.headline)
                                HStack {
                                    Text(booking.requestedDate, style: .date)
                                    Text(T("•"))
                                    Text(booking.requestedDate, style: .time)
                                }
                                .font(TDTypography.caption1)
                                .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(booking.duration) Min")
                                    .font(TDTypography.headline)
                                    .foregroundColor(.green)
                                Text(String(format: "%.1f Std.", Double(booking.duration) / 60.0))
                                    .font(TDTypography.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            } header: {
                Text(T("Abgeschlossene Privatstunden"))
            }
        }
        .navigationTitle(T("Privatstunden"))
    }
}

// MARK: - Trainer Stats Detail View
struct TrainerStatsDetailView: View {
    @StateObject private var walletManager = TrainerWalletManager.shared
    @StateObject private var lessonManager = PrivateLessonManager.shared
    @StateObject private var planManager = TrainingPlanManager.shared
    @StateObject private var reviewManager = VideoReviewManager.shared
    @StateObject private var userManager = UserManager.shared
    
    private var trainerId: String {
        userManager.currentUser?.id ?? ""
    }
    
    var body: some View {
        List {
            // Trainer-Wallet Statistik
            Section {
                StatRow(title: "Wallet-Guthaben", value: "\(walletManager.balance) DC", color: .orange)
                StatRow(title: "Gegenwert", value: walletManager.wallet?.formattedBalanceEUR ?? "€0,00", color: .green)
                StatRow(title: "Gesamt verdient", value: "\(walletManager.wallet?.totalEarned ?? 0) DC", color: .blue)
                StatRow(title: "Transaktionen", value: "\(walletManager.transactions.count)", color: .purple)
            } header: {
                Text(T("Coin-Wallet"))
            }
            
            // Privatstunden-Statistik
            Section {
                let bookings = lessonManager.bookingsForTrainer(trainerId)
                let completed = bookings.filter { $0.status == .completed }
                let totalMinutes = completed.reduce(into: 0) { $0 + $1.duration }
                
                StatRow(title: "Geleistete Stunden", value: String(format: "%.1f Std.", Double(totalMinutes) / 60.0), color: .green)
                StatRow(title: "Abgeschlossen", value: "\(completed.count)", color: .blue)
                StatRow(title: "Ausstehend", value: "\(bookings.filter { $0.status == .pending }.count)", color: .orange)
                StatRow(title: "Bestätigt", value: "\(bookings.filter { $0.status == .confirmed }.count)", color: .teal)
            } header: {
                Text(T("Privatstunden"))
            } footer: {
                Text(T("Die Abrechnung der Privatstunden erfolgt extern."))
            }
            
            // Trainingspläne
            Section {
                let orders = planManager.ordersForTrainer(trainerId)
                StatRow(title: "Bestellungen", value: "\(orders.count)", color: .purple)
                StatRow(title: "Abgeschlossen", value: "\(orders.filter { $0.status == .completed }.count)", color: .green)
                StatRow(title: "In Bearbeitung", value: "\(orders.filter { $0.status == .inProgress }.count)", color: .orange)
            } header: {
                Text(T("Trainingspläne"))
            }
            
            // Video-Reviews
            Section {
                let submissions = reviewManager.submissionsForTrainer(trainerId)
                StatRow(title: "Eingereicht", value: "\(submissions.count)", color: .blue)
                StatRow(title: "Ausstehend", value: "\(submissions.filter { $0.submissionStatus == .submitted }.count)", color: .orange)
                StatRow(title: "Abgeschlossen", value: "\(submissions.filter { $0.submissionStatus == .feedbackDelivered || $0.submissionStatus == .completed }.count)", color: .green)
            } header: {
                Text(T("Video-Reviews"))
            }
            
            // Provisionen
            Section {
                if walletManager.commissions.isEmpty {
                    Text(T("Keine Provisionen konfiguriert"))
                        .foregroundColor(.secondary)
                } else {
                    ForEach(walletManager.commissions) { commission in
                        HStack {
                            Text(commission.courseId)
                                .font(TDTypography.body)
                            Spacer()
                            Text("\(commission.commissionPercent)%")
                                .font(TDTypography.headline)
                                .foregroundColor(commission.isActive ? .green : .secondary)
                        }
                    }
                }
            } header: {
                Text(T("Meine Kurs-Provisionen"))
            } footer: {
                Text(T("Der Prozentsatz zeigt deinen Anteil an den Kursverkäufen."))
            }
        }
        .navigationTitle(T("Statistiken"))
        .task {
            await walletManager.loadCommissionsForTrainer(trainerId: trainerId)
        }
    }
}

struct StatRow: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(TDTypography.headline)
                .foregroundColor(color)
        }
    }
}

#Preview {
    TrainerDashboardView()
}
