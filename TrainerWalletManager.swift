//
//  TrainerWalletManager.swift
//  Tanzen mit Tatiana Drexler
//
//  Firebase-Service für das sichere Trainer-Wallet mit Transaction-Logging
//  WICHTIG: Alle Transaktionen werden unveränderlich in Firebase gespeichert
//

import Foundation
import Combine
import FirebaseFirestore

@MainActor
class TrainerWalletManager: ObservableObject {
    static let shared = TrainerWalletManager()
    
    // MARK: - Published Properties
    @Published var wallet: TrainerWallet?
    @Published var transactions: [TrainerWalletTransaction] = []
    @Published var commissions: [TrainerCourseCommission] = []
    @Published var allCommissions: [TrainerCourseCommission] = [] // Für Admin
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Private
    private let db = Firestore.firestore()
    private var walletListener: ListenerRegistration?
    private var transactionsListener: ListenerRegistration?
    
    // MARK: - Firestore Collections
    private let walletsCollection = "trainerWallets"
    private let transactionsCollection = "trainerWalletTransactions"
    private let commissionsCollection = "trainerCourseCommissions"
    
    // MARK: - Computed
    var balance: Int { wallet?.balance ?? 0 }
    var balanceInEUR: Decimal { wallet?.balanceInEUR ?? 0 }
    
    private init() {}
    
    // MARK: - Initialization for Trainer
    func initializeForTrainer(_ trainerId: String) async {
        await loadWallet(trainerId: trainerId)
        await loadTransactions(trainerId: trainerId)
        await loadCommissionsForTrainer(trainerId: trainerId)
        startWalletListener(trainerId: trainerId)
        startTransactionsListener(trainerId: trainerId)
    }
    
    // MARK: - Initialization for Admin
    func initializeForAdmin() async {
        await loadAllCommissions()
    }
    
    func cleanup() {
        walletListener?.remove()
        walletListener = nil
        transactionsListener?.remove()
        transactionsListener = nil
    }
    
    // MARK: - Load Wallet
    func loadWallet(trainerId: String) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let doc = try await db.collection(walletsCollection).document(trainerId).getDocument()
            
