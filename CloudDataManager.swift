//
//  CloudDataManager.swift
//  Tanzen mit Tatiana Drexler
//
//  Verwaltet das Laden von Kursdaten aus der Cloud
//  Nutzt Firebase für Kursdaten
//

import Foundation
import SwiftUI
import Combine

@MainActor
class CloudDataManager: ObservableObject {
    
    static let shared = CloudDataManager()
    
    // MARK: - Published Properties
    @Published var courses: [Course] = []
    @Published var lessons: [Lesson] = []
    @Published var isLoading = false
    @Published var lastSync: Date?
    @Published var errorMessage: String?
    @Published var useCloudData = false
    
    // Cache Keys
    private let coursesCacheKey = "cachedCourses"
    private let lessonsCacheKey = "cachedLessons"
    private let lastSyncKey = "lastSyncDate"
    
    // MARK: - Initialization
    private init() {
        loadCachedData()
    }
    
    // MARK: - Load Data from Firebase
    func loadCoursesFromCloud() async {
        isLoading = true
        errorMessage = nil
        
        let firebaseCourses = await FirebaseService.shared.loadCourses()
        
        if !firebaseCourses.isEmpty {
            courses = firebaseCourses
            
            // Lade Lektionen für jeden Kurs
            var allLessons: [Lesson] = []
            for course in firebaseCourses {
                let courseLessons = await FirebaseService.shared.loadLessons(for: course.id)
                allLessons.append(contentsOf: courseLessons)
            }
            lessons = allLessons
            
            lastSync = Date()
            useCloudData = true
            saveCachedData()
            
            print("✅ \(courses.count) Kurse und \(lessons.count) Lektionen von Firebase geladen")
        } else {
            // Fallback zu Cache oder MockData
            if courses.isEmpty {
                courses = MockData.courses
                lessons = MockData.lessons
                useCloudData = false
            }
            errorMessage = "Keine Daten in Firebase gefunden"
        }
        
        isLoading = false
    }
    
    // MARK: - Get Lessons for Course
    func lessons(for courseId: String) -> [Lesson] {
        lessons.filter { $0.courseId == courseId }.sorted { $0.orderIndex < $1.orderIndex }
    }
    
    // MARK: - Video URL
    func getVideoURL(for videoName: String) -> URL? {
        if useCloudData && CloudConfig.isConfigured {
            return CloudConfig.videoURL(for: videoName)
        } else {
            return VideoHelper.getVideoURL(for: videoName)
        }
    }
    
    // MARK: - Cache Management
    private func loadCachedData() {
        if let lastSyncData = UserDefaults.standard.object(forKey: lastSyncKey) as? Date {
            lastSync = lastSyncData
        }
        
        if let coursesData = UserDefaults.standard.data(forKey: coursesCacheKey),
           let cachedCourses = try? JSONDecoder().decode([Course].self, from: coursesData) {
            courses = cachedCourses
        }
        
        if let lessonsData = UserDefaults.standard.data(forKey: lessonsCacheKey),
           let cachedLessons = try? JSONDecoder().decode([Lesson].self, from: lessonsData) {
            lessons = cachedLessons
        }
        
        if courses.isEmpty {
            courses = MockData.courses
            lessons = MockData.lessons
            useCloudData = false
        }
    }
    
    private func saveCachedData() {
        UserDefaults.standard.set(lastSync, forKey: lastSyncKey)
        
        if let coursesData = try? JSONEncoder().encode(courses) {
            UserDefaults.standard.set(coursesData, forKey: coursesCacheKey)
        }
        
        if let lessonsData = try? JSONEncoder().encode(lessons) {
            UserDefaults.standard.set(lessonsData, forKey: lessonsCacheKey)
        }
    }
    
    func clearCache() {
        UserDefaults.standard.removeObject(forKey: coursesCacheKey)
        UserDefaults.standard.removeObject(forKey: lessonsCacheKey)
        UserDefaults.standard.removeObject(forKey: lastSyncKey)
        courses = MockData.courses
        lessons = MockData.lessons
        useCloudData = false
        lastSync = nil
    }
    
    func refresh() async {
        await loadCoursesFromCloud()
    }
}
