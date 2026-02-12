//
//  CourseViewModel.swift
//  Tanzen mit Tatiana Drexler
//
//  ViewModel for Course management - mit Cloud-Unterstützung
//

import Foundation
import SwiftUI
import Combine

@MainActor
class CourseViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var courses: [Course] = []
    @Published var selectedCourse: Course?
    @Published var lessons: [Lesson] = []
    @Published var filter = CourseFilter()
    @Published var isLoading = false
    @Published var error: String?
    
    // Data Managers
    private var cloudManager = CloudDataManager.shared
    private var courseDataManager = CourseDataManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - User State
    @Published var currentUser: User?
    @Published var purchasedProductIds: Set<String> = []
    @Published var favoriteCourseIds: Set<String> = []
    private let userManager = UserManager.shared
    
    // MARK: - Computed Properties
    var filteredCourses: [Course] {
        courses.filter { course in
            filter.matches(course: course, isPurchased: isPurchased(course))
        }
    }
    
    var purchasedCourses: [Course] {
        courses.filter { isPurchased($0) }
    }
    
    var favoriteCourses: [Course] {
        courses.filter { favoriteCourseIds.contains($0.id) }
    }
    
    // MARK: - Initialization
    init() {
        setupNotificationObserver()
        loadData()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Notification Observer Setup
    private func setupNotificationObserver() {
        // Höre auf Kursänderungen vom CourseDataManager
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCoursesDidChange(_:)),
            name: .coursesDidChange,
            object: nil
        )

        print("🔔 CourseViewModel: Notification Observer eingerichtet")
    }

    @objc private func handleCoursesDidChange(_ notification: Notification) {
        Task { @MainActor in
            self.reloadCourses()
        }
    }
    
    // MARK: - Data Loading
    func loadData() {
        isLoading = true
        
        // Lade Favoriten aus UserDefaults
        if let savedFavorites = UserDefaults.standard.array(forKey: "favoriteCourseIds") as? [String] {
            favoriteCourseIds = Set(savedFavorites)
        }
        
        // Lade Kurse direkt vom CourseDataManager
        reloadCourses()
        
        isLoading = false
    }
    
    /// Lädt die Kurse neu vom CourseDataManager
    /// Lädt die Kurse neu vom CourseDataManager
    func reloadCourses() {
        // Immer aktualisieren - die View muss die neuen Daten sehen
        courses = courseDataManager.courses
        print("🔄 CourseViewModel: \(courses.count) Kurse geladen")
        
        // Debug: Zeige Sprachen an
        for course in courses {
            print("   - \(course.title): \(course.language.flag) \(course.language.rawValue)")
        }
    }
    
    func refreshFromCloud() async {
        await cloudManager.refresh()
    }
    
    func loadLessons(for course: Course) {
        isLoading = true
        lessons = []
        
        // Nutze CourseDataManager als primäre Quelle
        lessons = courseDataManager.lessonsFor(courseId: course.id)
        
        // Fallback auf Cloud oder MockData
        if lessons.isEmpty {
            if cloudManager.useCloudData {
                lessons = cloudManager.lessons(for: course.id)
            } else {
                lessons = MockData.lessons(for: course.id)
            }
        }
        
        isLoading = false
    }
    
    // MARK: - Course Actions
    func selectCourse(_ course: Course) {
        selectedCourse = course
        loadLessons(for: course)
    }
    
    func isPurchased(_ course: Course) -> Bool {
        userManager.hasCourseUnlocked(course.id)
    }
    
    func canAccessLesson(_ lesson: Lesson) -> Bool {
        if lesson.isPreview { return true }
        guard let course = courses.first(where: { $0.id == lesson.courseId }) else { return false }
        return isPurchased(course)
    }
    
    // MARK: - Favorites
    func toggleFavorite(_ course: Course) {
        if favoriteCourseIds.contains(course.id) {
            favoriteCourseIds.remove(course.id)
        } else {
            favoriteCourseIds.insert(course.id)
        }
        // Speichern in UserDefaults
        UserDefaults.standard.set(Array(favoriteCourseIds), forKey: "favoriteCourseIds")
    }
    
    func isFavorite(_ course: Course) -> Bool {
        favoriteCourseIds.contains(course.id)
    }
    
    // MARK: - Filter Actions
    func clearFilters() {
        filter = CourseFilter()
    }
    
    func toggleLevelFilter(_ level: CourseLevel) {
        if filter.levels.contains(level) {
            filter.levels.remove(level)
        } else {
            filter.levels.insert(level)
        }
    }
    
    func toggleStyleFilter(_ style: DanceStyle) {
        if filter.styles.contains(style) {
            filter.styles.remove(style)
        } else {
            filter.styles.insert(style)
        }
    }
    
    func toggleLanguageFilter(_ language: CourseLanguage) {
        if filter.languages.contains(language) {
            filter.languages.remove(language)
        } else {
            filter.languages.insert(language)
        }
    }
    
    // MARK: - Purchase (Mock)
    func purchaseCourse(_ course: Course) async -> Bool {
        // This will be replaced with real StoreKit 2 implementation
        isLoading = true
        
        // Simulate purchase process
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        
        purchasedProductIds.insert(course.productId)
        isLoading = false
        
        return true
    }
    
    func restorePurchases() async {
        isLoading = true
        
        // Simulate restore process
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        // In real implementation, this would sync with StoreKit
        isLoading = false
    }
}
