//
//  ProfileView.swift
//  Tanzen mit Tatiana Drexler
//
//  Profile and Settings View
//

import SwiftUI
import StoreKit

struct ProfileView: View {
    @EnvironmentObject var courseViewModel: CourseViewModel
    @EnvironmentObject var storeViewModel: StoreViewModel
    @StateObject private var downloadManager = VideoDownloadManager.shared
    @StateObject private var authManager = AdminAuthManager.shared
    @StateObject private var courseDataManager = CourseDataManager.shared
    @StateObject private var coinManager = CoinManager.shared
    
    @State private var showAboutTrainer = false
    @State private var showRestoreSuccess = false
    @State private var showDeleteAllConfirm = false
    @State private var showAdminLogin = false
    @State private var showAdminDashboard = false
    @State private var showTrainerDashboard = false
    @State private var showSubscription = false
    @State private var showPrivacyPolicy = false
    @State private var showTermsOfService = false
    @State private var showImpressum = false
    @State private var showRedeemCode = false
    @State private var showCoinWallet = false
    @State private var showProfileImagePicker = false
    @State private var showAuthView = false
    @State private var showLogoutConfirm = false
    @State private var showFeedback = false
    @State private var isRestoring = false
    @StateObject private var userManager = UserManager.shared
    
    private var purchasedCoursesCount: Int {
        let courses = courseDataManager.courses.isEmpty ? MockData.courses : courseDataManager.courses
        return courses.filter { userManager.hasCourseUnlocked($0.id) }.count
    }
    