            if doc.exists, let data = try? doc.data(as: TrainerWallet.self) {
                self.wallet = data
                print("✅ Trainer-Wallet geladen: \(data.balance) DanceCoins")
            } else {
                // Neues Wallet erstellen (nur wenn Trainer)
                if UserManager.shared.currentUser?.group == .trainer {
                    let newWallet = TrainerWallet(trainerId: trainerId)
                    try db.collection(walletsCollection).document(trainerId).setData(from: newWallet)
                    self.wallet = newWallet
                    print("✅ Neues Trainer-Wallet erstellt")
                }
            }
        } catch {
            print("❌ Fehler beim Laden des Trainer-Wallets: \(error)")
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Load Transactions
    func loadTransactions(trainerId: String) async {
        do {
            let snapshot = try await db.collection(transactionsCollection)
                .whereField("trainerId", isEqualTo: trainerId)
                .order(by: "createdAt", descending: true)
                .limit(to: 100)
                .getDocuments()
            
            self.transactions = snapshot.documents.compactMap { doc in
                try? doc.data(as: TrainerWalletTransaction.self)
            }
            print("✅ \(transactions.count) Trainer-Transaktionen geladen")
        } catch {
            print("❌ Fehler beim Laden der Transaktionen: \(error)")
        }
    }
    
    // MARK: - Realtime Listener für Wallet
    private func startWalletListener(trainerId: String) {
        walletListener?.remove()
        walletListener = db.collection(walletsCollection).document(trainerId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let doc = snapshot, doc.exists else { return }
                if let wallet = try? doc.data(as: TrainerWallet.self) {
                    Task { @MainActor in
                        self.wallet = wallet
                    }
                }
            }
    }
    
    // MARK: - Realtime Listener für Transaktionen
    private func startTransactionsListener(trainerId: String) {
        transactionsListener?.remove()
        transactionsListener = db.collection(transactionsCollection)
            .whereField("trainerId", isEqualTo: trainerId)
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let docs = snapshot?.documents else { return }
                let newTransactions = docs.compactMap { doc in
                    try? doc.data(as: TrainerWalletTransaction.self)
                }
                Task { @MainActor in
                    self.transactions = newTransactions
                }
            }
    }
    
    // MARK: - Add Course Sale Earnings (Sichere Methode)
    /// Fügt dem Trainer-Wallet Coins aus einem Kursverkauf hinzu
    /// Diese Methode wird automatisch aufgerufen, wenn ein User einen Kurs kauft
    /// WICHTIG: Bezahlt ALLE Trainer, die für diesen Kurs eine Provision haben
    func addCourseSaleEarnings(
        trainerId: String, // Original Trainer-ID (wird ignoriert wenn mehrere Provisionen existieren)
        courseId: String,
        courseName: String,
        buyerUserId: String,
        buyerUserName: String,
        userPaidCoins: Int
    ) async -> Bool {
        // 1. Alle Commissions für diesen Kurs laden
        let commissions = getCommissionsForCourse(courseId)
        
        // Falls keine Commissions konfiguriert sind, den Original-Trainer verwenden
        if commissions.isEmpty {
            // Versuche die alte Einzelcommission zu laden (Migration)
            if let singleCommission = await getCommissionForCourse(courseId) {
                return await paySingleTrainer(
                    trainerId: singleCommission.trainerId,
                    commission: singleCommission,
                    courseId: courseId,
                    courseName: courseName,
                    buyerUserId: buyerUserId,
                    buyerUserName: buyerUserName,
                    userPaidCoins: userPaidCoins
                )
            }
            print("⚠️ Keine Commission-Einstellung für Kurs \(courseId)")
            return false
        }
        
        // 2. Alle Trainer bezahlen
        var allSuccess = true
        for commission in commissions {
            let success = await paySingleTrainer(
                trainerId: commission.trainerId,
                commission: commission,
                courseId: courseId,
                courseName: courseName,
                buyerUserId: buyerUserId,
                buyerUserName: buyerUserName,
                userPaidCoins: userPaidCoins
            )
            if !success {
                allSuccess = false
            }
        }
        
        return allSuccess
    }
    
    /// Bezahlt einen einzelnen Trainer für Kursverkauf
    private func paySingleTrainer(
        trainerId: String,
        commission: TrainerCourseCommission,
        courseId: String,
        courseName: String,
        buyerUserId: String,
        buyerUserName: String,
        userPaidCoins: Int
    ) async -> Bool {
        guard commission.isActive else {
            print("⚠️ Commission für Trainer \(trainerId) bei Kurs \(courseId) ist deaktiviert")
            return false
        }
        
        // Trainer-Coins berechnen
        let trainerCoins = commission.calculateTrainerCoins(from: userPaidCoins)
        guard trainerCoins > 0 else {
            print("⚠️ Trainer-Anteil für \(trainerId) ist 0 Coins")
            return false
        }
        
        // Wallet laden oder erstellen
        var wallet: TrainerWallet
        do {
            let doc = try await db.collection(walletsCollection).document(trainerId).getDocument()
            if doc.exists, let existingWallet = try? doc.data(as: TrainerWallet.self) {
                wallet = existingWallet
            } else {
                wallet = TrainerWallet(trainerId: trainerId)
            }
        } catch {
            print("❌ Fehler beim Laden des Wallets für \(trainerId): \(error)")
            return false
        }
        
        // Wallet aktualisieren
        wallet.balance += trainerCoins
        wallet.totalEarned += trainerCoins
        wallet.updatedAt = Date()
        
        // Transaktion erstellen
        let transaction = TrainerWalletTransaction(
            trainerId: trainerId,
            type: .courseSale,
            amount: trainerCoins,
            courseId: courseId,
            courseName: courseName,
            userId: buyerUserId,
            userName: buyerUserName,
            percentageApplied: commission.commissionPercent,
            originalCoins: userPaidCoins,
            description: "Kursverkauf: \(courseName) (\(commission.commissionPercent)%)",
            balanceAfter: wallet.balance,
            verifiedByAdmin: false
        )
        
        // In Firestore speichern (Transaktion für Atomarität)
        do {
            let batch = db.batch()
            
            // Wallet speichern
            let walletRef = db.collection(walletsCollection).document(trainerId)
            try batch.setData(from: wallet, forDocument: walletRef)
            
            // Transaktion speichern (unveränderlich)
            let transactionRef = db.collection(transactionsCollection).document(transaction.id)
            try batch.setData(from: transaction, forDocument: transactionRef)
            
            try await batch.commit()
            
            // Lokalen State aktualisieren
            if self.wallet?.id == trainerId {
                self.wallet = wallet
            }
            
            print("✅ Trainer-Earnings hinzugefügt: +\(trainerCoins) DC für Kurs \(courseName)")
            return true
        } catch {
            print("❌ Fehler beim Speichern der Earnings: \(error)")
            return false
        }
    }
    
    // MARK: - Admin: Adjust Balance
    /// Admin kann manuell Coins hinzufügen oder entfernen (mit Begründung)
    func adminAdjustBalance(
        trainerId: String,
        amount: Int,
        reason: String,
        adminId: String
    ) async -> Bool {
        guard UserManager.shared.isAdmin else {
            print("❌ Nur Admins können das Wallet anpassen")
            return false
        }
        
        // Wallet laden
        var wallet: TrainerWallet
        do {
            let doc = try await db.collection(walletsCollection).document(trainerId).getDocument()
            if doc.exists, let existingWallet = try? doc.data(as: TrainerWallet.self) {
                wallet = existingWallet
            } else {
                wallet = TrainerWallet(trainerId: trainerId)
            }
        } catch {
            print("❌ Fehler beim Laden des Wallets: \(error)")
            return false
        }
        
        // Balance prüfen bei negativem Betrag
        if amount < 0 && wallet.balance + amount < 0 {
            print("❌ Nicht genug Balance für diese Anpassung")
            return false
        }
        
        // Wallet aktualisieren
        wallet.balance += amount
        if amount > 0 {
            wallet.totalEarned += amount
        } else {
            wallet.totalWithdrawn += abs(amount)
        }
        wallet.updatedAt = Date()
        
        // Transaktion erstellen
        let transaction = TrainerWalletTransaction(
            trainerId: trainerId,
            type: .adminAdjustment,
            amount: amount,
            description: "Admin-Anpassung: \(reason)",
            balanceAfter: wallet.balance,
            verifiedByAdmin: true,
            adminNote: reason
        )
        
        // In Firestore speichern
        do {
            let batch = db.batch()
            
            let walletRef = db.collection(walletsCollection).document(trainerId)
            try batch.setData(from: wallet, forDocument: walletRef)
            
            let transactionRef = db.collection(transactionsCollection).document(transaction.id)
            try batch.setData(from: transaction, forDocument: transactionRef)
            
            try await batch.commit()
            
            if self.wallet?.id == trainerId {
                self.wallet = wallet
            }
            
            print("✅ Admin-Anpassung: \(amount > 0 ? "+" : "")\(amount) DC")
            return true
        } catch {
            print("❌ Fehler bei Admin-Anpassung: \(error)")
            return false
        }
    }
    
    // MARK: - Commission Management
    
    /// Commission für einen Kurs laden
    func getCommissionForCourse(_ courseId: String) async -> TrainerCourseCommission? {
        do {
            let doc = try await db.collection(commissionsCollection).document(courseId).getDocument()
            return try? doc.data(as: TrainerCourseCommission.self)
        } catch {
            print("❌ Fehler beim Laden der Commission: \(error)")
            return nil
        }
    }
    
    /// Alle Commissions für einen Trainer laden
    func loadCommissionsForTrainer(trainerId: String) async {
        do {
            let snapshot = try await db.collection(commissionsCollection)
                .whereField("trainerId", isEqualTo: trainerId)
                .getDocuments()
            
            self.commissions = snapshot.documents.compactMap { doc in
                try? doc.data(as: TrainerCourseCommission.self)
            }
        } catch {
            print("❌ Fehler beim Laden der Trainer-Commissions: \(error)")
        }
    }
    
    /// Alle Commissions laden (für Admin)
    func loadAllCommissions() async {
        do {
            let snapshot = try await db.collection(commissionsCollection).getDocuments()
            
            self.allCommissions = snapshot.documents.compactMap { doc in
                try? doc.data(as: TrainerCourseCommission.self)
            }
            print("✅ \(allCommissions.count) Commissions geladen")
        } catch {
            print("❌ Fehler beim Laden aller Commissions: \(error)")
        }
    }
    
    /// Admin: Commission für einen Kurs und Trainer setzen
    /// WICHTIG: Mehrere Trainer können für denselben Kurs Provisionen erhalten
    func setCommission(
        courseId: String,
        trainerId: String,
        percent: Int,
        adminId: String,
        notes: String? = nil
    ) async -> Bool {
        guard UserManager.shared.isAdmin else {
            print("❌ Nur Admins können Commissions setzen")
            return false
        }
        
        let commissionId = "\(courseId)_\(trainerId)" // Unique ID für Kurs+Trainer
        var commission: TrainerCourseCommission
        
        // Existierende Commission für diese Kombination laden oder neue erstellen
        if let existing = allCommissions.first(where: { $0.id == commissionId }) {
            commission = existing
            commission.commissionPercent = min(100, max(0, percent))
            commission.updatedAt = Date()
            commission.lastUpdatedBy = adminId
            if let notes = notes {
                commission.notes = notes
            }
        } else {
            commission = TrainerCourseCommission(
                courseId: courseId,
                trainerId: trainerId,
                commissionPercent: percent,
                createdBy: adminId
            )
            if let notes = notes {
                commission.notes = notes
            }
        }
        
        do {
            try db.collection(commissionsCollection).document(commissionId).setData(from: commission)
            
            // Lokalen State aktualisieren
            if let index = allCommissions.firstIndex(where: { $0.id == commissionId }) {
                allCommissions[index] = commission
            } else {
                allCommissions.append(commission)
            }
            
            print("✅ Commission gesetzt: \(percent)% für Trainer \(trainerId) bei Kurs \(courseId)")
            return true
        } catch {
            print("❌ Fehler beim Setzen der Commission: \(error)")
            return false
        }
    }
    
    /// Alle Commissions für einen Kurs abrufen
    func getCommissionsForCourse(_ courseId: String) -> [TrainerCourseCommission] {
        return allCommissions.filter { $0.courseId == courseId && $0.isActive }
    }
    
    /// Admin: Commission aktivieren/deaktivieren
    func setCommissionActive(commissionId: String, isActive: Bool, adminId: String) async -> Bool {
        guard UserManager.shared.isAdmin else { return false }
        
        do {
            try await db.collection(commissionsCollection).document(commissionId).updateData([
                "isActive": isActive,
                "updatedAt": Date(),
                "lastUpdatedBy": adminId
            ])
            
            if let index = allCommissions.firstIndex(where: { $0.id == commissionId }) {
                allCommissions[index].isActive = isActive
            }
            
            return true
        } catch {
            print("❌ Fehler beim Ändern des Active-Status: \(error)")
            return false
        }
    }
    
    // MARK: - Load Transactions for Admin
    /// Admin kann alle Transaktionen eines Trainers sehen
    func loadTransactionsForAdmin(trainerId: String) async -> [TrainerWalletTransaction] {
        guard UserManager.shared.isAdmin else { return [] }
        
        do {
            let snapshot = try await db.collection(transactionsCollection)
                .whereField("trainerId", isEqualTo: trainerId)
                .order(by: "createdAt", descending: true)
                .limit(to: 200)
                .getDocuments()
            
            return snapshot.documents.compactMap { doc in
                try? doc.data(as: TrainerWalletTransaction.self)
            }
        } catch {
            print("❌ Fehler beim Laden der Admin-Transaktionen: \(error)")
            return []
        }
    }
    
    // MARK: - Load Wallet for Admin
    func loadWalletForAdmin(trainerId: String) async -> TrainerWallet? {
        guard UserManager.shared.isAdmin else { return nil }
        
        do {
            let doc = try await db.collection(walletsCollection).document(trainerId).getDocument()
            return try? doc.data(as: TrainerWallet.self)
        } catch {
            print("❌ Fehler beim Laden des Admin-Wallets: \(error)")
            return nil
        }
    }
    
    // MARK: - Statistics
    /// Statistik für einen Trainer (für Dashboard)
    func getTrainerStats(trainerId: String, period: StatsPeriod = .thisMonth) async -> TrainerStatsSummary? {
        let (startDate, endDate) = period.dateRange
        
        // Wallet laden
        let wallet = await loadWalletForAdmin(trainerId: trainerId) ?? TrainerWallet(trainerId: trainerId)
        
        // Transaktionen für Zeitraum laden
        do {
            let snapshot = try await db.collection(transactionsCollection)
                .whereField("trainerId", isEqualTo: trainerId)
                .whereField("createdAt", isGreaterThanOrEqualTo: startDate)
                .whereField("createdAt", isLessThanOrEqualTo: endDate)
                .getDocuments()
            
            let periodTransactions = snapshot.documents.compactMap { doc in
                try? doc.data(as: TrainerWalletTransaction.self)
            }
            
            let courseSales = periodTransactions.filter { $0.type == .courseSale }
            
            // Privatstunden-Statistik aus PrivateLessonManager
            let allBookings: [PrivateLessonBooking] = await MainActor.run {
                PrivateLessonManager.shared.bookingsForTrainer(trainerId)
            }
            
            var periodBookings: [PrivateLessonBooking] = []
            for booking in allBookings {
                if booking.requestedDate >= startDate && booking.requestedDate <= endDate {
                    periodBookings.append(booking)
                }
            }
            
            var completedBookings: [PrivateLessonBooking] = []
            for booking in periodBookings {
                if booking.status == PrivateLessonBooking.BookingStatus.completed {
                    completedBookings.append(booking)
                }
            }
            
            var totalMinutes = 0
            for booking in completedBookings {
                totalMinutes += booking.duration
            }
            
            var pendingCount = 0
            for booking in periodBookings {
                if booking.status == PrivateLessonBooking.BookingStatus.pending {
                    pendingCount += 1
                }
            }
            
            return TrainerStatsSummary(
                trainerId: trainerId,
                totalPrivateLessonHours: Double(totalMinutes) / 60.0,
                totalPrivateLessonCount: periodBookings.count,
                completedPrivateLessonCount: completedBookings.count,
                pendingPrivateLessonCount: pendingCount,
                walletBalance: wallet.balance,
                walletBalanceEUR: wallet.balanceInEUR,
                totalCourseSales: courseSales.count,
                totalCourseCoinsEarned: courseSales.reduce(0) { $0 + $1.amount },
                periodStart: startDate,
                periodEnd: endDate
            )
        } catch {
            print("❌ Fehler beim Laden der Statistik: \(error)")
            return nil
        }
    }
    
    enum StatsPeriod {
        case thisMonth
        case lastMonth
        case thisYear
        case allTime
        
        var dateRange: (start: Date, end: Date) {
            let calendar = Calendar.current
            let now = Date()
            
            switch self {
            case .thisMonth:
                let start = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
                return (start, now)
            case .lastMonth:
                let lastMonth = calendar.date(byAdding: .month, value: -1, to: now)!
                let start = calendar.date(from: calendar.dateComponents([.year, .month], from: lastMonth))!
                let end = calendar.date(byAdding: .day, value: -1, to: calendar.date(from: calendar.dateComponents([.year, .month], from: now))!)!
                return (start, end)
            case .thisYear:
                let start = calendar.date(from: calendar.dateComponents([.year], from: now))!
                return (start, now)
            case .allTime:
                return (Date.distantPast, now)
            }
        }
    }
}

// MARK: - Firestore Rules
/*
 Füge diese Regeln zu deinen Firestore.rules hinzu für maximale Sicherheit:
 
 // Trainer Wallets - nur Trainer selbst und Admins können lesen
 match /trainerWallets/{trainerId} {
   allow read: if request.auth.uid == trainerId || 
               get(/databases/$(database)/documents/users/$(request.auth.uid)).data.group == 'admin';
   // Schreiben nur durch Cloud Functions oder Admin SDK
   allow write: if false;
 }
 
 // Trainer Wallet Transaktionen - unveränderlich
 match /trainerWalletTransactions/{transactionId} {
   allow read: if resource.data.trainerId == request.auth.uid ||
               get(/databases/$(database)/documents/users/$(request.auth.uid)).data.group == 'admin';
   // Schreiben nur durch Cloud Functions oder Admin SDK
   allow write: if false;
 }
 
 // Trainer Course Commissions - nur Admins können schreiben
 match /trainerCourseCommissions/{courseId} {
   allow read: if request.auth != null;
   allow write: if get(/databases/$(database)/documents/users/$(request.auth.uid)).data.group == 'admin';
 }
*/
