//
//  FreeCoursesView.swift
//  Tanzen mit Tatiana Drexler
//
//  Admin kann kostenlose Kurse festlegen
//

import SwiftUI

struct FreeCoursesView: View {
    @StateObject private var settingsManager = AppSettingsManager.shared
    @StateObject private var courseDataManager = CourseDataManager.shared
    @State private var selectedCourseIds: Set<String>
    @State private var isSaving = false
    @State private var isLoading = true
    @Environment(\.dismiss) var dismiss
    
    init() {
        _selectedCourseIds = State(initialValue: Set(AppSettingsManager.shared.settings.freeCourseIds))
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(T("Wähle die Kurse aus, die aktuell kostenlos verfügbar sein sollen. Diese Kurse können von allen Nutzern ohne Kauf angesehen werden."))
                        .font(TDTypography.caption1)
                        .foregroundColor(.secondary)
                }
                
                if isLoading {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                                .padding()
                            Spacer()
                        }
                    }
                } else if courseDataManager.courses.isEmpty {
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "film.stack")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text(T("Keine Kurse vorhanden"))
                                .font(TDTypography.body)
                                .foregroundColor(.secondary)
                            Text(T("Erstelle zuerst Kurse im Kurs-Editor"))
                                .font(TDTypography.caption1)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                } else {
                    Section(T("Kurse (%@)", "\(courseDataManager.courses.count)")) {
                        ForEach(courseDataManager.courses) { course in
                            courseRow(course)
                        }
                    }
                    
                    Section {
                        HStack {
                            Button(T("Alle auswählen")) {
                                selectedCourseIds = Set(courseDataManager.courses.map { $0.id })
                            }
                            Spacer()
                            Button(T("Keine")) {
                                selectedCourseIds.removeAll()
                            }
                        }
                        .font(TDTypography.caption1)
                        .foregroundColor(Color.accentGold)
                    }
                }
                
                Section {
                    Button {
                        Task { await saveChanges() }
                    } label: {
                        HStack {
                            Spacer()
                            if isSaving {
                                ProgressView().tint(.white)
                            } else {
                                Text(T("Speichern"))
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .listRowBackground(Color.accentGold)
                    .foregroundColor(.white)
                    .disabled(isLoading)
                }
            }
            .navigationTitle(T("Kostenlose Kurse"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(T("Abbrechen")) { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        loadCourses()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear {
                loadCourses()
            }
        }
    }
    
    @ViewBuilder
    private func courseRow(_ course: Course) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(course.title)
                    .font(TDTypography.body)
                    .fontWeight(.medium)
                
                HStack {
                    Text(course.style.rawValue)
                    Text(T("•"))
                    Text(course.level.rawValue)
                    Text(T("•"))
                    Text(course.formattedPrice)
                }
                .font(TDTypography.caption1)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if selectedCourseIds.contains(course.id) {
                HStack(spacing: 4) {
                    Text(T("KOSTENLOS"))
                        .font(TDTypography.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                }
            } else {
                Image(systemName: "circle")
                    .foregroundColor(.gray)
                    .font(.title2)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if selectedCourseIds.contains(course.id) {
                selectedCourseIds.remove(course.id)
            } else {
                selectedCourseIds.insert(course.id)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func loadCourses() {
        isLoading = true
        Task {
            await courseDataManager.loadFromFirebase()
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func saveChanges() async {
        isSaving = true
        defer { isSaving = false }
        
        _ = await settingsManager.setFreeCourses(Array(selectedCourseIds))
        dismiss()
    }
}

#Preview {
    FreeCoursesView()
}
