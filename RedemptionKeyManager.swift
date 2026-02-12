//
//  RedemptionKeyManager.swift
//  Tanzen mit Tatiana Drexler
//
//  Created by Admin on 07.02.26.
//

import Foundation
import Combine
import FirebaseFirestore

/// Ein Einlöseschlüssel für kostenlose Kursfreischaltungen
struct RedemptionKey: Codable, Identifiable {
    let id: String
    let key: String
    let courseIds: [String]          // Welche Kurse freigeschaltet werden
    let maxUses: Int                  // Wie oft nutzbar (0 = unbegrenzt)
    var currentUses: Int              // Aktuelle Nutzungen
    let createdAt: Date
    let expiresAt: Date?              // Ablaufdatum (optional)
    let note: String                  // Admin-Notiz
    let createdBy: String             // Admin der den Key erstellt hat
    
    var isValid: Bool {
        let notExpired = expiresAt == nil || expiresAt! > Date()
        let usesLeft = maxUses == 0 || currentUses < maxUses
        return notExpired && usesLeft
    }
    
    var usesRemaining: Int {
        if maxUses == 0 { return -1 } // Unbegrenzt
        return max(0, maxUses - currentUses)
    }
    
    var usesDisplay: String {
        if maxUses == 0 {
            return "\(currentUses) / ∞"
        }
        return "\(currentUses) / \(maxUses)"
    }
}

/// Speichert wer welchen Key eingelöst hat (zur Unterscheidung von echten Käufen)
struct KeyRedemptionRecord: Codable, Identifiable {
    let id: String
    let keyCode: String
    let keyId: String
    let userId: String
    let userName: String
    let userEmail: String
    let courseIds: [String]
    let redeemedAt: Date
    
    /// WICHTIG: Key-Einlösungen sind KEINE Verkäufe und zählen nicht für Trainer-Statistiken
    var isKeyRedemption: Bool { true }
}

/// Verwaltet Einlöseschlüssel in der Cloud
@MainActor
class RedemptionKeyManager: ObservableObject {
    static let shared = RedemptionKeyManager()
    
    @Published var keys: [RedemptionKey] = []
    @Published var redemptionHistory: [KeyRedemptionRecord] = []  // History aller Einlösungen
    @Published var isLoading = false
    @Published var lastError: String?
    
    private let localKeysKey = "local_redemption_keys"
    private let redeemedKeysKey = "redeemed_keys" // Welche Keys der User eingelöst hat
    private let redemptionHistoryKey = "key_redemption_history"
    
    private init() {
        loadLocalKeys()
        loadRedemptionHistory()
    }
    
    // MARK: - Schlüssel generieren
    
    /// Generiert einen zufälligen 12-stelligen Key
    func generateKeyCode() -> String {
        let characters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" // Ohne I, O, 0, 1 für Lesbarkeit
        var key = ""
        for i in 0..<12 {
            if i > 0 && i % 4 == 0 {
                key += "-"
            }
            let randomIndex = Int.random(in: 0..<characters.count)
            let index = characters.index(characters.startIndex, offsetBy: randomIndex)
            key += String(characters[index])
        }
        return key
    }
    
    /// Erstellt einen neuen Einlöseschlüssel
    func createKey(
        courseIds: [String],
        maxUses: Int,
        expiresAt: Date?,
        note: String,
        createdBy: String = "Admin"
    ) async -> RedemptionKey? {
        let newKey = RedemptionKey(
            id: UUID().uuidString,
            key: generateKeyCode(),
            courseIds: courseIds,
            maxUses: maxUses,
            currentUses: 0,
            createdAt: Date(),
            expiresAt: expiresAt,
            note: note,
            createdBy: createdBy
        )
        
        keys.append(newKey)
        await saveToCloud()
        saveLocalKeys()
        
        return newKey
    }
    
    /// Löscht einen Schlüssel
    func deleteKey(_ key: RedemptionKey) async {
        keys.removeAll { $0.id == key.id }
        await saveToCloud()
        saveLocalKeys()
    }
    
    // MARK: - Schlüssel einlösen
    
    /// Prüft ob ein Key gültig ist und gibt die Kurse zurück
    func validateKey(_ keyCode: String) -> RedemptionKey? {
        let normalizedKey = keyCode.uppercased().trimmingCharacters(in: .whitespaces)
        return keys.first { $0.key == normalizedKey && $0.isValid }
    }
    
