//
//  CoinWalletView.swift
//  Tanzen mit Tatiana Drexler
//
//  DanceCoins Wallet
//

import SwiftUI

struct CoinWalletView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var coinManager = CoinManager.shared
    @EnvironmentObject private var storeViewModel: StoreViewModel
    @State private var redeemCode = ""
    @State private var showRedeemAlert = false
    @State private var redeemMessage = ""
    @State private var isRedeeming = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                TDGradients.mainBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: TDSpacing.lg) {
                        balanceCard
                        cashbackHintCard
                        dailyBonusCard
                        redeemCard
                        coinPackagesSection
                        transactionsSection
                    }
                    .padding(TDSpacing.md)
                }
            }
            .navigationTitle(T("DanceCoins"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(T("Fertig")) { dismiss() }
                        .foregroundColor(Color.accentGold)
                }
            }
            .alert(T("Code"), isPresented: $showRedeemAlert) {
                Button(T("OK"), role: .cancel) { }
            } message: {
                Text(redeemMessage)
            }
            .task {
                // Stelle sicher dass Wallet initialisiert ist
                if let userId = UserManager.shared.currentUser?.id, coinManager.wallet == nil {
                    await coinManager.initialize(for: userId)
                }
            }
        }
    }
    
    private var balanceCard: some View {
        VStack(spacing: TDSpacing.sm) {
            Text(T("Kontostand"))
                .font(TDTypography.caption1)
                .foregroundColor(.secondary)
            Text("\(coinManager.balance) DanceCoins")
                .font(TDTypography.title1)
                .fontWeight(.bold)
                .foregroundColor(Color.accentGold)
            Text(T("1 Coin = €0,50"))
                .font(TDTypography.caption1)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(TDSpacing.md)
        .glassBackground()
    }

    private var cashbackHintCard: some View {
        HStack(spacing: TDSpacing.sm) {
            Image(systemName: "percent")
                .foregroundColor(Color.accentGold)
            Text(T("5% DanceCoins Cashback bei jedem Kurskauf"))
                .font(TDTypography.caption1)
                .foregroundColor(Color.accentGold)
            Spacer()
        }
        .padding(TDSpacing.md)
        .glassBackground()
    }
    
    private var dailyBonusCard: some View {
        VStack(spacing: TDSpacing.sm) {
            HStack {
                Image(systemName: "gift.fill")
                    .foregroundColor(.green)
                Text(T("Täglicher Bonus"))
                    .font(TDTypography.headline)
                Spacer()
            }
            Text(T("Einmal täglich bekommst du 1 DanceCoin."))
                .font(TDTypography.caption1)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Button {
                Task {
                    _ = await coinManager.claimDailyBonus()
                }
            } label: {
                Text(coinManager.canClaimDailyBonus ? "+1 Coin holen" : "Heute bereits erhalten")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.tdPrimary)
            .disabled(!coinManager.canClaimDailyBonus)
        }
        .padding(TDSpacing.md)
        .glassBackground()
    }
    
    private var redeemCard: some View {
        VStack(spacing: TDSpacing.sm) {
            HStack {
                Image(systemName: "key.fill")
                    .foregroundColor(.orange)
                Text(T("Code einlösen"))
                    .font(TDTypography.headline)
                Spacer()
            }
            
            TextField(T("DANCE-XXXX-XXXX"), text: $redeemCode)
                .textFieldStyle(GlassTextFieldStyle())
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled(true)
            
            Button {
                Task {
                    isRedeeming = true
                    let result = await coinManager.redeemCoinKey(code: redeemCode)
                    isRedeeming = false
                    redeemMessage = result.message
                    showRedeemAlert = true
                    if result.success { redeemCode = "" }
                }
            } label: {
                HStack {
                    if isRedeeming { ProgressView().tint(.white) }
                    Text(T("Einlösen"))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.tdSecondary)
            .disabled(redeemCode.count < 6 || isRedeeming)
        }
        .padding(TDSpacing.md)
        .glassBackground()
    }
    
    private var coinPackagesSection: some View {
        VStack(alignment: .leading, spacing: TDSpacing.sm) {
            Text(T("Coin-Pakete"))
                .font(TDTypography.headline)
                .foregroundColor(.secondary)
                .padding(.leading, TDSpacing.sm)
            
            ForEach(DanceCoinConfig.coinPackages) { package in
                CoinPackageRow(package: package) {
                    Task {
                        _ = await storeViewModel.purchaseCoinPackage(package)
                    }
                }
            }
        }
    }
    
    private var transactionsSection: some View {
        VStack(alignment: .leading, spacing: TDSpacing.sm) {
            Text(T("Transaktionen"))
                .font(TDTypography.headline)
                .foregroundColor(.secondary)
                .padding(.leading, TDSpacing.sm)
            
            if coinManager.wallet?.transactions.isEmpty != false {
                Text(T("Noch keine Transaktionen"))
                    .font(TDTypography.caption1)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, TDSpacing.md)
            } else {
                ForEach(coinManager.wallet?.transactions ?? []) { tx in
                    HStack {
                        Image(systemName: tx.icon)
                            .foregroundColor(tx.isPositive ? .green : .red)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tx.description)
                                .font(TDTypography.body)
                            Text(tx.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(TDTypography.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(tx.formattedAmount)
                            .font(TDTypography.headline)
                            .foregroundColor(tx.isPositive ? .green : .red)
                    }
                    .padding(TDSpacing.md)
                    .glassBackground()
                }
            }
        }
    }
}

struct CoinPackageRow: View {
    let package: CoinPackage
    let onBuy: () -> Void
    
    private var isTopDeal: Bool { package.bonusCoins >= 30 }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            HStack(spacing: TDSpacing.md) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(package.coins) Coins")
                        .font(TDTypography.headline)
                    if package.bonusCoins > 0 {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.caption2)
                            Text(T("BONUS +%@", "\(package.bonusCoins)"))
                                .font(TDTypography.caption1)
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .foregroundColor(.white)
                        .background(
                            LinearGradient(
                                colors: [Color.accentGold, Color.accentGold.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                    }
                }
                Spacer()
                Text(package.formattedPrice)
                    .font(TDTypography.headline)
                Button(T("Kaufen"), action: onBuy)
                    .buttonStyle(.tdPrimary)
            }
        }
        .padding(TDSpacing.md)
        .glassBackground()
    }
}

#Preview {
    CoinWalletView()
        .environmentObject(StoreViewModel())
}
