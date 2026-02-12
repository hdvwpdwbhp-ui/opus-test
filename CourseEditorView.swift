//
//  CourseEditorView.swift
//  Tanzen mit Tatiana Drexler
//
//  Einfacher Editor zum Erstellen und Bearbeiten von Kursen
//

import SwiftUI
import PhotosUI
import AVKit

// MARK: - Course Editor Main View
struct CourseEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var storeViewModel: StoreViewModel
    @StateObject private var courseDataManager = CourseDataManager.shared
    
    @State private var courses: [EditableCourse] = []
    @State private var selectedCourse: EditableCourse?
    @State private var showAddCourse = false
    @State private var showExportCode = false
    @State private var exportedCode = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                TDGradients.mainBackground
                    .ignoresSafeArea()
                
                if courses.isEmpty {
                    emptyState
                } else {
                    courseList
                }
            }
            .navigationTitle(T("Kurs-Editor"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(T("Schließen")) {
                        // Speichere alle Änderungen vor dem Schließen
                        saveAllChanges()
                        dismiss()
                    }
                    .foregroundColor(Color.accentGold)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showAddCourse = true
                        } label: {
                            Label(T("Neuer Kurs"), systemImage: "plus")
                        }
                        
                        Button {
                            loadExistingCourses()
                        } label: {
                            Label(T("Bestehende laden"), systemImage: "arrow.down.circle")
                        }
                        
                        if !courses.isEmpty {
                            Button {
                                generateCode()
                                showExportCode = true
                            } label: {
                                Label(T("Code exportieren"), systemImage: "doc.text")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(Color.accentGold)
                    }
                }
            }
            .sheet(isPresented: $showAddCourse) {
                AddCourseSheet(courses: $courses)
            }
            .sheet(item: $selectedCourse) { course in
                EditCourseSheet(course: binding(for: course), onDelete: {
                    // Aus lokaler Liste entfernen
                    courses.removeAll { $0.id == course.id }
                    // Aus CourseDataManager entfernen
                    courseDataManager.deleteCourse(course.id)
                    selectedCourse = nil
                })
            }
            .sheet(isPresented: $showExportCode) {
                CodeExportView(code: exportedCode)
            }
            .onAppear {
                loadExistingCourses()
            }
        }
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: TDSpacing.lg) {
            Image(systemName: "film.stack")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text(T("Keine Kurse"))
                .font(TDTypography.title2)
                .foregroundColor(.primary)
            
            Text(T("Erstelle deinen ersten Kurs oder lade die bestehenden Kurse."))
                .font(TDTypography.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, TDSpacing.xl)
            
            HStack(spacing: TDSpacing.md) {
                Button {
                    showAddCourse = true
                } label: {
                    HStack {
                        Image(systemName: "plus")
                        Text(T("Neuer Kurs"))
                    }
                }
                .buttonStyle(.tdPrimary)
                
                Button {
                    loadExistingCourses()
                } label: {
                    HStack {
                        Image(systemName: "arrow.down.circle")
                        Text(T("Laden"))
                    }
                }
                .buttonStyle(.tdSecondary)
            }
        }
    }
    
    // MARK: - Course List
    private var courseList: some View {
        ScrollView {
            LazyVStack(spacing: TDSpacing.md) {
                ForEach(courses) { course in
                    CourseEditorCard(course: course) {
                        selectedCourse = course
                    }
                }
            }
            .padding(TDSpacing.md)
        }
    }
    
    // MARK: - Helpers
    private func binding(for course: EditableCourse) -> Binding<EditableCourse> {
        guard let index = courses.firstIndex(where: { $0.id == course.id }) else {
            return .constant(course)
        }
        return Binding(
            get: { self.courses[index] },
            set: { newValue in
                self.courses[index] = newValue
                // Sofort speichern wenn sich etwas ändert
                self.saveCourse(newValue)
            }
        )
    }
    
    private func loadExistingCourses() {
        // Lade aus CourseDataManager (enthält gespeicherte Änderungen)
        courses = courseDataManager.courses.map { course in
            let courseLessons = courseDataManager.lessonsFor(courseId: course.id)
            return EditableCourse(
                id: course.id,
                title: course.title,
                description: course.description,
                level: course.level,
                style: course.style,
                language: course.language,
                price: course.price,
                productId: course.productId,
                trailerVideoName: course.trailerURL,
                lessons: courseLessons.map { lesson in
                    EditableLesson(
                        id: lesson.id,
                        title: lesson.title,
                        videoName: lesson.videoURL,
                        duration: lesson.duration,
                        notes: lesson.notes ?? "",
                        isPreview: lesson.isPreview,
                        orderIndex: lesson.orderIndex
                    )
                }
            )
        }
    }
    
    /// Speichert einen einzelnen Kurs
    private func saveCourse(_ editableCourse: EditableCourse) {
        let course = Course(
            id: editableCourse.id,
            title: editableCourse.title,
            description: editableCourse.description,
            level: editableCourse.level,
            style: editableCourse.style,
            coverURL: "\(editableCourse.style.rawValue.lowercased())_cover",
            trailerURL: editableCourse.trailerVideoName,
            price: editableCourse.price,
            productId: editableCourse.productId,
            createdAt: courseDataManager.course(by: editableCourse.id)?.createdAt ?? Date(),
            updatedAt: Date(),
            lessonCount: editableCourse.lessons.count,
            totalDuration: editableCourse.lessons.reduce(0) { $0 + $1.duration },
            trainerId: courseDataManager.course(by: editableCourse.id)?.trainerId,
            trainerName: courseDataManager.course(by: editableCourse.id)?.trainerName,
            language: editableCourse.language
        )
        
        // Prüfe ob Kurs existiert
        if courseDataManager.course(by: editableCourse.id) != nil {
            courseDataManager.updateCourse(course)
        } else {
            courseDataManager.addCourse(course)
        }
        
        // Speichere Lektionen
        let lessons = editableCourse.lessons.map { editableLesson in
            Lesson(
                id: editableLesson.id,
                courseId: editableCourse.id,
                title: editableLesson.title,
                orderIndex: editableLesson.orderIndex,
                videoURL: editableLesson.videoName,
                duration: editableLesson.duration,
                notes: editableLesson.notes.isEmpty ? nil : editableLesson.notes,
                isPreview: editableLesson.isPreview
            )
        }
        courseDataManager.setLessons(lessons, courseId: editableCourse.id)
    }
    
    /// Speichert alle Änderungen
    private func saveAllChanges() {
        for editableCourse in courses {
            saveCourse(editableCourse)
        }
    }
    
    private func generateCode() {
        var code = """
        // MARK: - Kurse
        static let courses: [Course] = [
        
        """
        
        for (index, course) in courses.enumerated() {
            let escapedDescription = course.description.replacingOccurrences(of: "\"", with: "\\\"")
            let languageString = course.language.languageCode == "de" ? "german" : course.language.languageCode == "en" ? "english" : course.language.languageCode == "ru" ? "russian" : course.language.languageCode == "cs" ? "czech" : "slovak"
            let levelString = course.level.rawValue.lowercased().replacingOccurrences(of: "ä", with: "a").replacingOccurrences(of: " ", with: "")
            let styleString = course.style.rawValue.lowercased().replacingOccurrences(of: " ", with: "_")
            let totalDuration = Int(course.lessons.reduce(0) { $0 + $1.duration })
            
            code += """
                Course(
                    id: "\(course.id)",
                    title: "\(course.title)",
                    description: "\(escapedDescription)",
                    level: .\(levelString),
                    style: .\(styleString),
                    coverURL: "\(course.id)_cover",
                    trailerURL: "\(course.trailerVideoName)",
                    price: \(course.price),
                    productId: "\(course.productId)",
                    createdAt: Date(),
                    updatedAt: Date(),
                    lessonCount: \(course.lessons.count),
                    totalDuration: \(totalDuration),
                    language: .\(languageString)
                )
            """
            if index < courses.count - 1 {
                code += ",\n"
            }
        }
        
        code += "\n    ]\n\n"
        
        code += """
            // MARK: - Lektionen
            static let lessons: [Lesson] = [
        
        """
        
        let allLessons = courses.flatMap { $0.lessons }
        for (index, lesson) in allLessons.enumerated() {
            let courseId = courses.first { $0.lessons.contains { $0.id == lesson.id } }?.id ?? ""
            let escapedNotes = lesson.notes.replacingOccurrences(of: "\"", with: "\\\"")
            code += """
                Lesson(
                    id: "\(lesson.id)",
                    courseId: "\(courseId)",
                    title: "\(lesson.title)",
                    orderIndex: \(lesson.orderIndex),
                    videoURL: "\(lesson.videoName)",
                    duration: \(lesson.duration),
                    notes: "\(escapedNotes)",
                    isPreview: \(lesson.isPreview)
                )
            """
            if index < allLessons.count - 1 {
                code += ",\n"
            }
        }
        
        code += "\n    ]"
        
        exportedCode = code
    }
}

