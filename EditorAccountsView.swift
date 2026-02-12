//
//  EditorAccountsView.swift
//  Tanzen mit Tatiana Drexler
//
//  Admin-Ansicht zum Verwalten von Editor-Accounts
//

import SwiftUI

// MARK: - Editor Accounts List View
struct EditorAccountsView: View {
    @StateObject private var editorManager = EditorAccountManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showAddEditor = false
    @State private var selectedEditor: EditorAccount? = nil
    @State private var showDeleteConfirm = false
    @State private var editorToDelete: EditorAccount? = nil
    
    var body: some View {
        NavigationStack {
            ZStack {
                TDGradients.mainBackground
                    .ignoresSafeArea()
                
                if editorManager.editorAccounts.isEmpty {
                    emptyState
                } else {
                    editorList
                }
            }
            .navigationTitle(T("Editor-Accounts"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(T("Fertig")) {
                        dismiss()
                    }
                    .foregroundColor(Color.accentGold)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddEditor = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(Color.accentGold)
                    }
                }
            }
            .sheet(isPresented: $showAddEditor) {
                AddEditorView()
            }
            .sheet(item: $selectedEditor) { editor in
                EditEditorView(editor: editor)
            }
            .alert(T("Editor löschen?"), isPresented: $showDeleteConfirm) {
                Button(T("Abbrechen"), role: .cancel) { }
                Button(T("Löschen"), role: .destructive) {
                    if let editor = editorToDelete {
                        editorManager.deleteEditorAccount(editor.id)
                    }
                }
            } message: {
                Text(T("Der Editor-Account wird unwiderruflich gelöscht."))
            }
        }
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: TDSpacing.lg) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text(T("Keine Editor-Accounts"))
                .font(TDTypography.title2)
                .foregroundColor(.primary)
            
            Text(T("Erstelle Editor-Accounts, um anderen Personen Zugriff auf die Kursbearbeitung zu geben."))
                .font(TDTypography.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, TDSpacing.xl)
            
            Button {
                showAddEditor = true
            } label: {
                HStack {
                    Image(systemName: "plus")
                    Text(T("Editor hinzufügen"))
                }
            }
            .buttonStyle(.tdPrimary)
        }
    }
    
    // MARK: - Editor List
    private var editorList: some View {
        ScrollView {
            LazyVStack(spacing: TDSpacing.md) {
                ForEach(editorManager.editorAccounts) { editor in
                    EditorAccountRow(editor: editor) {
                        selectedEditor = editor
                    } onDelete: {
                        editorToDelete = editor
                        showDeleteConfirm = true
                    } onToggleActive: {
                        editorManager.setAccountActive(editor.id, isActive: !editor.isActive)
                    }
                }
            }
            .padding(TDSpacing.md)
        }
    }
}

// MARK: - Editor Account Row
struct EditorAccountRow: View {
    let editor: EditorAccount
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onToggleActive: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: TDSpacing.sm) {
            HStack {
                // Avatar
                ZStack {
                    Circle()
                        .fill(editor.isActive ? Color.accentGold : Color.gray)
                        .frame(width: 50, height: 50)
                    
                    Text(editor.displayName.prefix(1).uppercased())
                        .font(TDTypography.title2)
                        .foregroundColor(.white)
                }
                
                // Info
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(editor.displayName)
                            .font(TDTypography.headline)
                            .foregroundColor(.primary)
                        
                        if !editor.isActive {
                            Text(T("DEAKTIVIERT"))
                                .font(TDTypography.caption2)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red)
                                .cornerRadius(4)
                        }
                    }
                    
                    Text("@\(editor.username)")
                        .font(TDTypography.caption1)
                        .foregroundColor(.secondary)
                    
                    Text("\(editor.allowedCourseIds.count) Kurse zugewiesen")
                        .font(TDTypography.caption1)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Actions Menu
                Menu {
                    Button {
                        onEdit()
                    } label: {
                        Label(T("Bearbeiten"), systemImage: "pencil")
                    }
                    
                    Button {
                        onToggleActive()
                    } label: {
                        Label(editor.isActive ? "Deaktivieren" : "Aktivieren",
                              systemImage: editor.isActive ? "pause.circle" : "play.circle")
                    }
                    
                    Divider()
                    
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label(T("Löschen"), systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 24))
                        .foregroundColor(Color.accentGold)
                }
            }
            
            // Permissions Preview
            HStack(spacing: TDSpacing.sm) {
                PermissionBadge(title: "Titel", allowed: editor.canEditTitle)
                PermissionBadge(title: "Beschreibung", allowed: editor.canEditDescription)
                PermissionBadge(title: "Lektionen", allowed: editor.canEditLessons)
                PermissionBadge(title: "Preis", allowed: false)
            }
        }
        .padding(TDSpacing.md)
        .glassBackground()
    }
}

