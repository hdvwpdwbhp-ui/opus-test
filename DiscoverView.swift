//
//  DiscoverView.swift
//  Tanzen mit Tatiana Drexler
//
//  Course Catalog / Discover View mit Trainer und Kursen
//

import SwiftUI

struct DiscoverView: View {
    @EnvironmentObject var courseViewModel: CourseViewModel
    @EnvironmentObject var storeViewModel: StoreViewModel
    @StateObject private var userManager = UserManager.shared
    @StateObject private var settingsManager = AppSettingsManager.shared
    @StateObject private var lessonManager = PrivateLessonManager.shared
    @StateObject private var courseDataManager = CourseDataManager.shared
    @State private var showFilter = false
    @State private var searchText = ""
    @State private var selectedTrainerId: String?
    @State private var expandedTrainerId: String?
    @State private var showBookingSheet = false
    @State private var bookingTrainerId: String?
    @State private var showTrainingPlanSheet = false
    @State private var trainingPlanTrainerId: String?
    
    var trainers: [AppUser] {
        userManager.allUsers.filter { $0.group == .trainer }
    }
    
    var displayedCourses: [Course] {
        // Direkt vom CourseDataManager lesen für sofortige Updates
        var courses = courseDataManager.courses.filter { course in
            courseViewModel.filter.matches(course: course, isPurchased: userManager.hasCourseUnlocked(course.id))
        }
        if let trainerId = selectedTrainerId {
            let assignedIds = trainers.first { $0.id == trainerId }?.trainerProfile?.assignedCourseIds ?? []
            courses = courses.filter { $0.trainerId == trainerId || assignedIds.contains($0.id) }
        }
        return courses
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                TDGradients.mainBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: TDSpacing.lg) {
                        heroSection
                        
                        NavigationLink {
                            LiveClassesListView()
                        } label: {
                            HStack {
                                Image(systemName: "dot.radiowaves.left.and.right")
                                    .foregroundColor(Color.accentGold)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(T("Livestream-Gruppenstunden"))
                                        .font(TDTypography.headline)
                                    Text(T("Mit Coins buchen und live mitmachen"))
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
 
                        if !trainers.isEmpty {
                            trainerSection
                        }
                        
                        if courseViewModel.filter.isActive || selectedTrainerId != nil {
                            activeFiltersSection
                        }
                        
                        if courseViewModel.isLoading {
                            loadingView
                        } else {
                            coursesSection
                        }
                    }
                    .padding(.horizontal, TDSpacing.md)
                    .padding(.bottom, TDSpacing.xxl)
                }
            }
            .navigationTitle(T("Entdecken"))
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Kurse suchen...")
            .onChange(of: searchText) { _, newValue in
                courseViewModel.filter.searchText = newValue
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showFilter = true } label: {
                        HStack(spacing: 4) {
                            Image(systemName: courseViewModel.filter.isActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                            if courseViewModel.filter.isActive {
                                Text(T("Filter"))
                                    .font(TDTypography.caption2)
                            }
                        }
                        .foregroundColor(Color.accentGold)
                    }
                }
            }
            .sheet(isPresented: $showFilter) { FilterView() }
            .sheet(isPresented: $showBookingSheet) {
                if let trainerId = bookingTrainerId {
                    BookingFormView(trainerId: trainerId)
                }
            }
            .sheet(isPresented: $showTrainingPlanSheet) {
                if let trainerId = trainingPlanTrainerId,
                   let trainer = trainers.first(where: { $0.id == trainerId }) {
                    // Verwende vorhandene Settings oder erstelle Default-Settings
                    let settings = TrainingPlanManager.shared.trainerSettings[trainerId] ?? TrainerPlanSettings()
                    TrainingPlanOrderFormSimple()
                } else {
                    // Fallback wenn Trainer nicht gefunden wird
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text(T("Trainer nicht verfügbar"))
                            .font(.headline)
                        Text(T("Bitte versuche es später erneut"))
                            .foregroundColor(.secondary)
                        Button(T("Schließen")) {
                            showTrainingPlanSheet = false
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
            }
            .onAppear {
                // Lade Kurse neu wenn die View erscheint
                courseViewModel.reloadCourses()
            }
        }
    }
    
    // MARK: - Hero Section
    private var heroSection: some View {
        VStack(alignment: .leading, spacing: TDSpacing.sm) {
            Text(T("Lerne Tanzen"))
                .font(TDTypography.largeTitle)
                .foregroundColor(.primary)
            
            Text(T("mit unseren Trainern"))
                .font(TDTypography.title2)
                .foregroundColor(Color.accentGold)
            
            Text("\(courseDataManager.courses.count) Kurse • \(trainers.count) Trainer")
                .font(TDTypography.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, TDSpacing.md)
    }
    
    // MARK: - Trainer Section (mit direkten Kursen und Privatstunden)
    private var trainerSection: some View {
        VStack(alignment: .leading, spacing: TDSpacing.md) {
            Text(T("Unsere Trainer"))
                .font(TDTypography.headline)
                .foregroundColor(.secondary)
            
            ForEach(trainers) { trainer in
                TrainerCard(
                    trainer: trainer,
                    isExpanded: expandedTrainerId == trainer.id,
                    isSelected: selectedTrainerId == trainer.id,
                    onToggleExpand: {
                        withAnimation(.spring(response: 0.3)) {
                            if expandedTrainerId == trainer.id {
                                expandedTrainerId = nil
                            } else {
                                expandedTrainerId = trainer.id
                            }
                        }
                    },
                    onFilterCourses: {
                        if selectedTrainerId == trainer.id {
                            selectedTrainerId = nil
                        } else {
                            selectedTrainerId = trainer.id
                        }
                    },
                    onBookPrivateLesson: {
                        bookingTrainerId = trainer.id
                        showBookingSheet = true
                    },
                    onOrderTrainingPlan: {
                        trainingPlanTrainerId = trainer.id
                        showTrainingPlanSheet = true
                    }
                )
            }
        }
    }
    
    // MARK: - Active Filters
    private var activeFiltersSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: TDSpacing.xs) {
                if let trainerId = selectedTrainerId,
                   let trainer = trainers.first(where: { $0.id == trainerId }) {
                    FilterChip(title: "Trainer: \(trainer.name)") { selectedTrainerId = nil }
                }
                
                ForEach(Array(courseViewModel.filter.levels), id: \.self) { level in
                    FilterChip(title: level.rawValue) { courseViewModel.toggleLevelFilter(level) }
                }
                
                ForEach(Array(courseViewModel.filter.styles), id: \.self) { style in
                    FilterChip(title: style.rawValue) { courseViewModel.toggleStyleFilter(style) }
                }
                
                if courseViewModel.filter.isActive || selectedTrainerId != nil {
                    Button(T("Alle löschen")) {
                        courseViewModel.clearFilters()
                        selectedTrainerId = nil
                    }
                    .font(TDTypography.caption1)
                    .foregroundColor(Color.accentGold)
                }
            }
        }
    }
    
    // MARK: - Courses Section
    private var coursesSection: some View {
        LazyVStack(spacing: TDSpacing.md) {
            ForEach(displayedCourses) { course in
                NavigationLink(destination: CourseDetailView(course: course)) {
                    CourseCardEnhanced(course: course)
                }
                .buttonStyle(.plain)
                .id("\(course.id)_\(course.language.rawValue)_\(course.updatedAt.timeIntervalSince1970)")
            }
            
            if displayedCourses.isEmpty {
                ContentUnavailableView("Keine Kurse gefunden", systemImage: "magnifyingglass", description: Text(T("Versuche andere Filter")))
                    .padding(.top, TDSpacing.xxl)
            }
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: TDSpacing.md) {
            ForEach(0..<3, id: \.self) { _ in SkeletonCourseCard() }
        }
    }
}