// MARK: - Editable Models
struct EditableCourse: Identifiable, Equatable {
    var id: String
    var title: String
    var description: String
    var level: CourseLevel
    var style: DanceStyle
    var language: CourseLanguage
    var price: Decimal
    var productId: String
    var trailerVideoName: String
    var lessons: [EditableLesson]
    
    static func == (lhs: EditableCourse, rhs: EditableCourse) -> Bool {
        lhs.id == rhs.id
    }
}

struct EditableLesson: Identifiable, Equatable {
    var id: String
    var title: String
    var videoName: String
    var duration: TimeInterval
    var notes: String
    var isPreview: Bool
    var orderIndex: Int
}

// MARK: - Course Editor Card
struct CourseEditorCard: View {
    let course: EditableCourse
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: TDSpacing.md) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: TDRadius.md)
                        .fill(
                            LinearGradient(
                                colors: [Color.accentGold.opacity(0.4), Color.purple.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 70, height: 70)
                    
                    Image(systemName: course.style.icon)
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                }
                
                // Info
                VStack(alignment: .leading, spacing: TDSpacing.xs) {
                    Text(course.title)
                        .font(TDTypography.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    HStack(spacing: TDSpacing.sm) {
                        Label(course.level.rawValue, systemImage: "chart.bar")
                        Label(course.style.rawValue, systemImage: course.style.icon)
                    }
                    .font(TDTypography.caption1)
                    .foregroundColor(.secondary)
                    
                    HStack(spacing: TDSpacing.sm) {
                        Label("\(course.lessons.count) Lektionen", systemImage: "play.rectangle")
                        Label("€\(NSDecimalNumber(decimal: course.price).doubleValue.formatted(.number.precision(.fractionLength(2))))", systemImage: "eurosign")
                    }
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

// MARK: - Add Course Sheet
struct AddCourseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var courses: [EditableCourse]
    @StateObject private var settingsManager = AppSettingsManager.shared
    
    @State private var title = ""
    @State private var description = ""
    @State private var level: CourseLevel = .beginner
    @State private var style: DanceStyle = .waltz
    @State private var language: CourseLanguage = .german
    @State private var price = "29.99"
    @State private var isFree = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                TDGradients.mainBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: TDSpacing.lg) {
                        // Title
                        FormField(title: "Kurstitel") {
                            TextField(T("z.B. Wiener Walzer für Anfänger"), text: $title)
                                .textFieldStyle(GlassTextFieldStyle())
                        }
                        
                        // Description
                        FormField(title: "Beschreibung") {
                            TextEditor(text: $description)
                                .frame(minHeight: 100)
                                .padding(TDSpacing.sm)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(TDRadius.md)
                        }
                        
                        // Level
                        FormField(title: "Schwierigkeitsgrad") {
                            Picker("Level", selection: $level) {
                                ForEach(CourseLevel.allCases) { l in
                                    Text(l.rawValue).tag(l)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        
                        // Style
                        FormField(title: "Tanzstil") {
                            Picker("Stil", selection: $style) {
                                ForEach(DanceStyle.allCases) { s in
                                    Label(s.rawValue, systemImage: s.icon).tag(s)
                                }
                            }
                            .pickerStyle(.menu)
                            .padding(TDSpacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(TDRadius.md)
                        }
                        
                        // Language
                        FormField(title: "Sprache") {
                            Picker("Sprache", selection: $language) {
                                ForEach(CourseLanguage.allCases) { lang in
                                    HStack {
                                        Text(lang.flag)
                                        Text(lang.rawValue)
                                    }
                                    .tag(lang)
                                }
                            }
                            .pickerStyle(.menu)
                            .padding(TDSpacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(TDRadius.md)
                            
                            // Aktuelle Auswahl anzeigen
                            HStack {
                                Text(language.flag)
                                Text(language.rawValue)
                            }
                            .font(TDTypography.caption1)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                        }
                        
                        // Price
                        FormField(title: "Preis (€)") {
                            TextField(T("29.99"), text: $price)
                                .textFieldStyle(GlassTextFieldStyle())
                                .keyboardType(.decimalPad)
                                .disabled(isFree)
                                .opacity(isFree ? 0.5 : 1)
                        }
                        
                        // Free Toggle
                        FormField(title: "Kostenlos") {
                            Toggle("Kurs kostenlos anbieten", isOn: $isFree)
                                .tint(Color.accentGold)
                            
                            if isFree {
                                Text(T("Dieser Kurs ist für alle Nutzer kostenlos zugänglich"))
                                    .font(TDTypography.caption1)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    .padding(TDSpacing.md)
                }
            }
            .navigationTitle(T("Neuer Kurs"))
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
                        createCourse()
                        dismiss()
                    }
                    .foregroundColor(Color.accentGold)
                    .fontWeight(.semibold)
                    .disabled(title.isEmpty)
                }
            }
        }
    }
    
    private func createCourse() {
        let courseDataManager = CourseDataManager.shared
        let courseNumber = courseDataManager.courses.count + courses.count + 1
        let courseId = "course_\(String(format: "%03d", courseNumber))"
        let styleName = style.rawValue.lowercased().replacingOccurrences(of: " ", with: "_").replacingOccurrences(of: "-", with: "_")
        
        let newCourse = EditableCourse(
            id: courseId,
            title: title,
            description: description,
            level: level,
            style: style,
            language: language,
            price: Decimal(string: price) ?? 29.99,
            productId: "com.tatianadrexler.dance.\(styleName)_\(level.rawValue.lowercased())",
            trailerVideoName: "\(styleName)_trailer",
            lessons: []
        )
        
        courses.append(newCourse)
        
        // Sofort in CourseDataManager speichern
        let course = Course(
            id: courseId,
            title: title,
            description: description,
            level: level,
            style: style,
            coverURL: "\(styleName)_cover",
            trailerURL: "\(styleName)_trailer",
            price: Decimal(string: price) ?? 29.99,
            productId: "com.tatianadrexler.dance.\(styleName)_\(level.rawValue.lowercased())",
            createdAt: Date(),
            updatedAt: Date(),
            lessonCount: 0,
            totalDuration: 0,
            trainerId: nil,
            trainerName: nil,
            language: language
        )
        courseDataManager.addCourse(course)
        
        // Falls kostenlos markiert, zu kostenlosen Kursen hinzufügen
        if isFree {
            Task {
                await settingsManager.addFreeCourse(courseId)
            }
        }
    }
}

// MARK: - Edit Course Sheet
struct EditCourseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var course: EditableCourse
    let onDelete: () -> Void
    
    @StateObject private var courseDataManager = CourseDataManager.shared
    @State private var showAddLesson = false
    @State private var selectedLesson: EditableLesson?
    @State private var showDeleteConfirm = false
    @State private var selectedLanguage: CourseLanguage = .german
    
    var body: some View {
        NavigationStack {
            ZStack {
                TDGradients.mainBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: TDSpacing.lg) {
                        // Course Details Section
                        courseDetailsSection
                        
                        // Trailer Section
                        trailerSection
                        
                        // Lessons Section
                        lessonsSection
                        
                        // Danger Zone
                        dangerZone
                    }
                    .padding(TDSpacing.md)
                }
            }
            .navigationTitle(T("Kurs bearbeiten"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(T("Speichern")) {
                        saveCourseChanges()
                        dismiss()
                    }
                    .foregroundColor(Color.accentGold)
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showAddLesson) {
                AddLessonSheet(course: $course)
            }
            .sheet(item: $selectedLesson) { lesson in
                if let index = course.lessons.firstIndex(where: { $0.id == lesson.id }) {
                    EditLessonSheet(lesson: $course.lessons[index], onDelete: {
                        course.lessons.removeAll { $0.id == lesson.id }
                        reorderLessons()
                    })
                }
            }
            .alert(T("Kurs löschen?"), isPresented: $showDeleteConfirm) {
                Button(T("Abbrechen"), role: .cancel) { }
                Button(T("Löschen"), role: .destructive) {
                    onDelete()
                    dismiss()
                }
            } message: {
                Text(T("Der Kurs und alle Lektionen werden gelöscht."))
            }
        }
    }
    
    // MARK: - Course Details Section
    private var courseDetailsSection: some View {
        VStack(alignment: .leading, spacing: TDSpacing.md) {
            SectionHeader(title: "Kursdetails", icon: "info.circle")
            
            FormField(title: "Titel") {
                TextField(T("Kurstitel"), text: $course.title)
                    .textFieldStyle(GlassTextFieldStyle())
            }
            
            FormField(title: "Beschreibung") {
                TextEditor(text: $course.description)
                    .frame(minHeight: 80)
                    .padding(TDSpacing.sm)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(TDRadius.md)
            }
            
            HStack(spacing: TDSpacing.md) {
                FormField(title: "Level") {
                    Picker("", selection: $course.level) {
                        ForEach(CourseLevel.allCases) { l in
                            Text(l.rawValue).tag(l)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(TDSpacing.sm)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(TDRadius.md)
                }
                
                FormField(title: "Preis (€)") {
                    TextField(T("29.99"), value: $course.price, format: .number)
                        .textFieldStyle(GlassTextFieldStyle())
                        .keyboardType(.decimalPad)
                }
            }
            
            FormField(title: "Tanzstil") {
                Picker("", selection: $course.style) {
                    ForEach(DanceStyle.allCases) { s in
                        Label(s.rawValue, systemImage: s.icon).tag(s)
                    }
                }
                .pickerStyle(.menu)
                .padding(TDSpacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(TDRadius.md)
            }
            
            FormField(title: "Sprache") {
                Picker("Sprache", selection: $selectedLanguage) {
                    ForEach(CourseLanguage.allCases) { lang in
                        HStack {
                            Text(lang.flag)
                            Text(lang.rawValue)
                        }
                        .tag(lang)
                    }
                }
                .pickerStyle(.menu)
                .padding(TDSpacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(TDRadius.md)
                .onChange(of: selectedLanguage) { _, newValue in
                    course.language = newValue
                }
                .onAppear {
                    selectedLanguage = course.language
                }
            }
            
            // Aktuelle Sprache anzeigen
            HStack {
                Text(T("Aktuell:"))
                    .font(TDTypography.caption1)
                    .foregroundColor(.secondary)
                Text(selectedLanguage.flag)
                Text(selectedLanguage.rawValue)
                    .font(TDTypography.body)
                    .fontWeight(.medium)
            }
            .padding(.top, TDSpacing.xs)
        }
        .padding(TDSpacing.md)
        .glassBackground()
    }
    
    // MARK: - Trailer Section
    private var trailerSection: some View {
        VStack(alignment: .leading, spacing: TDSpacing.md) {
            SectionHeader(title: "Trailer-Video", icon: "film")
            
            FormField(title: "Video-Dateiname (ohne .mp4)") {
                TextField(T("z.B. walzer_trailer"), text: $course.trailerVideoName)
                    .textFieldStyle(GlassTextFieldStyle())
            }
            
            // Video Preview
            if VideoHelper.isVideoAvailable(course.trailerVideoName) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(T("Video gefunden"))
                        .font(TDTypography.caption1)
                        .foregroundColor(.green)
                }
            } else {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(T("Video nicht gefunden: %@", "\(course.trailerVideoName).mp4"))
                        .font(TDTypography.caption1)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(TDSpacing.md)
        .glassBackground()
    }
    
    // MARK: - Lessons Section
    private var lessonsSection: some View {
        VStack(alignment: .leading, spacing: TDSpacing.md) {
            HStack {
                SectionHeader(title: "Lektionen (\(course.lessons.count))", icon: "play.rectangle")
                
                Spacer()
                
                Button {
                    showAddLesson = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color.accentGold)
                }
            }
            
            if course.lessons.isEmpty {
                Text(T("Noch keine Lektionen. Tippe auf + um eine hinzuzufügen."))
                    .font(TDTypography.caption1)
                    .foregroundColor(.secondary)
                    .padding(.vertical, TDSpacing.md)
            } else {
                ForEach(course.lessons.sorted { $0.orderIndex < $1.orderIndex }) { lesson in
                    LessonEditorRow(lesson: lesson) {
                        selectedLesson = lesson
                    }
                }
            }
        }
        .padding(TDSpacing.md)
        .glassBackground()
    }
    
    // MARK: - Danger Zone
    private var dangerZone: some View {
        VStack(alignment: .leading, spacing: TDSpacing.md) {
            SectionHeader(title: "Gefahrenzone", icon: "exclamationmark.triangle")
            
            Button {
                showDeleteConfirm = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text(T("Kurs löschen"))
                }
                .font(TDTypography.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(TDSpacing.md)
                .background(Color.red)
                .cornerRadius(TDRadius.md)
            }
        }
        .padding(TDSpacing.md)
        .glassBackground()
    }
    
    private func reorderLessons() {
        for i in course.lessons.indices {
            course.lessons[i].orderIndex = i + 1
        }
    }
    
    /// Speichert alle Änderungen am Kurs
    private func saveCourseChanges() {
        // Aktualisiere die Sprache im course binding
        course.language = selectedLanguage
        
        // Erstelle das Course-Objekt mit allen aktuellen Werten
        let styleName = course.style.rawValue.lowercased().replacingOccurrences(of: " ", with: "_").replacingOccurrences(of: "-", with: "_")
        
        let updatedCourse = Course(
            id: course.id,
            title: course.title,
            description: course.description,
            level: course.level,
            style: course.style,
            coverURL: "\(styleName)_cover",
            trailerURL: course.trailerVideoName,
            price: course.price,
            productId: course.productId,
            createdAt: courseDataManager.course(by: course.id)?.createdAt ?? Date(),
            updatedAt: Date(),
            lessonCount: course.lessons.count,
            totalDuration: course.lessons.reduce(0) { $0 + $1.duration },
            trainerId: courseDataManager.course(by: course.id)?.trainerId,
            trainerName: courseDataManager.course(by: course.id)?.trainerName,
            language: selectedLanguage  // Wichtig: Verwende selectedLanguage!
        )
        
        // Speichere im CourseDataManager
        courseDataManager.updateCourse(updatedCourse)
        
        // Speichere auch die Lektionen
        let lessonsToSave = course.lessons.map { editableLesson in
            Lesson(
                id: editableLesson.id,
                courseId: course.id,
                title: editableLesson.title,
                orderIndex: editableLesson.orderIndex,
                videoURL: editableLesson.videoName,
                duration: editableLesson.duration,
                notes: editableLesson.notes.isEmpty ? nil : editableLesson.notes,
                isPreview: editableLesson.isPreview
            )
        }
        courseDataManager.setLessons(lessonsToSave, courseId: course.id)
        
        print("💾 Kurs gespeichert: \(course.title) - Sprache: \(selectedLanguage.flag) \(selectedLanguage.rawValue)")
    }
}

// MARK: - Lesson Editor Row
struct LessonEditorRow: View {
    let lesson: EditableLesson
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: TDSpacing.md) {
                // Order Number
                ZStack {
                    Circle()
                        .fill(Color.accentGold.opacity(0.3))
                        .frame(width: 36, height: 36)
                    
                    Text("\(lesson.orderIndex)")
                        .font(TDTypography.headline)
                        .foregroundColor(Color.accentGold)
                }
                
                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(lesson.title)
                        .font(TDTypography.body)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    HStack(spacing: TDSpacing.sm) {
                        if lesson.isPreview {
                            Text(T("GRATIS"))
                                .font(TDTypography.caption2)
                                .foregroundColor(.green)
                        }
                        
                        Text(formatDuration(lesson.duration))
                            .font(TDTypography.caption1)
                            .foregroundColor(.secondary)
                        
                        if !VideoHelper.isVideoAvailable(lesson.videoName) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14))
            }
            .padding(TDSpacing.sm)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(TDRadius.sm)
        }
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - Add Lesson Sheet
struct AddLessonSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var course: EditableCourse
    
    @State private var title = ""
    @State private var videoName = ""
    @State private var durationMinutes = "5"
    @State private var notes = ""
    @State private var isPreview = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                TDGradients.mainBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: TDSpacing.lg) {
                        FormField(title: "Lektions-Titel") {
                            TextField(T("z.B. Der Grundschritt"), text: $title)
                                .textFieldStyle(GlassTextFieldStyle())
                        }
                        
                        FormField(title: "Video-Dateiname (ohne .mp4)") {
                            TextField(T("z.B. walzer_01_grundschritt"), text: $videoName)
                                .textFieldStyle(GlassTextFieldStyle())
                        }
                        
                        FormField(title: "Dauer (Minuten)") {
                            TextField(T("5"), text: $durationMinutes)
                                .textFieldStyle(GlassTextFieldStyle())
                                .keyboardType(.numberPad)
                        }
                        
                        FormField(title: "Notizen") {
                            TextField(T("Tipps für die Lektion..."), text: $notes)
                                .textFieldStyle(GlassTextFieldStyle())
                        }
                        
                        Toggle(isOn: $isPreview) {
                            VStack(alignment: .leading) {
                                Text(T("Gratis-Vorschau"))
                                    .font(TDTypography.body)
                                Text(T("Diese Lektion kann ohne Kauf angesehen werden"))
                                    .font(TDTypography.caption1)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .tint(Color.accentGold)
                        .padding(TDSpacing.md)
                        .glassBackground()
                    }
                    .padding(TDSpacing.md)
                }
            }
            .navigationTitle(T("Neue Lektion"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(T("Abbrechen")) {
                        dismiss()
                    }
                    .foregroundColor(Color.accentGold)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(T("Hinzufügen")) {
                        addLesson()
                        dismiss()
                    }
                    .foregroundColor(Color.accentGold)
                    .fontWeight(.semibold)
                    .disabled(title.isEmpty || videoName.isEmpty)
                }
            }
        }
    }
    
    private func addLesson() {
        let lessonNumber = course.lessons.count + 1
        let lessonId = "\(course.id)_lesson_\(String(format: "%02d", lessonNumber))"
        
        let newLesson = EditableLesson(
            id: lessonId,
            title: title,
            videoName: videoName,
            duration: TimeInterval((Int(durationMinutes) ?? 5) * 60),
            notes: notes,
            isPreview: isPreview,
            orderIndex: lessonNumber
        )
        
        course.lessons.append(newLesson)
    }
}