// MARK: - Permission Badge
struct PermissionBadge: View {
    let title: String
    let allowed: Bool
    
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: allowed ? "checkmark" : "xmark")
                .font(.system(size: 8, weight: .bold))
            Text(title)
                .font(.system(size: 10))
        }
        .foregroundColor(allowed ? .green : .red)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill((allowed ? Color.green : Color.red).opacity(0.2))
        )
    }
}

// MARK: - Add Editor View
struct AddEditorView: View {
    @StateObject private var editorManager = EditorAccountManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var username = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var selectedCourseIds: Set<String> = []
    @State private var canEditTitle = true
    @State private var canEditDescription = true
    @State private var canEditLessons = true
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                TDGradients.mainBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: TDSpacing.lg) {
                        // Account Details
                        accountDetailsSection
                        
                        // Permissions
                        permissionsSection
                        
                        // Course Selection
                        courseSelectionSection
                        
                        // Info
                        infoSection
                    }
                    .padding(TDSpacing.md)
                }
            }
            .navigationTitle(T("Neuer Editor"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(T("Abbrechen")) {
                        dismiss()
                    }
                    .foregroundColor(Color.accentGold)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(T("Erstellen")) {
                        createEditor()
                    }
                    .foregroundColor(Color.accentGold)
                    .fontWeight(.semibold)
                    .disabled(!canCreate)
                }
            }
            .alert(T("Fehler"), isPresented: $showError) {
                Button(T("OK"), role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Account Details Section
    private var accountDetailsSection: some View {
        VStack(alignment: .leading, spacing: TDSpacing.md) {
            Text(T("Account-Details"))
                .font(TDTypography.headline)
                .foregroundColor(.secondary)
            
            VStack(spacing: TDSpacing.md) {
                FormField(title: "Anzeigename") {
                    TextField(T("z.B. Anna Müller"), text: $displayName)
                        .textFieldStyle(GlassTextFieldStyle())
                }
                
                FormField(title: "Benutzername") {
                    TextField(T("z.B. anna_m"), text: $username)
                        .textFieldStyle(GlassTextFieldStyle())
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                
                FormField(title: "Passwort") {
                    SecureField(T("Mindestens 8 Zeichen"), text: $password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .textContentType(.password)
                        .textFieldStyle(GlassTextFieldStyle())
                }
            }
            .padding(TDSpacing.md)
            .glassBackground()
        }
    }
    
    // MARK: - Permissions Section
    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: TDSpacing.md) {
            Text(T("Berechtigungen"))
                .font(TDTypography.headline)
                .foregroundColor(.secondary)
            
            VStack(spacing: 0) {
                PermissionToggle(title: "Titel bearbeiten", isOn: $canEditTitle)
                Divider().background(Color.gray.opacity(0.3))
                PermissionToggle(title: "Beschreibung bearbeiten", isOn: $canEditDescription)
                Divider().background(Color.gray.opacity(0.3))
                PermissionToggle(title: "Lektionen bearbeiten", isOn: $canEditLessons)
                Divider().background(Color.gray.opacity(0.3))
                
                // Preis - immer gesperrt
                HStack {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.red)
                    VStack(alignment: .leading) {
                        Text(T("Preis bearbeiten"))
                            .font(TDTypography.body)
                            .foregroundColor(.primary)
                        Text(T("Editoren können keine Preise ändern"))
                            .font(TDTypography.caption1)
                            .foregroundColor(.red)
                    }
                    Spacer()
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                }
                .padding(TDSpacing.md)
            }
            .glassBackground()
        }
    }
    
    // MARK: - Course Selection Section
    private var courseSelectionSection: some View {
        VStack(alignment: .leading, spacing: TDSpacing.md) {
            HStack {
                Text(T("Zugewiesene Kurse"))
                    .font(TDTypography.headline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button {
                    if selectedCourseIds.count == MockData.courses.count {
                        selectedCourseIds.removeAll()
                    } else {
                        selectedCourseIds = Set(MockData.courses.map { $0.id })
                    }
                } label: {
                    Text(selectedCourseIds.count == MockData.courses.count ? "Keine" : "Alle")
                        .font(TDTypography.caption1)
                        .foregroundColor(Color.accentGold)
                }
            }
            
            VStack(spacing: 0) {
                ForEach(MockData.courses) { course in
                    CourseSelectionRow(
                        course: course,
                        isSelected: selectedCourseIds.contains(course.id)
                    ) {
                        if selectedCourseIds.contains(course.id) {
                            selectedCourseIds.remove(course.id)
                        } else {
                            selectedCourseIds.insert(course.id)
                        }
                    }
                    
                    if course.id != MockData.courses.last?.id {
                        Divider().background(Color.gray.opacity(0.3))
                    }
                }
            }
            .glassBackground()
        }
    }
    
    // MARK: - Info Section
    private var infoSection: some View {
        HStack {
            Image(systemName: "info.circle.fill")
                .foregroundColor(Color.accentGold)
            Text(T("Editoren können nur die ihnen zugewiesenen Kurse bearbeiten. Preisänderungen sind nicht möglich."))
                .font(TDTypography.caption1)
                .foregroundColor(.secondary)
        }
        .padding(TDSpacing.md)
        .glassBackground()
    }
    
    // MARK: - Helpers
    private var canCreate: Bool {
        !username.isEmpty && password.count >= 8 && !displayName.isEmpty && !selectedCourseIds.isEmpty
    }
    
    private func createEditor() {
        guard let newEditor = editorManager.createEditorAccount(
            username: username,
            password: password,
            displayName: displayName,
            allowedCourseIds: selectedCourseIds
        ) else {
            errorMessage = "Benutzername bereits vergeben"
            showError = true
            return
        }
        
        // Update permissions
        var updatedEditor = newEditor
        updatedEditor.canEditTitle = canEditTitle
        updatedEditor.canEditDescription = canEditDescription
        updatedEditor.canEditLessons = canEditLessons
        editorManager.updateEditorAccount(updatedEditor)
        
        dismiss()
    }
}

// MARK: - Edit Editor View
struct EditEditorView: View {
    let editor: EditorAccount
    @StateObject private var editorManager = EditorAccountManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var displayName: String = ""
    @State private var password: String = ""
    @State private var selectedCourseIds: Set<String> = []
    @State private var canEditTitle = true
    @State private var canEditDescription = true
    @State private var canEditLessons = true
    
    var body: some View {
        NavigationStack {
            ZStack {
                TDGradients.mainBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: TDSpacing.lg) {
                        // Account Details
                        VStack(alignment: .leading, spacing: TDSpacing.md) {
                            Text(T("Account-Details"))
                                .font(TDTypography.headline)
                                .foregroundColor(.secondary)
                            
                            VStack(spacing: TDSpacing.md) {
                                FormField(title: "Anzeigename") {
                                    TextField(T("Name"), text: $displayName)
                                        .textFieldStyle(GlassTextFieldStyle())
                                }
                                
                                FormField(title: "Benutzername") {
                                    Text("@\(editor.username)")
                                        .font(TDTypography.body)
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(TDSpacing.md)
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(TDRadius.md)
                                }
                                
                                FormField(title: "Neues Passwort (leer lassen für unverändert)") {
                                    SecureField(T("Neues Passwort"), text: $password)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled(true)
                                        .textContentType(.password)
                                        .textFieldStyle(GlassTextFieldStyle())
                                }
                            }
                            .padding(TDSpacing.md)
                            .glassBackground()
                        }
                        
                        // Permissions
                        VStack(alignment: .leading, spacing: TDSpacing.md) {
                            Text(T("Berechtigungen"))
                                .font(TDTypography.headline)
                                .foregroundColor(.secondary)
                            
                            VStack(spacing: 0) {
                                PermissionToggle(title: "Titel bearbeiten", isOn: $canEditTitle)
                                Divider().background(Color.gray.opacity(0.3))
                                PermissionToggle(title: "Beschreibung bearbeiten", isOn: $canEditDescription)
                                Divider().background(Color.gray.opacity(0.3))
                                PermissionToggle(title: "Lektionen bearbeiten", isOn: $canEditLessons)
                            }
                            .glassBackground()
                        }
                        
                        // Course Selection
                        VStack(alignment: .leading, spacing: TDSpacing.md) {
                            Text(T("Zugewiesene Kurse"))
                                .font(TDTypography.headline)
                                .foregroundColor(.secondary)
                            
                            VStack(spacing: 0) {
                                ForEach(MockData.courses) { course in
                                    CourseSelectionRow(
                                        course: course,
                                        isSelected: selectedCourseIds.contains(course.id)
                                    ) {
                                        if selectedCourseIds.contains(course.id) {
                                            selectedCourseIds.remove(course.id)
                                        } else {
                                            selectedCourseIds.insert(course.id)
                                        }
                                    }
                                    
                                    if course.id != MockData.courses.last?.id {
                                        Divider().background(Color.gray.opacity(0.3))
                                    }
                                }
                            }
                            .glassBackground()
                        }
                    }
                    .padding(TDSpacing.md)
                }
            }
            .navigationTitle(T("Editor bearbeiten"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(T("Abbrechen")) {
                        dismiss()
                    }
                    .foregroundColor(Color.accentGold)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(T("Speichern")) {
                        saveChanges()
                    }
                    .foregroundColor(Color.accentGold)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                loadEditorData()
            }
        }
    }
    
    private func loadEditorData() {
        displayName = editor.displayName
        selectedCourseIds = editor.allowedCourseIds
        canEditTitle = editor.canEditTitle
        canEditDescription = editor.canEditDescription
        canEditLessons = editor.canEditLessons
    }
    
    private func saveChanges() {
        var updatedEditor = editor
        updatedEditor.displayName = displayName
        updatedEditor.allowedCourseIds = selectedCourseIds
        updatedEditor.canEditTitle = canEditTitle
        updatedEditor.canEditDescription = canEditDescription
        updatedEditor.canEditLessons = canEditLessons
        
        if !password.isEmpty && password.count >= 8 {
            updatedEditor.password = password
        }
        
        editorManager.updateEditorAccount(updatedEditor)
        dismiss()
    }
}

// MARK: - Permission Toggle
struct PermissionToggle: View {
    let title: String
    @Binding var isOn: Bool
    
    var body: some View {
        Toggle(isOn: $isOn) {
            Text(title)
                .font(TDTypography.body)
                .foregroundColor(.primary)
        }
        .tint(Color.accentGold)
        .padding(TDSpacing.md)
    }
}

// MARK: - Course Selection Row
struct CourseSelectionRow: View {
    let course: Course
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: TDSpacing.md) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? Color.accentGold : .secondary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(course.title)
                        .font(TDTypography.body)
                        .foregroundColor(.primary)
                    
                    Text(course.style.rawValue)
                        .font(TDTypography.caption1)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(TDSpacing.md)
        }
    }
}

#Preview {
    EditorAccountsView()
}
