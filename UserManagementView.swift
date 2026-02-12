//
//  UserManagementView.swift
//  Tanzen mit Tatiana Drexler
//
//  Admin-Ansicht für User-Management mit verbesserter User-Bearbeitung
//

import SwiftUI

struct UserManagementView: View {
    @StateObject private var userManager = UserManager.shared
    @State private var searchText = ""
    @State private var filterGroup: UserGroup?
    @State private var selectedUser: AppUser?
    @State private var showCreateUser = false
    
    var filteredUsers: [AppUser] {
        var users = userManager.allUsers
        if let group = filterGroup {
            users = users.filter { $0.group == group }
        }
        if !searchText.isEmpty {
            users = users.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.username.localizedCaseInsensitiveContains(searchText) ||
                $0.email.localizedCaseInsensitiveContains(searchText)
            }
        }
        return users.sorted { $0.createdAt > $1.createdAt }
    }
    
    var body: some View {
        List {
            // Statistiken
            Section {
                HStack(spacing: TDSpacing.sm) {
                    StatBadge(count: userManager.allUsers.count, title: "Gesamt", color: .blue)
                    StatBadge(count: userManager.allUsers.filter { $0.group == .admin }.count, title: "Admin", color: .red)
                    StatBadge(count: userManager.allUsers.filter { $0.group == .trainer }.count, title: "Trainer", color: .blue)
                    StatBadge(count: userManager.allUsers.filter { $0.group == .premium }.count, title: "Premium", color: .orange)
                }
                .padding(.vertical, 8)
            }
            
            // Filter
            Section {
                Picker("Gruppe", selection: $filterGroup) {
                    Text(T("Alle")).tag(nil as UserGroup?)
                    ForEach(UserGroup.allCases, id: \.self) { group in
                        Label(group.displayName, systemImage: group.icon).tag(group as UserGroup?)
                    }
                }
                .pickerStyle(.menu)
            }
            
            // User Liste
            Section {
                ForEach(filteredUsers) { user in
                    UserRowView(user: user)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedUser = user
                        }
                }
            } header: {
                Text(T("Users (%@)", "\(filteredUsers.count)"))
            }
        }
        .searchable(text: $searchText, prompt: "Suchen...")
        .navigationTitle(T("User-Verwaltung"))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showCreateUser = true } label: {
                    Label(T("User"), systemImage: "person.badge.plus")
                }
            }
        }
        .sheet(item: $selectedUser) { user in
            UserDetailView(user: user)
        }
        .sheet(isPresented: $showCreateUser) {
            CreateUserView()
        }
        .refreshable {
            await userManager.loadFromCloud()
        }
    }
}

// MARK: - User Row
struct UserRowView: View {
    let user: AppUser
    
    var body: some View {
        HStack(spacing: TDSpacing.md) {
            ZStack {
                Circle().fill(groupColor.opacity(0.2)).frame(width: 44, height: 44)
                if let imageURL = user.profileImageURL, !imageURL.isEmpty {
                    AsyncImage(url: URL(string: imageURL)) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Image(systemName: user.group.icon).foregroundColor(groupColor)
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                } else {
                    Image(systemName: user.group.icon).foregroundColor(groupColor)
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(user.name).font(TDTypography.body).fontWeight(.medium)
                    if !user.isActive {
                        Text(T("Deaktiviert")).font(TDTypography.caption2)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.red.opacity(0.2)).foregroundColor(.red).cornerRadius(4)
                    }
                }
                Text("@\(user.username)").font(TDTypography.caption1).foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(user.group.displayName).font(TDTypography.caption1).fontWeight(.medium)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(groupColor.opacity(0.2)).foregroundColor(groupColor).cornerRadius(TDRadius.sm)
        }
    }
    
    private var groupColor: Color {
        switch user.group {
        case .admin: return .red
        case .support: return .purple
        case .trainer: return .blue
        case .premium: return .orange
        case .user: return .gray
        }
    }
}

// MARK: - User Detail View (Fixed with direct user object)
struct UserDetailView: View {
    let user: AppUser
    @StateObject private var userManager = UserManager.shared
    @StateObject private var courseDataManager = CourseDataManager.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedGroup: UserGroup
    @State private var isActive: Bool
    @State private var unlockedCourseIds: Set<String>
    @State private var showDeleteConfirm = false
    @State private var showLoginAsConfirm = false
    @State private var showAssignCourses = false
    @State private var showSendMessage = false
    @State private var isSaving = false
    @State private var showSaveError = false
    @State private var saveErrorMessage = ""
    
    init(user: AppUser) {
        self.user = user
        _selectedGroup = State(initialValue: user.group)
        _isActive = State(initialValue: user.isActive)
        _unlockedCourseIds = State(initialValue: Set(user.unlockedCourseIds ?? []))
    }
    
