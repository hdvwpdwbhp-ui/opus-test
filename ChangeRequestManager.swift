//
//  ChangeRequestManager.swift
//  Tanzen mit Tatiana Drexler
//
//  Verwaltet Änderungsanfragen von Editoren
//  Änderungen müssen vom Admin genehmigt werden bevor sie live gehen
//

import Foundation
import SwiftUI
import Combine

// MARK: - Change Request Model
struct ChangeRequest: Identifiable, Codable, Equatable {
    let id: String
    let editorId: String
    let editorName: String
    let courseId: String
    let courseName: String
    let changeType: ChangeType
    let fieldName: String
    let oldValue: String
    let newValue: String
    let createdAt: Date
    var status: ChangeStatus
    var reviewedAt: Date?
    var reviewedBy: String?
    var rejectionReason: String?
    
    enum ChangeType: String, Codable {
        case title = "Titel"
        case description = "Beschreibung"
        case lessonTitle = "Lektionstitel"
        case lessonNotes = "Lektionsnotizen"
        case lessonOrder = "Lektionsreihenfolge"
    }
    
    enum ChangeStatus: String, Codable {
        case pending = "Ausstehend"
        case approved = "Genehmigt"
        case rejected = "Abgelehnt"
    }
    
    static func == (lhs: ChangeRequest, rhs: ChangeRequest) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Change Requests Data for JSONBin
struct ChangeRequestsData: Codable {
    var requests: [ChangeRequest]
    var lastUpdated: Date
}

// MARK: - Change Request Manager
@MainActor
class ChangeRequestManager: ObservableObject {
    
    static let shared = ChangeRequestManager()
    
    // MARK: - Published Properties
    @Published var pendingRequests: [ChangeRequest] = []
    @Published var allRequests: [ChangeRequest] = []
    @Published var isSyncing = false
    @Published var unreadCount: Int = 0
    
    // Local Cache
    private let localCacheKey = "changeRequestsCache"
    private let lastCheckedKey = "lastCheckedChangeRequests"
    
    // MARK: - Initialization
    private init() {
        loadLocalCache()
        Task {
            await syncFromCloud()
        }
    }
    
    // MARK: - Create Change Request
    func submitChangeRequest(
        editorId: String,
        editorName: String,
        courseId: String,
        courseName: String,
        changeType: ChangeRequest.ChangeType,
        fieldName: String,
        oldValue: String,
        newValue: String
    ) async -> Bool {
        
        let request = ChangeRequest(
            id: UUID().uuidString,
            editorId: editorId,
            editorName: editorName,
            courseId: courseId,
            courseName: courseName,
            changeType: changeType,
            fieldName: fieldName,
            oldValue: oldValue,
            newValue: newValue,
            createdAt: Date(),
            status: .pending,
            reviewedAt: nil,
            reviewedBy: nil,
            rejectionReason: nil
        )
        
        allRequests.append(request)
        updatePendingRequests()
        
        // Sync to cloud
        await syncToCloud()
        
        // Trigger Push Notification to Admin
        await PushNotificationService.shared.sendAdminNotification(
            title: "Neue Änderungsanfrage",
            body: "\(editorName) möchte \(changeType.rawValue) von '\(courseName)' ändern",
            data: ["requestId": request.id, "type": "change_request"]
        )
        
        return true
    }
    
    // MARK: - Approve Request
    func approveRequest(_ requestId: String, by adminName: String) async {
        guard let index = allRequests.firstIndex(where: { $0.id == requestId }) else { return }
        
        allRequests[index].status = .approved
        allRequests[index].reviewedAt = Date()
        allRequests[index].reviewedBy = adminName
        
        // Apply the change to the actual course data
        let request = allRequests[index]
        await applyChange(request)
        
        updatePendingRequests()
        await syncToCloud()
        
        // Notify editor
        await PushNotificationService.shared.sendEditorNotification(
            editorId: request.editorId,
            title: "Änderung genehmigt ✓",
            body: "Deine Änderung an '\(request.courseName)' wurde genehmigt",
            data: ["requestId": requestId, "status": "approved"]
        )
    }
    
    // MARK: - Reject Request
    func rejectRequest(_ requestId: String, by adminName: String, reason: String) async {
        guard let index = allRequests.firstIndex(where: { $0.id == requestId }) else { return }
        
        allRequests[index].status = .rejected
        allRequests[index].reviewedAt = Date()
        allRequests[index].reviewedBy = adminName
        allRequests[index].rejectionReason = reason
        
        let request = allRequests[index]
        
        updatePendingRequests()
        await syncToCloud()
        
        // Notify editor
        await PushNotificationService.shared.sendEditorNotification(
            editorId: request.editorId,
            title: "Änderung abgelehnt",
            body: "Deine Änderung an '\(request.courseName)' wurde abgelehnt: \(reason)",
            data: ["requestId": requestId, "status": "rejected"]
        )
    }
    
    // MARK: - Apply Change
    private func applyChange(_ request: ChangeRequest) async {
        // Hier würde die tatsächliche Änderung an den Kursdaten vorgenommen
        // Da die Kursdaten in JSONBin gespeichert sind, müsste hier
        // der CloudDataManager aktualisiert werden
        
        // Für jetzt: Log the change
        print("✅ Änderung angewendet: \(request.changeType.rawValue) für \(request.courseName)")
        print("   Alter Wert: \(request.oldValue)")
        print("   Neuer Wert: \(request.newValue)")
        
        // TODO: Implementiere die tatsächliche Änderung in CloudDataManager
    }
    
    // MARK: - Get Requests for Editor
    func getRequestsForEditor(_ editorId: String) -> [ChangeRequest] {
        allRequests.filter { $0.editorId == editorId }
    }
    
    // MARK: - Update Pending Count
    private func updatePendingRequests() {
        pendingRequests = allRequests.filter { $0.status == .pending }
        unreadCount = pendingRequests.count
    }
    
    // MARK: - Cloud Sync
    func syncFromCloud() async {
        isSyncing = true
        defer { isSyncing = false }
        
        let firebaseRequests = await FirebaseService.shared.loadChangeRequests()
        
        if !firebaseRequests.isEmpty {
            allRequests = firebaseRequests
            updatePendingRequests()
            saveLocalCache()
            print("✅ \(allRequests.count) Änderungsanfragen von Firebase geladen")
        }
    }
    
    func syncToCloud() async {
        isSyncing = true
        defer { isSyncing = false }
        
        let success = await FirebaseService.shared.saveAllChangeRequests(allRequests)
        
        if success {
            saveLocalCache()
            print("✅ Änderungsanfragen zu Firebase gespeichert")
        } else {
            saveLocalCache()
        }
    }
    
    // MARK: - Local Cache
    private func loadLocalCache() {
        if let data = UserDefaults.standard.data(forKey: localCacheKey),
           let requests = try? JSONDecoder().decode([ChangeRequest].self, from: data) {
            allRequests = requests
            updatePendingRequests()
        }
    }
    
    private func saveLocalCache() {
        if let data = try? JSONEncoder().encode(allRequests) {
            UserDefaults.standard.set(data, forKey: localCacheKey)
        }
    }
    
    func refresh() async {
        await syncFromCloud()
    }
}

// MARK: - JSONBin Response
struct JSONBinChangeRequestsResponse: Codable {
    let record: ChangeRequestsData
}