// MARK: - Trainer Card
struct TrainerCard: View {
    let trainer: AppUser
    let isExpanded: Bool
    let isSelected: Bool
    let onToggleExpand: () -> Void
    let onFilterCourses: () -> Void
    let onBookPrivateLesson: () -> Void
    var onOrderTrainingPlan: (() -> Void)? = nil
    
    @StateObject private var lessonManager = PrivateLessonManager.shared
    @StateObject private var planManager = TrainingPlanManager.shared
    
    var hasPrivateLessons: Bool {
        lessonManager.trainerSettings[trainer.id]?.isEnabled == true
    }
    
    var hasTrainingPlans: Bool {
        planManager.trainerSettings[trainer.id]?.offersTrainingPlans == true
    }
    
    var assignedCourses: [Course] {
        let assignedIds = trainer.trainerProfile?.assignedCourseIds ?? []
        let courses = CourseDataManager.shared.courses.isEmpty ? MockData.courses : CourseDataManager.shared.courses
        return courses.filter { $0.trainerId == trainer.id || assignedIds.contains($0.id) }
    }
    
    var availableSlots: [TrainerTimeSlot] {
        lessonManager.availableSlotsForTrainer(trainer.id).prefix(3).map { $0 }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header (immer sichtbar)
            HStack(spacing: TDSpacing.md) {
                NavigationLink(destination: TrainerProfileView(trainer: trainer)) {
                    HStack(spacing: TDSpacing.md) {
                        // Avatar
                        ZStack {
                            Circle()
                                .fill(Color.accentGold.opacity(0.2))
                                .frame(width: 56, height: 56)

                            if let imageURL = trainer.profileImageURL, !imageURL.isEmpty {
                                AsyncImage(url: URL(string: imageURL)) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    Image(systemName: "person.fill").font(.title2).foregroundColor(Color.accentGold)
                                }
                                .frame(width: 56, height: 56)
                                .clipShape(Circle())
                            } else {
                                Image(systemName: "person.fill").font(.title2).foregroundColor(Color.accentGold)
                            }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(trainer.name)
                                .font(TDTypography.headline)
                                .foregroundColor(.primary)

                            HStack(spacing: 8) {
                                Label("\(assignedCourses.count) Kurse", systemImage: "book.fill")
                                    .font(TDTypography.caption1)
                                    .foregroundColor(.secondary)

                                if hasPrivateLessons {
                                    Label(T("Privatstunden"), systemImage: "video.fill")
                                        .font(TDTypography.caption1)
                                        .foregroundColor(.green)
                                }

                                if hasTrainingPlans {
                                    Label(T("Trainingspläne"), systemImage: "doc.text.fill")
                                        .font(TDTypography.caption1)
                                        .foregroundColor(.purple)
                                }
                            }
                        }
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: onToggleExpand) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
            .padding(TDSpacing.md)
            
            // Expanded Content
            if isExpanded {
                VStack(spacing: TDSpacing.md) {
                    Divider()
                    
                    // Bio
                    if let bio = trainer.trainerProfile?.bio, !bio.isEmpty {
                        Text(bio)
                            .font(TDTypography.body)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, TDSpacing.md)
                    }
                    
                    // Spezialisierungen
                    if let specialties = trainer.trainerProfile?.specialties, !specialties.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(specialties, id: \.self) { s in
                                    Text(s)
                                        .font(TDTypography.caption1)
                                        .foregroundColor(Color.accentGold)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(Color.accentGold.opacity(0.15))
                                        .cornerRadius(12)
                                }
                            }
                            .padding(.horizontal, TDSpacing.md)
                        }
                    }
                    