    /// Löst einen Key ein und schaltet die Kurse frei
    func redeemKey(_ keyCode: String, storeViewModel: StoreViewModel) async -> (success: Bool, message: String, courses: [String]) {
        // Key validieren
        guard let key = validateKey(keyCode) else {
            return (false, "Ungültiger oder abgelaufener Code", [])
        }
        
        // Prüfen ob User den Key schon eingelöst hat
        let redeemedKeys = UserDefaults.standard.stringArray(forKey: redeemedKeysKey) ?? []
        if redeemedKeys.contains(key.id) {
            return (false, "Du hast diesen Code bereits eingelöst", [])
        }
        
        // Key als eingelöst markieren (lokal für User)
        var updatedRedeemedKeys = redeemedKeys
        updatedRedeemedKeys.append(key.id)
        UserDefaults.standard.set(updatedRedeemedKeys, forKey: redeemedKeysKey)
        
        // Kurse freischalten - aus Firebase laden
        let allCourses = CourseDataManager.shared.courses
        for courseId in key.courseIds {
            // Finde die productId für die courseId
            if let course = allCourses.first(where: { $0.id == courseId }) {
                storeViewModel.unlockCourse(course.productId)
            } else if let mockCourse = MockData.courses.first(where: { $0.id == courseId }) {
                // Fallback auf MockData falls Firebase-Kurse nicht geladen
                storeViewModel.unlockCourse(mockCourse.productId)
            }
            
            // Auch über UserManager freischalten
            await UserManager.shared.unlockCourse(courseId: courseId)
        }
        
        // Nutzungszähler erhöhen
        if let index = keys.firstIndex(where: { $0.id == key.id }) {
            var updatedKey = keys[index]
            updatedKey = RedemptionKey(
                id: updatedKey.id,
                key: updatedKey.key,
                courseIds: updatedKey.courseIds,
                maxUses: updatedKey.maxUses,
                currentUses: updatedKey.currentUses + 1,
                createdAt: updatedKey.createdAt,
                expiresAt: updatedKey.expiresAt,
                note: updatedKey.note,
                createdBy: updatedKey.createdBy
            )
            keys[index] = updatedKey
            await saveToCloud()
            saveLocalKeys()
        }
        
        // Einlösung in History speichern (NICHT als Verkauf - für Admin-Transparenz)
        await saveRedemptionToHistory(key: key, keyCode: keyCode)
        
        return (true, "Code erfolgreich eingelöst! \(key.courseIds.count) Kurs(e) freigeschaltet.", key.courseIds)
    }
    
    // MARK: - Redemption History (separate from purchases!)
    
    /// Speichert eine Key-Einlösung in der History
    /// WICHTIG: Dies ist KEIN Verkauf und wird nicht für Trainer-Statistiken gezählt
    private func saveRedemptionToHistory(key: RedemptionKey, keyCode: String) async {
        let user = UserManager.shared.currentUser
        
        let record = KeyRedemptionRecord(
            id: UUID().uuidString,
            keyCode: keyCode,
            keyId: key.id,
            userId: user?.id ?? "unknown",
            userName: user?.name ?? "Unbekannt",
            userEmail: user?.email ?? "",
            courseIds: key.courseIds,
            redeemedAt: Date()
        )
        
        redemptionHistory.insert(record, at: 0)
        
        // Behalte nur die letzten 500 Einlösungen
        if redemptionHistory.count > 500 {
            redemptionHistory = Array(redemptionHistory.prefix(500))
        }
        
        saveRedemptionHistory()
        await saveRedemptionHistoryToCloud(record)
        
        print("📋 Key-Einlösung gespeichert: \(keyCode) von \(user?.name ?? "Unbekannt") - KEIN Verkauf")
    }
    
    /// Gibt alle Key-Einlösungen zurück (für Admin)
    func getRedemptionHistory() -> [KeyRedemptionRecord] {
        return redemptionHistory
    }
    
    private func saveRedemptionHistory() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(redemptionHistory) {
            UserDefaults.standard.set(data, forKey: redemptionHistoryKey)
        }
    }
    
    private func loadRedemptionHistory() {
        guard let data = UserDefaults.standard.data(forKey: redemptionHistoryKey) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let history = try? decoder.decode([KeyRedemptionRecord].self, from: data) {
            self.redemptionHistory = history
        }
    }
    
    private func saveRedemptionHistoryToCloud(_ record: KeyRedemptionRecord) async {
        // Speichere in Firebase für Admin-Zugriff
        do {
            let db = Firestore.firestore()
            try db.collection("keyRedemptions").document(record.id).setData(from: record)
        } catch {
            print("❌ Fehler beim Speichern der Einlösung: \(error)")
        }
    }
    
    // MARK: - Cloud Sync
    
    func loadFromCloud() async {
        isLoading = true
        defer { isLoading = false }
        
        let firebaseKeys = await FirebaseService.shared.loadRedemptionKeys()
        
        if !firebaseKeys.isEmpty {
            self.keys = firebaseKeys
            saveLocalKeys()
            print("✅ \(keys.count) Redemption Keys von Firebase geladen")
        }
    }
    
    private func saveToCloud() async {
        let success = await FirebaseService.shared.saveAllRedemptionKeys(keys)
        if success {
            print("✅ Redemption Keys zu Firebase gespeichert")
        }
    }
    
    // MARK: - Local Storage
    
    private func saveLocalKeys() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(keys) {
            UserDefaults.standard.set(data, forKey: localKeysKey)
        }
    }
    
    private func loadLocalKeys() {
        guard let data = UserDefaults.standard.data(forKey: localKeysKey) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let keys = try? decoder.decode([RedemptionKey].self, from: data) {
            self.keys = keys
        }
    }
}
