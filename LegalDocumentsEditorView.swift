//
//  LegalDocumentsEditorView.swift
//  Tanzen mit Tatiana Drexler
//
//  Admin kann rechtliche Dokumente bearbeiten
//

import SwiftUI

struct LegalDocumentsEditorView: View {
    @StateObject private var settingsManager = AppSettingsManager.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedTab = 0
    @State private var privacyPolicy = ""
    @State private var termsOfService = ""
    @State private var impressum = ""
    @State private var isSaving = false
    @State private var showAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            Picker("Dokument", selection: $selectedTab) {
                Text(T("Datenschutz")).tag(0)
                Text(T("AGB")).tag(1)
                Text(T("Impressum")).tag(2)
            }
            .pickerStyle(.segmented)
            .padding()
            
            TabView(selection: $selectedTab) {
                DocumentEditor(title: "Datenschutzerklärung", content: $privacyPolicy).tag(0)
                DocumentEditor(title: "Allgemeine Geschäftsbedingungen", content: $termsOfService).tag(1)
                DocumentEditor(title: "Impressum", content: $impressum).tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .navigationTitle(T("Rechtliche Dokumente"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(T("Abbrechen")) { dismiss() }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task { await save() }
                } label: {
                    if isSaving { ProgressView() }
                    else { Text(T("Speichern")).fontWeight(.semibold) }
                }
                .disabled(isSaving)
            }
        }
        .onAppear { loadDocuments() }
        .alert(T("✅ Gespeichert"), isPresented: $showAlert) {
            Button(T("OK")) { dismiss() }
        }
    }
    
    private func loadDocuments() {
        let docs = settingsManager.settings.legalDocuments
        privacyPolicy = docs.privacyPolicy
        termsOfService = docs.termsOfService
        impressum = docs.impressum
    }
    
    private func save() async {
        isSaving = true
        defer { isSaving = false }
        
        _ = await settingsManager.updateLegalDocuments(
            privacyPolicy: privacyPolicy,
            termsOfService: termsOfService,
            impressum: impressum
        )
        showAlert = true
    }
}

struct DocumentEditor: View {
    let title: String
    @Binding var content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: TDSpacing.sm) {
            Text(title)
                .font(TDTypography.headline)
                .padding(.horizontal)
            
            Text(T("Markdown-Formatierung wird unterstützt"))
                .font(TDTypography.caption2)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            TextEditor(text: $content)
                .font(.system(.body, design: .monospaced))
                .padding(TDSpacing.sm)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(TDRadius.sm)
                .padding(.horizontal)
        }
        .padding(.vertical)
    }
}

// MARK: - Trainer Course Assignment View
struct TrainerCourseAssignmentView: View {
    @StateObject private var userManager = UserManager.shared
    @Environment(\.dismiss) var dismiss
    
    var trainers: [AppUser] {
        userManager.allUsers.filter { $0.group == .trainer }
    }
    
    var body: some View {
        List {
            ForEach(MockData.courses) { course in
                CourseAssignmentRow(course: course, trainers: trainers)
            }
        }
        .navigationTitle(T("Trainer zu Kursen"))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(T("Fertig")) { dismiss() }
            }
        }
    }
}

struct CourseAssignmentRow: View {
    let course: Course
    let trainers: [AppUser]
    @StateObject private var userManager = UserManager.shared
    @State private var selectedTrainerId: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(course.title)
                .font(TDTypography.headline)
            
            HStack {
                Text(T("Trainer:"))
                    .font(TDTypography.subheadline)
                
                Picker("", selection: $selectedTrainerId) {
                    Text(T("Nicht zugewiesen")).tag(nil as String?)
                    ForEach(trainers) { trainer in
                        Text(trainer.name).tag(trainer.id as String?)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedTrainerId) { _, newValue in
                    Task { await assignTrainer(newValue) }
                }
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            selectedTrainerId = course.trainerId
        }
    }
    
    private func assignTrainer(_ trainerId: String?) async {
        guard let trainerId = trainerId,
              let trainer = trainers.first(where: { $0.id == trainerId }) else { return }
        
        var courseIds = trainer.trainerProfile?.assignedCourseIds ?? []
        if !courseIds.contains(course.id) {
            courseIds.append(course.id)
            _ = await userManager.assignCoursesToTrainer(trainerId: trainerId, courseIds: courseIds)
        }
    }
}
