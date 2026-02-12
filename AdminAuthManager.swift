//
//  AdminAuthManager.swift
//  Tanzen mit Tatiana Drexler
//
//  Verwaltet die Admin-Authentifizierung
//

import Foundation
import SwiftUI
import Combine
import FirebaseAuth

class AdminAuthManager: ObservableObject {
    static let shared = AdminAuthManager()
    
    @Published var isAuthenticated = false
    @Published var showLoginError = false
    @Published var lastErrorMessage: String?
    
    // Session-Timeout in Sekunden (30 Minuten)
    private let sessionTimeout: TimeInterval = 1800
    private var lastAuthTime: Date?
    private var cancellables = Set<AnyCancellable>()
    
    private let isAuthenticatedKey = "adminIsAuthenticated"
    private let lastAuthTimeKey = "adminLastAuthTime"
    
    private init() {
        bindToUserManager()
        loadSession()
    }
    
    // MARK: - Login
    func login(username: String, password: String) async -> Bool {
        let result = await UserManager.shared.login(usernameOrEmail: username, password: password)
        if result.success, UserManager.shared.isAdmin {
            isAuthenticated = true
            lastAuthTime = Date()
            saveSession()
            showLoginError = false
            lastErrorMessage = nil
            return true
        }
        showLoginError = true
        lastErrorMessage = UserManager.shared.isAdmin ? result.message : "Kein Admin-Zugriff"
        return false
    }
    
    // MARK: - Logout
    func logout() {
        isAuthenticated = false
        lastAuthTime = nil
        clearSession()
    }
    
    // MARK: - Session Management
    private func loadSession() {
        let wasAuthenticated = UserDefaults.standard.bool(forKey: isAuthenticatedKey)
        
        if wasAuthenticated, let lastAuth = UserDefaults.standard.object(forKey: lastAuthTimeKey) as? Date {
            // Prüfe ob Session noch gültig
            if Date().timeIntervalSince(lastAuth) < sessionTimeout {
                isAuthenticated = true
                lastAuthTime = lastAuth
            } else {
                // Session abgelaufen
                clearSession()
            }
        }
    }
    
    private func saveSession() {
        UserDefaults.standard.set(isAuthenticated, forKey: isAuthenticatedKey)
        UserDefaults.standard.set(lastAuthTime, forKey: lastAuthTimeKey)
    }
    
    private func clearSession() {
        UserDefaults.standard.removeObject(forKey: isAuthenticatedKey)
        UserDefaults.standard.removeObject(forKey: lastAuthTimeKey)
    }
    
    // MARK: - Check Session
    func checkSession() {
        if isAuthenticated, let lastAuth = lastAuthTime {
            if Date().timeIntervalSince(lastAuth) >= sessionTimeout {
                logout()
            }
        }
    }
    
    private func bindToUserManager() {
        UserManager.shared.$currentUser
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                let isAdmin = UserManager.shared.isAdmin
                if !isAdmin {
                    self.isAuthenticated = false
                    self.lastAuthTime = nil
                    self.clearSession()
                }
            }
            .store(in: &cancellables)
    }
}