                    // Privatstunden Button
                    if hasPrivateLessons {
                        VStack(alignment: .leading, spacing: 8) {
                            if !availableSlots.isEmpty {
                                Text(T("Nächste freie Termine:"))
                                    .font(TDTypography.caption1)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, TDSpacing.md)
                                
                                ForEach(availableSlots) { slot in
                                    HStack {
                                        Image(systemName: "calendar")
                                            .foregroundColor(.green)
                                        Text(slot.date.formatted(date: .abbreviated, time: .shortened))
                                            .font(TDTypography.subheadline)
                                        Spacer()
                                        Text("\(slot.duration) Min")
                                            .font(TDTypography.caption1)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, TDSpacing.md)
                                }
                            }
                            
                            Button(action: onBookPrivateLesson) {
                                HStack {
                                    Image(systemName: "video.badge.plus")
                                    Text(T("Video-Privatstunde buchen"))
                                }
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(TDRadius.md)
                            }
                            .padding(.horizontal, TDSpacing.md)
                        }
                    }
                    
                    // Trainingsplan Button
                    if hasTrainingPlans, let onOrder = onOrderTrainingPlan {
                        Button(action: onOrder) {
                            HStack {
                                Image(systemName: "doc.text.badge.plus")
                                Text(T("Persönlichen Trainingsplan bestellen"))
                            }
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.purple)
                            .foregroundColor(.white)
                            .cornerRadius(TDRadius.md)
                        }
                        .padding(.horizontal, TDSpacing.md)
                    }
                    
                    // Kurse des Trainers
                    if !assignedCourses.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(T("Kurse von %@", trainer.name.components(separatedBy: " ").first ?? trainer.name))
                                    .font(TDTypography.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Button {
                                    onFilterCourses()
                                } label: {
                                    Text(isSelected ? "Filter entfernen" : "Alle anzeigen")
                                        .font(TDTypography.caption1)
                                        .foregroundColor(Color.accentGold)
                                }
                            }
                            .padding(.horizontal, TDSpacing.md)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: TDSpacing.sm) {
                                    ForEach(assignedCourses.prefix(4)) { course in
                                        NavigationLink(destination: CourseDetailView(course: course)) {
                                            MiniCourseCard(course: course)
                                        }
                                    }
                                }
                                .padding(.horizontal, TDSpacing.md)
                            }
                        }
                    }
                }
                .padding(.bottom, TDSpacing.md)
            }
        }
        .background(Color.gray.opacity(0.08))
        .cornerRadius(TDRadius.lg)
    }
}

