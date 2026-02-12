//
//  FeedbackViews.swift
//  Tanzen mit Tatiana Drexler
//
//  Views für das User-Feedback System
//

import SwiftUI

// MARK: - User Feedback Form
struct UserFeedbackView: View {
    @StateObject private var feedbackManager = FeedbackManager.shared
    @StateObject private var userManager = UserManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedType: FeedbackType = .improvement
    @State private var selectedCategory: FeedbackCategory = .app
    @State private var rating: Int = 0
    @State private var title: String = ""
    @State private var message: String = ""
    @State private var isSubmitting = false
    @State private var showSuccess = false
    @State private var showMyFeedbacks = false
    
    var body: some View {
        NavigationStack {
            Form {
                // Feedback-Typ
                Section {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 12) {
                        ForEach(FeedbackType.allCases, id: \.self) { type in
                            FeedbackTypeButton(
                                type: type,
                                isSelected: selectedType == type
                            ) {
                                selectedType = type
                            }
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text(T("Art des Feedbacks"))
                }
                
                // Kategorie
                Section {
                    Picker("Bereich", selection: $selectedCategory) {
                        ForEach(FeedbackCategory.allCases, id: \.self) { cat in
                            Text(cat.displayName).tag(cat)
                        }
                    }
                } header: {
                    Text(T("Kategorie"))
                }
                
                // Bewertung (optional)
                if selectedType == .praise || selectedType == .complaint {
                    Section {
                        HStack {
                            Text(T("Bewertung"))
                            Spacer()
                            HStack(spacing: 4) {
                                ForEach(1...5, id: \.self) { star in
                                    Image(systemName: star <= rating ? "star.fill" : "star")
                                        .foregroundColor(star <= rating ? .yellow : .gray)
                                        .onTapGesture {
                                            rating = star
                                        }
                                }
                            }
                        }
                    }
                }
                
                // Titel und Nachricht
                Section {
                    TextField(T("Kurzer Titel"), text: $title)
                    
                    ZStack(alignment: .topLeading) {
                        if message.isEmpty {
                            Text(T("Beschreibe dein Anliegen ausführlich..."))
                                .foregroundColor(.secondary)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                        }
                        TextEditor(text: $message)
                            .frame(minHeight: 150)
                    }
                } header: {
                    Text(T("Dein Feedback"))
                }
                
                // Info
                Section {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        Text(T("Dein Feedback hilft uns, die App zu verbessern. Wir lesen jede Nachricht!"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Senden Button
                Section {
                    Button {
                        Task { await submitFeedback() }
                    } label: {
                        HStack {
                            Spacer()
                            if isSubmitting {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(T("Feedback senden"))
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(title.isEmpty || message.isEmpty || isSubmitting)
                    .listRowBackground(title.isEmpty || message.isEmpty ? Color.gray : Color.accentGold)
                    .foregroundColor(.white)
                }
            }
            .navigationTitle(T("Feedback"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(T("Abbrechen")) { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showMyFeedbacks = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                }
            }
            .alert(T("Feedback gesendet!"), isPresented: $showSuccess) {
                Button(T("OK")) { dismiss() }
            } message: {
                Text(T("Vielen Dank für dein Feedback! Wir werden es so schnell wie möglich prüfen."))
            }
            .sheet(isPresented: $showMyFeedbacks) {
                MyFeedbacksView()
            }
        }
    }
    
    private func submitFeedback() async {
        isSubmitting = true
        defer { isSubmitting = false }
        
        let success = await feedbackManager.submitFeedback(
            type: selectedType,
            rating: rating > 0 ? rating : nil,
            title: title,
            message: message,
            category: selectedCategory
        )
        
        if success {
            showSuccess = true
        }
    }
}

// MARK: - Feedback Type Button
struct FeedbackTypeButton: View {
    let type: FeedbackType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: type.icon)
                    .font(.title2)
                Text(type.displayName)
                    .font(.caption2)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? typeColor.opacity(0.2) : Color(.systemGray6))
            .foregroundColor(isSelected ? typeColor : .primary)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? typeColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var typeColor: Color {
        switch type.color {
        case "red": return .red
        case "purple": return .purple
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "teal": return .teal
        default: return .gray
        }
    }
}

// MARK: - My Feedbacks View (User)
struct MyFeedbacksView: View {
    @StateObject private var feedbackManager = FeedbackManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                if feedbackManager.myFeedbacks.isEmpty {
                    ContentUnavailableView(
                        "Noch kein Feedback",
                        systemImage: "bubble.left.and.bubble.right",
                        description: Text(T("Du hast noch kein Feedback gesendet"))
                    )
                } else {
                    ForEach(feedbackManager.myFeedbacks) { feedback in
                        MyFeedbackRow(feedback: feedback)
                    }
                }
            }
            .navigationTitle(T("Mein Feedback"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(T("Fertig")) { dismiss() }
                }
            }
            .task {
                await feedbackManager.loadMyFeedbacks()
            }
        }
    }
}

struct MyFeedbackRow: View {
    let feedback: UserFeedback
    @State private var showDetail = false
    
    var body: some View {
        Button {
            showDetail = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: feedback.type.icon)
                    .foregroundColor(typeColor)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(feedback.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(feedback.createdAt, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(feedback.status.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.2))
                    .foregroundColor(statusColor)
                    .cornerRadius(8)
            }
        }
        .sheet(isPresented: $showDetail) {
            FeedbackDetailView(feedback: feedback, isAdmin: false)
        }
    }
    
    private var typeColor: Color {
        switch feedback.type.color {
        case "red": return .red
        case "purple": return .purple
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "teal": return .teal
        default: return .gray
        }
    }
    
    private var statusColor: Color {
        switch feedback.status.color {
        case "blue": return .blue
        case "orange": return .orange
        case "purple": return .purple
        case "green": return .green
        default: return .gray
        }
    }
}

// MARK: - Feedback Detail View
struct FeedbackDetailView: View {
    let feedback: UserFeedback
    let isAdmin: Bool
    
    @StateObject private var feedbackManager = FeedbackManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var adminResponse: String = ""
    @State private var selectedStatus: FeedbackStatus
    @State private var isSaving = false
    
    init(feedback: UserFeedback, isAdmin: Bool) {
        self.feedback = feedback
        self.isAdmin = isAdmin
        _selectedStatus = State(initialValue: feedback.status)
        _adminResponse = State(initialValue: feedback.adminResponse ?? "")
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Header
                Section {
                    HStack {
                        Image(systemName: feedback.type.icon)
                            .font(.title)
                            .foregroundColor(typeColor)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(feedback.title)
                                .font(.headline)
                            Text(feedback.type.displayName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // User Info (Admin only)
                if isAdmin {
                    Section(T("Benutzer")) {
                        LabeledContent("Name", value: feedback.userName)
                        LabeledContent("E-Mail", value: feedback.userEmail)
                        LabeledContent("Gesendet", value: feedback.createdAt.formatted())
                    }
                }
                
                // Details
                Section(T("Details")) {
                    LabeledContent("Kategorie", value: feedback.category.displayName)
                    if let rating = feedback.rating {
                        HStack {
                            Text(T("Bewertung"))
                            Spacer()
                            HStack(spacing: 2) {
                                ForEach(1...5, id: \.self) { star in
                                    Image(systemName: star <= rating ? "star.fill" : "star")
                                        .foregroundColor(star <= rating ? .yellow : .gray)
                                        .font(.caption)
                                }
                            }
                        }
                    }
                    LabeledContent("App-Version", value: feedback.appVersion)
                    LabeledContent("Gerät", value: feedback.deviceInfo)
                }
                
                // Message
                Section(T("Nachricht")) {
                    Text(feedback.message)
                        .font(.body)
                }
                
                // Admin Response
                if let response = feedback.adminResponse, !response.isEmpty {
                    Section(T("Antwort vom Team")) {
                        Text(response)
                            .font(.body)
                        if let respondedAt = feedback.adminRespondedAt {
                            Text(respondedAt, style: .date)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Admin Actions
                if isAdmin {
                    Section(T("Status")) {
                        Picker("Status", selection: $selectedStatus) {
                            ForEach(FeedbackStatus.allCases, id: \.self) { status in
                                Text(status.displayName).tag(status)
                            }
                        }
                    }
                    
                    Section(T("Antworten")) {
                        TextEditor(text: $adminResponse)
                            .frame(minHeight: 100)
                        
                        Button {
                            Task { await respond() }
                        } label: {
                            HStack {
                                Spacer()
                                if isSaving {
                                    ProgressView()
                                } else {
                                    Text(T("Antwort senden"))
                                }
                                Spacer()
                            }
                        }
                        .disabled(adminResponse.isEmpty || isSaving)
                    }
                }
            }
            .navigationTitle(T("Feedback-Details"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(T("Fertig")) { dismiss() }
                }
            }
            .onChange(of: selectedStatus) { _, newValue in
                Task {
                    _ = await feedbackManager.updateStatus(feedbackId: feedback.id, status: newValue)
                }
            }
        }
    }
    
    private func respond() async {
        isSaving = true
        defer { isSaving = false }
        
        _ = await feedbackManager.respondToFeedback(feedbackId: feedback.id, response: adminResponse)
        dismiss()
    }
    
    private var typeColor: Color {
        switch feedback.type.color {
        case "red": return .red
        case "purple": return .purple
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "teal": return .teal
        default: return .gray
        }
    }
}

// MARK: - Admin Feedback Dashboard View
struct AdminFeedbackView: View {
    @StateObject private var feedbackManager = FeedbackManager.shared
    @State private var selectedStatus: FeedbackStatus?
    @State private var selectedType: FeedbackType?
    @State private var searchText = ""
    
    private var filteredFeedbacks: [UserFeedback] {
        var result = feedbackManager.feedbacks
        
        if let status = selectedStatus {
            result = result.filter { $0.status == status }
        }
        
        if let type = selectedType {
            result = result.filter { $0.type == type }
        }
        
        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.message.localizedCaseInsensitiveContains(searchText) ||
                $0.userName.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return result
    }
    
    var body: some View {
        List {
            // Statistiken
            Section {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    FeedbackStatCard(title: "Gesamt", value: "\(feedbackManager.statistics.totalCount)", color: .blue)
                    FeedbackStatCard(title: "Neu", value: "\(feedbackManager.statistics.newCount)", color: .orange)
                    FeedbackStatCard(title: "In Bearbeitung", value: "\(feedbackManager.statistics.inReviewCount)", color: .purple)
                    FeedbackStatCard(title: "Beantwortet", value: "\(feedbackManager.statistics.respondedCount)", color: .green)
                }
            }
            
            // Filter
            Section(T("Filter")) {
                Picker("Status", selection: $selectedStatus) {
                    Text(T("Alle")).tag(nil as FeedbackStatus?)
                    ForEach(FeedbackStatus.allCases, id: \.self) { status in
                        Text(status.displayName).tag(status as FeedbackStatus?)
                    }
                }
                
                Picker("Typ", selection: $selectedType) {
                    Text(T("Alle")).tag(nil as FeedbackType?)
                    ForEach(FeedbackType.allCases, id: \.self) { type in
                        Label(type.displayName, systemImage: type.icon).tag(type as FeedbackType?)
                    }
                }
            }
            
            // Feedback Liste
            Section(T("Feedbacks (%@)", "\(filteredFeedbacks.count)")) {
                if filteredFeedbacks.isEmpty {
                    ContentUnavailableView(
                        "Kein Feedback",
                        systemImage: "bubble.left.and.bubble.right",
                        description: Text(T("Keine Feedbacks gefunden"))
                    )
                } else {
                    ForEach(filteredFeedbacks) { feedback in
                        AdminFeedbackRow(feedback: feedback)
                    }
                    .onDelete { indexSet in
                        Task {
                            for index in indexSet {
                                _ = await feedbackManager.deleteFeedback(feedbackId: filteredFeedbacks[index].id)
                            }
                        }
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Suchen...")
        .navigationTitle(T("User-Feedback"))
        .refreshable {
            await feedbackManager.loadAllFeedbacks()
        }
        .task {
            await feedbackManager.loadAllFeedbacks()
            feedbackManager.startListeningToFeedbacks()
        }
        .onDisappear {
            feedbackManager.stopListening()
        }
    }
}

struct FeedbackStatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

struct AdminFeedbackRow: View {
    let feedback: UserFeedback
    @State private var showDetail = false
    
    var body: some View {
        Button {
            showDetail = true
        } label: {
            HStack(spacing: 12) {
                // Status Indicator
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                
                // Type Icon
                Image(systemName: feedback.type.icon)
                    .foregroundColor(typeColor)
                    .frame(width: 24)
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(feedback.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    HStack {
                        Text(feedback.userName)
                            .font(.caption)
                        Text(T("•"))
                        Text(feedback.createdAt, style: .relative)
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Status Badge
                Text(feedback.status.displayName)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(statusColor.opacity(0.2))
                    .foregroundColor(statusColor)
                    .cornerRadius(6)
            }
        }
        .sheet(isPresented: $showDetail) {
            FeedbackDetailView(feedback: feedback, isAdmin: true)
        }
    }
    
    private var typeColor: Color {
        switch feedback.type.color {
        case "red": return .red
        case "purple": return .purple
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "teal": return .teal
        default: return .gray
        }
    }
    
    private var statusColor: Color {
        switch feedback.status.color {
        case "blue": return .blue
        case "orange": return .orange
        case "purple": return .purple
        case "green": return .green
        default: return .gray
        }
    }
}

#Preview {
    UserFeedbackView()
}
