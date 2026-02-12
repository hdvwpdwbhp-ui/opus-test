//
//  CourseDataManager.swift
//  Tanzen mit Tatiana Drexler
//
//  Zentraler Manager für Kursdaten mit Firebase-Synchronisation
//  Änderungen werden in Echtzeit synchronisiert
//

import Foundation
import Combine

// Notification für Kursänderungen
extension Notification.Name {
    static let coursesDidChange = Notification.Name("coursesDidChange")
}

@MainActor
class CourseDataManager: ObservableObject {
    static let shared = CourseDataManager()
    
    @Published var courses: [Course] = []
    @Published var lessons: [String: [Lesson]] = [:]
    @Published var isSyncing: Bool = false
    @Published var lastSync: Date?
    @Published var syncError: String?
    
    private let firebase = FirebaseService.shared
    private let localCoursesKey = "local_courses_backup"
    private let localLessonsKey = "local_lessons_backup"
    
    private init() {
        // Lade lokale Daten als Backup
        loadLocalBackup()
        
        // Starte Firebase Echtzeit-Listener
        startRealtimeSync()
        
        // Initiales Laden von Firebase
        Task {
            await loadFromFirebase()
        }
    }
    
    // MARK: - Firebase Sync
    
    /// Lädt Kurse von Firebase
    func loadFromFirebase() async {
        isSyncing = true
        syncError = nil
        defer { isSyncing = false }
        
        let firebaseCourses = await firebase.loadCourses()
        
        if !firebaseCourses.isEmpty {
            courses = firebaseCourses
            
            // Lade Lektionen für jeden Kurs
            for course in firebaseCourses {
                let courseLessons = await firebase.loadLessons(for: course.id)
                lessons[course.id] = courseLessons
            }
            
            lastSync = Date()
            saveLocalBackup()
            notifyChanges()
            print("🔥 Firebase Sync abgeschlossen: \(courses.count) Kurse")
        } else if courses.isEmpty {
            // Fallback auf MockData wenn Firebase leer ist
            courses = MockData.courses
            for course in courses {
                lessons[course.id] = MockData.lessons(for: course.id)
            }
            
            // Lade MockData zu Firebase hoch
            await uploadToFirebase()
        }
    }
    
    /// Startet Echtzeit-Listener
    private func startRealtimeSync() {
        firebase.startCoursesListener { [weak self] updatedCourses in
            Task { @MainActor in
                guard let self = self else { return }
                self.courses = updatedCourses
                self.lastSync = Date()
                self.saveLocalBackup()
                self.notifyChanges()
            }
        }
    }
    
    /// Lädt alle Daten zu Firebase hoch
    func uploadToFirebase() async {
        isSyncing = true
        defer { isSyncing = false }
        
        let success = await firebase.saveAllData(courses: courses, lessons: lessons)
        if success {
            lastSync = Date()
            print("🔥 Alle Daten zu Firebase hochgeladen")
        } else {
            syncError = firebase.error
        }
    }
    
    // MARK: - Local Backup
    
    private func loadLocalBackup() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        if let data = UserDefaults.standard.data(forKey: localCoursesKey),
           let savedCourses = try? decoder.decode([Course].self, from: data) {
            courses = savedCourses
        }
        
        if let data = UserDefaults.standard.data(forKey: localLessonsKey),
           let savedLessons = try? decoder.decode([String: [Lesson]].self, from: data) {
            lessons = savedLessons
        }
    }
    
    private func saveLocalBackup() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        if let data = try? encoder.encode(courses) {
            UserDefaults.standard.set(data, forKey: localCoursesKey)
        }
        if let data = try? encoder.encode(lessons) {
            UserDefaults.standard.set(data, forKey: localLessonsKey)
        }
    }
    
    // MARK: - Notifications
    
    private func notifyChanges() {
        NotificationCenter.default.post(name: .coursesDidChange, object: nil)
    }
    
    // MARK: - Course CRUD
    
    func updateCourse(_ course: Course) {
        if let index = courses.firstIndex(where: { $0.id == course.id }) {
            courses[index] = course
            saveLocalBackup()
            notifyChanges()
            
            Task {
                await firebase.saveCourse(course)
            }
        }
    }
    
    func addCourse(_ course: Course) {
        courses.append(course)
        lessons[course.id] = []
        saveLocalBackup()
        notifyChanges()
        
        Task {
            await firebase.saveCourse(course)
        }
    }
    
    func deleteCourse(_ courseId: String) {
        courses.removeAll { $0.id == courseId }
        lessons.removeValue(forKey: courseId)
        saveLocalBackup()
        notifyChanges()
        
        Task {
            await firebase.deleteCourse(courseId)
        }
    }
    
    func course(by id: String) -> Course? {
        courses.first { $0.id == id }
    }
    
    // MARK: - Lesson CRUD
    
    func lessonsFor(courseId: String) -> [Lesson] {
        lessons[courseId] ?? []
    }
    
    func setLessons(_ newLessons: [Lesson], courseId: String) {
        lessons[courseId] = newLessons
        updateCourseStats(courseId: courseId)
        saveLocalBackup()
        
        Task {
            await firebase.saveLessons(newLessons, for: courseId)
        }
    }
    
    func addLesson(_ lesson: Lesson, courseId: String) {
        if lessons[courseId] == nil {
            lessons[courseId] = []
        }
        lessons[courseId]?.append(lesson)
        updateCourseStats(courseId: courseId)
        saveLocalBackup()
        notifyChanges()
        
        Task {
            if let courseLessons = lessons[courseId] {
                _ = await firebase.saveLessons(courseLessons, for: courseId)
            }
        }
    }
    
    func deleteLesson(_ lessonId: String, courseId: String) {
        lessons[courseId]?.removeAll { $0.id == lessonId }
        updateCourseStats(courseId: courseId)
        saveLocalBackup()
        notifyChanges()
        
        Task {
            if let courseLessons = lessons[courseId] {
                _ = await firebase.saveLessons(courseLessons, for: courseId)
            }
        }
    }
    
    private func updateCourseStats(courseId: String) {
        guard let courseLessons = lessons[courseId],
              let index = courses.firstIndex(where: { $0.id == courseId }) else { return }
        
        let course = courses[index]
        let updatedCourse = Course(
            id: course.id,
            title: course.title,
            description: course.description,
            level: course.level,
            style: course.style,
            coverURL: course.coverURL,
            trailerURL: course.trailerURL,
            price: course.price,
            productId: course.productId,
            createdAt: course.createdAt,
            updatedAt: Date(),
            lessonCount: courseLessons.count,
            totalDuration: courseLessons.reduce(0) { $0 + $1.duration },
            trainerId: course.trainerId,
            trainerName: course.trainerName,
            language: course.language
        )
        courses[index] = updatedCourse
    }
    
    // MARK: - Utility
    
    func forceRefresh() {
        Task {
            await loadFromFirebase()
        }
    }
    
    func resetToDefault() {
        courses = MockData.courses
        lessons = [:]
        for course in courses {
            lessons[course.id] = MockData.lessons(for: course.id)
        }
        saveLocalBackup()
        notifyChanges()
        
        Task {
            await uploadToFirebase()
        }
    }
}