    // Hole den aktuellsten User aus dem Manager (falls aktualisiert)
    private var currentUser: AppUser {
        userManager.allUsers.first { $0.id == user.id } ?? user
    }
    
    var body: some View {
        NavigationStack {
            userContentView(user: currentUser)
            .navigationTitle(T("User bearbeiten"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(T("Fertig")) { dismiss() }
                }
            }
            .task {
                if courseDataManager.courses.isEmpty {
                    await courseDataManager.loadFromFirebase()
                }
            }
            .alert(T("Account löschen?"), isPresented: $showDeleteConfirm) {
                Button(T("Abbrechen"), role: .cancel) { }
                Button(T("Löschen"), role: .destructive) {
                    Task {
                        _ = await userManager.deleteUser(userId: user.id)
                        dismiss()
                    }
                }
            }
            .alert(T("Als User einloggen?"), isPresented: $showLoginAsConfirm) {
                Button(T("Abbrechen"), role: .cancel) { }
                Button(T("Einloggen")) {
                    Task {
                        _ = await userManager.loginAsUser(userId: user.id)
                        dismiss()
                    }
                }
            } message: {
                Text(T("Du wirst als %@ eingeloggt.", currentUser.name))
            }
            .alert(T("Speichern fehlgeschlagen"), isPresented: $showSaveError) {
                Button(T("OK"), role: .cancel) {}
            } message: {
                Text(saveErrorMessage)
            }
            .sheet(isPresented: $showSendMessage) {
                AdminSendMessageView(user: user)
            }
        }
    }
    