    private var totalCoursesCount: Int {
        courseDataManager.courses.isEmpty ? MockData.courses.count : courseDataManager.courses.count
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                TDGradients.mainBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: TDSpacing.lg) {
                        profileHeader
                        subscriptionSection
                        coinSection
                        if userManager.isLoggedIn { referralSection }
                        if userManager.isLoggedIn { achievementsSection }
                        trainerSection
                        supportSection
                        myTrainingPlansSection
                        if userManager.isLoggedIn { feedbackSection }
                        statsSection
                        storageSection
                        purchasesSection
                        adminSection
                        legalSection
                        appInfoSection
                    }
                    .padding(TDSpacing.md)
                }
            }
            .navigationTitle(T("Profil"))
            .sheet(isPresented: $showAboutTrainer) {
                AboutTrainerView()
            }
            .sheet(isPresented: $showAdminLogin) {
                AdminLoginView()
            }
            .sheet(isPresented: $showAdminDashboard) {
                AdminDashboardView()
            }
            .sheet(isPresented: $showTrainerDashboard) {
                TrainerDashboardView()
            }
            .sheet(isPresented: $showFeedback) {
                UserFeedbackView()
            }
            .sheet(isPresented: $showSubscription) {
                SubscriptionView()
            }
            .sheet(isPresented: $showPrivacyPolicy) {
                PrivacyPolicyView()
            }
            .sheet(isPresented: $showTermsOfService) {
                TermsOfServiceView()
            }
            .sheet(isPresented: $showImpressum) {
                ImpressumView()
            }
            .sheet(isPresented: $showRedeemCode) {
                RedeemKeyView()
            }
            .sheet(isPresented: $showCoinWallet) {
                CoinWalletView()
            }
            .sheet(isPresented: $showProfileImagePicker) {
                if let userId = UserManager.shared.currentUser?.id {
                    ProfileImagePickerView(userId: userId)
                }
            }
            .sheet(isPresented: $showAuthView) {
                AuthView()
            }
            .alert(T("Käufe wiederhergestellt"), isPresented: $showRestoreSuccess) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(T("Alle bisherigen Käufe wurden wiederhergestellt."))
            }
            .alert(T("Alle Downloads löschen?"), isPresented: $showDeleteAllConfirm) {
                Button("Abbrechen", role: .cancel) { }
                Button("Löschen", role: .destructive) {
                    downloadManager.deleteAllVideos()
                }
            } message: {
                Text(T("Alle heruntergeladenen Videos werden gelöscht."))
            }
            .alert(T("Abmelden?"), isPresented: $showLogoutConfirm) {
                Button("Abbrechen", role: .cancel) { }
                Button("Abmelden", role: .destructive) {
                    userManager.logout()
                }
            } message: {
                Text(T("Du wirst aus deinem Account abgemeldet."))
            }
            .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
                if isAuthenticated {
                    showAdminLogin = false
                    showAdminDashboard = true
                }
            }
        }
    }
    
    // MARK: - Profile Header
    private var profileHeader: some View {
        VStack(spacing: TDSpacing.md) {
            // Profilbild
            Button {
                if userManager.isLoggedIn {
                    showProfileImagePicker = true
                } else {
                    showAuthView = true
                }
            } label: {
                ZStack {
                    if let user = userManager.currentUser,
                       let imageURL = user.profileImageURL, !imageURL.isEmpty {
                        AsyncImage(url: URL(string: imageURL)) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.accentGold, Color.accentGoldLight],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 3
                                )
                        )
                    } else {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.accentGold, Color.accentGoldLight],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)
                            .overlay(
                                Image(systemName: userManager.isLoggedIn ? (storeViewModel.hasActiveSubscription ? "crown.fill" : "person.fill") : "person.badge.plus")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white)
                            )
                    }
                    
                    // Kamera-Badge (nur wenn eingeloggt)
                    if userManager.isLoggedIn {
                        Image(systemName: "camera.fill")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(6)
                            .background(Color.accentGold)
                            .clipShape(Circle())
                            .offset(x: 35, y: 35)
                    }
                }
            }
            
            // Name und Info
            if let user = userManager.currentUser {
                HStack(spacing: TDSpacing.sm) {
                    Text(user.name)
                        .font(TDTypography.title2)
                        .foregroundColor(.primary)
                    
                    if storeViewModel.hasActiveSubscription {
                        SubscriptionBadge()
                    } else if user.group != .user {
                        Text(user.group.displayName)
                            .font(TDTypography.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(groupColor(for: user.group))
                            .cornerRadius(4)
                    }
                }
                
                Text("@" + user.username)
                    .font(TDTypography.caption1)
                    .foregroundColor(.secondary)
                
                // Logout Button
                Button {
                    showLogoutConfirm = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text(T("Abmelden"))
                    }
                    .font(TDTypography.caption1)
                    .foregroundColor(.red)
                }
                .padding(.top, 4)
                
            } else {
                // Nicht eingeloggt
                Text(T("Nicht eingeloggt"))
                    .font(TDTypography.title2)
                    .foregroundColor(.primary)
                
                Text(T("Melde dich an um alle Features zu nutzen"))
                    .font(TDTypography.caption1)
                    .foregroundColor(.secondary)
                
                // Login Button
                Button {
                    showAuthView = true
                } label: {
                    HStack {
                        Image(systemName: "person.badge.plus")
                        Text(T("Anmelden / Registrieren"))
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, TDSpacing.lg)
                    .padding(.vertical, TDSpacing.sm)
                    .background(Color.accentGold)
                    .cornerRadius(TDRadius.md)
                }
                .padding(.top, 8)
            }
            
            if storeViewModel.hasActiveSubscription {
                Text(T("Alle Kurse freigeschaltet"))
                    .font(TDTypography.subheadline)
                    .foregroundColor(.green)
            } else {
                Text(T("%@ von %@ Kursen freigeschaltet", "\(purchasedCoursesCount)", "\(totalCoursesCount)"))
                    .font(TDTypography.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(TDSpacing.lg)
        .frame(maxWidth: .infinity)
        .glassBackground()
    }
    
    // MARK: - Subscription Section
    private var subscriptionSection: some View {
        VStack(alignment: .leading, spacing: TDSpacing.sm) {
            Text(T("Premium"))
                .font(TDTypography.headline)
                .foregroundColor(.secondary)
                .padding(.leading, TDSpacing.sm)
            
            Button {
                showSubscription = true
            } label: {
                HStack(spacing: TDSpacing.md) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color.accentGold)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        if storeViewModel.hasActiveSubscription {
                            Text(T("Premium aktiv"))
                                .font(TDTypography.headline)
                                .foregroundColor(.primary)
                            
                            Text(storeViewModel.currentSubscriptionType?.displayName ?? "Abo")
                                .font(TDTypography.caption1)
                                .foregroundColor(.green)
                        } else {
                            Text(T("Alle Kurse freischalten"))
                                .font(TDTypography.headline)
                                .foregroundColor(.primary)
                            
                            Text(T("40% sparen mit Jahresabo"))
                                .font(TDTypography.caption1)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding(TDSpacing.md)
                .background(
                    LinearGradient(
                        colors: [Color.accentGold.opacity(0.1), Color.purple.opacity(0.1)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(TDRadius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: TDRadius.md)
                        .stroke(Color.accentGold.opacity(0.3), lineWidth: 1)
                )
            }
            
            // Gutschein einlösen Button
            Button {
                showRedeemCode = true
            } label: {
                HStack(spacing: TDSpacing.md) {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.purple)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(T("Gutschein einlösen"))
                            .font(TDTypography.headline)
                            .foregroundColor(.primary)
                        
                        Text(T("Hast du einen Code? Hier einlösen"))
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
    }
    
    // MARK: - DanceCoins Section
    private var coinSection: some View {
        VStack(spacing: TDSpacing.sm) {
            HStack {
                Text(T("DanceCoins"))
                    .font(TDTypography.headline)
                Spacer()
                Text(T("1 Coin = €0,50"))
                    .font(TDTypography.caption1)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: TDSpacing.md) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(T("Dein Kontostand"))
                        .font(TDTypography.caption1)
                        .foregroundColor(.secondary)
                    Text("\(coinManager.balance) " + T("Coins"))
                        .font(TDTypography.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Color.accentGold)
                }
                Spacer()
                Button {
                    showCoinWallet = true
                } label: {
                    Text(T("Wallet"))
                        .font(TDTypography.caption1)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.accentGold)
                        .foregroundColor(.white)
                        .cornerRadius(TDRadius.sm)
                }
            }
        }
        .padding(TDSpacing.md)
        .glassBackground()
    }
    
    // MARK: - Referral Section
    private var referralSection: some View {
        NavigationLink(destination: ReferralView()) {
            HStack(spacing: TDSpacing.md) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.green)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(T("Freunde einladen"))
                        .font(TDTypography.headline)
                        .foregroundColor(.primary)
                    
                    Text(T("Verdiene %@ Coins pro Einladung", "\(ReferralConfig.referrerRewardOnSignup)"))
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
    
    // MARK: - Achievements Section
    private var achievementsSection: some View {
        NavigationLink(destination: AchievementsView()) {
            HStack(spacing: TDSpacing.md) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 24))
                    .foregroundColor(Color.accentGold)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(T("Achievements"))
                        .font(TDTypography.headline)
                        .foregroundColor(.primary)
                    
                    let unlocked = LearningProgressManager.shared.achievements.filter { $0.isUnlocked }.count
                    let total = LearningProgressManager.shared.achievements.count
                    Text(T("%@/%@ freigeschaltet", "\(unlocked)", "\(total)"))
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
    
    // MARK: - Trainer Section (nur für Trainer sichtbar)
    @ViewBuilder
    private var trainerSection: some View {
        if UserManager.shared.currentUser?.group == .trainer {
            VStack(alignment: .leading, spacing: TDSpacing.sm) {
                Text(T("Trainer-Bereich"))
                    .font(TDTypography.headline)
                    .foregroundColor(.secondary)
                    .padding(.leading, TDSpacing.sm)
                
                // Trainer Dashboard Button (Hauptzugang)
                Button {
                    showTrainerDashboard = true
                } label: {
                    HStack(spacing: TDSpacing.md) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [Color.accentGold, Color.accentGoldLight], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 50, height: 50)
                            Image(systemName: "rectangle.grid.2x2.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(T("Trainer-Dashboard"))
                                .font(TDTypography.headline)
                                .foregroundColor(.primary)
                            
                            let pendingCount = PrivateLessonManager.shared.pendingBookingsForTrainer(UserManager.shared.currentUser?.id ?? "").count
                            + TrainingPlanManager.shared.pendingOrdersForTrainer(UserManager.shared.currentUser?.id ?? "").count
                            
                            Text(pendingCount > 0 ? T("%@ Anfragen warten", "\(pendingCount)") : T("Livestreams, Buchungen, Reviews"))
                                .font(TDTypography.caption1)
                                .foregroundColor(pendingCount > 0 ? .orange : .secondary)
                        }
                        
                        Spacer()
                        
                        if PrivateLessonManager.shared.pendingBookingsForTrainer(UserManager.shared.currentUser?.id ?? "").count > 0 {
                            Text("\(PrivateLessonManager.shared.pendingBookingsForTrainer(UserManager.shared.currentUser?.id ?? "").count)")
                                .font(TDTypography.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.red)
                                .clipShape(Capsule())
                        }
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(Color.accentGold)
                    }
                    .padding(TDSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: TDRadius.md)
                            .fill(Color.accentGold.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: TDRadius.md)
                                    .stroke(Color.accentGold.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                
                // Öffentliches Profil bearbeiten
                NavigationLink(destination: TrainerPublicProfileEditView()) {
                    HStack(spacing: TDSpacing.md) {
                        Image(systemName: "person.text.rectangle")
                            .font(.system(size: 24))
                            .foregroundColor(Color.accentGold)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(T("Öffentliches Profil"))
                                .font(TDTypography.headline)
                                .foregroundColor(.primary)
                            
                            Text(T("Bio, Spezialisierungen, Social Media"))
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
                
                NavigationLink(destination: TrainerCoursesView()) {
                    HStack(spacing: TDSpacing.md) {
                        Image(systemName: "book.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(T("Meine Kurse bearbeiten"))
                                .font(TDTypography.headline)
                                .foregroundColor(.primary)
                            
                            Text(T("Titel, Beschreibung ändern"))
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
                
                NavigationLink(destination: TrainerBookingsView()) {
                    HStack(spacing: TDSpacing.md) {
                        Image(systemName: "video.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.green)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(T("Privatstunden-Anfragen"))
                                .font(TDTypography.headline)
                                .foregroundColor(.primary)
                            
                            let pending = PrivateLessonManager.shared.pendingBookingsForTrainer(UserManager.shared.currentUser?.id ?? "").count
                            Text(pending > 0 ? T("%@ ausstehend", "\(pending)") : T("Alle Anfragen ansehen"))
                                .font(TDTypography.caption1)
                                .foregroundColor(pending > 0 ? .orange : .secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding(TDSpacing.md)
                    .glassBackground()
                }
                
                NavigationLink(destination: TrainerChatInboxView()) {
                    HStack(spacing: TDSpacing.md) {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.orange)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(T("Trainer-Postfach"))
                                .font(TDTypography.headline)
                                .foregroundColor(.primary)
                            
                            Text(T("Nachrichten von Schülern"))
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
        }
    }
    
    // MARK: - Support Section (nur für Support sichtbar)
    @ViewBuilder
    private var supportSection: some View {
        if userManager.currentUser?.group == .support {
            VStack(alignment: .leading, spacing: TDSpacing.sm) {
                Text(T("Support-Bereich"))
                    .font(TDTypography.headline)
                    .foregroundColor(.secondary)
                    .padding(.leading, TDSpacing.sm)
                
                NavigationLink(destination: SupportDashboardView()) {
                    HStack(spacing: TDSpacing.md) {
                        Image(systemName: "headphones")
                            .font(.system(size: 24))
                            .foregroundColor(.purple)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(T("Support-Anfragen"))
                                .font(TDTypography.headline)
                                .foregroundColor(.primary)
                            
                            let openCount = SupportChatManager.shared.conversations.filter { $0.status == .open }.count
                            Text(openCount > 0 ? T("%@ offene Anfragen", "\(openCount)") : T("Alle Anfragen ansehen"))
                                .font(TDTypography.caption1)
                                .foregroundColor(openCount > 0 ? .orange : .secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding(TDSpacing.md)
                    .glassBackground()
                }
                
                NavigationLink(destination: SupportUserListView()) {
                    HStack(spacing: TDSpacing.md) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(T("User & Kurse verwalten"))
                                .font(TDTypography.headline)
                                .foregroundColor(.primary)
                            
                            Text(T("User-Kurse einsehen und bearbeiten"))
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
        }
    }
    
    // MARK: - My Training Plans Section
    @ViewBuilder
    private var myTrainingPlansSection: some View {
        if userManager.isLoggedIn {
            let myOrders = TrainingPlanManager.shared.orders.filter { $0.userId == userManager.currentUser?.id }
            
            VStack(alignment: .leading, spacing: TDSpacing.sm) {
                Text(T("Trainingspläne"))
                    .font(TDTypography.headline)
                    .foregroundColor(.secondary)
                    .padding(.leading, TDSpacing.sm)
                
                NavigationLink(destination: TrainingPlanOverviewView()) {
                    HStack(spacing: TDSpacing.md) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.purple)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(T("Meine Trainingspläne"))
                                .font(TDTypography.headline)
                                .foregroundColor(.primary)
                            
                            if myOrders.isEmpty {
                                Text(T("Persönlichen Plan bestellen"))
                                    .font(TDTypography.caption1)
                                    .foregroundColor(.secondary)
                            } else {
                                let pendingCount = myOrders.filter { $0.status == .paid || $0.status == .inProgress }.count
                                Text(pendingCount > 0 ? T("%@ in Bearbeitung", "\(pendingCount)") : T("%@ Bestellungen", "\(myOrders.count)"))
                                    .font(TDTypography.caption1)
                                    .foregroundColor(pendingCount > 0 ? .orange : .secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding(TDSpacing.md)
                    .glassBackground()
                }
            }
        }
    }
    
    // MARK: - Storage Section
    private var statsSection: some View {
        HStack(spacing: TDSpacing.md) {
            ProfileStatCard(title: "Gekauft", value: "\(purchasedCoursesCount)", icon: "cart.fill")
            ProfileStatCard(title: "Favoriten", value: "\(courseViewModel.favoriteCourses.count)", icon: "heart.fill")
        }
    }
    
    // MARK: - Feedback Section
    private var feedbackSection: some View {
        VStack(alignment: .leading, spacing: TDSpacing.sm) {
            Text(T("Feedback"))
                .font(TDTypography.headline)
                .foregroundColor(.secondary)
                .padding(.leading, TDSpacing.sm)
            
            Button {
                showFeedback = true
            } label: {
                HStack(spacing: TDSpacing.md) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.teal)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(T("Feedback senden"))
                            .font(TDTypography.headline)
                            .foregroundColor(.primary)
                        
                        Text(T("Hilf uns, die App zu verbessern"))
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
    }
    
    // MARK: - Storage Section
    private var storageSection: some View {
        VStack(alignment: .leading, spacing: TDSpacing.sm) {
            Text(T("Speicher"))
                .font(TDTypography.headline)
                .foregroundColor(.secondary)
                .padding(.leading, TDSpacing.sm)
            
            HStack {
                Image(systemName: "internaldrive")
                    .font(.system(size: 20))
                    .foregroundColor(Color.accentGold)
                    .frame(width: 28)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(T("Heruntergeladene Videos"))
                        .font(TDTypography.body)
                        .foregroundColor(.primary)
                    
                    Text(downloadManager.getStorageUsed())
                        .font(TDTypography.caption1)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if !downloadManager.downloadedVideos.isEmpty {
                    Button(T("Löschen")) {
                        showDeleteAllConfirm = true
                    }
                    .font(TDTypography.caption1)
                    .foregroundColor(.red)
                }
            }
            .padding(TDSpacing.md)
            .glassBackground()
        }
    }
    
    // MARK: - Purchases Section
    private var purchasesSection: some View {
        VStack(alignment: .leading, spacing: TDSpacing.sm) {
            Text(T("Käufe"))
                .font(TDTypography.headline)
                .foregroundColor(.secondary)
                .padding(.leading, TDSpacing.sm)
            
            SettingsRow(title: "Käufe wiederherstellen", icon: "arrow.clockwise", showChevron: false) {
                Task {
                    isRestoring = true
                    await storeViewModel.restorePurchases()
                    isRestoring = false
                    showRestoreSuccess = true
                }
            }
            .glassBackground()
        }
    }
    
    // MARK: - Admin Section
    @ViewBuilder
    private var adminSection: some View {
        // Admin-Dashboard NUR für Admins sichtbar
        if userManager.isAdmin {
            VStack(alignment: .leading, spacing: TDSpacing.sm) {
                Text(T("Administration"))
                    .font(TDTypography.headline)
                    .foregroundColor(.secondary)
                    .padding(.leading, TDSpacing.sm)
                
                Button {
                    showAdminDashboard = true
                } label: {
                    HStack(spacing: TDSpacing.md) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color.accentGold)
                            .frame(width: 28)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(T("Admin-Dashboard"))
                                .font(TDTypography.body)
                                .foregroundColor(.primary)
                            
                            Text(T("Kurse, User & Einstellungen verwalten"))
                                .font(TDTypography.caption1)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .padding(TDSpacing.md)
                }
                .glassBackground()
            }
        }
    }
    
    // MARK: - Legal Section
    private var legalSection: some View {
        VStack(alignment: .leading, spacing: TDSpacing.sm) {
            // Einstellungen
            Text(String.localized(.settings))
                .font(TDTypography.headline)
                .foregroundColor(.secondary)
                .padding(.leading, TDSpacing.sm)

            VStack(spacing: 0) {
                NavigationLink(destination: UserSettingsView()) {
                    HStack(spacing: TDSpacing.md) {
                        Image(systemName: "gearshape")
                            .font(.title3)
                            .foregroundColor(Color.accentGold)
                            .frame(width: 24)

                        Text(T("App-Einstellungen"))
                            .font(TDTypography.body)
                            .foregroundColor(.primary)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(TDSpacing.md)
                }

                Divider().padding(.leading, 44)

                // Spracheinstellung
                NavigationLink(destination: LanguageSettingsView()) {
                    HStack(spacing: TDSpacing.md) {
                        Image(systemName: "globe")
                            .font(.title3)
                            .foregroundColor(Color.accentGold)
                            .frame(width: 24)
                        
                        Text(String.localized(.language))
                            .font(TDTypography.body)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Text(LanguageManager.shared.currentLanguage.flag)
                            Text(LanguageManager.shared.currentLanguage.displayName)
                                .font(TDTypography.caption1)
                                .foregroundColor(.secondary)
                        }
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(TDSpacing.md)
                }
                
                Divider().padding(.leading, 44)
                
                // Marketing-Einstellungen
                NavigationLink(destination: MarketingSettingsView()) {
                    HStack(spacing: TDSpacing.md) {
                        Image(systemName: "envelope.badge")
                            .font(.title3)
                            .foregroundColor(Color.accentGold)
                            .frame(width: 24)
                        
                        Text(T("E-Mail-Benachrichtigungen"))
                            .font(TDTypography.body)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(TDSpacing.md)
                }
                
                Divider().padding(.leading, 44)
                
                // Verknüpfte Accounts (nur wenn eingeloggt)
                if userManager.isLoggedIn {
                    NavigationLink(destination: LinkedAccountsView()) {
                        HStack(spacing: TDSpacing.md) {
                            Image(systemName: "person.badge.key")
                                .font(.title3)
                                .foregroundColor(Color.accentGold)
                                .frame(width: 24)
                            
                            Text(T("Verknüpfte Accounts"))
                                .font(TDTypography.body)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(TDSpacing.md)
                    }
                }
            }
            .glassBackground()
            
            // Rechtliches
            Text(T("Rechtliches"))
                .font(TDTypography.headline)
                .foregroundColor(.secondary)
                .padding(.leading, TDSpacing.sm)
                .padding(.top, TDSpacing.sm)
            
            VStack(spacing: 0) {
                SettingsRow(title: "Datenschutz", icon: "hand.raised.fill", showChevron: true) {
                    showPrivacyPolicy = true
                }
                
                Divider().padding(.leading, 44)
                
                SettingsRow(title: "Nutzungsbedingungen", icon: "doc.text.fill", showChevron: true) {
                    showTermsOfService = true
                }
                
                Divider().padding(.leading, 44)
                
                SettingsRow(title: "Impressum", icon: "info.circle.fill", showChevron: true) {
                    showImpressum = true
                }
            }
            .glassBackground()
        }
    }
    
    // MARK: - App Info Section
    private var appInfoSection: some View {
        VStack(spacing: TDSpacing.xs) {
            Text(T("Tanzen mit Tatiana Drexler"))
                .font(TDTypography.caption1)
                .foregroundColor(.secondary)
            
            Text(T("Version 1.0.0"))
                .font(TDTypography.caption2)
                .foregroundColor(.secondary.opacity(0.7))
        }
        .padding(.top, TDSpacing.lg)
    }
    
    // MARK: - Helper
    private func groupColor(for group: UserGroup) -> Color {
        switch group {
        case .admin: return .red
        case .support: return .purple
        case .trainer: return .blue
        case .premium: return .orange
        case .user: return .gray
        }
    }
}

// MARK: - About Trainer View
struct AboutTrainerView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                TDGradients.mainBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: TDSpacing.lg) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [Color.accentGold, Color.accentGoldLight], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 150, height: 150)
                            Image(systemName: "person.fill").font(.system(size: 60)).foregroundColor(.white)
                        }
                        
                        Text(T("Tatiana Drexler")).font(TDTypography.title1).foregroundColor(.primary)
                        Text(T("Professionelle Paartanztrainerin")).font(TDTypography.subheadline).foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: TDSpacing.md) {
                            Text(T("Über mich")).font(TDTypography.headline).foregroundColor(.primary)
                            Text(T("Mit über 15 Jahren Erfahrung im Paartanz bringe ich Ihnen die Freude am Tanzen bei. Meine Leidenschaft ist es, Menschen jeden Alters das Tanzen beizubringen und ihre Begeisterung für Paartanz zu wecken."))
                                .font(TDTypography.body).foregroundColor(.secondary).lineSpacing(4)
                        }
                        .padding(TDSpacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassBackground()
                    }
                    .padding(TDSpacing.md)
                }
            }
            .navigationTitle(T("Über die Trainerin"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(T("Fertig")) { dismiss() }.foregroundColor(Color.accentGold)
                }
            }
        }
    }
}

// MARK: - Stat Card
struct ProfileStatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: TDSpacing.sm) {
            Image(systemName: icon).font(.system(size: 24)).foregroundColor(Color.accentGold)
            Text(value).font(TDTypography.title1).foregroundColor(.primary)
            Text(title).font(TDTypography.caption1).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(TDSpacing.md)
        .glassBackground()
    }
}

// MARK: - Settings Row
struct SettingsRow: View {
    let title: String
    let icon: String
    var showChevron: Bool = true
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: TDSpacing.md) {
                Image(systemName: icon).font(.system(size: 20)).foregroundColor(Color.accentGold).frame(width: 28)
                Text(title).font(TDTypography.body).foregroundColor(.primary)
                Spacer()
                if showChevron {
                    Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundColor(.secondary)
                }
            }
            .padding(TDSpacing.md)
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(CourseViewModel())
        .environmentObject(StoreViewModel())
}
