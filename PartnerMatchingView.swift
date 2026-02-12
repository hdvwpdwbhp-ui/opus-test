//
//  PartnerMatchingView.swift
//  Tanzen mit Tatiana Drexler
//
//  Partner-Matching: Tanzpartner finden basierend auf Skill-Level und Standort
//

import SwiftUI
import CoreLocation
import Combine
import PhotosUI

// MARK: - Partner Matching View
struct PartnerMatchingView: View {
    @StateObject private var matchingManager = PartnerMatchingManager.shared
    @StateObject private var userManager = UserManager.shared
    @State private var selectedTab = 0
    @State private var showProfileSetup = false
    @State private var filterStyles: Set<DanceStyle> = []
    @State private var filterLevel: PartnerProfile.SkillLevel?
    @State private var filterCity = ""
    @State private var filterGender: PartnerProfile.Gender?
    @State private var filterLookingFor: PartnerProfile.Gender?
    @State private var filterMinAge = 18
    @State private var filterMaxAge = 60
    @State private var filterOnlineOnly = false
    @State private var filterMutualPreference = true
    @State private var sortOption: PartnerSortOption = .lastActive
    
    var hasProfile: Bool {
        matchingManager.myProfile != nil && matchingManager.myProfile?.isVisible == true
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if !hasProfile {
                noProfileView
            } else {
                // Tab Selector
                Picker("", selection: $selectedTab) {
                    Text(T("Entdecken")).tag(0)
                    Text(T("Anfragen")).tag(1)
                    Text(T("Matches")).tag(2)
                }
                .pickerStyle(.segmented)
                .padding()

                TabView(selection: $selectedTab) {
                    discoverView.tag(0)
                    requestsView.tag(1)
                    matchesView.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
        .background(TDGradients.mainBackground.ignoresSafeArea())
        .navigationTitle(T("Tanzpartner"))
        .toolbar {
            if hasProfile {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showProfileSetup = true
                    } label: {
                        Image(systemName: "person.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showProfileSetup) {
            PartnerProfileSetupView()
        }
        .task {
            if let userId = userManager.currentUser?.id {
                await matchingManager.loadInitialData(for: userId)
                refreshSearch()
            }
        }
        .onChange(of: filterCity) { _, _ in
            refreshSearch()
        }
        .onChange(of: filterLevel) { _, _ in
            refreshSearch()
        }
        .onChange(of: filterStyles) { _, _ in
            refreshSearch()
        }
        .onChange(of: filterGender) { _, _ in
            refreshSearch()
        }
        .onChange(of: filterLookingFor) { _, _ in
            refreshSearch()
        }
        .onChange(of: filterMinAge) { _, _ in
            refreshSearch()
        }
        .onChange(of: filterMaxAge) { _, _ in
            refreshSearch()
        }
        .onChange(of: filterOnlineOnly) { _, _ in
            refreshSearch()
        }
        .onChange(of: filterMutualPreference) { _, _ in
            refreshSearch()
        }
        .onChange(of: sortOption) { _, _ in
            refreshSearch()
        }
    }

    private func refreshSearch() {
        let styles = filterStyles.isEmpty ? nil : Array(filterStyles)
        let city = filterCity.isEmpty ? nil : filterCity
        let minAge = filterMinAge > 0 ? filterMinAge : nil
        let maxAge = filterMaxAge > 0 ? filterMaxAge : nil
        let lookingFor = (filterLookingFor == .any) ? nil : filterLookingFor
        Task {
            await matchingManager.searchPartners(
                styles: styles,
                level: filterLevel,
                city: city,
                gender: filterGender,
                lookingForGender: lookingFor,
                minAge: minAge,
                maxAge: maxAge,
                onlineOnly: filterOnlineOnly,
                requiresMutualPreference: filterMutualPreference,
                sort: sortOption
            )
        }
    }
    
    // MARK: - No Profile View
    private var noProfileView: some View {
        VStack(spacing: TDSpacing.xl) {
            Spacer()
            
            Image(systemName: "person.2.fill")
                .font(.system(size: 80))
                .foregroundColor(Color.accentGold)
            
            Text(T("Finde deinen Tanzpartner"))
                .font(TDTypography.title2)
            
            Text(T("Erstelle ein Profil, um andere Tänzer in deiner Nähe zu finden und gemeinsam zu üben."))
                .font(TDTypography.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button {
                showProfileSetup = true
            } label: {
                Text(T("Profil erstellen"))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentGold)
                    .cornerRadius(TDRadius.md)
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
    }
    
    // MARK: - Discover View
    private var discoverView: some View {
        ScrollView {
            VStack(spacing: TDSpacing.md) {
                // Filters
                filterSection

                // Partner Cards
                let partners = matchingManager.potentialPartners

                if partners.isEmpty {
                    ContentUnavailableView(
                        "Keine Partner gefunden",
                        systemImage: "person.slash",
                        description: Text(T("Versuche andere Filter"))
                    )
                } else {
                    ForEach(partners) { partner in
                        PartnerCard(partner: partner)
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Filter Section
    private var filterSection: some View {
        VStack(spacing: TDSpacing.sm) {
            // City
            HStack {
                Image(systemName: "mappin")
                    .foregroundColor(.secondary)
                TextField(T("Stadt"), text: $filterCity)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(TDRadius.md)

            // Age + Online + Mutual
            VStack(spacing: TDSpacing.sm) {
                HStack {
                    Text(T("Alter"))
                        .font(TDTypography.caption1)
                    Spacer()
                    Text("\(filterMinAge)-\(filterMaxAge)")
                        .font(TDTypography.caption1)
                        .foregroundColor(.secondary)
                }
                HStack(spacing: TDSpacing.sm) {
                    Stepper(T("Min"), value: $filterMinAge, in: 16...filterMaxAge)
                    Stepper(T("Max"), value: $filterMaxAge, in: filterMinAge...80)
                }
                Toggle(T("Nur online"), isOn: $filterOnlineOnly)
                Toggle(T("Passende Präferenzen"), isOn: $filterMutualPreference)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(TDRadius.md)

            // Level + Gender
            HStack(spacing: TDSpacing.sm) {
                Picker(T("Level"), selection: $filterLevel) {
                    Text(T("Alle Level")).tag(PartnerProfile.SkillLevel?.none)
                    ForEach(PartnerProfile.SkillLevel.allCases, id: \.self) { level in
                        Text(T(level.rawValue)).tag(Optional(level))
                    }
                }
                Picker(T("Geschlecht"), selection: $filterGender) {
                    Text(T("Alle")).tag(PartnerProfile.Gender?.none)
                    ForEach(PartnerProfile.Gender.allCases.filter { $0 != .any }, id: \.self) { gender in
                        Text(T(gender.rawValue)).tag(Optional(gender))
                    }
                }
            }
            .pickerStyle(.menu)

            HStack(spacing: TDSpacing.sm) {
                Picker(T("Sucht"), selection: $filterLookingFor) {
                    Text(T("Alle")).tag(PartnerProfile.Gender?.none)
                    ForEach(PartnerProfile.Gender.allCases, id: \.self) { gender in
                        Text(T(gender.rawValue)).tag(Optional(gender))
                    }
                }
                Picker(T("Sortierung"), selection: $sortOption) {
                    ForEach(PartnerSortOption.allCases) { option in
                        Text(T(option.rawValue)).tag(option)
                    }
                }
            }
            .pickerStyle(.menu)

            // Dance Styles
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: TDSpacing.sm) {
                    ForEach(DanceStyle.allCases, id: \.self) { style in
                        PartnerFilterChip(label: style.rawValue, isSelected: filterStyles.contains(style)) {
                            if filterStyles.contains(style) {
                                filterStyles.remove(style)
                            } else {
                                filterStyles.insert(style)
                            }
                        }
                    }
                }
            }

            Button(T("Filter zurücksetzen")) {
                filterStyles.removeAll()
                filterLevel = nil
                filterCity = ""
                filterGender = nil
                filterLookingFor = nil
                filterMinAge = 18
                filterMaxAge = 60
                filterOnlineOnly = false
                filterMutualPreference = true
                sortOption = .lastActive
                refreshSearch()
            }
            .font(TDTypography.caption1)
        }
    }
    
    // MARK: - Requests View
    private var requestsView: some View {
        ScrollView {
            VStack(spacing: TDSpacing.md) {
                if matchingManager.receivedRequests.isEmpty && matchingManager.myRequests.isEmpty {
                    ContentUnavailableView(
                        "Keine Anfragen",
                        systemImage: "envelope",
                        description: Text(T("Du hast noch keine Anfragen erhalten oder gesendet"))
                    )
                } else {
                    // Received Requests
                    if !matchingManager.receivedRequests.isEmpty {
                        Section {
                            ForEach(matchingManager.receivedRequests) { request in
                                RequestCard(request: request, isReceived: true)
                            }
                        } header: {
                            Text(T("Erhaltene Anfragen"))
                                .font(TDTypography.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    
                    // Sent Requests
                    if !matchingManager.myRequests.isEmpty {
                        Section {
                            ForEach(matchingManager.myRequests) { request in
                                RequestCard(request: request, isReceived: false)
                            }
                        } header: {
                            Text(T("Gesendete Anfragen"))
                                .font(TDTypography.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Matches View
    private var matchesView: some View {
        ScrollView {
            VStack(spacing: TDSpacing.md) {
                if matchingManager.matches.isEmpty {
                    ContentUnavailableView(
                        "Noch keine Matches",
                        systemImage: "heart.slash",
                        description: Text(T("Wenn jemand deine Anfrage annimmt, erscheint er hier"))
                    )
                } else {
                    ForEach(matchingManager.matches) { match in
                        MatchCard(match: match)
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Partner Card
struct PartnerCard: View {
    let partner: PartnerProfile
    @State private var showContactSheet = false
    @State private var showReportSheet = false
    @State private var showDetailSheet = false
    @StateObject private var matchingManager = PartnerMatchingManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: TDSpacing.md) {
            // Foto-Galerie oder Avatar
            if !partner.photoURLs.isEmpty {
                TabView {
                    ForEach(partner.photoURLs.indices, id: \.self) { index in
                        AsyncImage(url: URL(string: partner.photoURLs[index])) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Color.gray.opacity(0.2)
                        }
                        .frame(height: 180)
                        .clipped()
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .frame(height: 180)
                .cornerRadius(TDRadius.md)
            }
            
            HStack(spacing: TDSpacing.md) {
                // Avatar (falls keine Fotos)
                if partner.photoURLs.isEmpty {
                    ZStack {
                        Circle()
                            .fill(Color.accentGold.opacity(0.2))
                            .frame(width: 60, height: 60)

                        Text(String(partner.displayName.prefix(1)))
                            .font(.title)
                            .foregroundColor(Color.accentGold)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(partner.displayName)
                            .font(TDTypography.headline)

                        if let age = partner.age {
                            Text(", \(age)")
                                .font(TDTypography.body)
                                .foregroundColor(.secondary)
                        }
                        
                        if let height = partner.height {
                            Text("• \(height) " + T("cm"))
                                .font(TDTypography.caption1)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Headline
                    if !partner.headline.isEmpty {
                        Text(partner.headline)
                            .font(TDTypography.caption1)
                            .foregroundColor(Color.accentGold)
                            .lineLimit(1)
                    }

                    HStack {
                        Image(systemName: "mappin")
                            .font(.caption)
                        Text(partner.city)
                        if let radius = partner.searchRadius {
                            Text("(\(radius) " + T("km") + ")")
                        }
                    }
                    .font(TDTypography.caption1)
                    .foregroundColor(.secondary)
                }

                Spacer()

                // Online Status
                VStack {
                    Circle()
                        .fill(partner.lastActive.timeIntervalSinceNow > -3600 ? Color.green : Color.gray)
                        .frame(width: 10, height: 10)
                    Text(partner.lastActive.timeIntervalSinceNow > -3600 ? T("Online") : T("Offline"))
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
            }
            
            // Level & Erfahrung
            HStack {
                Label(T(partner.skillLevel.rawValue), systemImage: "star.fill")
                    .font(TDTypography.caption1)
                    .foregroundColor(Color.accentGold)
                
                if let years = partner.danceExperienceYears, years > 0 {
                    Text(T("• %@ J. Erfahrung", "\(years)"))
                        .font(TDTypography.caption1)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(T(partner.lookingForType.rawValue))
                    .font(TDTypography.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
            }

            // Dance Styles
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(partner.danceStyles, id: \.self) { style in
                        Text(T(style.rawValue))
                            .font(TDTypography.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.accentGold.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
            }
            
            // Badges
            HStack(spacing: 8) {
                if partner.availableForEvents {
                    Label(T("Events"), systemImage: "trophy")
                        .font(TDTypography.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(4)
                }
                
                if partner.hasOwnStudio {
                    Label(T("Übungsraum"), systemImage: "house")
                        .font(TDTypography.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(4)
                }
                
                if !partner.videoURLs.isEmpty {
                    Label("\(partner.videoURLs.count) Video(s)", systemImage: "video.fill")
                        .font(TDTypography.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(4)
                }
            }

            // Bio
            if !partner.bio.isEmpty {
                Text(partner.bio)
                    .font(TDTypography.body)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            // Action Buttons
            HStack(spacing: TDSpacing.sm) {
                Button {
                    showDetailSheet = true
                } label: {
                    HStack {
                        Image(systemName: "eye")
                        Text(T("Details"))
                    }
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(TDRadius.md)
                }
                
                Button {
                    showContactSheet = true
                } label: {
                    HStack {
                        Image(systemName: "paperplane.fill")
                        Text(T("Anfrage"))
                    }
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentGold)
                    .cornerRadius(TDRadius.md)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(TDRadius.lg)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        .contextMenu {
            Button(T("Melden")) {
                showReportSheet = true
            }
            Button(role: .destructive) {
                Task { _ = await matchingManager.blockUser(partner.userId) }
            } label: {
                Text(T("Blockieren"))
            }
        }
        .sheet(isPresented: $showContactSheet) {
            SendRequestSheet(partner: partner)
        }
        .sheet(isPresented: $showReportSheet) {
            PartnerReportSheet(reportedUserId: partner.userId)
        }
        .sheet(isPresented: $showDetailSheet) {
            PartnerDetailView(partner: partner)
        }
    }
}

// MARK: - Partner Detail View
struct PartnerDetailView: View {
    let partner: PartnerProfile
    @Environment(\.dismiss) var dismiss
    @State private var showContactSheet = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: TDSpacing.lg) {
                    // Foto-Galerie
                    if !partner.photoURLs.isEmpty {
                        TabView {
                            ForEach(partner.photoURLs.indices, id: \.self) { index in
                                AsyncImage(url: URL(string: partner.photoURLs[index])) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    Color.gray.opacity(0.2)
                                }
                                .frame(height: 300)
                                .clipped()
                            }
                        }
                        .tabViewStyle(.page)
                        .frame(height: 300)
                    }
                    
                    VStack(alignment: .leading, spacing: TDSpacing.md) {
                        // Header
                        HStack {
                            VStack(alignment: .leading) {
                                Text(partner.displayName)
                                    .font(TDTypography.title2)
                                
                                if !partner.headline.isEmpty {
                                    Text(partner.headline)
                                        .font(TDTypography.body)
                                        .foregroundColor(Color.accentGold)
                                }
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing) {
                                if let age = partner.age {
                                    Text(T("%@ Jahre", "\(age)"))
                                }
                                if let height = partner.height {
                                    Text("\(height) " + T("cm"))
                                }
                            }
                            .font(TDTypography.body)
                            .foregroundColor(.secondary)
                        }
                        
                        Divider()
                        
                        // Standort
                        HStack {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(Color.accentGold)
                            Text(partner.city)
                            if let radius = partner.searchRadius {
                                Text(T("(Suchradius: %@ km)", "\(radius)"))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Tanzinfos
                        VStack(alignment: .leading, spacing: 8) {
                            Text(T("Tanzerfahrung"))
                                .font(TDTypography.headline)
                            
                            HStack {
                                Label(T(partner.skillLevel.rawValue), systemImage: "star.fill")
                                if let years = partner.danceExperienceYears {
                                    Text(T("• %@ Jahre", "\(years)"))
                                }
                            }
                            .foregroundColor(Color.accentGold)
                            
                            // Tanzstile
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(partner.danceStyles, id: \.self) { style in
                                        Text(T(style.rawValue))
                                            .font(TDTypography.caption1)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.accentGold.opacity(0.1))
                                            .cornerRadius(16)
                                    }
                                }
                            }
                        }
                        
                        Divider()
                        
                        // Was wird gesucht
                        VStack(alignment: .leading, spacing: 8) {
                            Text(T("Sucht nach"))
                                .font(TDTypography.headline)
                            
                            HStack {
                                Label(T(partner.lookingForType.rawValue), systemImage: "person.2")
                                if let gender = partner.lookingForGender, gender != .any {
                                    Text("• " + T(gender.rawValue))
                                }
                            }
                            
                            if partner.availableForEvents {
                                Label(T("Für Events/Turniere verfügbar"), systemImage: "trophy.fill")
                                    .foregroundColor(.purple)
                            }
                            
                            if partner.hasOwnStudio {
                                Label(T("Hat eigenen Übungsraum"), systemImage: "house.fill")
                                    .foregroundColor(.green)
                            }
                        }
                        
                        // Verfügbarkeit
                        if !partner.preferredDays.isEmpty || !partner.preferredTimes.isEmpty {
                            Divider()
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text(T("Verfügbarkeit"))
                                    .font(TDTypography.headline)
                                
                                if !partner.preferredDays.isEmpty {
                                    HStack {
                                        Image(systemName: "calendar")
                                        Text(localizedDays(partner.preferredDays))
                                    }
                                    .font(TDTypography.body)
                                }
                                
                                if !partner.preferredTimes.isEmpty {
                                    HStack {
                                        Image(systemName: "clock")
                                        Text(localizedTimes(partner.preferredTimes))
                                    }
                                    .font(TDTypography.body)
                                }
                            }
                        }
                        
                        // Bio
                        if !partner.bio.isEmpty {
                            Divider()
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text(T("Über mich"))
                                    .font(TDTypography.headline)
                                Text(partner.bio)
                                    .font(TDTypography.body)
                            }
                        }
                        
                        // Videos
                        if !partner.videoURLs.isEmpty {
                            Divider()
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text(T("Videos"))
                                    .font(TDTypography.headline)
                                
                                ForEach(partner.videoURLs.indices, id: \.self) { index in
                                    if let url = URL(string: partner.videoURLs[index]) {
                                        Link(destination: url) {
                                            HStack {
                                                Image(systemName: "play.rectangle.fill")
                                                    .foregroundColor(Color.accentGold)
                                                Text(T("Video %@ ansehen", "\(index + 1)"))
                                                Spacer()
                                                Image(systemName: "arrow.up.right")
                                            }
                                            .padding()
                                            .background(Color.gray.opacity(0.1))
                                            .cornerRadius(TDRadius.md)
                                        }
                                    }
                                }
                            }
                        }
                        
                        Divider()
                        
                        // Kontakt
                        VStack(alignment: .leading, spacing: 8) {
                            Text(T("Kontakt"))
                                .font(TDTypography.headline)
                            
                            Text(T("Bevorzugt: %@", T(partner.contactPreference.rawValue)))
                                .font(TDTypography.body)
                            
                            if let instagram = partner.instagramHandle, !instagram.isEmpty {
                                if let url = URL(string: "https://instagram.com/\(instagram)") {
                                    Link(destination: url) {
                                        Label("@\(instagram)", systemImage: "camera")
                                    }
                                }
                            }
                        }
                        
                        // Contact Button
                        Button {
                            showContactSheet = true
                        } label: {
                            HStack {
                                Image(systemName: "paperplane.fill")
                                Text(T("Anfrage senden"))
                            }
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentGold)
                            .cornerRadius(TDRadius.md)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(T("Profil"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(T("Schließen")) { dismiss() }
                }
            }
            .sheet(isPresented: $showContactSheet) {
                SendRequestSheet(partner: partner)
            }
        }
    }
    
    // Helper für lokalisierte Wochentage
    private func localizedDays(_ days: [PartnerProfile.DayOfWeek]) -> String {
        days.map { T($0.rawValue) }.joined(separator: ", ")
    }
    
    // Helper für lokalisierte Uhrzeiten
    private func localizedTimes(_ times: [PartnerProfile.TimeOfDay]) -> String {
        times.map { T($0.rawValue) }.joined(separator: ", ")
    }
}

// MARK: - Request Card
struct RequestCard: View {
    let request: PartnerRequest
    let isReceived: Bool
    @StateObject private var matchingManager = PartnerMatchingManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: TDSpacing.sm) {
            HStack {
                Text(displayName)
                    .font(TDTypography.headline)

                Spacer()

                Text(request.status.rawValue)
                    .font(TDTypography.caption1)
                    .foregroundColor(statusColor)
            }

            Text(request.message)
                .font(TDTypography.body)
                .foregroundColor(.secondary)

            if isReceived && request.status == .pending {
                HStack(spacing: TDSpacing.md) {
                    Button {
                        Task { await matchingManager.respondToRequest(request.id, accept: false) }
                    } label: {
                        Text(T("Ablehnen"))
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(TDRadius.md)
                    }

                    Button {
                        Task { await matchingManager.respondToRequest(request.id, accept: true) }
                    } label: {
                        Text(T("Annehmen"))
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentGold)
                            .cornerRadius(TDRadius.md)
                    }
                }
            } else if !isReceived && request.status == .pending {
                Button {
                    Task { await matchingManager.cancelRequest(request.id) }
                } label: {
                    Text(T("Anfrage stornieren"))
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(TDRadius.md)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(TDRadius.md)
    }

    private var displayName: String {
        if isReceived {
            return request.fromUserName
        }
        return request.toUserName ?? "Gesendete Anfrage"
    }

    private var statusColor: Color {
        switch request.status {
        case .pending: return .orange
        case .accepted: return .green
        case .declined: return .red
        case .cancelled: return .gray
        }
    }
}

// MARK: - Match Card
struct MatchCard: View {
    let match: PartnerMatchSummary
    @StateObject private var matchingManager = PartnerMatchingManager.shared

    var body: some View {
        NavigationLink {
            PartnerChatView(match: match)
        } label: {
            HStack(spacing: TDSpacing.md) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.2))
                        .frame(width: 50, height: 50)

                    Text(String(match.partner.displayName.prefix(1)))
                        .font(.title2)
                        .foregroundColor(.green)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(match.partner.displayName)
                        .font(TDTypography.headline)

                    Text(match.partner.city)
                        .font(TDTypography.caption1)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "message.fill")
                    .foregroundColor(Color.accentGold)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(TDRadius.md)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                Task { _ = await matchingManager.removeMatch(matchId: match.id) }
            } label: {
                Text(T("Match entfernen"))
            }
        }
    }
}

// MARK: - Send Request Sheet
struct SendRequestSheet: View {
    let partner: PartnerProfile
    @StateObject private var matchingManager = PartnerMatchingManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var message = ""
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 8) {
                        Text(partner.displayName)
                            .font(TDTypography.title2)
                        Text(partner.city)
                            .font(TDTypography.caption1)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                
                Section(T("Deine Nachricht")) {
                    TextEditor(text: $message)
                        .frame(minHeight: 100)
                    
                    Text(T("Stell dich kurz vor und erkläre, warum du gerne mit %@ tanzen möchtest.", partner.displayName))
                        .font(TDTypography.caption1)
                        .foregroundColor(.secondary)
                }
                
                Section {
                    Button {
                        Task {
                            let success = await matchingManager.sendRequest(
                                to: partner.userId,
                                partnerName: partner.displayName,
                                message: message
                            )
                            if success {
                                dismiss()
                            } else {
                                errorMessage = matchingManager.errorMessage ?? "Anfrage konnte nicht gesendet werden"
                            }
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Text(T("Anfrage senden"))
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .listRowBackground(Color.accentGold)
                    .foregroundColor(.white)
                    .disabled(message.isEmpty)
                }
            }
            .navigationTitle(T("Anfrage senden"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(T("Abbrechen")) { dismiss() }
                }
            }
            .alert(T("Fehler"), isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button(T("OK"), role: .cancel) {}
            } message: {
                Text(errorMessage ?? T("Unbekannter Fehler"))
            }
        }
    }
}

// MARK: - Profile Setup View
struct PartnerProfileSetupView: View {
    @StateObject private var matchingManager = PartnerMatchingManager.shared
    @StateObject private var userManager = UserManager.shared
    @Environment(\.dismiss) var dismiss
    
    // Persönliche Daten
    @State private var displayName = ""
    @State private var headline = ""
    @State private var age = ""
    @State private var height = ""
    @State private var gender: PartnerProfile.Gender = .other
    @State private var lookingFor: PartnerProfile.Gender = .any
    @State private var city = ""
    @State private var searchRadius = 50
    
    // Tanzerfahrung
    @State private var selectedStyles: Set<DanceStyle> = []
    @State private var skillLevel: PartnerProfile.SkillLevel = .beginner
    @State private var danceExperienceYears = ""
    @State private var lookingForType: PartnerProfile.PartnerType = .any
    @State private var availableForEvents = false
    @State private var hasOwnStudio = false
    
    // Verfügbarkeit
    @State private var preferredDays: Set<PartnerProfile.DayOfWeek> = []
    @State private var preferredTimes: Set<PartnerProfile.TimeOfDay> = []
    
    // Kontakt & Medien
    @State private var contactPreference: PartnerProfile.ContactPreference = .appOnly
    @State private var instagramHandle = ""
    @State private var phoneNumber = ""
    @State private var bio = ""
    
    // Fotos & Videos - mit Galerie-Upload
    @State private var photoURLs: [String] = []
    @State private var videoURLs: [String] = []
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedVideoItem: PhotosPickerItem?
    @State private var isUploadingPhoto = false
    @State private var isUploadingVideo = false
    
    @State private var isVisible = true
    @State private var errorMessage: String?
    @State private var currentStep = 0
    
    var body: some View {
        NavigationStack {
            TabView(selection: $currentStep) {
                // Step 1: Persönliche Daten
                personalDataStep.tag(0)
                
                // Step 2: Tanzerfahrung
                danceExperienceStep.tag(1)
                
                // Step 3: Verfügbarkeit
                availabilityStep.tag(2)
                
                // Step 4: Medien & Kontakt
                mediaContactStep.tag(3)
                
                // Step 5: Vorschau & Speichern
                previewStep.tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: currentStep)
            .navigationTitle(T("Tanzpartner-Anzeige"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(T("Abbrechen")) { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 4) {
                        ForEach(0..<5) { i in
                            Circle()
                                .fill(i <= currentStep ? Color.accentGold : Color.gray.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                    }
                }
            }
            .onAppear { loadExistingProfile() }
        }
    }
    
    // MARK: - Step 1: Persönliche Daten
    private var personalDataStep: some View {
        Form {
            Section {
                VStack(spacing: 8) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 60))
                        .foregroundColor(Color.accentGold)
                    Text(T("Erzähl uns von dir"))
                        .font(TDTypography.title2)
                    Text(T("Diese Infos helfen anderen, dich zu finden"))
                        .font(TDTypography.caption1)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
            }
            .listRowBackground(Color.clear)
            
            Section(T("Grunddaten")) {
                TextField(T("Anzeigename *"), text: $displayName)
                TextField(T("Überschrift (z.B. 'Suche Salsa-Partner in Berlin')"), text: $headline)
                
                HStack {
                    TextField(T("Alter"), text: $age)
                        .keyboardType(.numberPad)
                        .frame(width: 80)
                    Spacer()
                    TextField(T("Größe (cm)"), text: $height)
                        .keyboardType(.numberPad)
                        .frame(width: 100)
                }
            }
            
            Section(T("Geschlecht")) {
                Picker("Ich bin", selection: $gender) {
                    ForEach(PartnerProfile.Gender.allCases.filter { $0 != .any }, id: \.self) { g in
                        Text(g.rawValue).tag(g)
                    }
                }
                .pickerStyle(.segmented)
                
                Picker("Ich suche", selection: $lookingFor) {
                    ForEach(PartnerProfile.Gender.allCases, id: \.self) { g in
                        Text(g.rawValue).tag(g)
                    }
                }
            }
            
            Section(T("Standort")) {
                TextField(T("Stadt *"), text: $city)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(T("Suchradius: %@ km", "\(searchRadius)"))
                        .font(TDTypography.caption1)
                    Slider(value: Binding(
                        get: { Double(searchRadius) },
                        set: { searchRadius = Int($0) }
                    ), in: 5...200, step: 5)
                }
            }
            
            Section {
                nextStepButton(step: 1)
            }
        }
    }
    
    // MARK: - Step 2: Tanzerfahrung
    private var danceExperienceStep: some View {
        Form {
            Section {
                VStack(spacing: 8) {
                    Image(systemName: "figure.dance")
                        .font(.system(size: 60))
                        .foregroundColor(Color.accentGold)
                    Text(T("Deine Tanzerfahrung"))
                        .font(TDTypography.title2)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
            }
            .listRowBackground(Color.clear)
            
            Section(T("Tanzstile (wähle alle die du tanzt)")) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                    ForEach(DanceStyle.allCases, id: \.self) { style in
                        Button {
                            if selectedStyles.contains(style) {
                                selectedStyles.remove(style)
                            } else {
                                selectedStyles.insert(style)
                            }
                        } label: {
                            Text(style.rawValue)
                                .font(TDTypography.caption1)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(selectedStyles.contains(style) ? Color.accentGold : Color.gray.opacity(0.1))
                                .foregroundColor(selectedStyles.contains(style) ? .white : .primary)
                                .cornerRadius(20)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 8)
            }
            
            Section(T("Niveau")) {
                Picker("Dein Level", selection: $skillLevel) {
                    ForEach(PartnerProfile.SkillLevel.allCases, id: \.self) { level in
                        Text(level.rawValue).tag(level)
                    }
                }
                .pickerStyle(.segmented)
                
                HStack {
                    Text(T("Jahre Erfahrung"))
                    Spacer()
                    TextField(T("Jahre"), text: $danceExperienceYears)
                        .keyboardType(.numberPad)
                        .frame(width: 60)
                        .multilineTextAlignment(.trailing)
                }
            }
            
            Section(T("Was suchst du?")) {
                Picker("Partner-Typ", selection: $lookingForType) {
                    ForEach(PartnerProfile.PartnerType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                
                Toggle("Für Events/Turniere verfügbar", isOn: $availableForEvents)
                Toggle("Eigener Übungsraum vorhanden", isOn: $hasOwnStudio)
            }
            
            Section {
                HStack {
                    backStepButton(step: 0)
                    nextStepButton(step: 2)
                }
            }
        }
    }
    
    // MARK: - Step 3: Verfügbarkeit
    private var availabilityStep: some View {
        Form {
            Section {
                VStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 60))
                        .foregroundColor(Color.accentGold)
                    Text(T("Wann hast du Zeit?"))
                        .font(TDTypography.title2)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
            }
            .listRowBackground(Color.clear)
            
            Section(T("Bevorzugte Tage")) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 8) {
                    ForEach(PartnerProfile.DayOfWeek.allCases, id: \.self) { day in
                        Button {
                            if preferredDays.contains(day) {
                                preferredDays.remove(day)
                            } else {
                                preferredDays.insert(day)
                            }
                        } label: {
                            Text(String(day.rawValue.prefix(2)))
                                .font(TDTypography.caption1)
                                .frame(width: 40, height: 40)
                                .background(preferredDays.contains(day) ? Color.accentGold : Color.gray.opacity(0.1))
                                .foregroundColor(preferredDays.contains(day) ? .white : .primary)
                                .cornerRadius(20)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 8)
            }
            
            Section(T("Bevorzugte Zeiten")) {
                ForEach(PartnerProfile.TimeOfDay.allCases, id: \.self) { time in
                    Button {
                        if preferredTimes.contains(time) {
                            preferredTimes.remove(time)
                        } else {
                            preferredTimes.insert(time)
                        }
                    } label: {
                        HStack {
                            Text(time.rawValue)
                                .foregroundColor(.primary)
                            Spacer()
                            if preferredTimes.contains(time) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Color.accentGold)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
            }
            
            Section {
                HStack {
                    backStepButton(step: 1)
                    nextStepButton(step: 3)
                }
            }
        }
    }
    
    // MARK: - Step 4: Medien & Kontakt
    private var mediaContactStep: some View {
        Form {
            Section {
                VStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 60))
                        .foregroundColor(Color.accentGold)
                    Text(T("Zeig dich von deiner besten Seite"))
                        .font(TDTypography.title2)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
            }
            .listRowBackground(Color.clear)
            
            Section(T("Fotos (bis zu 5)")) {
                ForEach(photoURLs.indices, id: \.self) { index in
                    HStack {
                        AsyncImage(url: URL(string: photoURLs[index])) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            case .failure(_):
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                            case .empty:
                                ProgressView()
                            @unknown default:
                                Color.gray.opacity(0.2)
                            }
                        }
                        .frame(width: 60, height: 60)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        
                        Text(T("Foto %@", "\(index + 1)"))
                        Spacer()
                        Button(role: .destructive) {
                            photoURLs.remove(at: index)
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
                
                if photoURLs.count < 5 {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        HStack {
                            if isUploadingPhoto {
                                ProgressView()
                                    .padding(.trailing, 4)
                            }
                            Label(T("Foto aus Galerie wählen"), systemImage: "photo.badge.plus")
                        }
                    }
                    .disabled(isUploadingPhoto)
                    .onChange(of: selectedPhotoItem) { _, newItem in
                        handlePhotoSelection(newItem)
                    }
                }
            }
            
            Section(T("Videos (bis zu 2)")) {
                ForEach(videoURLs.indices, id: \.self) { index in
                    HStack {
                        Image(systemName: "video.fill")
                            .frame(width: 60, height: 60)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        
                        Text(T("Video %@", "\(index + 1)"))
                        Spacer()
                        Button(role: .destructive) {
                            videoURLs.remove(at: index)
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
                
                if videoURLs.count < 2 {
                    PhotosPicker(selection: $selectedVideoItem, matching: .videos) {
                        HStack {
                            if isUploadingVideo {
                                ProgressView()
                                    .padding(.trailing, 4)
                            }
                            Label(T("Video aus Galerie wählen"), systemImage: "video.badge.plus")
                        }
                    }
                    .disabled(isUploadingVideo)
                    .onChange(of: selectedVideoItem) { _, newItem in
                        handleVideoSelection(newItem)
                    }
                }
            }
            
            Section(T("Über mich")) {
                TextEditor(text: $bio)
                    .frame(minHeight: 100)
                Text(T("Beschreibe dich, deine Tanzvorlieben und was du suchst"))
                    .font(TDTypography.caption2)
                    .foregroundColor(.secondary)
            }
            
            Section(T("Kontaktmöglichkeiten")) {
                Picker("Wie kann man dich erreichen?", selection: $contactPreference) {
                    ForEach(PartnerProfile.ContactPreference.allCases, id: \.self) { pref in
                        Text(pref.rawValue).tag(pref)
                    }
                }
                
                if contactPreference == .instagram || contactPreference == .all {
                    HStack {
                        Text(T("@"))
                        TextField(T("Instagram Username"), text: $instagramHandle)
                    }
                }
                
                if contactPreference == .phone || contactPreference == .all {
                    TextField(T("Telefonnummer"), text: $phoneNumber)
                        .keyboardType(.phonePad)
                }
            }
            
            Section {
                HStack {
                    backStepButton(step: 2)
                    nextStepButton(step: 4)
                }
            }
        }
    }
    
    // MARK: - Photo/Video Upload Handlers
    private func handlePhotoSelection(_ item: PhotosPickerItem?) {
        guard let item = item else { return }
        isUploadingPhoto = true
        
        Task {
            do {
                if let data = try await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    // Bild komprimieren und als Base64 speichern
                    let scaledImage = image.scaled(toMaxSize: 800)
                    if let base64String = scaledImage.toBase64(compressionQuality: 0.7) {
                        let dataURL = "data:image/jpeg;base64,\(base64String)"
                        await MainActor.run {
                            photoURLs.append(dataURL)
                        }
                    }
                }
            } catch {
                print("Fehler beim Laden des Fotos: \(error)")
            }
            
            await MainActor.run {
                isUploadingPhoto = false
                selectedPhotoItem = nil
            }
        }
    }
    
    private func handleVideoSelection(_ item: PhotosPickerItem?) {
        guard let item = item else { return }
        isUploadingVideo = true
        
        Task {
            do {
                // Videos als URL speichern (für spätere Firebase-Upload)
                // Vorläufig: Platzhalter-URL
                if let _ = try await item.loadTransferable(type: Data.self) {
                    // In einer echten Implementierung würde das Video zu Firebase Storage hochgeladen
                    // Hier verwenden wir einen Platzhalter
                    let placeholderURL = "video://local/\(UUID().uuidString)"
                    await MainActor.run {
                        videoURLs.append(placeholderURL)
                    }
                }
            } catch {
                print("Fehler beim Laden des Videos: \(error)")
            }
            
            await MainActor.run {
                isUploadingVideo = false
                selectedVideoItem = nil
            }
        }
    }
    
    // MARK: - Step 5: Vorschau & Speichern
    private var previewStep: some View {
        Form {
            Section {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 60))
                        .foregroundColor(Color.accentGold)
                    Text(T("Fast geschafft!"))
                        .font(TDTypography.title2)
                    Text(T("Überprüfe deine Anzeige"))
                        .font(TDTypography.caption1)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
            }
            .listRowBackground(Color.clear)
            
            Section(T("Vorschau")) {
                VStack(alignment: .leading, spacing: 12) {
                    // Header
                    HStack {
                        Circle()
                            .fill(Color.accentGold.opacity(0.2))
                            .frame(width: 60, height: 60)
                            .overlay(
                                Text(String(displayName.prefix(1)))
                                    .font(.title)
                                    .foregroundColor(Color.accentGold)
                            )
                        
                        VStack(alignment: .leading) {
                            Text(displayName)
                                .font(TDTypography.headline)
                            if !headline.isEmpty {
                                Text(headline)
                                    .font(TDTypography.caption1)
                                    .foregroundColor(.secondary)
                            }
                            HStack {
                                if let ageInt = Int(age) {
                                    Text(T("%@ Jahre", "\(ageInt)"))
                                }
                                if let heightInt = Int(height) {
                                    Text("• \(heightInt) " + T("cm"))
                                }
                                Text("• " + city)
                            }
                            .font(TDTypography.caption2)
                            .foregroundColor(.secondary)
                        }
                    }
                    
                    Divider()
                    
                    // Tanzstile
                    if !selectedStyles.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(Array(selectedStyles), id: \.self) { style in
                                    Text(T(style.rawValue))
                                        .font(TDTypography.caption2)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.accentGold.opacity(0.1))
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }
                    
                    // Details
                    HStack {
                        Label(skillLevel.rawValue, systemImage: "star.fill")
                        Spacer()
                        Label(lookingForType.rawValue, systemImage: "person.2")
                    }
                    .font(TDTypography.caption1)
                    .foregroundColor(.secondary)
                    
                    if !bio.isEmpty {
                        Text(bio)
                            .font(TDTypography.body)
                            .lineLimit(3)
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(TDRadius.md)
            }
            
            Section {
                Toggle("Anzeige sichtbar schalten", isOn: $isVisible)
            } footer: {
                Text(T("Nur wenn sichtbar, können andere dich finden und kontaktieren"))
            }
            
            Section {
                HStack {
                    backStepButton(step: 3)
                    
                    Button {
                        saveProfile()
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text(T("Anzeige veröffentlichen"))
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
        }
        .alert(T("Fehler"), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }
    
    // MARK: - Helper Views
    private func nextStepButton(step: Int) -> some View {
        Button {
            withAnimation { currentStep = step }
        } label: {
            HStack {
                Text(T("Weiter"))
                Image(systemName: "arrow.right")
            }
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.accentGold)
            .cornerRadius(TDRadius.md)
        }
    }
    
    private func backStepButton(step: Int) -> some View {
        Button {
            withAnimation { currentStep = step }
        } label: {
            HStack {
                Image(systemName: "arrow.left")
                Text(T("Zurück"))
            }
            .fontWeight(.medium)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(TDRadius.md)
        }
    }
    
    // MARK: - Load Existing Profile
    private func loadExistingProfile() {
        if let existing = matchingManager.myProfile {
            displayName = existing.displayName
            headline = existing.headline
            age = existing.age.map { String($0) } ?? ""
            height = existing.height.map { String($0) } ?? ""
            gender = existing.gender ?? .other
            lookingFor = existing.lookingForGender ?? .any
            selectedStyles = Set(existing.danceStyles)
            skillLevel = existing.skillLevel
            danceExperienceYears = existing.danceExperienceYears.map { String($0) } ?? ""
            lookingForType = existing.lookingForType
            availableForEvents = existing.availableForEvents
            hasOwnStudio = existing.hasOwnStudio
            preferredDays = Set(existing.preferredDays)
            preferredTimes = Set(existing.preferredTimes)
            contactPreference = existing.contactPreference
            instagramHandle = existing.instagramHandle ?? ""
            phoneNumber = existing.phoneNumber ?? ""
            bio = existing.bio
            city = existing.city
            searchRadius = existing.searchRadius ?? 50
            photoURLs = existing.photoURLs
            videoURLs = existing.videoURLs
            isVisible = existing.isVisible
        } else if let user = userManager.currentUser {
            displayName = user.name
        }
    }
    
    // MARK: - Save Profile
    private func saveProfile() {
        guard let user = userManager.currentUser else { return }
        guard !displayName.isEmpty && !city.isEmpty else {
            errorMessage = "Bitte fülle alle Pflichtfelder aus (Name, Stadt)"
            return
        }

        let now = Date()
        let normalizedCity = city.lowercased().trimmingCharacters(in: .whitespaces)
        let createdAt = matchingManager.myProfile?.createdAt ?? now
        
        let profile = PartnerProfile(
            id: user.id,
            userId: user.id,
            displayName: displayName,
            age: Int(age),
            gender: gender,
            lookingForGender: lookingFor,
            danceStyles: Array(selectedStyles),
            skillLevel: skillLevel,
            bio: bio,
            city: city,
            cityLowercased: normalizedCity,
            isVisible: isVisible,
            lastActive: now,
            profileImageURL: photoURLs.first ?? user.profileImageURL,
            createdAt: createdAt,
            updatedAt: now,
            photoURLs: photoURLs,
            videoURLs: videoURLs,
            height: Int(height),
            danceExperienceYears: Int(danceExperienceYears),
            preferredDays: Array(preferredDays),
            preferredTimes: Array(preferredTimes),
            searchRadius: searchRadius,
            contactPreference: contactPreference,
            instagramHandle: instagramHandle.isEmpty ? nil : instagramHandle,
            phoneNumber: phoneNumber.isEmpty ? nil : phoneNumber,
            lookingForType: lookingForType,
            availableForEvents: availableForEvents,
            hasOwnStudio: hasOwnStudio,
            headline: headline
        )

        Task {
            let success = await matchingManager.createOrUpdateProfile(profile)
            if success {
                dismiss()
            } else {
                errorMessage = matchingManager.errorMessage ?? "Profil konnte nicht gespeichert werden"
            }
        }
    }
}

// MARK: - Partner Chat
struct PartnerChatView: View {
    let match: PartnerMatchSummary
    @StateObject private var matchingManager = PartnerMatchingManager.shared
    @StateObject private var userManager = UserManager.shared
    @State private var message = ""

    private var messages: [PartnerMessage] {
        matchingManager.messages[match.id] ?? []
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: TDSpacing.sm) {
                        ForEach(messages) { msg in
                            PartnerMessageBubble(message: msg, isMine: msg.senderId == userManager.currentUser?.id)
                                .id(msg.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _, _ in
                    if let last = messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            HStack(spacing: TDSpacing.sm) {
                TextField(T("Nachricht..."), text: $message)
                    .textFieldStyle(.roundedBorder)

                Button {
                    Task {
                        let text = message.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !text.isEmpty else { return }
                        if await matchingManager.sendMessage(matchId: match.id, content: text) {
                            message = ""
                        }
                    }
                } label: {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(Color.accentGold)
                }
                .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
        .navigationTitle(match.partner.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await matchingManager.loadMessages(matchId: match.id)
            matchingManager.startListeningForMessages(matchId: match.id)
            await matchingManager.markMessagesAsRead(matchId: match.id)
        }
        .onDisappear {
            matchingManager.stopListeningForMessages(matchId: match.id)
        }
    }
}

struct PartnerMessageBubble: View {
    let message: PartnerMessage
    let isMine: Bool

    var body: some View {
        VStack(alignment: isMine ? .trailing : .leading, spacing: 4) {
            Text(message.content)
                .padding(10)
                .background(isMine ? Color.accentGold.opacity(0.2) : Color.gray.opacity(0.1))
                .cornerRadius(10)

            Text(message.createdAt.formatted(date: .omitted, time: .shortened))
                .font(TDTypography.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: isMine ? .trailing : .leading)
    }
}

// MARK: - Report Sheet
struct PartnerReportSheet: View {
    let reportedUserId: String
    @Environment(\.dismiss) var dismiss
    @StateObject private var matchingManager = PartnerMatchingManager.shared
    @State private var reason = ""
    @State private var details = ""

    var body: some View {
        NavigationStack {
            Form {
                Section(T("Grund")) {
                    TextField(T("z.B. Unangemessenes Verhalten"), text: $reason)
                }
                Section(T("Details")) {
                    TextEditor(text: $details)
                        .frame(minHeight: 120)
                }
                Section {
                    Button(T("Melden")) {
                        Task {
                            _ = await matchingManager.reportUser(reportedUserId: reportedUserId, reason: reason, details: details)
                            dismiss()
                        }
                    }
                    .disabled(reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle(T("Profil melden"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(T("Abbrechen")) { dismiss() }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        PartnerMatchingView()
    }
}

// MARK: - Partner Filter Chip
struct PartnerFilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(TDTypography.caption1)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.accentGold : Color.gray.opacity(0.1))
                )
        }
    }
}