// MARK: - Trainer Profile View
struct TrainerProfileView: View {
    let trainer: AppUser
    @StateObject private var lessonManager = PrivateLessonManager.shared
    @StateObject private var planManager = TrainingPlanManager.shared
    @StateObject private var courseDataManager = CourseDataManager.shared
    @StateObject private var trainerChatManager = TrainerChatManager.shared
    @StateObject private var userManager = UserManager.shared
    @State private var showBookingSheet = false
    @State private var showTrainingPlanSheet = false
    @State private var showIntroVideo = false
    @State private var showTrainerChat = false
    @State private var showChatError = false
    @State private var showLoginRequired = false
    @State private var activeConversation: TrainerChatConversation?

    private var assignedCourses: [Course] {
        let assignedIds = trainer.trainerProfile?.assignedCourseIds ?? []
        let courses = courseDataManager.courses.isEmpty ? MockData.courses : courseDataManager.courses
        return courses.filter { $0.trainerId == trainer.id || assignedIds.contains($0.id) }
    }

    private var hasPrivateLessons: Bool {
        lessonManager.trainerSettings[trainer.id]?.isEnabled == true
    }

    private var hasTrainingPlans: Bool {
        planManager.trainerSettings[trainer.id]?.offersTrainingPlans == true
    }

    private var availableSlots: [TrainerTimeSlot] {
        lessonManager.availableSlotsForTrainer(trainer.id).prefix(5).map { $0 }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: TDSpacing.lg) {
                headerSection
                bioSection
                specialtiesSection
                offeringsSection
                coursesSection
            }
            .padding(TDSpacing.md)
        }
        .navigationTitle(trainer.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showBookingSheet) {
            BookingFormView(trainerId: trainer.id)
        }
        .sheet(isPresented: $showTrainingPlanSheet) {
            if let settings = TrainingPlanManager.shared.trainerSettings[trainer.id] {
                TrainingPlanOrderFormSimple()
            }
        }
        .sheet(isPresented: $showIntroVideo) {
            if let videoURL = trainer.trainerProfile?.introVideoURL,
               let url = URL(string: videoURL) {
                TrainerIntroVideoPlayerView(trainerName: trainer.name, url: url)
            }
        }
        .sheet(isPresented: $showTrainerChat) {
            if let conversation = activeConversation {
                TrainerChatDetailView(conversation: conversation)
            }
        }
        .alert(T("Chat nicht möglich"), isPresented: $showChatError) {
            Button(T("OK"), role: .cancel) {}
        } message: {
            Text(T("Der Chat konnte nicht gestartet werden. Bitte versuche es später erneut."))
        }
        .alert(T("Anmeldung erforderlich"), isPresented: $showLoginRequired) {
            Button(T("OK"), role: .cancel) {}
        } message: {
            Text(T("Bitte melde dich an, um dem Trainer zu schreiben."))
        }
    }

    private var headerSection: some View {
        HStack(spacing: TDSpacing.md) {
            ZStack {
                Circle()
                    .fill(Color.accentGold.opacity(0.2))
                    .frame(width: 72, height: 72)

                if let imageURL = trainer.profileImageURL, !imageURL.isEmpty {
                    AsyncImage(url: URL(string: imageURL)) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Image(systemName: "person.fill").font(.title2).foregroundColor(Color.accentGold)
                    }
                    .frame(width: 72, height: 72)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.fill").font(.title2).foregroundColor(Color.accentGold)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(trainer.name)
                    .font(TDTypography.title2)

                if let specialties = trainer.trainerProfile?.specialties, !specialties.isEmpty {
                    Text(specialties.prefix(3).joined(separator: ", "))
                        .font(TDTypography.caption1)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 8) {
                    if hasPrivateLessons {
                        Label(T("Privatstunden"), systemImage: "video.fill")
                            .font(TDTypography.caption1)
                            .foregroundColor(.green)
                    }
                    if hasTrainingPlans {
                        Label(T("Trainingspläne"), systemImage: "doc.text.fill")
                            .font(TDTypography.caption1)
                            .foregroundColor(.purple)
                    }
                }
            }

            Spacer()
        }
        .padding(TDSpacing.md)
        .glassBackground()
    }

    private var bioSection: some View {
        Group {
            if let bio = trainer.trainerProfile?.bio, !bio.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(T("Über den Trainer"))
                        .font(TDTypography.headline)
                    Text(bio)
                        .font(TDTypography.body)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(TDSpacing.md)
                .glassBackground()
            }
        }
    }

    private var specialtiesSection: some View {
        Group {
            if let specialties = trainer.trainerProfile?.specialties, !specialties.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(T("Spezialisierungen"))
                        .font(TDTypography.headline)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(specialties, id: \.self) { s in
                                Text(s)
                                    .font(TDTypography.caption1)
                                    .foregroundColor(Color.accentGold)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.accentGold.opacity(0.15))
                                    .cornerRadius(12)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(TDSpacing.md)
                .glassBackground()
            }
        }
    }

    private var offeringsSection: some View {
        VStack(alignment: .leading, spacing: TDSpacing.sm) {
            Text(T("Angebote"))
                .font(TDTypography.headline)

            Button {
                Task {
                    guard let user = userManager.currentUser else {
                        showLoginRequired = true
                        return
                    }
                    let convo = await trainerChatManager.getOrCreateConversation(
                        userId: user.id,
                        userName: user.name,
                        trainerId: trainer.id,
                        trainerName: trainer.name
                    )
                    if let convo = convo {
                        activeConversation = convo
                        showTrainerChat = true
                    } else {
                        showChatError = true
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "message.fill")
                    Text(T("Nachricht schreiben"))
                }
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.tdSecondary)

            if hasPrivateLessons {
                VStack(alignment: .leading, spacing: 6) {
                    Text(T("Privatstunden"))
                        .font(TDTypography.subheadline)
                    if !availableSlots.isEmpty {
                        ForEach(availableSlots) { slot in
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundColor(.green)
                                Text(slot.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(TDTypography.caption1)
                                Spacer()
                                Text("\(slot.duration) Min")
                                    .font(TDTypography.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    Button {
                        showBookingSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "video.badge.plus")
                            Text(T("Privatstunde buchen"))
                        }
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.tdPrimary)
                }
                .padding(.bottom, TDSpacing.sm)
            }

            if hasTrainingPlans {
                Button {
                    showTrainingPlanSheet = true
                } label: {
                    HStack {
                        Image(systemName: "doc.text.badge.plus")
                        Text(T("Trainingsplan bestellen"))
                    }
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.tdSecondary)
            }

            if let intro = trainer.trainerProfile?.introVideoURL, !intro.isEmpty {
                Button {
                    showIntroVideo = true
                } label: {
                    HStack {
                        Image(systemName: "play.circle")
                        Text(T("Vorstellungsvideo ansehen"))
                    }
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.tdSecondary)
            }
        }
        .padding(TDSpacing.md)
        .glassBackground()
    }

    private var coursesSection: some View {
        VStack(alignment: .leading, spacing: TDSpacing.sm) {
            Text(T("Kurse"))
                .font(TDTypography.headline)

            if assignedCourses.isEmpty {
                Text(T("Noch keine Kurse"))
                    .font(TDTypography.caption1)
                    .foregroundColor(.secondary)
            } else {
                ForEach(assignedCourses) { course in
                    NavigationLink(destination: CourseDetailView(course: course)) {
                        CourseCardEnhanced(course: course)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(TDSpacing.md)
        .glassBackground()
    }
}

// MARK: - Mini Course Card
struct MiniCourseCard: View {
    let course: Course
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(colors: [Color.accentGold.opacity(0.4), Color.purple.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 100, height: 70)
                
                Image(systemName: course.style.icon)
                    .font(.title)
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Text(course.title)
                .font(TDTypography.caption1)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .lineLimit(2)
            
            HStack(spacing: 2) {
                Text(course.language.flag)
                Text(course.level.rawValue)
            }
            .font(TDTypography.caption2)
            .foregroundColor(.secondary)
        }
        .frame(width: 100)
    }
}

// MARK: - Filter Chip
struct FilterChip: View {
    let title: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(title)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
            }
        }
        .font(TDTypography.caption1)
        .foregroundColor(.white)
        .padding(.horizontal, TDSpacing.sm)
        .padding(.vertical, 6)
        .background(Color.accentGold)
        .cornerRadius(TDRadius.full)
    }
}

// MARK: - Skeleton Course Card
struct SkeletonCourseCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: TDRadius.md)
                .fill(Color.gray.opacity(0.2))
                .frame(height: 140)
            
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 200, height: 20)
            
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 150, height: 16)
        }
        .shimmer()
    }
}

