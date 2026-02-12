//
//  AdminTrainerWalletsView.swift
//  Tanzen mit Tatiana Drexler
//
//  Admin-View zur Verwaltung aller Trainer-Wallets
//

import SwiftUI

struct AdminTrainerWalletsView: View {
    @StateObject private var walletManager = TrainerWalletManager.shared
    @StateObject private var userManager = UserManager.shared
    
    @State private var selectedTrainer: AppUser?
    @State private var showAdjustSheet = false
    @State private var showTransactionsSheet = false
    @State private var isLoading = false
    @State private var trainerWallets: [(trainer: AppUser, wallet: TrainerWallet?)] = []
    
    private var trainers: [AppUser] {
        userManager.allUsers.filter { $0.group == .trainer }
    }
    
    var body: some View {
        List {
            // Übersicht
            Section {
                HStack {
                    VStack(alignment: .leading) {
                        Text(T("Trainer"))
                            .font(TDTypography.caption1)
                            .foregroundColor(.secondary)
                        Text("\(trainers.count)")
                            .font(TDTypography.title2)
                            .fontWeight(.bold)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text(T("Gesamt DC im Umlauf"))
                            .font(TDTypography.caption1)
                            .foregroundColor(.secondary)
                        Text("\(totalCoinsInCirculation)")
                            .font(TDTypography.title2)
                            .fontWeight(.bold)
                            .foregroundColor(Color.accentGold)
                    }
                }
                .padding(.vertical, 4)
            }
            
            // Trainer-Liste
            Section {
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView("Lade Wallets...")
                        Spacer()
                    }
                } else if trainerWallets.isEmpty {
                    ContentUnavailableView(
                        "Keine Trainer",
                        systemImage: "person.slash",
                        description: Text(T("Keine Trainer-Accounts vorhanden"))
                    )
                } else {
                    ForEach(trainerWallets, id: \.trainer.id) { item in
                        TrainerWalletRow(
                            trainer: item.trainer,
                            wallet: item.wallet,
                            onAdjust: {
                                selectedTrainer = item.trainer
                                showAdjustSheet = true
                            },
                            onShowTransactions: {
                                selectedTrainer = item.trainer
                                showTransactionsSheet = true
                            }
                        )
                    }
                }
            } header: {
                Text(T("Trainer-Wallets"))
            }
        }
        .navigationTitle(T("Trainer-Wallets"))
        .refreshable {
            await loadWallets()
        }
        .task {
            await loadWallets()
        }
        .sheet(isPresented: $showAdjustSheet) {
            if let trainer = selectedTrainer {
                AdminAdjustWalletView(trainer: trainer)
            }
        }
        .sheet(isPresented: $showTransactionsSheet) {
            if let trainer = selectedTrainer {
                NavigationStack {
                    AdminTrainerTransactionsView(trainer: trainer)
                }
            }
        }
    }
    
    private var totalCoinsInCirculation: Int {
        trainerWallets.reduce(0) { $0 + ($1.wallet?.balance ?? 0) }
    }
    
    private func loadWallets() async {
        isLoading = true
        defer { isLoading = false }
        
        var results: [(trainer: AppUser, wallet: TrainerWallet?)] = []
        
        for trainer in trainers {
            let wallet = await walletManager.loadWalletForAdmin(trainerId: trainer.id)
            results.append((trainer: trainer, wallet: wallet))
        }
        
        trainerWallets = results.sorted { ($0.wallet?.balance ?? 0) > ($1.wallet?.balance ?? 0) }
    }
}

// MARK: - Trainer Wallet Row
struct TrainerWalletRow: View {
    let trainer: AppUser
    let wallet: TrainerWallet?
    let onAdjust: () -> Void
    let onShowTransactions: () -> Void
    
    var body: some View {
        HStack(spacing: TDSpacing.md) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.accentGold.opacity(0.2))
                    .frame(width: 44, height: 44)
                Text(trainer.name.prefix(1).uppercased())
                    .font(.headline)
                    .foregroundColor(Color.accentGold)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(trainer.name)
                    .font(TDTypography.headline)
                