// MARK: - Edit Lesson Sheet
struct EditLessonSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var lesson: EditableLesson
    let onDelete: () -> Void
    
    @State private var durationMinutes: String = ""
    @State private var showDeleteConfirm = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                TDGradients.mainBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: TDSpacing.lg) {
                        FormField(title: "Lektions-Titel") {
                            TextField(T("Titel"), text: $lesson.title)
                                .textFieldStyle(GlassTextFieldStyle())
                        }
                        
                        FormField(title: "Video-Dateiname (ohne .mp4)") {
                            TextField(T("video_name"), text: $lesson.videoName)
                                .textFieldStyle(GlassTextFieldStyle())
                        }
                        
                        // Video Status
                        if VideoHelper.isVideoAvailable(lesson.videoName) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text(T("Video gefunden: %@", "\(lesson.videoName).mp4"))
                                    .font(TDTypography.caption1)
                                    .foregroundColor(.green)
                            }
                            .padding(TDSpacing.sm)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(TDRadius.sm)
                        } else {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text(T("Video nicht gefunden: %@", "\(lesson.videoName).mp4"))
                                    .font(TDTypography.caption1)
                                    .foregroundColor(.orange)
                            }
                            .padding(TDSpacing.sm)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(TDRadius.sm)
                        }
                        
                        FormField(title: "Dauer (Minuten)") {
                            TextField(T("5"), text: $durationMinutes)
                                .textFieldStyle(GlassTextFieldStyle())
                                .keyboardType(.numberPad)
                                .onChange(of: durationMinutes) { _, newValue in
                                    if let minutes = Int(newValue) {
                                        lesson.duration = TimeInterval(minutes * 60)
                                    }
                                }
                        }
                        
                        FormField(title: "Notizen") {
                            TextField(T("Tipps..."), text: $lesson.notes)
                                .textFieldStyle(GlassTextFieldStyle())
                        }
                        
                        Toggle(isOn: $lesson.isPreview) {
                            VStack(alignment: .leading) {
                                Text(T("Gratis-Vorschau"))
                                    .font(TDTypography.body)
                                Text(T("Diese Lektion kann ohne Kauf angesehen werden"))
                                    .font(TDTypography.caption1)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .tint(Color.accentGold)
                        .padding(TDSpacing.md)
                        .glassBackground()
                        
                        // Delete Button
                        Button {
                            showDeleteConfirm = true
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text(T("Lektion löschen"))
                            }
                            .font(TDTypography.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(TDSpacing.md)
                            .background(Color.red)
                            .cornerRadius(TDRadius.md)
                        }
                    }
                    .padding(TDSpacing.md)
                }
            }
            .navigationTitle(T("Lektion bearbeiten"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(T("Fertig")) {
                        dismiss()
                    }
                    .foregroundColor(Color.accentGold)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                durationMinutes = "\(lesson.duration / 60)"
            }
            .alert(T("Lektion löschen?"), isPresented: $showDeleteConfirm) {
                Button(T("Abbrechen"), role: .cancel) { }
                Button(T("Löschen"), role: .destructive) {
                    onDelete()
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Code Export View
struct CodeExportView: View {
    let code: String
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                TDGradients.mainBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: TDSpacing.md) {
                        // Info
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(Color.accentGold)
                            Text(T("Kopiere diesen Code in MockData.swift"))
                                .font(TDTypography.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(TDSpacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassBackground()
                        
                        // Code
                        Text(code)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.primary)
                            .padding(TDSpacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(TDRadius.md)
                        
                        // Copy Button
                        Button {
                            UIPasteboard.general.string = code
                            copied = true
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                copied = false
                            }
                        } label: {
                            HStack {
                                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                Text(copied ? "Kopiert!" : "Code kopieren")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.tdPrimary)
                    }
                    .padding(TDSpacing.md)
                }
            }
            .navigationTitle(T("Code exportieren"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(T("Fertig")) {
                        dismiss()
                    }
                    .foregroundColor(Color.accentGold)
                }
            }
        }
    }
}

// MARK: - Helper Views
struct FormField<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: TDSpacing.xs) {
            Text(title)
                .font(TDTypography.subheadline)
                .foregroundColor(.secondary)
            
            content
        }
    }
}

struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack(spacing: TDSpacing.sm) {
            Image(systemName: icon)
                .foregroundColor(Color.accentGold)
            Text(title)
                .font(TDTypography.headline)
                .foregroundColor(.primary)
        }
    }
}

struct GlassTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(TDSpacing.md)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(TDRadius.md)
    }
}

#Preview {
    CourseEditorView()
        .environmentObject(StoreViewModel())
}
