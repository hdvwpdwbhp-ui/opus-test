//
//  MockData.swift
//  Tanzen mit Tatiana Drexler
//
//  Kursdaten - Videos werden lokal im App Bundle gespeichert
//  Um neue Videos hinzuzufügen:
//  1. Video-Dateien in Xcode ziehen (MP4 Format)
//  2. Hier den Dateinamen eintragen (ohne .mp4 Endung)
//  3. App-Update veröffentlichen
//

import Foundation

struct MockData {
    
    // MARK: - Kurse
    static let courses: [Course] = [
        Course(
            id: "course_001",
            title: "Wiener Walzer für Anfänger",
            description: "Lernen Sie die Grundlagen des eleganten Wiener Walzers. In diesem Kurs führt Sie Tatiana Drexler durch die wichtigsten Schritte und Figuren, die Sie für Ihren ersten Ballabend benötigen.",
            level: .beginner,
            style: .viennese_waltz,
            coverURL: "waltz_cover",
            trailerURL: "walzer_trailer",
            price: 29.99,
            productId: "com.tatianadrexler.dance.waltz_beginner",
            createdAt: Date().addingTimeInterval(-86400 * 30),
            updatedAt: Date().addingTimeInterval(-86400 * 5),
            lessonCount: 3,
            totalDuration: 2700
        ),
        Course(
            id: "course_002",
            title: "Tango Argentino Intensiv",
            description: "Tauchen Sie ein in die leidenschaftliche Welt des Tango Argentino! Dieser Kurs für Fortgeschrittene vermittelt Ihnen komplexe Figuren und das typische Tango-Feeling.",
            level: .intermediate,
            style: .tango,
            coverURL: "tango_cover",
            trailerURL: "tango_trailer",
            price: 49.99,
            productId: "com.tatianadrexler.dance.tango_intensive",
            createdAt: Date().addingTimeInterval(-86400 * 60),
            updatedAt: Date().addingTimeInterval(-86400 * 10),
            lessonCount: 3,
            totalDuration: 3600
        ),
        Course(
            id: "course_003",
            title: "Salsa Cubana Masterclass",
            description: "Bringen Sie Feuer auf die Tanzfläche! Diese Masterclass zeigt Ihnen fortgeschrittene Salsa-Techniken und beeindruckende Kombinationen.",
            level: .advanced,
            style: .salsa,
            coverURL: "salsa_cover",
            trailerURL: "salsa_trailer",
            price: 59.99,
            productId: "com.tatianadrexler.dance.salsa_masterclass",
            createdAt: Date().addingTimeInterval(-86400 * 15),
            updatedAt: Date().addingTimeInterval(-86400 * 2),
            lessonCount: 3,
            totalDuration: 4200
        ),
        Course(
            id: "course_004",
            title: "Discofox Basics",
            description: "Der Discofox ist der vielseitigste Paartanz für jede Party! Lernen Sie die Grundschritte und wie Sie zu fast jeder Musik tanzen können.",
            level: .beginner,
            style: .discofox,
            coverURL: "discofox_cover",
            trailerURL: "discofox_trailer",
            price: 24.99,
            productId: "com.tatianadrexler.dance.discofox_basics",
            createdAt: Date().addingTimeInterval(-86400 * 45),
            updatedAt: Date().addingTimeInterval(-86400 * 7),
            lessonCount: 3,
            totalDuration: 2400
        )
    ]
    
    // MARK: - Lektionen
    static let lessons: [Lesson] = [
        // Wiener Walzer
        Lesson(
            id: "lesson_001_01",
            courseId: "course_001",
            title: "Die richtige Tanzhaltung",
            orderIndex: 1,
            videoURL: "walzer_01_haltung",
            duration: 720,
            notes: "Achten Sie auf die Schulterposition.",
            isPreview: true
        ),
        Lesson(
            id: "lesson_001_02",
            courseId: "course_001",
            title: "Der Grundschritt",
            orderIndex: 2,
            videoURL: "walzer_02_grundschritt",
            duration: 900,
            notes: "1-2-3, 1-2-3 - Der Rhythmus ist der Schlüssel!",
            isPreview: false
        ),
        Lesson(
            id: "lesson_001_03",
            courseId: "course_001",
            title: "Die Rechtsdrehung",
            orderIndex: 3,
            videoURL: "walzer_03_rechtsdrehung",
            duration: 1080,
            notes: "Langsam beginnen und steigern.",
            isPreview: false
        ),
        
        // Tango
        Lesson(
            id: "lesson_002_01",
            courseId: "course_002",
            title: "Die Tango-Umarmung",
            orderIndex: 1,
            videoURL: "tango_01_umarmung",
            duration: 900,
            notes: "Der Embrace ist das Herzstück.",
            isPreview: true
        ),
        Lesson(
            id: "lesson_002_02",
            courseId: "course_002",
            title: "Ochos und Giros",
            orderIndex: 2,
            videoURL: "tango_02_ochos",
            duration: 1200,
            notes: "Die Achter-Bewegung erfordert Übung.",
            isPreview: false
        ),
        Lesson(
            id: "lesson_002_03",
            courseId: "course_002",
            title: "Improvisation & Musicality",
            orderIndex: 3,
            videoURL: "tango_03_improvisation",
            duration: 1500,
            notes: "Lassen Sie die Musik durch sich fließen.",
            isPreview: false
        ),
        
        // Salsa
        Lesson(
            id: "lesson_003_01",
            courseId: "course_003",
            title: "Fortgeschrittene Drehungen",
            orderIndex: 1,
            videoURL: "salsa_01_drehungen",
            duration: 1200,
            notes: "Spotting ist essentiell.",
            isPreview: true
        ),
        Lesson(
            id: "lesson_003_02",
            courseId: "course_003",
            title: "Komplexe Figurenkombinationen",
            orderIndex: 2,
            videoURL: "salsa_02_figuren",
            duration: 1500,
            notes: "Verbinden Sie die Elemente.",
            isPreview: false
        ),
        Lesson(
            id: "lesson_003_03",
            courseId: "course_003",
            title: "Styling & Performance",
            orderIndex: 3,
            videoURL: "salsa_03_styling",
            duration: 1500,
            notes: "Zeigen Sie Ihre Persönlichkeit.",
            isPreview: false
        ),
        
        // Discofox
        Lesson(
            id: "lesson_004_01",
            courseId: "course_004",
            title: "Der Grundschritt",
            orderIndex: 1,
            videoURL: "discofox_01_grundschritt",
            duration: 600,
            notes: "Tap-Tap-Tap - einfach!",
            isPreview: true
        ),
        Lesson(
            id: "lesson_004_02",
            courseId: "course_004",
            title: "Erste Drehungen",
            orderIndex: 2,
            videoURL: "discofox_02_drehungen",
            duration: 900,
            notes: "Die Damendrehung.",
            isPreview: false
        ),
        Lesson(
            id: "lesson_004_03",
            courseId: "course_004",
            title: "Platzwechsel & Kombinationen",
            orderIndex: 3,
            videoURL: "discofox_03_platzwechsel",
            duration: 900,
            notes: "Beeindrucken auf jeder Party.",
            isPreview: false
        )
    ]
    
    // MARK: - Helper Functions
    static func lessons(for courseId: String) -> [Lesson] {
        lessons.filter { $0.courseId == courseId }.sorted { $0.orderIndex < $1.orderIndex }
    }
    
    static func course(byId id: String) -> Course? {
        courses.first { $0.id == id }
    }
    
    static func lesson(byId id: String) -> Lesson? {
        lessons.first { $0.id == id }
    }
}