                if let wallet = wallet {
                    HStack {
                        Text("\(wallet.balance) DC")
                            .font(TDTypography.caption1)
                            .foregroundColor(Color.accentGold)
                        Text(T("•"))
                            .foregroundColor(.secondary)
                        Text(wallet.formattedBalanceEUR)
                            .font(TDTypography.caption1)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text(T("Kein Wallet"))
                        .font(TDTypography.caption1)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Actions
            HStack(spacing: TDSpacing.sm) {
                Button(action: onAdjust) {
                    Image(systemName: "plus.minus")
                        .foregroundColor(.blue)
                }
                .buttonStyle(.borderless)
                
                Button(action: onShowTransactions) {
                    Image(systemName: "list.bullet")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Admin Adjust Wallet View
struct AdminAdjustWalletView: View {
    let trainer: AppUser
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var walletManager = TrainerWalletManager.shared
    @StateObject private var userManager = UserManager.shared
    
    @State private var amount: Int = 0
    @State private var isPositive = true
    @State private var reason: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section(T("Trainer")) {
                    HStack {
                        Text(T("Name"))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(trainer.name)
                    }
                }
                
                Section(T("Anpassung")) {
                    Picker("Typ", selection: $isPositive) {
                        Text(T("Hinzufügen (+)")).tag(true)
                        Text(T("Entfernen (-)")).tag(false)
                    }
                    .pickerStyle(.segmented)
                    
                    HStack {
                        Text(T("Betrag"))
                        Spacer()
                        TextField(T("0"), value: $amount, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                        Text(T("DC"))
                            .foregroundColor(.secondary)
                    }
                    
                    // Vorschau
                    let finalAmount = isPositive ? amount : -amount
                    HStack {
                        Text(T("Änderung"))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(finalAmount > 0 ? "+" : "")\(finalAmount) DC")
                            .font(.headline)
                            .foregroundColor(isPositive ? .green : .red)
                    }
                }
                
                Section(T("Begründung")) {
                    TextField(T("Grund für die Anpassung"), text: $reason, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
                
                Section {
                    HStack {
                        Spacer()
                        if isSaving {
                            ProgressView()
                        } else {
                            Button(T("Anpassung durchführen")) {
                                Task { await save() }
                            }
                            .disabled(amount == 0 || reason.isEmpty)
                        }
                        Spacer()
                    }
                }
            }
            .navigationTitle(T("Wallet anpassen"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(T("Abbrechen")) { dismiss() }
                }
            }
            .alert(T("Erfolgreich"), isPresented: $showSuccess) {
                Button(T("OK")) { dismiss() }
            } message: {
                Text(T("Die Wallet-Anpassung wurde durchgeführt."))
            }
        }
    }
    
    private func save() async {
        guard let adminId = userManager.currentUser?.id else {
            errorMessage = "Nicht eingeloggt"
            return
        }
        
        isSaving = true
        defer { isSaving = false }
        
        let finalAmount = isPositive ? amount : -amount
        
        let success = await walletManager.adminAdjustBalance(
            trainerId: trainer.id,
            amount: finalAmount,
            reason: reason,
            adminId: adminId
        )
        
        if success {
            showSuccess = true
        } else {
            errorMessage = "Fehler bei der Anpassung"
        }
    }
}

// MARK: - Admin Trainer Transactions View
struct AdminTrainerTransactionsView: View {
    let trainer: AppUser
    
    @StateObject private var walletManager = TrainerWalletManager.shared
    @State private var transactions: [TrainerWalletTransaction] = []
    @State private var wallet: TrainerWallet?
    @State private var isLoading = true
    
    var body: some View {
        List {
            // Wallet-Info
            Section {
                if let wallet = wallet {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(T("Aktuelles Guthaben"))
                                .font(TDTypography.caption1)
                                .foregroundColor(.secondary)
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("\(wallet.balance)")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(Color.accentGold)
                                Text(T("DC"))
                                    .font(TDTypography.caption1)
                                    .foregroundColor(Color.accentGold)
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(T("Gesamt verdient"))
                                .font(TDTypography.caption1)
                                .foregroundColor(.secondary)
                            Text("\(wallet.totalEarned) DC")
                                .font(TDTypography.headline)
                                .foregroundColor(.green)
                        }
                    }
                } else {
                    Text(T("Kein Wallet vorhanden"))
                        .foregroundColor(.secondary)
                }
            }
            
            // Transaktionen
            Section {
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else if transactions.isEmpty {
                    ContentUnavailableView(
                        "Keine Transaktionen",
                        systemImage: "clock.arrow.circlepath",
                        description: Text(T("Noch keine Transaktionen für diesen Trainer"))
                    )
                } else {
                    ForEach(transactions) { transaction in
                        AdminTransactionRow(transaction: transaction)
                    }
                }
            } header: {
                Text(T("Transaktionshistorie (%@)", "\(transactions.count)"))
            }
        }
        .navigationTitle(trainer.name)
        .task {
            isLoading = true
            wallet = await walletManager.loadWalletForAdmin(trainerId: trainer.id)
            transactions = await walletManager.loadTransactionsForAdmin(trainerId: trainer.id)
            isLoading = false
        }
    }
}

struct AdminTransactionRow: View {
    let transaction: TrainerWalletTransaction
    
    @State private var showDetail = false
    
    var body: some View {
        Button {
            showDetail = true
        } label: {
            HStack(spacing: TDSpacing.md) {
                // Icon
                ZStack {
                    Circle()
                        .fill(transaction.isPositive ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: transaction.icon)
                        .font(.caption)
                        .foregroundColor(transaction.isPositive ? .green : .red)
                }
                
                // Details
                VStack(alignment: .leading, spacing: 2) {
                    Text(transaction.description)
                        .font(TDTypography.body)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text(transaction.createdAt, style: .date)
                        .font(TDTypography.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Betrag
                VStack(alignment: .trailing, spacing: 2) {
                    Text(transaction.formattedAmount)
                        .font(TDTypography.headline)
                        .foregroundColor(transaction.isPositive ? .green : .red)
                    if transaction.verifiedByAdmin {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .sheet(isPresented: $showDetail) {
            TransactionDetailView(transaction: transaction)
        }
    }
}

struct TransactionDetailView: View {
    let transaction: TrainerWalletTransaction
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section(T("Transaktion")) {
                    DetailRow(label: "ID", value: transaction.id)
                    DetailRow(label: "Typ", value: transaction.type.defaultDescription)
                    DetailRow(label: "Datum", value: transaction.createdAt.formatted())
                }
                
                Section(T("Betrag")) {
                    DetailRow(label: "DanceCoins", value: transaction.formattedAmount)
                    DetailRow(label: "EUR-Wert", value: transaction.formattedAmountEUR)
                    DetailRow(label: "Balance danach", value: "\(transaction.balanceAfter) DC")
                }
                
                if transaction.type == .courseSale {
                    Section(T("Kursverkauf")) {
                        if let courseId = transaction.courseId {
                            DetailRow(label: "Kurs-ID", value: courseId)
                        }
                        if let courseName = transaction.courseName {
                            DetailRow(label: "Kursname", value: courseName)
                        }
                        if let userName = transaction.userName {
                            DetailRow(label: "Käufer", value: userName)
                        }
                        if let percent = transaction.percentageApplied {
                            DetailRow(label: "Provision", value: "\(percent)%")
                        }
                        if let original = transaction.originalCoins {
                            DetailRow(label: "Originaler Preis", value: "\(original) DC")
                        }
                    }
                }
                
                Section(T("Verifizierung")) {
                    HStack {
                        Text(T("Admin-verifiziert"))
                            .foregroundColor(.secondary)
                        Spacer()
                        Image(systemName: transaction.verifiedByAdmin ? "checkmark.circle.fill" : "xmark.circle")
                            .foregroundColor(transaction.verifiedByAdmin ? .green : .secondary)
                    }
                    if let note = transaction.adminNote {
                        DetailRow(label: "Admin-Notiz", value: note)
                    }
                }
            }
            .navigationTitle(T("Transaktionsdetails"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(T("Fertig")) { dismiss() }
                }
            }
        }
    }
}

struct WalletDetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(TDTypography.body)
                .multilineTextAlignment(.trailing)
        }
    }
}

#Preview {
    NavigationStack {
        AdminTrainerWalletsView()
    }
}
