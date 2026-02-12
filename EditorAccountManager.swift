//
//  EditorAccountManager.swift
//  Tanzen mit Tatiana Drexler
//
//  Verwaltet Editor-Accounts mit eingeschränkten Berechtigungen
//  Accounts werden in Firebase gespeichert und sind auf allen Geräten verfügbar
//

import Foundation
import SwiftUI
import Combine

// MARK: - Editor Account Model
struct EditorAccount: Identifiable, Codable, Equatable {
    let id: String
    var username: String
    var password: String
    var displayName: String
    var allowedCourseIds: Set<String>
    var createdAt: Date
    var lastLogin: Date?
    var isActive: Bool
    
    // Berechtigungen
    var canEditTitle: Bool = true
    var canEditDescription: Bool = true
    var canEditLessons: Bool = true
    var canEditPrice: Bool = false  // Niemals true!
    var canDeleteCourse: Bool = false
    var canCreateCourse: Bool = false
    
    static func == (lhs: EditorAccount, rhs: EditorAccount) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Cloud Storage for Editor Accounts
struct EditorAccountsData: Codable {
    var accounts: [EditorAccount]
    var lastUpdated: Date
}

// MARK: - Editor Account Manager
@MainActor
class EditorAccountManager: ObservableObject {
    
    static let shared = EditorAccountManager()
    
    // MARK: - Published Properties
    @Published var editorAccounts: [EditorAccount] = []
    @Published var currentEditor: EditorAccount? = nil
    @Published var isEditorLoggedIn = false
    @Published var loginError: String? = nil
    @Published var isSyncing = false
    @Published var lastSyncError: String? = nil
    
    // Local Cache Keys
    private let localAccountsKey = "editorAccountsCache"
    private let currentEditorKey = "currentEditorId"
    
    // MARK: - Initialization
    private init() {
        loadLocalCache()
        Task {
            await syncFromCloud()
        }
    }
    
    // MARK: - Cloud Sync
    
    /// Lädt Accounts von Firebase
    func syncFromCloud() async {
        isSyncing = true
        lastSyncError = nil
        defer { isSyncing = false }
        
        let firebaseAccounts = await FirebaseService.shared.loadEditorAccounts()
        
        if !firebaseAccounts.isEmpty {
            editorAccounts = firebaseAccounts
            saveLocalCache()
            print("✅ \(editorAccounts.count) Editor-Accounts von Firebase geladen")
        } else if editorAccounts.isEmpty {
            // Keine Accounts vorhanden - lokale behalten
            print("ℹ️ Keine Editor-Accounts in Firebase gefunden")
        }
    }
    
    /// Speichert Accounts in Firebase
    func syncToCloud() async {
        isSyncing = true
        defer { isSyncing = false }
        
        let success = await FirebaseService.shared.saveAllEditorAccounts(editorAccounts)
        
        if success {
            saveLocalCache()
            print("✅ Editor-Accounts in Firebase gespeichert")
        } else {
            lastSyncError = "Upload fehlgeschlagen"
            // Trotzdem lokal speichern
            saveLocalCache()
        }
    }
    
    // MARK: - Account Management (nur für Admin)
    
    /// Erstellt einen neuen Editor-Account
    func createEditorAccount(
        username: String,
        password: String,
        displayName: String,
        allowedCourseIds: Set<String>
    ) -> EditorAccount? {
        // Prüfe ob Username bereits existiert
        guard !editorAccounts.contains(where: { $0.username.lowercased() == username.lowercased() }) else {
            return nil
        }
        
        let newAccount = EditorAccount(
            id: UUID().uuidString,
            username: username,
            password: password,
            displayName: displayName,
            allowedCourseIds: allowedCourseIds,
            createdAt: Date(),
            lastLogin: nil,
            isActive: true,
            canEditTitle: true,
            canEditDescription: true,
            canEditLessons: true,
            canEditPrice: false,
            canDeleteCourse: false,
            canCreateCourse: false
        )
        
        editorAccounts.append(newAccount)
        
        // Sync to cloud
        Task {
            await syncToCloud()
        }
        
        return newAccount
    }
    