// MARK: - Enhanced Course Card
struct CourseCardEnhanced: View {
    let course: Course
    @StateObject private var settingsManager = AppSettingsManager.shared
    @StateObject private var userManager = UserManager.shared
    @StateObject private var coinManager = CoinManager.shared

    var isFree: Bool { settingsManager.isCourseFree(course.id) }
    var activeSale: CourseSale? { settingsManager.getSaleForCourse(course.id) }
    var coinPriceText: String { "\(coinManager.coinsNeededForCourse(course)) Coins" }

    var trainerName: String? {
        if let name = course.trainerName { return name }
        if let trainerId = course.trainerId,
           let trainer = userManager.allUsers.first(where: { $0.id == trainerId }) {
            return trainer.name
        }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                LinearGradient(colors: [Color.accentGold.opacity(0.6), Color.purple.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .frame(height: 140)
                    .overlay(Image(systemName: course.style.icon).font(.system(size: 50)).foregroundColor(.white.opacity(0.3)))

                VStack(alignment: .trailing, spacing: 4) {
                    if isFree {
                        Text(T("KOSTENLOS"))
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green)
                            .cornerRadius(4)
                    } else if let sale = activeSale, sale.isCurrentlyActive {
                        Text("-\(sale.discountPercent)%")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red)
                            .cornerRadius(4)
                    }
                }
                .padding(8)
            }
            .cornerRadius(TDRadius.md, corners: [.topLeft, .topRight])

