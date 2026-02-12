//
//  AdminDashboardView.swift
//  Tanzen mit Tatiana Drexler
//
//  Übersichtliches Admin-Dashboard mit kategorisierten Bereichen
//

import SwiftUI

// MARK: - Admin Dashboard
struct AdminDashboardView: View {
    @StateObject private var userManager = UserManager.shared
    @StateObject private var cloudManager = CloudDataManager.shared
    @StateObject private var changeRequestManager = ChangeRequestManager.shared
    @StateObject private var chatManager = SupportChatManager.shared
    @StateObject private var settingsManager = AppSettingsManager.shared
    @StateObject private var analyticsManager = AppAnalyticsManager.shared
    @StateObject private var redemptionKeyManager = RedemptionKeyManager.shared
    @StateObject private var feedbackManager = FeedbackManager.shared
    @EnvironmentObject var storeViewModel: StoreViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedCategory: AdminCategory = .overview
    @State private var showLogoutConfirm = false
    @State private var showSeedResult = false
    @State private var seedResultMessage = ""

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
                            case .users:
                                usersSection
                            case .content:
                                contentSection
                            case .sales:
                                salesContentSection
                            case .support:
                                supportContentSection
                            case .settings:
                                settingsContentSection
                            }
                        }
                        .padding(TDSpacing.md)
                    }
                }
            }
            .navigationTitle(T("Admin"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showLogoutConfirm = true } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(.red)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(T("Schließen")) { dismiss() }
                        .foregroundColor(Color.accentGold)
                }
            }
            .alert(T("Abmelden?"), isPresented: $showLogoutConfirm) {
                Button(T("Abbrechen"), role: .cancel) { }
                Button(T("Abmelden"), role: .destructive) {
                    userManager.logout()
                    dismiss()
                }
            }
            .alert(T("Referral-Codes"), isPresented: $showSeedResult) {
                Button(T("OK"), role: .cancel) { }
            } message: {
                Text(seedResultMessage)
            }
            .onAppear {
                if !userManager.isAdmin { dismiss() }
                Task {
                    _ = await PushNotificationService.shared.requestPermission()
                    PushNotificationService.shared.registerAdminDevice()
                    feedbackManager.startListeningToFeedbacks()
                }
            }
            .onDisappear {
                feedbackManager.stopListening()
            }
        }
    }
    
    // MARK: - Category Picker
    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: TDSpacing.sm) {
                ForEach(AdminCategory.allCases, id: \.self) { category in
                    AdminCategoryTab(
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
    
    private func badgeCount(for category: AdminCategory) -> Int {
        switch category {
        case .overview:
            return changeRequestManager.pendingRequests.count + chatManager.unreadCount + feedbackManager.unreadCount
        case .support:
            return chatManager.unreadCount + feedbackManager.unreadCount
        case .content:
            return settingsManager.pendingTrainerRequests.count
        default:
            return 0
        }
    }
    
    // MARK: - Overview Section
    private var overviewSection: some View {
        VStack(spacing: TDSpacing.lg) {
            welcomeCard
            if hasAlerts { alertsCard }
            quickStatsGrid
            quickAccessGrid
            recentActivityCard
        }
    }
    
    private var hasAlerts: Bool {
        changeRequestManager.pendingRequests.count > 0 ||
        chatManager.unreadCount > 0 ||
        settingsManager.pendingTrainerRequests.count > 0 ||
        feedbackManager.unreadCount > 0
    }
    
    private var welcomeCard: some View {
        HStack(spacing: TDSpacing.md) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color.accentGold, Color.accentGoldLight], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 60, height: 60)
                Text(userManager.currentUser?.name.prefix(1).uppercased() ?? "A")
                    .font(.title).fontWeight(.bold).foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(T("Hallo, %@", userManager.currentUser?.name.components(separatedBy: " ").first ?? "Admin"))
                    .font(TDTypography.title3).fontWeight(.bold)
                Text(Date(), style: .date)
                    .font(TDTypography.caption1).foregroundColor(.secondary)
            }
            Spacer()
            VStack {
                Image(systemName: cloudManager.useCloudData ? "cloud.fill" : "cloud.slash")
                    .foregroundColor(cloudManager.useCloudData ? .green : .orange)
                Text(cloudManager.useCloudData ? "Online" : "Offline")
                    .font(TDTypography.caption2).foregroundColor(.secondary)
            }
        }
        .padding(TDSpacing.md)
        .glassBackground()
    }
    
    private var alertsCard: some View {
        VStack(spacing: TDSpacing.sm) {
            if changeRequestManager.pendingRequests.count > 0 {
                AdminAlertRow(icon: "doc.badge.clock", title: "\(changeRequestManager.pendingRequests.count) Änderungsanfragen", color: .orange, destination: AnyView(ChangeRequestsView()))
            }
            if chatManager.unreadCount > 0 {
                AdminAlertRow(icon: "message.badge", title: "\(chatManager.unreadCount) ungelesene Nachrichten", color: .blue, destination: AnyView(AdminSupportView()))
            }
            if settingsManager.pendingTrainerRequests.count > 0 {
                AdminAlertRow(icon: "person.crop.circle.badge.exclamationmark", title: "\(settingsManager.pendingTrainerRequests.count) Trainer-Anfragen", color: .purple, destination: AnyView(TrainerEditRequestsView()))
            }
            if feedbackManager.unreadCount > 0 {
                AdminAlertRow(icon: "bubble.left.and.bubble.right.fill", title: "\(feedbackManager.unreadCount) neues Feedback", color: .teal, destination: AnyView(AdminFeedbackView()))
            }
        }
        .padding(TDSpacing.md)
        .background(Color.red.opacity(0.1))
        .cornerRadius(TDRadius.md)
        .overlay(RoundedRectangle(cornerRadius: TDRadius.md).stroke(Color.red.opacity(0.3), lineWidth: 1))
    }
    
    private var quickStatsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: TDSpacing.md) {
            AdminStatCard(title: "Benutzer", value: "\(userManager.allUsers.count)", icon: "person.2.fill", color: .blue)
            AdminStatCard(title: "Premium", value: "\(userManager.allUsers.filter { $0.group == .premium }.count)", icon: "star.fill", color: .yellow)
            AdminStatCard(title: "Trainer", value: "\(userManager.trainers.count)", icon: "figure.dance", color: .purple)
            AdminStatCard(title: "Codes", value: "\(redemptionKeyManager.keys.count)", icon: "ticket.fill", color: .green)
        }
    }
    
    private var quickAccessGrid: some View {
        VStack(alignment: .leading, spacing: TDSpacing.sm) {
            Text(T("Schnellzugriff")).font(TDTypography.headline).foregroundColor(.secondary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: TDSpacing.md) {
                AdminQuickButton(icon: "person.badge.plus", title: "User", color: .blue) { selectedCategory = .users }
                AdminQuickButton(icon: "play.rectangle.fill", title: "Kurse", color: .purple) { selectedCategory = .content }
                AdminQuickButton(icon: "tag.fill", title: "Sales", color: .red) { selectedCategory = .sales }
                AdminQuickButton(icon: "message.fill", title: "Support", color: .green) { selectedCategory = .support }
                AdminQuickButton(icon: "bubble.left.and.bubble.right.fill", title: "Feedback", color: .teal) { selectedCategory = .support }
                AdminQuickButton(icon: "gearshape.fill", title: "Settings", color: .gray) { selectedCategory = .settings }
            }
        }
    }
    
    private var recentActivityCard: some View {
        VStack(alignment: .leading, spacing: TDSpacing.sm) {
            HStack {
                Text(T("Letzte Käufe")).font(TDTypography.headline).foregroundColor(.secondary)
                Spacer()
                NavigationLink(destination: PurchaseHistoryView()) {
                    Text(T("Alle")).font(TDTypography.caption1).foregroundColor(Color.accentGold)
                }
            }
            let recent = PushNotificationService.shared.getPurchaseHistory().prefix(3)
            if recent.isEmpty {
                Text(T("Keine Käufe")).font(TDTypography.body).foregroundColor(.secondary).frame(maxWidth: .infinity).padding()
            } else {
                ForEach(Array(recent), id: \.id) { p in
                    HStack {
                        Circle().fill(Color.green.opacity(0.2)).frame(width: 8, height: 8)
                        Text(p.productName).font(TDTypography.caption1)
                        Spacer()
                        Text(p.price).font(TDTypography.caption1).foregroundColor(.green)
                    }
                }
            }
        }
        .padding(TDSpacing.md)
        .glassBackground()
    }
    
    // MARK: - Users Section
    private var usersSection: some View {
        VStack(spacing: TDSpacing.lg) {
            userStatsCard
            AdminMenuCard(title: "Benutzer-Verwaltung", items: [
                AdminMenuItem(icon: "person.2.fill", title: "Alle Benutzer", subtitle: "\(userManager.allUsers.count) registriert", color: .blue, destination: AnyView(UserManagementView())),
                AdminMenuItem(icon: "person.badge.plus", title: "User erstellen", subtitle: "Neuen Account anlegen", color: .green, destination: AnyView(AdminCreateUserView())),
                AdminMenuItem(icon: "star.fill", title: "Premium vergeben", subtitle: "Abos & Freischaltungen", color: .yellow, destination: AnyView(AdminPremiumView())),
                AdminMenuItem(icon: "bitcoinsign.circle", title: "DanceCoins", subtitle: "Wallets & Keys", color: .orange, destination: AnyView(CoinAdminView()))
            ])
            AdminMenuCard(title: "Rollen", items: [
                AdminMenuItem(icon: "lock.shield", title: "Editor-Accounts", subtitle: "Kurseditoren", color: .orange, destination: AnyView(EditorAccountsView()))
            ])
        }
    }
    
    private var userStatsCard: some View {
        VStack(spacing: TDSpacing.md) {
            HStack { Text(T("Benutzer-Statistiken")).font(TDTypography.headline); Spacer() }
            HStack(spacing: TDSpacing.lg) {
                AdminUserStat(title: "Gesamt", value: userManager.allUsers.count, icon: "person.2")
                AdminUserStat(title: "Aktiv", value: userManager.allUsers.filter { $0.isActive }.count, icon: "checkmark.circle")
                AdminUserStat(title: "Heute", value: userManager.allUsers.filter { Calendar.current.isDateInToday($0.createdAt) }.count, icon: "calendar")
            }
        }
        .padding(TDSpacing.md)
        .glassBackground()
    }
    
    // MARK: - Content Section
    private var contentSection: some View {
        VStack(spacing: TDSpacing.lg) {
            AdminMenuCard(title: "Kurse & Lektionen", items: [
                AdminMenuItem(icon: "play.rectangle.fill", title: "Kurs-Editor", subtitle: "Kurse bearbeiten", color: .blue, destination: AnyView(CourseEditorView())),
                AdminMenuItem(icon: "gift.fill", title: "Kostenlose Inhalte", subtitle: "Gratis-Kurse", color: .green, destination: AnyView(FreeCoursesView())),
                AdminMenuItem(icon: "person.fill.badge.plus", title: "Trainer zuweisen", subtitle: "Kurse vergeben", color: .purple, destination: AnyView(TrainerCourseAssignmentView()))
            ])
            AdminMenuCard(title: "Anfragen", items: [
                AdminMenuItem(icon: "doc.badge.clock", title: "Änderungsanfragen", subtitle: "\(changeRequestManager.pendingRequests.count) ausstehend", color: .orange, badge: changeRequestManager.pendingRequests.count, destination: AnyView(ChangeRequestsView())),
                AdminMenuItem(icon: "person.crop.circle.badge.exclamationmark", title: "Trainer-Anfragen", subtitle: "\(settingsManager.pendingTrainerRequests.count) zu prüfen", color: .red, badge: settingsManager.pendingTrainerRequests.count, destination: AnyView(TrainerEditRequestsView()))
            ])
            AdminMenuCard(title: "Rechtliches", items: [
                AdminMenuItem(icon: "doc.text.fill", title: "AGB & Datenschutz", subtitle: "Texte bearbeiten", color: .gray, destination: AnyView(LegalDocumentsEditorView()))
            ])
        }
    }
    
    // MARK: - Sales Section
    private var salesContentSection: some View {
        VStack(spacing: TDSpacing.lg) {
            revenueCard
            AdminMenuCard(title: "Verkauf", items: [
                AdminMenuItem(icon: "tag.fill", title: "Sales & Rabatte", subtitle: "Aktionen verwalten", color: .red, destination: AnyView(SalesManagementView())),
                AdminMenuItem(icon: "ticket.fill", title: "Einlöse-Codes", subtitle: "\(redemptionKeyManager.keys.count) Codes", color: .green, destination: AnyView(RedemptionKeysView().environmentObject(CourseViewModel()))),
                AdminMenuItem(icon: "creditcard.fill", title: "Kaufhistorie", subtitle: "Transaktionen", color: .blue, destination: AnyView(PurchaseHistoryView()))
            ])
            AdminMenuCard(title: "Privatstunden & Pläne", items: [
                AdminMenuItem(icon: "calendar.badge.clock", title: "Privatstunden", subtitle: "Buchungen", color: .purple, destination: AnyView(PrivateLessonsAdminView())),
                AdminMenuItem(icon: "list.clipboard.fill", title: "Trainingspläne", subtitle: "Preise & Bestellungen", color: .orange, destination: AnyView(TrainingPlanAdminView()))
            ])
            AdminMenuCard(title: "Trainer-Vergütung", items: [
                AdminMenuItem(icon: "percent", title: "Kurs-Provisionen", subtitle: "Trainer-Anteile festlegen", color: .green, destination: AnyView(TrainerCommissionAdminView())),
                AdminMenuItem(icon: "bitcoinsign.circle.fill", title: "Trainer-Wallets", subtitle: "Coin-Guthaben verwalten", color: .orange, destination: AnyView(AdminTrainerWalletsView()))
            ])
        }
    }
    
    private var revenueCard: some View {
        VStack(spacing: TDSpacing.md) {
            HStack {
                Text(T("Umsatz")).font(TDTypography.headline)
                Spacer()
                Text(T("Diese Woche")).font(TDTypography.caption1).foregroundColor(.secondary)
            }
            let history = PushNotificationService.shared.getPurchaseHistory()
            let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            let weekPurchases = history.filter { $0.date >= weekAgo }
            HStack(spacing: TDSpacing.lg) {
                VStack {
                    Text("\(weekPurchases.count)").font(.title).fontWeight(.bold).foregroundColor(.green)
                    Text(T("Käufe")).font(TDTypography.caption1).foregroundColor(.secondary)
                }
                Divider().frame(height: 40)
                VStack {
                    Text("\(history.count)").font(.title).fontWeight(.bold)
                    Text(T("Gesamt")).font(TDTypography.caption1).foregroundColor(.secondary)
                }
            }
        }
        .padding(TDSpacing.md)
        .glassBackground()
    }
    
    // MARK: - Support Section
    private var supportContentSection: some View {
        VStack(spacing: TDSpacing.lg) {
            AdminMenuCard(title: "Support", items: [
                AdminMenuItem(icon: "message.fill", title: "Support-Chats", subtitle: "\(chatManager.unreadCount) ungelesen", color: .blue, badge: chatManager.unreadCount, destination: AnyView(AdminSupportView())),
                AdminMenuItem(icon: "bubble.left.and.bubble.right.fill", title: "User-Feedback", subtitle: "\(feedbackManager.unreadCount) neu", color: .teal, badge: feedbackManager.unreadCount, destination: AnyView(AdminFeedbackView())),
                AdminMenuItem(icon: "clock.arrow.circlepath", title: "Support-Änderungen", subtitle: "Protokoll", color: .gray, destination: AnyView(SupportChangesView()))
            ])
            AdminMenuCard(title: "Kommunikation", items: [
                AdminMenuItem(icon: "envelope.fill", title: "Newsletter senden", subtitle: "Marketing-Abonnenten", color: .green, destination: AnyView(AdminNewsletterView())),
                AdminMenuItem(icon: "bell.badge.fill", title: "Push-Nachricht", subtitle: "An alle senden", color: .orange, destination: AnyView(AdminPushView())),
                AdminMenuItem(icon: "megaphone.fill", title: "Broadcast senden", subtitle: "Popup an alle User", color: .purple, destination: AnyView(AdminBroadcastMessageView())),
                AdminMenuItem(icon: "envelope.badge", title: "Nachrichtenverlauf", subtitle: "Gesendete Admin-Nachrichten", color: .indigo, destination: AnyView(AdminMessageHistoryView()))
            ])
        }
    }
    
    // MARK: - Settings Section
    private var settingsContentSection: some View {
        VStack(spacing: TDSpacing.md) {
            AdminSettingsCard(
                title: "App-Einstellungen",
                subtitle: "Kurse, Sales, Dokumente",
                icon: "gearshape.fill",
                color: .blue,
                destination: AnyView(MarketingSettingsView())
            )
            AdminSettingsCard(
                title: "Livestream-Settings",
                subtitle: "Trainer-Regeln und Limits",
                icon: "dot.radiowaves.left.and.right",
                color: .orange,
                destination: AnyView(AdminLiveClassSettingsView())
            )
            VStack(alignment: .leading, spacing: TDSpacing.sm) {
                Text(T("Referral"))
                    .font(TDTypography.headline)
                    .foregroundColor(.secondary)
                    .padding(.leading, TDSpacing.sm)
                Button {
                    Task {
                        await ReferralManager.shared.seedExampleReferralCodes()
                        seedResultMessage = "Beispiel-Codes wurden geprüft/angelegt."
                        showSeedResult = true
                    }
                } label: {
                    HStack(spacing: TDSpacing.md) {
                        Image(systemName: "giftcard.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.purple)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(T("Beispiel-Referral-Codes anlegen"))
                                .font(TDTypography.body)
                                .foregroundColor(.primary)
                            Text(T("Legt feste Codes in Firebase an"))
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
            }
            AdminMenuCard(title: "Speicher & Sync", items: [
                AdminMenuItem(icon: "internaldrive.fill", title: "Speicher", subtitle: "Cache & Downloads", color: .orange, destination: AnyView(AdminStorageView())),
                AdminMenuItem(icon: "arrow.triangle.2.circlepath", title: "Synchronisieren", subtitle: "Cloud-Sync", color: .green, destination: AnyView(AdminSyncView()))
            ])
            AdminMenuCard(title: "Sicherheit", items: [
                AdminMenuItem(icon: "key.fill", title: "API-Schlüssel", subtitle: "PayPal, Firebase", color: .gray, destination: AnyView(AdminAPIKeysView()))
            ])
        }
    }
}

// MARK: - Admin Category Enum
enum AdminCategory: String, CaseIterable {
    case overview = "Übersicht"
    case users = "Benutzer"
    case content = "Inhalte"
    case sales = "Verkauf"
    case support = "Support"
    case settings = "Einstellungen"
    
    var icon: String {
        switch self {
        case .overview: return "square.grid.2x2"
        case .users: return "person.2"
        case .content: return "play.rectangle"
        case .sales: return "cart"
        case .support: return "message"
        case .settings: return "gearshape"
        }
    }
}

// MARK: - Supporting Views
struct AdminCategoryTab: View {
    let category: AdminCategory
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

struct AdminMenuCard: View {
    let title: String
    let items: [AdminMenuItem]
    
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

struct AdminMenuItem {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    var badge: Int = 0
    let destination: AnyView
}

struct AdminSettingsCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let destination: AnyView

    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: TDSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: icon)
                        .font(.system(size: 22))
                        .foregroundColor(color)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(TDTypography.headline)
                        .foregroundColor(.primary)
                    Text(subtitle)
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
        .buttonStyle(.plain)
    }
}

struct AdminAlertRow: View {
    let icon: String
    let title: String
    let color: Color
    let destination: AnyView
    
    var body: some View {
        NavigationLink(destination: destination) {
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

struct AdminStatCard: View {
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

struct AdminQuickButton: View {
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

struct AdminUserStat: View {
    let title: String
    let value: Int
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon).foregroundColor(Color.accentGold)
            Text("\(value)").font(TDTypography.title3).fontWeight(.bold)
            Text(title).font(TDTypography.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Placeholder Views
struct AdminCreateUserView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var userManager = UserManager.shared
    @State private var name = ""
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var selectedGroup: UserGroup = .user
    @State private var isLoading = false
    @State private var showSuccess = false
    @State private var errorMessage: String?
    
    var body: some View {
        Form {
            Section(T("Benutzer-Daten")) {
                TextField(T("Name"), text: $name)
                TextField(T("Benutzername"), text: $username).textInputAutocapitalization(.never)
                TextField(T("E-Mail"), text: $email).textInputAutocapitalization(.never).keyboardType(.emailAddress)
                SecureField(T("Passwort"), text: $password)
            }
            Section(T("Rolle")) {
                Picker("Benutzergruppe", selection: $selectedGroup) {
                    Text(T("Benutzer")).tag(UserGroup.user)
                    Text(T("Premium")).tag(UserGroup.premium)
                    Text(T("Trainer")).tag(UserGroup.trainer)
                    Text(T("Support")).tag(UserGroup.support)
                    Text(T("Admin")).tag(UserGroup.admin)
                }
            }
            if let error = errorMessage { Section { Text(error).foregroundColor(.red) } }
            Section {
                Button { Task { await createUser() } } label: {
                    HStack { Spacer(); if isLoading { ProgressView() } else { Text(T("Benutzer erstellen")) }; Spacer() }
                }
                .disabled(name.isEmpty || email.isEmpty || password.count < 6)
            }
        }
        .navigationTitle(T("User erstellen"))
        .alert(T("Erfolgreich!"), isPresented: $showSuccess) { Button(T("OK")) { dismiss() } }
    }
    
    private func createUser() async {
        isLoading = true; errorMessage = nil
        let (success, message) = await userManager.createUserAsAdmin(name: name, username: username.isEmpty ? email.components(separatedBy: "@").first ?? "user" : username, email: email, password: password, group: selectedGroup)
        isLoading = false
        if success { showSuccess = true } else { errorMessage = message }
    }
}

struct AdminPremiumView: View {
    @StateObject private var userManager = UserManager.shared
    var body: some View {
        List {
            Section(T("Premium-Benutzer")) {
                ForEach(userManager.allUsers.filter { $0.group == .premium || $0.premiumExpiresAt != nil }) { user in
                    HStack {
                        Text(user.name)
                        Spacer()
                        if let expires = user.premiumExpiresAt {
                            Text(expires, style: .date).font(TDTypography.caption1).foregroundColor(expires > Date() ? .green : .red)
                        }
                    }
                }
            }
        }
        .navigationTitle(T("Premium"))
    }
}

struct AdminNewsletterView: View {
    @Environment(\.dismiss) var dismiss
    @State private var subject = ""
    @State private var messageBody = ""
    var body: some View {
        Form {
            Section(T("Newsletter")) {
                TextField(T("Betreff"), text: $subject)
                TextEditor(text: $messageBody).frame(minHeight: 200)
            }
            Section { Button(T("Senden")) { dismiss() }.disabled(subject.isEmpty || messageBody.isEmpty) }
        }
        .navigationTitle(T("Newsletter"))
    }
}

struct AdminPushView: View {
    @StateObject private var pushService = PushNotificationService.shared
    @Environment(\.dismiss) var dismiss
    @State private var title = ""
    @State private var message = ""
    @State private var isSending = false
    @State private var showResult = false
    @State private var resultMessage = ""
    @State private var sentCount = 0
    
    var body: some View {
        Form {
            Section(T("Push-Nachricht an alle User")) {
                TextField(T("Titel"), text: $title)
                TextEditor(text: $message)
                    .frame(minHeight: 100)
            }
            
            Section {
                Text(T("Diese Nachricht wird an alle User gesendet und erscheint als Push-Benachrichtigung sowie als In-App-Nachricht."))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section {
                Button {
                    Task { await sendBroadcast() }
                } label: {
                    HStack {
                        if isSending {
                            ProgressView()
                                .padding(.trailing, 8)
                        }
                        Text(T("An alle senden"))
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(title.isEmpty || message.isEmpty || isSending)
            }
        }
        .navigationTitle(T("Push senden"))
        .alert(T("Broadcast gesendet"), isPresented: $showResult) {
            Button(T("OK")) { dismiss() }
        } message: {
            Text(resultMessage)
        }
    }
    
    private func sendBroadcast() async {
        isSending = true
        defer { isSending = false }
        
        let result = await pushService.sendBroadcastPush(title: title, body: message)
        
        if result.success {
            resultMessage = "Die Nachricht wurde erfolgreich an \(result.sentCount) User gesendet."
        } else {
            resultMessage = "Fehler beim Senden der Nachricht."
        }
        showResult = true
    }
}

struct AdminNotifSettingsView: View {
    @StateObject private var settings = AppSettingsManager.shared
    var body: some View {
        Form {
            Section(T("Kaufbenachrichtigungen")) {
                Toggle("Bei Käufen benachrichtigen", isOn: Binding(
                    get: { settings.settings.adminPurchaseNotificationsEnabled },
                    set: { newValue in Task { await settings.setAdminPurchaseNotifications(enabled: newValue) } }
                ))
            }
        }
        .navigationTitle(T("Benachrichtigungen"))
    }
}

struct AdminStorageView: View {
    @StateObject private var downloadManager = VideoDownloadManager.shared
    var body: some View {
        Form {
            Section(T("Downloads")) {
                HStack { Text(T("Videos")); Spacer(); Text("\(downloadManager.downloadedVideos.count)").foregroundColor(.secondary) }
                Button(T("Alle löschen"), role: .destructive) { downloadManager.deleteAllDownloads() }
            }
            Section(T("Cache")) { Button(T("Cache leeren")) { URLCache.shared.removeAllCachedResponses() } }
        }
        .navigationTitle(T("Speicher"))
    }
}

struct AdminSyncView: View {
    @StateObject private var userManager = UserManager.shared
    @State private var isSyncing = false
    var body: some View {
        Form {
            Section(T("Cloud-Sync")) {
                Button {
                    Task { isSyncing = true; await userManager.forceSync(); isSyncing = false }
                } label: {
                    HStack { Text(T("Jetzt synchronisieren")); Spacer(); if isSyncing { ProgressView() } }
                }
            }
        }
        .navigationTitle(T("Sync"))
    }
}

struct AdminAPIKeysView: View {
    var body: some View {
        Form {
            Section(T("PayPal")) {
                HStack { Text(T("Status")); Spacer(); Text(PayPalConfig.isConfigured ? "✓ Konfiguriert" : "Nicht eingerichtet").foregroundColor(PayPalConfig.isConfigured ? .green : .red) }
            }
            Section(T("Firebase")) {
                HStack { Text(T("Status")); Spacer(); Text(T("✓ Konfiguriert")).foregroundColor(.green) }
            }
        }
        .navigationTitle(T("API-Schlüssel"))
    }
}

#Preview {
    AdminDashboardView()
        .environmentObject(StoreViewModel())
}
