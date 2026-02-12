//
//  TrainerCommissionAdminView.swift
//  Tanzen mit Tatiana Drexler
//
//  Admin-View zur Konfiguration der Trainer-Anteile pro Kurs
//  MEHRERE TRAINER pro Kurs möglich
//

import SwiftUI

struct TrainerCommissionAdminView: View {
    @StateObject private var walletManager = TrainerWalletManager.shared
    @StateObject private var courseDataManager = CourseDataManager.shared
    @StateObject private var userManager = UserManager.shared
    
    @State private var showAddCommission = false
    @State private var searchText = ""
    @State private var selectedCourseForNewTrainer: Course?
    
    private var trainers: [AppUser] {
        userManager.allUsers.filter { $0.group == .trainer }
    }
    
    // Gruppiere Commissions nach Kurs
    private var commissionsByCourse: [String: [TrainerCourseCommission]] {
        Dictionary(grouping: walletManager.allCommissions) { $0.courseId }
    }
    
    private var filteredCourses: [Course] {
        if searchText.isEmpty {
            return courseDataManager.courses
        }
        return courseDataManager.courses.filter { course in
            course.title.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Übersicht
                Section {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(T("Aktive Provisionen"))
                                .font(TDTypography.caption1)
                                .foregroundColor(.secondary)
                            Text("\(walletManager.allCommissions.filter { $0.isActive }.count)")
                                .font(TDTypography.title2)
                                .fontWeight(.bold)
                        }
                        Spacer()
                        VStack(alignment: .center) {
                            Text(T("Kurse"))
                                .font(TDTypography.caption1)
                                .foregroundColor(.secondary)
                            Text("\(Set(walletManager.allCommissions.map { $0.courseId }).count)")
                                .font(TDTypography.title2)
                                .fontWeight(.bold)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text(T("Trainer"))
                                .font(TDTypography.caption1)
                                .foregroundColor(.secondary)
                            Text("\(trainers.count)")
                                .font(TDTypography.title2)
                                .fontWeight(.bold)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // Kurse mit ihren Provisionen
                ForEach(filteredCourses) { course in
                    Section {
                        // Kurs-Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text(course.title)
                                .font(TDTypography.headline)
                            
                            // Zugewiesene Trainer anzeigen
                            let courseCommissions = commissionsByCourse[course.id] ?? []
                            
                            if courseCommissions.isEmpty {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundColor(.orange)
                                    Text(T("Keine Provisionen konfiguriert"))
                                        .font(TDTypography.caption1)
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                // Zeige alle Trainer mit ihren Provisionen
                                ForEach(courseCommissions) { commission in
                                    let trainerName = userManager.allUsers.first(where: { $0.id == commission.trainerId })?.name ?? "Unbekannt"
                                    
                                    CommissionRowMulti(
                                        commission: commission,
                                        trainerName: trainerName,
                                        courseName: course.title
                                    )
                                }
                                
                                // Gesamtprovision anzeigen
                                let totalPercent = courseCommissions.filter { $0.isActive }.reduce(0) { $0 + $1.commissionPercent }
                                HStack {
                                    Text(T("Gesamt-Provision:"))
                                        .font(TDTypography.caption1)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("\(totalPercent)%")
                                        .font(TDTypography.caption1)
                                        .fontWeight(.bold)
                                        .foregroundColor(totalPercent > 100 ? .red : .green)
                                }
                                
                                if totalPercent > 100 {
                                    Text(T("⚠️ Achtung: Gesamtprovision übersteigt 100%!"))
                                        .font(TDTypography.caption2)
                                        .foregroundColor(.red)
                                }
                            }
                            
                            // Button um weiteren Trainer hinzuzufügen
                            Button {
                                selectedCourseForNewTrainer = course
                            } label: {
                                Label(T("Trainer hinzufügen"), systemImage: "person.badge.plus")
                                    .font(TDTypography.caption1)
                            }
                            .padding(.top, 4)
                        }
                    } header: {
                        if let trainerName = course.trainerName ?? userManager.allUsers.first(where: { $0.id == course.trainerId })?.name {
                            Text(T("Kurs-Trainer: %@", trainerName))
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Kurs suchen")
            .navigationTitle(T("Trainer-Provisionen"))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddCommission = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(T("Aktualisieren")) {
                        Task {
                            await walletManager.loadAllCommissions()
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddCommission) {
                AddCommissionViewMulti(preselectedCourse: nil)
            }
            .sheet(item: $selectedCourseForNewTrainer) { course in
                AddCommissionViewMulti(preselectedCourse: course)
            }
            .task {
                await walletManager.loadAllCommissions()
            }
        }
    }
}

// MARK: - Commission Row for Multiple Trainers
struct CommissionRowMulti: View {
    let commission: TrainerCourseCommission
    let trainerName: String
    let courseName: String
    
    @State private var showEdit = false
    
    var body: some View {
        Button {
            showEdit = true
        } label: {
            HStack {
                // Trainer Info
                HStack(spacing: 8) {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(commission.isActive ? .blue : .gray)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(trainerName)
                            .font(TDTypography.body)
                            .foregroundColor(.primary)
                        
                        if !commission.isActive {
                            Text(T("Deaktiviert"))
                                .font(TDTypography.caption2)
                                .foregroundColor(.red)
                        }
                    }
                }
                
                Spacer()
                
                // Provision
                Text("\(commission.commissionPercent)%")
                    .font(TDTypography.headline)
                    .fontWeight(.bold)
                    .foregroundColor(commission.isActive ? .green : .secondary)
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
        .sheet(isPresented: $showEdit) {
            EditCommissionViewMulti(commission: commission, courseName: courseName, trainerName: trainerName)
        }
    }
}

// MARK: - Add Commission View (Multiple Trainers)
struct AddCommissionViewMulti: View {
    let preselectedCourse: Course?
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var walletManager = TrainerWalletManager.shared
    @StateObject private var courseDataManager = CourseDataManager.shared
    @StateObject private var userManager = UserManager.shared
    
    @State private var selectedCourseId: String = ""
    @State private var selectedTrainerId: String = ""
    @State private var commissionPercent: Int = 30
    @State private var notes: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    
    private var trainers: [AppUser] {
        userManager.allUsers.filter { $0.group == .trainer }
    }
    
    // Trainer die noch keine Provision für diesen Kurs haben
    private var availableTrainers: [AppUser] {
        let courseId = preselectedCourse?.id ?? selectedCourseId
        let existingTrainerIds = walletManager.allCommissions
            .filter { $0.courseId == courseId }
            .map { $0.trainerId }
        
        return trainers.filter { !existingTrainerIds.contains($0.id) }
    }
    
    private var selectedCourse: Course? {
        preselectedCourse ?? courseDataManager.courses.first(where: { $0.id == selectedCourseId })
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Kurs auswählen (nur wenn nicht vorselektiert)
                if preselectedCourse == nil {
                    Section(T("Kurs auswählen")) {
                        Picker("Kurs", selection: $selectedCourseId) {
                            Text(T("Kurs auswählen...")).tag("")
                            ForEach(courseDataManager.courses) { course in
                                Text(course.title).tag(course.id)
                            }
                        }
                    }
                } else {
                    Section(T("Kurs")) {
                        Text(preselectedCourse?.title ?? "")
                            .fontWeight(.medium)
                    }
                }
                
                // Trainer auswählen
                Section(T("Trainer auswählen")) {
                    if availableTrainers.isEmpty {
                        Text(T("Alle Trainer haben bereits eine Provision für diesen Kurs"))
                            .foregroundColor(.secondary)
                            .font(TDTypography.caption1)
                    } else {
                        Picker("Trainer", selection: $selectedTrainerId) {
                            Text(T("Trainer auswählen...")).tag("")
                            ForEach(availableTrainers) { trainer in
                                Text(trainer.name).tag(trainer.id)
                            }
                        }
                    }
                }
                
                // Provision
                Section(T("Provision")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(T("Trainer-Anteil"))
                            Spacer()
                            Text("\(commissionPercent)%")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(Color.accentGold)
                        }
                        
                        Slider(value: Binding(
                            get: { Double(commissionPercent) },
                            set: { commissionPercent = Int($0) }
                        ), in: 0...100, step: 5)
                        .tint(Color.accentGold)
                        
                        // Beispielrechnung
                        let exampleCoins = 100
                        let trainerCoins = Int(Double(exampleCoins) * Double(commissionPercent) / 100.0)
                        
                        HStack {
                            Text(T("Beispiel: Bei %@ DC Kauf", "\(exampleCoins)"))
                                .font(TDTypography.caption1)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("→ \(trainerCoins) DC für Trainer")
                                .font(TDTypography.caption1)
                                .foregroundColor(.green)
                        }
                        
                        // Warnung wenn Gesamtprovision > 100%
                        if let course = selectedCourse {
                            let existingTotal = walletManager.allCommissions
                                .filter { $0.courseId == course.id && $0.isActive }
                                .reduce(0) { $0 + $1.commissionPercent }
                            let newTotal = existingTotal + commissionPercent
                            
                            if newTotal > 100 {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                    Text(T("Gesamtprovision würde %@%% betragen!", "\(newTotal)"))
                                        .font(TDTypography.caption1)
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                    }
                }
                
                Section(T("Notizen (optional)")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle(T("Provision hinzufügen"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(T("Abbrechen")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(T("Speichern")) {
                        Task { await save() }
                    }
                    .disabled(selectedTrainerId.isEmpty || (preselectedCourse == nil && selectedCourseId.isEmpty) || isSaving)
                }
            }
            .onAppear {
                if let course = preselectedCourse {
                    selectedCourseId = course.id
                }
            }
        }
    }
    
    private func save() async {
        guard let course = selectedCourse,
              let adminId = userManager.currentUser?.id else {
            errorMessage = "Bitte wähle einen Kurs aus"
            return
        }
        
        guard !selectedTrainerId.isEmpty else {
            errorMessage = "Bitte wähle einen Trainer aus"
            return
        }
        
        isSaving = true
        defer { isSaving = false }
        
        let success = await walletManager.setCommission(
            courseId: course.id,
            trainerId: selectedTrainerId,
            percent: commissionPercent,
            adminId: adminId,
            notes: notes.isEmpty ? nil : notes
        )
        
        if success {
            dismiss()
        } else {
            errorMessage = "Fehler beim Speichern"
        }
    }
}

// MARK: - Edit Commission View (Multiple Trainers)
struct EditCommissionViewMulti: View {
    let commission: TrainerCourseCommission
    let courseName: String
    let trainerName: String
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var walletManager = TrainerWalletManager.shared
    @StateObject private var userManager = UserManager.shared
    
    @State private var commissionPercent: Int
    @State private var isActive: Bool
    @State private var notes: String
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showDeleteConfirm = false
    
    init(commission: TrainerCourseCommission, courseName: String, trainerName: String) {
        self.commission = commission
        self.courseName = courseName
        self.trainerName = trainerName
        _commissionPercent = State(initialValue: commission.commissionPercent)
        _isActive = State(initialValue: commission.isActive)
        _notes = State(initialValue: commission.notes ?? "")
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(T("Info")) {
                    HStack {
                        Text(T("Kurs"))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(courseName)
                    }
                    HStack {
                        Text(T("Trainer"))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(trainerName)
                    }
                }
                
                Section(T("Provision")) {
                    Toggle("Aktiv", isOn: $isActive)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(T("Trainer-Anteil"))
                            Spacer()
                            Text("\(commissionPercent)%")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(isActive ? Color.accentGold : .secondary)
                        }
                        
                        Slider(value: Binding(
                            get: { Double(commissionPercent) },
                            set: { commissionPercent = Int($0) }
                        ), in: 0...100, step: 5)
                        .tint(Color.accentGold)
                        .disabled(!isActive)
                        
                        // Beispielrechnung
                        let exampleCoins = 100
                        let trainerCoins = Int(Double(exampleCoins) * Double(commissionPercent) / 100.0)
                        
                        HStack {
                            Text(T("Beispiel: Bei %@ DC Kauf", "\(exampleCoins)"))
                                .font(TDTypography.caption1)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("→ \(trainerCoins) DC für Trainer")
                                .font(TDTypography.caption1)
                                .foregroundColor(.green)
                        }
                    }
                }
                
                Section(T("Notizen")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
                
                Section(T("Details")) {
                    HStack {
                        Text(T("Erstellt am"))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(commission.createdAt, style: .date)
                    }
                    HStack {
                        Text(T("Zuletzt geändert"))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(commission.updatedAt, style: .date)
                    }
                }
                
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        HStack {
                            Spacer()
                            Text(T("Provision löschen"))
                            Spacer()
                        }
                    }
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle(T("Provision bearbeiten"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(T("Abbrechen")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(T("Speichern")) {
                        Task { await save() }
                    }
                    .disabled(isSaving)
                }
            }
            .alert(T("Provision löschen?"), isPresented: $showDeleteConfirm) {
                Button(T("Abbrechen"), role: .cancel) { }
                Button(T("Löschen"), role: .destructive) {
                    Task { await deleteCommission() }
                }
            } message: {
                Text(T("Der Trainer %@ erhält dann keine Provision mehr für diesen Kurs.", trainerName))
            }
        }
    }
    
    private func save() async {
        guard let adminId = userManager.currentUser?.id else {
            errorMessage = "Nicht eingeloggt"
            return
        }
        
        isSaving = true
        defer { isSaving = false }
        
        // Active-Status und Commission updaten
        if isActive != commission.isActive {
            _ = await walletManager.setCommissionActive(
                commissionId: commission.id,
                isActive: isActive,
                adminId: adminId
            )
        }
        
        let success = await walletManager.setCommission(
            courseId: commission.courseId,
            trainerId: commission.trainerId,
            percent: commissionPercent,
            adminId: adminId,
            notes: notes.isEmpty ? nil : notes
        )
        
        if success {
            dismiss()
        } else {
            errorMessage = "Fehler beim Speichern"
        }
    }
    
    private func deleteCommission() async {
        guard let adminId = userManager.currentUser?.id else { return }
        
        // Commission deaktivieren und auf 0 setzen
        _ = await walletManager.setCommissionActive(
            commissionId: commission.id,
            isActive: false,
            adminId: adminId
        )
        
        dismiss()
    }
}

// Make Course conform to Hashable for sheet(item:)
extension Course: @retroactive Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

#Preview {
    TrainerCommissionAdminView()
}