    private func userContentView(user: AppUser) -> some View {
        List {
            // Header
            Section {
                VStack(spacing: TDSpacing.md) {
                    ZStack {
                        Circle().fill(Color.accentGold.opacity(0.2)).frame(width: 80, height: 80)
                        if let imageURL = user.profileImageURL, !imageURL.isEmpty {
                            AsyncImage(url: URL(string: imageURL)) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Image(systemName: selectedGroup.icon).font(.system(size: 36)).foregroundColor(Color.accentGold)
                            }
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                        } else {
                            Image(systemName: selectedGroup.icon).font(.system(size: 36)).foregroundColor(Color.accentGold)
                        }
                    }
                    Text(user.name).font(TDTypography.title2)
                    Text("@\(user.username)").font(TDTypography.subheadline).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity).padding(.vertical)
            }
            
            // Admin Actions
            if user.id != userManager.currentUser?.id {
                Section(T("Admin-Aktionen")) {
                    Button { showLoginAsConfirm = true } label: {
                        HStack {
                            Image(systemName: "person.crop.circle.badge.checkmark").foregroundColor(.blue)
                            Text(T("Als dieser User einloggen")).foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(.secondary)
                        }
                    }
                    
                    Button { showSendMessage = true } label: {
                        HStack {
                            Image(systemName: "envelope.fill").foregroundColor(.purple)
                            Text(T("Nachricht senden")).foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            // Details
            Section(T("Details")) {
                LabeledContent("User-ID", value: String(user.id.prefix(12)) + "...").font(TDTypography.caption1)
                LabeledContent("E-Mail", value: user.email)
                LabeledContent("Registriert", value: user.createdAt.formatted(date: .abbreviated, time: .shortened))
            }
            
            // Rolle
            Section(T("Rolle & Status")) {
                Picker("Rolle", selection: $selectedGroup) {
                    ForEach(UserGroup.allCases, id: \.self) { group in
                        Label(group.displayName, systemImage: group.icon).tag(group)
                    }
                }
                .pickerStyle(.menu)
                .disabled(user.id == userManager.currentUser?.id)
                
                Toggle("Account aktiv", isOn: $isActive)
                    .disabled(user.id == userManager.currentUser?.id)
            }
            
            // Trainer - Kurse zuweisen
            if selectedGroup == .trainer {
                Section(T("Trainer-Einstellungen")) {
                    Button { showAssignCourses = true } label: {
                        HStack {
                            Image(systemName: "book").foregroundColor(Color.accentGold)
                            Text(T("Kurse zuweisen")).foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            // Kurse freischalten
            Section(T("Freigeschaltete Kurse")) {
                if courseDataManager.courses.isEmpty {
                    Text(T("Keine Kurse vorhanden"))
                        .foregroundColor(.secondary)
                } else {
                    ForEach(courseDataManager.courses) { course in
                        HStack {
                            Text(course.title).font(TDTypography.body)
                            Spacer()
                            Image(systemName: unlockedCourseIds.contains(course.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(unlockedCourseIds.contains(course.id) ? .green : .gray)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if unlockedCourseIds.contains(course.id) {
                                unlockedCourseIds.remove(course.id)
                            } else {
                                unlockedCourseIds.insert(course.id)
                            }
                        }
                    }
                }
            }
            
            // Speichern
            Section {
                Button { Task { await save() } } label: {
                    HStack {
                        Spacer()
                        if isSaving { ProgressView().tint(.white) }
                        else { Text(T("Speichern")).fontWeight(.semibold) }
                        Spacer()
                    }
                }
                .listRowBackground(Color.accentGold)
                .foregroundColor(.white)
            }
            
            // Löschen
            if user.id != userManager.currentUser?.id {
                Section {
                    Button(role: .destructive) { showDeleteConfirm = true } label: {
                        Text(T("Account löschen")).frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .sheet(isPresented: $showAssignCourses) {
            AssignCoursesView(trainerId: user.id, currentCourseIds: currentUser.trainerProfile?.assignedCourseIds ?? [])
        }
    }
    
    private func save() async {
        isSaving = true
        defer { isSaving = false }
        
        let ok = await userManager.updateUserAsAdmin(
            userId: user.id,
            newGroup: selectedGroup,
            isActive: isActive,
            unlockedCourseIds: Array(unlockedCourseIds)
        )
        if ok {
            await userManager.forceSync()
            dismiss()
        } else {
            saveErrorMessage = userManager.lastError ?? "Unbekannter Fehler"
            showSaveError = true
        }
    }
}

// MARK: - Create User View
struct CreateUserView: View {
    @StateObject private var userManager = UserManager.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var name = ""
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var selectedGroup: UserGroup = .user
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertSuccess = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section(T("User-Daten")) {
                    TextField(T("Name"), text: $name)
                    TextField(T("Benutzername"), text: $username).textInputAutocapitalization(.never)
                    TextField(T("E-Mail"), text: $email).keyboardType(.emailAddress).textInputAutocapitalization(.never)
                    SecureField(T("Passwort (min. 6)"), text: $password)
                }
                
                Section(T("Rolle")) {
                    Picker("Rolle", selection: $selectedGroup) {
                        ForEach(UserGroup.allCases, id: \.self) { group in
                            Label(group.displayName, systemImage: group.icon).tag(group)
                        }
                    }
                    .pickerStyle(.inline)
                }
                
                Section {
                    Button {
                        Task { await createUser() }
                    } label: {
                        HStack {
                            Spacer()
                            if isLoading { ProgressView().tint(.white) }
                            else { Text(T("Erstellen")).fontWeight(.semibold) }
                            Spacer()
                        }
                    }
                    .disabled(!isFormValid || isLoading)
                    .listRowBackground(isFormValid ? Color.accentGold : Color.gray)
                    .foregroundColor(.white)
                }
            }
            .navigationTitle(T("Neuer User"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(T("Abbrechen")) { dismiss() }
                }
            }
            .alert(alertSuccess ? "✅ Erfolg" : "❌ Fehler", isPresented: $showAlert) {
                Button(T("OK")) { if alertSuccess { dismiss() } }
            } message: { Text(alertMessage) }
        }
    }
    
    private var isFormValid: Bool {
        !name.isEmpty && username.count >= 3 && email.contains("@") && password.count >= 6
    }
    
    private func createUser() async {
        isLoading = true
        defer { isLoading = false }
        let result = await userManager.createUserAsAdmin(name: name, username: username, email: email, password: password, group: selectedGroup)
        alertMessage = result.message
        alertSuccess = result.success
        showAlert = true
    }
}

// MARK: - Assign Courses View
struct AssignCoursesView: View {
    let trainerId: String
    let currentCourseIds: [String]
    @StateObject private var userManager = UserManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var selectedCourseIds: Set<String>
    
    init(trainerId: String, currentCourseIds: [String]) {
        self.trainerId = trainerId
        self.currentCourseIds = currentCourseIds
        _selectedCourseIds = State(initialValue: Set(currentCourseIds))
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(MockData.courses) { course in
                    HStack {
                        Text(course.title)
                        Spacer()
                        Image(systemName: selectedCourseIds.contains(course.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(selectedCourseIds.contains(course.id) ? Color.accentGold : .gray)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if selectedCourseIds.contains(course.id) { selectedCourseIds.remove(course.id) }
                        else { selectedCourseIds.insert(course.id) }
                    }
                }
            }
            .navigationTitle(T("Kurse zuweisen"))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button(T("Abbrechen")) { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(T("Speichern")) {
                        Task {
                            _ = await userManager.assignCoursesToTrainer(trainerId: trainerId, courseIds: Array(selectedCourseIds))
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Stat Badge
struct StatBadge: View {
    let count: Int
    let title: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text("\(count)").font(TDTypography.headline).fontWeight(.bold).foregroundColor(color)
            Text(title).font(TDTypography.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 6)
        .background(color.opacity(0.1)).cornerRadius(TDRadius.sm)
    }
}
