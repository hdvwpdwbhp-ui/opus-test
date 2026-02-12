//
//  CoinAdminView.swift
//  Tanzen mit Tatiana Drexler
//
//  Admin-Verwaltung für DanceCoins
//

import SwiftUI
import FirebaseFirestore

struct CoinAdminView: View {
    @StateObject private var userManager = UserManager.shared
    @StateObject private var coinManager = CoinManager.shared
    @State private var wallets: [CoinWallet] = []
    @State private var isLoading = false
    @State private var selectedUser: AppUser?
    @State private var showAdjustSheet = false
    @State private var showCreateKey = false
    @State private var walletByUserId: [String: CoinWallet] = [:]
    
    private let db = Firestore.firestore()
    
    var body: some View {
        NavigationStack {
            ZStack {
                TDGradients.mainBackground.ignoresSafeArea()

                if isLoading {
                    ProgressView("Lade Wallets...")
                } else {
                    List {
                        Section(T("DanceCoins")) {
                            HStack {
                                Text(T("Wallets"))
                                Spacer()
                                Text("\(walletByUserId.count)")
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Section(T("Coin-Keys")) {
                            if coinManager.coinKeys.isEmpty {
                                Text(T("Keine Keys erstellt"))
                                    .foregroundColor(.secondary)
                            } else {
                                ForEach(coinManager.coinKeys) { key in
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text(key.code)
                                                .font(TDTypography.headline)
                                                .foregroundColor(key.isValid ? .primary : .secondary)
                                            Spacer()
                                            Text("\(key.coinAmount) Coins")
                                                .foregroundColor(Color.accentGold)
                                        }
                                        HStack {
                                            Text(key.isUsed ? "Verwendet" : "Aktiv")
                                                .font(TDTypography.caption2)
                                                .foregroundColor(key.isUsed ? .red : .green)
                                            Spacer()
                                            Text("\(key.currentUses)/\(key.maxUses) Uses")
                                                .font(TDTypography.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                        
                        Section(T("User-Wallets")) {
                            ForEach(sortedUsers) { user in
                                let wallet = walletByUserId[user.id]
                                HStack(spacing: TDSpacing.md) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(user.name)
                                            .font(TDTypography.body)
                                        Text(T("ID: %@...", String(user.id.prefix(8))))
                                            .font(TDTypography.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    if let wallet = wallet {
                                        Text("\(wallet.balance)")
                                            .font(TDTypography.headline)
                                            .foregroundColor(Color.accentGold)
                                    } else {
                                        Text(T("Kein Wallet"))
                                            .font(TDTypography.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedUser = user
                                    showAdjustSheet = true
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(T("DanceCoins Admin"))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(T("Key")) { showCreateKey = true }
                        .foregroundColor(Color.accentGold)
                }
            }
            .task {
                await loadWallets()
                await coinManager.adminLoadCoinKeys()
            }
            .refreshable {
                await loadWallets()
                await coinManager.adminLoadCoinKeys()
            }
            .sheet(isPresented: $showAdjustSheet) {
                if let user = selectedUser {
                    CoinAdjustSheet(user: user, wallet: walletByUserId[user.id]) {
                        Task { await loadWallets() }
                    }
                }
            }
            .sheet(isPresented: $showCreateKey) {
                CoinKeyCreateSheet { Task { await coinManager.adminLoadCoinKeys() } }
            }
        }
    }
    
    private var sortedUsers: [AppUser] {
        userManager.allUsers.sorted {
            let balance0 = walletByUserId[$0.id]?.balance ?? 0
            let balance1 = walletByUserId[$1.id]?.balance ?? 0
            if balance0 == balance1 { return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            return balance0 > balance1
        }
    }
    
    private func loadWallets() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let snapshot = try await db.collection("coinWallets").getDocuments()
            let loaded = snapshot.documents.compactMap { try? $0.data(as: CoinWallet.self) }
            wallets = loaded.sorted { $0.balance > $1.balance }
            walletByUserId = Dictionary(uniqueKeysWithValues: loaded.map { ($0.id, $0) })
        } catch {
            print("❌ Fehler beim Laden der Wallets: \(error)")
        }
    }
    
    private func userName(for userId: String) -> String {
        userManager.allUsers.first { $0.id == userId }?.name ?? "Unbekannt"
    }
}

struct CoinAdjustSheet: View {
    let user: AppUser
    let wallet: CoinWallet?
    let onDone: () -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var coinManager = CoinManager.shared

    @State private var amountText = ""
    @State private var reason = ""
    @State private var activeWallet: CoinWallet?
    @State private var mode: AdjustMode = .add
    @State private var isLoading = false

    enum AdjustMode: String, CaseIterable, Identifiable {
        case add = "Hinzufügen"
        case remove = "Entfernen"
        case set = "Setzen"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(T("User")) {
                    Text(user.name)
                    Text(user.email)
                        .foregroundColor(.secondary)
                }

                Section(T("Wallet")) {
                    if let wallet = activeWallet {
                        HStack {
                            Text(T("Kontostand"))
                            Spacer()
                            Text("\(wallet.balance)")
                                .foregroundColor(Color.accentGold)
                        }
                        HStack {
                            Text(T("Gesamt erhalten"))
                            Spacer()
                            Text("\(wallet.totalEarned)")
                                .foregroundColor(.secondary)
                        }
                        HStack {
                            Text(T("Gesamt ausgegeben"))
                            Spacer()
                            Text("\(wallet.totalSpent)")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text(T("Kein Wallet vorhanden"))
                            .foregroundColor(.secondary)
                        Button(T("Wallet erstellen")) {
                            Task {
                                _ = await coinManager.adminSetCoins(userId: user.id, newBalance: 0)
                                await reloadWallet()
                                onDone()
                            }
                        }
                    }
                }
                
                Section(T("Anpassung")) {
                   Picker("Aktion", selection: $mode) {
                       ForEach(AdjustMode.allCases) { mode in
                           Text(mode.rawValue).tag(mode)
                       }
                   }
                   .pickerStyle(.segmented)
                   
                    TextField(mode == .set ? "Neuer Kontostand" : "Coins", text: $amountText)
                        .keyboardType(.numberPad)
                    TextField(T("Grund (optional)"), text: $reason)
                }

                Section {
                   Button(actionTitle) {
                       Task {
                           guard let amount = Int(amountText), amount >= 0 else { return }
                           switch mode {
                           case .add:
                               if amount > 0 {
                                   _ = await coinManager.adminAddCoins(userId: user.id, amount: amount, reason: reason)
                               }
                           case .remove:
                               if amount > 0 {
                                   _ = await coinManager.adminRemoveCoins(userId: user.id, amount: amount, reason: reason)
                               }
                           case .set:
                               _ = await coinManager.adminSetCoins(userId: user.id, newBalance: amount)
                           }
                           await reloadWallet()
                           onDone()
                           dismiss()
                       }
                   }
                   .foregroundColor(mode == .remove ? .red : .primary)
                }
                
               if let wallet = activeWallet, !wallet.transactions.isEmpty {
                   Section(T("Letzte Transaktionen")) {
                       ForEach(wallet.transactions.prefix(20)) { tx in
                           HStack(alignment: .top, spacing: TDSpacing.sm) {
                               Image(systemName: tx.icon)
                                   .foregroundColor(tx.isPositive ? .green : .red)
                               VStack(alignment: .leading, spacing: 2) {
                                   Text(tx.description)
                                       .font(TDTypography.caption1)
                                   Text(tx.createdAt.formatted(date: .abbreviated, time: .shortened))
                                       .font(TDTypography.caption2)
                                       .foregroundColor(.secondary)
                               }
                               Spacer()
                               Text(tx.formattedAmount)
                                   .font(TDTypography.caption1)
                                   .foregroundColor(tx.isPositive ? .green : .red)
                           }
                       }
                   }
               }
            }
            .navigationTitle(T("Coins anpassen"))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(T("Abbrechen")) { dismiss() }
                }
            }
           .task {
               await reloadWallet()
           }
        }
    }
    
   private var actionTitle: String {
       switch mode {
       case .add: return "Coins hinzufügen"
       case .remove: return "Coins entfernen"
       case .set: return "Kontostand setzen"
       }
   }
   
   private func reloadWallet() async {
       isLoading = true
       defer { isLoading = false }
       activeWallet = await coinManager.adminGetUserWallet(userId: user.id) ?? wallet
   }
}

struct CoinKeyCreateSheet: View {
    let onDone: () -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var coinManager = CoinManager.shared
    
    @State private var code = ""
    @State private var amountText = ""
    @State private var maxUsesText = "1"
    @State private var expiresDaysText = ""
    @State private var showCopied = false
    @State private var createdKey: CoinRedemptionKey?
    
    var body: some View {
        NavigationStack {
            Form {
                if let key = createdKey {
                    // Erfolgsansicht
                    Section(T("Key erstellt!")) {
                        VStack(alignment: .center, spacing: TDSpacing.md) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.green)
                            
                            Text(key.code)
                                .font(.system(.title2, design: .monospaced))
                                .fontWeight(.bold)
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                            
                            Text("\(key.coinAmount) DanceCoins")
                                .font(TDTypography.headline)
                                .foregroundColor(Color.accentGold)
                            
                            Button {
                                UIPasteboard.general.string = key.code
                                showCopied = true
                            } label: {
                                HStack {
                                    Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                                    Text(showCopied ? "Kopiert!" : "Code kopieren")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.tdPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical)
                    }
                    
                    Section {
                        Button(T("Weiteren Key erstellen")) {
                            createdKey = nil
                            code = generateCode()
                            amountText = ""
                            showCopied = false
                        }
                        
                        Button(T("Fertig")) {
                            onDone()
                            dismiss()
                        }
                    }
                } else {
                    // Erstellungsformular
                    Section(T("Neuer Coin-Key")) {
                        HStack {
                            Text(T("Code:"))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(code.isEmpty ? "Wird generiert..." : code)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(code.isEmpty ? .secondary : .primary)
                        }
                        
                        HStack {
                            Text(T("Coins:"))
                            TextField(T("z.B. 10"), text: $amountText)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                        }
                        
                        HStack {
                            Text(T("Max. Einlösungen:"))
                            TextField(T("1"), text: $maxUsesText)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                        }
                        
                        HStack {
                            Text(T("Ablauf (Tage):"))
                            TextField(T("Unbegrenzt"), text: $expiresDaysText)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    
                    Section {
                        Button {
                            Task {
                                if let amount = Int(amountText), amount > 0 {
                                    let maxUses = Int(maxUsesText) ?? 1
                                    let expires = Int(expiresDaysText)
                                    if code.isEmpty {
                                        code = generateCode()
                                    }
                                    if let key = await coinManager.adminCreateCoinKey(
                                        code: code,
                                        coinAmount: amount,
                                        maxUses: maxUses,
                                        expiresInDays: expires
                                    ) {
                                        createdKey = key
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Spacer()
                                Text(T("Key erstellen"))
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                        }
                        .disabled(amountText.isEmpty || Int(amountText) == nil || Int(amountText)! <= 0)
                    }
                }
            }
            .navigationTitle(T("Coin-Key erstellen"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(T("Abbrechen")) { dismiss() }
                }
            }
            .onAppear {
                code = generateCode()
            }
        }
    }

    private func generateCode() -> String {
        let raw = UUID().uuidString.replacingOccurrences(of: "-", with: "").uppercased()
        let part1 = String(raw.prefix(4))
        let part2 = String(raw.dropFirst(4).prefix(4))
        return "DANCE-\(part1)-\(part2)"
    }
}

#Preview {
    CoinAdminView()
}
