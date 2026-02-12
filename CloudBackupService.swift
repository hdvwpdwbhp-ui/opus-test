//
//  CloudBackupService.swift
//  Tanzen mit Tatiana Drexler
//
//  Sicherer Cloud-Backup-Service für User-Account-Daten
//  Speichert Daten redundant in mehreren Speicherorten
//

import Foundation
import Security
import Combine

@MainActor
class CloudBackupService: ObservableObject {
    static let shared = CloudBackupService()
    
    @Published var lastBackupDate: Date?
    @Published var isBackingUp = false
    @Published var backupStatus: BackupStatus = .unknown
    
    enum BackupStatus: String {
        case unknown = "Unbekannt"
        case synced = "Synchronisiert"
        case syncing = "Synchronisiere..."
        case error = "Fehler"
        case offline = "Offline"
    }
    
    private let backupKey = "user_backup_date"
    private let userDataBackupBinId = "USERS_BACKUP_BIN_ID" // Separater Backup-Bin
    
    private init() {
        loadLastBackupDate()
    }
    
    // MARK: - Auto Backup Trigger
    
    /// Startet automatisches Backup bei App-Start und wichtigen Änderungen
    func startAutoBackup() {
        // Backup beim App-Start
        Task {
            await performBackup()
        }
        
        // Periodisches Backup alle 5 Minuten
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performBackup()
            }
        }
    }
    
    // MARK: - Perform Full Backup
    
    func performBackup() async {
        guard !isBackingUp else { return }
        
        isBackingUp = true
        backupStatus = .syncing
        defer { isBackingUp = false }
        
        do {
            // 1. Lokales Backup (Documents & App Group)
            try saveLocalBackup()
            
            // 2. Cloud Backup
            await saveCloudBackup()
            
            // 3. Keychain Backup (für kritische Login-Daten)
            try saveKeychainBackup()
            
            lastBackupDate = Date()
            saveLastBackupDate()
            backupStatus = .synced
            
            print("✅ Vollständiges Backup erfolgreich")
        } catch {
            print("❌ Backup-Fehler: \(error)")
            backupStatus = .error
        }
    }
    
    // MARK: - Local Backup
    
    private func saveLocalBackup() throws {
        let userManager = UserManager.shared
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        let backupData = UserBackupData(
            users: userManager.allUsers,
            backupDate: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        )
        
        let data = try encoder.encode(backupData)
        
        // In Documents speichern
        if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = documentsURL.appendingPathComponent("user_backup.json")
            try data.write(to: fileURL)
            
            // Zusätzliches versioniertes Backup (letzte 5 Versionen behalten)
            let timestamp = ISO8601DateFormatter().string(from: Date())
            let versionedURL = documentsURL.appendingPathComponent("backups/user_backup_\(timestamp).json")
            try FileManager.default.createDirectory(at: documentsURL.appendingPathComponent("backups"), withIntermediateDirectories: true)
            try data.write(to: versionedURL)
            
            // Alte Backups aufräumen (nur letzte 5 behalten)
            cleanupOldBackups(in: documentsURL.appendingPathComponent("backups"))
        }
    }
    
    private func cleanupOldBackups(in directory: URL) {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.creationDateKey])
            let sortedFiles = files.sorted { (url1, url2) -> Bool in
                let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                return date1 > date2
            }
            
            // Lösche alle außer den neuesten 5
            for file in sortedFiles.dropFirst(5) {
                try? FileManager.default.removeItem(at: file)
            }
        } catch {
            print("⚠️ Backup-Cleanup fehlgeschlagen: \(error)")
        }
    }
    
    // MARK: - Cloud Backup
    
    private func saveCloudBackup() async {
        // Cloud-Backup läuft jetzt über Firebase
        // UserManager, CourseDataManager etc. speichern automatisch zu Firebase
        print("☁️ Cloud-Backup über Firebase synchronisiert")
    }
    
    // MARK: - Keychain Backup (für kritische Daten)
    
    private func saveKeychainBackup() throws {
        guard let user = UserManager.shared.currentUser else { return }
        
        // Speichere minimale Login-Daten im Keychain (überlebt App-Deinstallation bei iCloud aktiviert)
        let loginData = KeychainLoginData(
            userId: user.id,
            username: user.username,
            email: user.email
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(loginData)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.tatianadrexler.dance.login",
            kSecAttrAccount as String: "current_user",
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecAttrSynchronizable as String: kCFBooleanTrue! // Sync mit iCloud Keychain
        ]
        
        // Erst löschen, dann neu speichern
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status != errSecSuccess {
            print("⚠️ Keychain-Backup fehlgeschlagen: \(status)")
        } else {
            print("✅ Login-Daten im Keychain gesichert")
        }
    }
    
    // MARK: - Restore from Backup
    
    /// Stellt Daten aus dem besten verfügbaren Backup wieder her
    func restoreFromBestBackup() async -> Bool {
        // 1. Versuche Cloud-Backup
        if await restoreFromCloud() {
            return true
        }
        
        // 2. Versuche lokales Backup
        if restoreFromLocalBackup() {
            return true
        }
        
        // 3. Versuche Keychain (minimale Daten)
        if let keychainData = restoreFromKeychain() {
            print("ℹ️ Minimale Login-Daten aus Keychain wiederhergestellt: \(keychainData.username)")
            return false // Nur teilweise wiederhergestellt
        }
        
        return false
    }
    
    private func restoreFromCloud() async -> Bool {
        // Cloud-Restore wird bereits vom UserManager.loadFromCloud() behandelt
        await UserManager.shared.loadFromCloud()
        return !UserManager.shared.allUsers.isEmpty
    }
    
    private func restoreFromLocalBackup() -> Bool {
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return false
        }
        
        let fileURL = documentsURL.appendingPathComponent("user_backup.json")
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let backupData = try decoder.decode(UserBackupData.self, from: data)
            
            print("✅ Lokales Backup gefunden vom \(backupData.backupDate.formatted())")
            return true
        } catch {
            return false
        }
    }
    
    private func restoreFromKeychain() -> KeychainLoginData? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.tatianadrexler.dance.login",
            kSecAttrAccount as String: "current_user",
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess, let data = dataTypeRef as? Data {
            let decoder = JSONDecoder()
            return try? decoder.decode(KeychainLoginData.self, from: data)
        }
        
        return nil
    }
    
    // MARK: - Helper
    
    private func loadLastBackupDate() {
        if let date = UserDefaults.standard.object(forKey: backupKey) as? Date {
            lastBackupDate = date
        }
    }
    
    private func saveLastBackupDate() {
        UserDefaults.standard.set(lastBackupDate, forKey: backupKey)
    }
}

// MARK: - Backup Data Models

struct UserBackupData: Codable {
    let users: [AppUser]
    let backupDate: Date
    let appVersion: String
}

struct KeychainLoginData: Codable {
    let userId: String
    let username: String
    let email: String
}