            VStack(alignment: .leading, spacing: 6) {
                Text(course.title)
                    .font(TDTypography.headline)
                    .foregroundColor(.primary)
                    .lineLimit(2)

                HStack {
                    Text(course.language.flag)
                    Text(course.language.rawValue)
                    Text(T("•"))
                    Text(course.style.rawValue)
                    Text(T("•"))
                    Text(course.level.rawValue)
                    if let trainer = trainerName {
                        Text(T("•"))
                        Text(trainer)
                    }
                }
                .font(TDTypography.caption1)
                .foregroundColor(.secondary)

                HStack {
                    if isFree {
                        Text(coinPriceText)
                            .font(TDTypography.caption1)
                            .strikethrough()
                            .foregroundColor(.secondary)
                        Text(T("KOSTENLOS"))
                            .font(TDTypography.subheadline)
                            .fontWeight(.black)
                            .foregroundColor(.green)
                    } else if let sale = activeSale, sale.isCurrentlyActive {
                        Text(coinPriceText)
                            .font(TDTypography.caption1)
                            .strikethrough()
                            .foregroundColor(.secondary)
                        Text(formatSaleCoins(originalPrice: course.price, discountPercent: sale.discountPercent))
                            .font(TDTypography.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                    } else {
                        Text(coinPriceText)
                            .font(TDTypography.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(Color.accentGold)
                    }
                    Spacer()
                    Text(T("5% Cashback"))
                        .font(TDTypography.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.accentGold.opacity(0.15))
                        .foregroundColor(Color.accentGold)
                        .cornerRadius(6)
                }
            }
            .padding(TDSpacing.md)
        }
        .background(Color.gray.opacity(0.08))
        .cornerRadius(TDRadius.md)
    }

    private func formatSaleCoins(originalPrice: Decimal, discountPercent: Int) -> String {
        let discount = originalPrice * Decimal(discountPercent) / 100
        let salePrice = originalPrice - discount
        let saleCoins = DanceCoinConfig.coinsForPrice(salePrice)
        return "\(saleCoins) Coins"
    }
}

// Helper für abgerundete Ecken
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

// Shimmer effect
extension View {
    func shimmer() -> some View {
        self.modifier(ShimmerModifier())
    }
}

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(colors: [.clear, .white.opacity(0.3), .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: geo.size.width * 2)
                        .offset(x: -geo.size.width + phase * geo.size.width * 2)
                }
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}