    /// Aktualisiert einen Editor-Account
    func updateEditorAccount(_ account: EditorAccount) {
        if let index = editorAccounts.firstIndex(where: { $0.id == account.id }) {
            var updatedAccount = account
            updatedAccount.canEditPrice = false // Immer false!
            editorAccounts[index] = updatedAccount
            
            Task {
                await syncToCloud()
            }
        }
    }
    
    /// Löscht einen Editor-Account
    func deleteEditorAccount(_ accountId: String) {
        editorAccounts.removeAll { $0.id == accountId }
        
        if currentEditor?.id == accountId {
            logoutEditor()
        }
        
        Task {
            await syncToCloud()
        }
    }
    
    /// Aktiviert/Deaktiviert einen Account
    func setAccountActive(_ accountId: String, isActive: Bool) {
        if let index = editorAccounts.firstIndex(where: { $0.id == accountId }) {
            editorAccounts[index].isActive = isActive
            
            if !isActive && currentEditor?.id == accountId {
                logoutEditor()
            }
            
            Task {
                await syncToCloud()
            }
        }
    }
    
    /// Aktualisiert die erlaubten Kurse für einen Editor
    func updateAllowedCourses(for accountId: String, courseIds: Set<String>) {
        if let index = editorAccounts.firstIndex(where: { $0.id == accountId }) {
            editorAccounts[index].allowedCourseIds = courseIds
            
            Task {
                await syncToCloud()
            }
        }
    }
    
    // MARK: - Editor Login
    
    /// Editor Login
    func loginEditor(username: String, password: String) -> Bool {
        guard let account = editorAccounts.first(where: {
            $0.username.lowercased() == username.lowercased() && $0.password == password
        }) else {
            loginError = "Ungültige Anmeldedaten"
            return false
        }
        
        guard account.isActive else {
            loginError = "Dieser Account wurde deaktiviert"
            return false
        }
        
        currentEditor = account
        isEditorLoggedIn = true
        loginError = nil
        
        // Update last login
        if let index = editorAccounts.firstIndex(where: { $0.id == account.id }) {
            editorAccounts[index].lastLogin = Date()
            Task {
                await syncToCloud()
            }
        }
        
        UserDefaults.standard.set(account.id, forKey: currentEditorKey)
        
        return true
    }
    
    /// Editor Logout
    func logoutEditor() {
        currentEditor = nil
        isEditorLoggedIn = false
        UserDefaults.standard.removeObject(forKey: currentEditorKey)
    }
    
    // MARK: - Permission Checks
    
    func canEditCourse(_ courseId: String) -> Bool {
        guard let editor = currentEditor else { return false }
        return editor.allowedCourseIds.contains(courseId) || editor.allowedCourseIds.contains("*")
    }
    
    func canEditField(_ field: EditableField) -> Bool {
        guard let editor = currentEditor else { return false }
        
        switch field {
        case .title: return editor.canEditTitle
        case .description: return editor.canEditDescription
        case .lessons: return editor.canEditLessons
        case .price: return false // Niemals!
        case .delete: return editor.canDeleteCourse
        case .create: return editor.canCreateCourse
        }
    }
    
    enum EditableField {
        case title, description, lessons, price, delete, create
    }
    
    // MARK: - Local Cache
    
    private func loadLocalCache() {
        if let data = UserDefaults.standard.data(forKey: localAccountsKey),
           let accounts = try? JSONDecoder().decode([EditorAccount].self, from: data) {
            editorAccounts = accounts
        }
        
        // Restore current editor session
        if let editorId = UserDefaults.standard.string(forKey: currentEditorKey),
           let editor = editorAccounts.first(where: { $0.id == editorId && $0.isActive }) {
            currentEditor = editor
            isEditorLoggedIn = true
        }
    }
    
    private func saveLocalCache() {
        if let data = try? JSONEncoder().encode(editorAccounts) {
            UserDefaults.standard.set(data, forKey: localAccountsKey)
        }
    }
    
    /// Manueller Refresh
    func refresh() async {
        await syncFromCloud()
    }
}
