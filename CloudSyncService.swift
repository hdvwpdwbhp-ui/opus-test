//
//  CloudSyncService.swift
//  Tanzen mit Tatiana Drexler
//
//  Echtzeit Cloud-Synchronisation mit Firebase
//

import Foundation
import Combine
import Network

@MainActor
class CloudSyncService: ObservableObject {
    static let shared = CloudSyncService()
    
    @Published var isConnected = true
    @Published var lastSyncTime: Date?
    @Published var isSyncing = false
    
    private var syncTimer: Timer?
    private var networkMonitor: NWPathMonitor?
    private let syncInterval: TimeInterval = 30.0 // Periodisches Sync alle 30 Sekunden
    
    private init() {
        setupNetworkMonitoring()
        startAutoSync()
    }
    
    // MARK: - Network Monitoring
    private func setupNetworkMonitoring() {
        networkMonitor = NWPathMonitor()
        let queue = DispatchQueue(label: "NetworkMonitor")
        
        networkMonitor?.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = path.status == .satisfied
                if path.status == .satisfied {
                    // Bei Verbindungswiederherstellung sofort synchronisieren
                    await self?.syncAll()
                }
            }
        }
        networkMonitor?.start(queue: queue)
    }
    
    // MARK: - Auto Sync
    func startAutoSync() {
        stopAutoSync()
        
        // Periodischer Sync als Fallback (Firebase hat Echtzeit-Listener)
        syncTimer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.syncAll()
            }
        }
        
        // Sofort synchronisieren
        Task {
            await syncAll()
        }
    }
    
    func stopAutoSync() {
        syncTimer?.invalidate()
        syncTimer = nil
    }
    
    // MARK: - Full Sync
    func syncAll() async {
        guard isConnected else { return }
        
        isSyncing = true
        defer { isSyncing = false }
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await UserManager.shared.loadFromCloud() }
            group.addTask { await SupportChatManager.shared.loadFromCloud() }
            group.addTask { await CommentManager.shared.loadFromCloud() }
            group.addTask { await AppSettingsManager.shared.loadFromCloud() }
            group.addTask { await RedemptionKeyManager.shared.loadFromCloud() }
            group.addTask { await EditorAccountManager.shared.syncFromCloud() }
        }
        
        lastSyncTime = Date()
        print("✅ Firebase Synchronisation abgeschlossen")
    }
    
    // MARK: - Force Refresh
    func forceRefresh() async {
        await syncAll()
    }
}
