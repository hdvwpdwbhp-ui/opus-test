//
//  TrainerCourseEditView.swift
//  Tanzen mit Tatiana Drexler
//
//  Trainer können ihre zugewiesenen Kurse bearbeiten (mit Admin-Genehmigung)
//

import SwiftUI

// MARK: - Trainer's Courses List
struct TrainerCoursesView: View {
    @StateObject private var userManager = UserManager.shared
    @StateObject private var settingsManager = AppSettingsManager.shared
    
    var assignedCourses: [Course] {
        guard let trainer = userManager.currentUser,
              let profile = trainer.trainerProfile else { return [] }
        return MockData.courses.filter { profile.assignedCourseIds.contains($0.id) }
    }
    
    var pendingRequestsCount: Int {
        guard let trainerId = userManager.currentUser?.id else { return 0 }
        return settingsManager.trainerEditRequests.filter {
            $0.trainerId == trainerId && $0.status == .pending
        }.count
    }
    
    var body: some View {
        List {
            if pendingRequestsCount > 0 {
                Section {
                    HStack {
                        Image(systemName: "clock.badge.exclamationmark")
                            .foregroundColor(.orange)
                        Text("\(pendingRequestsCount) Änderungsanfrage(n) ausstehend")
                            .font(TDTypography.subheadline)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
            
            if assignedCourses.isEmpty {
                ContentUnavailableView(
                    "Keine Kurse zugewiesen",
                    systemImage: "book.closed",
                    description: Text(T("Dir wurden noch keine Kurse zugewiesen. Kontaktiere den Admin."))
                )
            } else {
                Section(T("Deine Kurse (%@)", "\(assignedCourses.count)")) {
                    ForEach(assignedCourses) { course in
                        NavigationLink(destination: TrainerCourseEditView(course: course)) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(course.title).font(TDTypography.headline)
                                    Text("\(course.lessonCount) Lektionen • \(course.style.rawValue)")
                                        .font(TDTypography.caption1)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "pencil.circle")
                                    .foregroundColor(Color.accentGold)
                            }
                        }
                    }
                }
            }
            
            Section {
                Text(T("Änderungen an deinen Kursen müssen vom Admin genehmigt werden."))
                    .font(TDTypography.caption1)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle(T("Meine Kurse bearbeiten"))
    }
}

// MARK: - Edit Single Course
struct TrainerCourseEditView: View {
    let course: Course
    @StateObject private var userManager = UserManager.shared
    @StateObject private var settingsManager = AppSettingsManager.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var editedTitle: String = ""
    @State private var editedDescription: String = ""
    @State private var isSubmitting = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertSuccess = false
    
    var pendingRequests: [TrainerEditRequest] {
        guard let trainerId = userManager.currentUser?.id else { return [] }
        return settingsManager.trainerEditRequests.filter {
            $0.courseId == course.id && $0.trainerId == trainerId && $0.status == .pending
        }
    }
    
    var body: some View {
        Form {
            // Aktuelle Kurs-Info
            Section(T("Aktueller Kurs")) {
                LabeledContent("Titel", value: course.title)
                LabeledContent("Stil", value: course.style.rawValue)
                LabeledContent("Level", value: course.level.rawValue)
                LabeledContent("Lektionen", value: "\(course.lessonCount)")
            }
            
            // Ausstehende Anfragen
            if !pendingRequests.isEmpty {
                Section(T("Ausstehende Änderungen")) {
                    ForEach(pendingRequests) { request in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(request.fieldName)
                                    .font(TDTypography.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Text(T("Ausstehend"))
                                    .font(TDTypography.caption2)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.orange)
                                    .cornerRadius(4)
                            }
                            Text(T("Neu: %@", request.newValue))
                                .font(TDTypography.caption1)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            
            // Bearbeitbare Felder
            Section(T("Änderungen vorschlagen")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(T("Neuer Titel"))
                        .font(TDTypography.caption1)
                        .foregroundColor(.secondary)
                    TextField(T("Titel (leer lassen = keine Änderung)"), text: $editedTitle)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(T("Neue Beschreibung"))
                        .font(TDTypography.caption1)
                        .foregroundColor(.secondary)
                    TextEditor(text: $editedDescription)
                        .frame(minHeight: 100)
                }
            }
            
            // Submit Button
            Section {
                Button { Task { await submitChanges() } } label: {
                    HStack {
                        Spacer()
                        if isSubmitting { ProgressView().tint(.white) }
                        else { Text(T("Änderungen zur Genehmigung senden")).fontWeight(.semibold) }
                        Spacer()
                    }
                }
                .disabled((editedTitle.isEmpty && editedDescription.isEmpty) || isSubmitting)
                .listRowBackground((editedTitle.isEmpty && editedDescription.isEmpty) ? Color.gray : Color.accentGold)
                .foregroundColor(.white)
            }
            
            Section {
                Text(T("Der Admin wird über deine Änderungsanfrage benachrichtigt und kann sie genehmigen oder ablehnen."))
                    .font(TDTypography.caption1)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle(T("Kurs bearbeiten"))
        .navigationBarTitleDisplayMode(.inline)
        .alert(alertSuccess ? "✅ Gesendet" : "❌ Fehler", isPresented: $showAlert) {
            Button(T("OK")) { if alertSuccess { dismiss() } }
        } message: { Text(alertMessage) }
    }
    
    private func submitChanges() async {
        guard userManager.currentUser != nil else { return }
        
        isSubmitting = true
        defer { isSubmitting = false }
        
        var requestsCreated = 0
        
        // Titel-Änderung
        if !editedTitle.isEmpty && editedTitle != course.title {
            _ = await settingsManager.createTrainerEditRequest(
                courseId: course.id,
                courseName: course.title,
                fieldName: "Titel",
                oldValue: course.title,
                newValue: editedTitle
            )
            requestsCreated += 1
        }
        
        // Beschreibung-Änderung
        if !editedDescription.isEmpty && editedDescription != course.description {
            _ = await settingsManager.createTrainerEditRequest(
                courseId: course.id,
                courseName: course.title,
                fieldName: "Beschreibung",
                oldValue: course.description,
                newValue: editedDescription
            )
            requestsCreated += 1
        }
        
        if requestsCreated > 0 {
            alertMessage = "\(requestsCreated) Änderungsanfrage(n) gesendet. Der Admin wird benachrichtigt."
            alertSuccess = true
        } else {
            alertMessage = "Keine Änderungen vorgenommen."
            alertSuccess = false
        }
        
        showAlert = true
    }
}
