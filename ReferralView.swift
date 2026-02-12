//
//  ReferralView.swift
//  Tanzen mit Tatiana Drexler
//
//  Freunde einladen und DanceCoins verdienen
//

import SwiftUI

struct ReferralView: View {
    @StateObject private var referralManager = ReferralManager.shared
    @StateObject private var userManager = UserManager.shared
    @State private var showShareSheet = false
    @State private var isLoadingCode = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: TDSpacing.lg) {
                // Header
                headerSection
                
                // Mein Code
                myCodeSection
                
                // Belohnungen
                rewardsSection
                
                // Statistiken
                if !referralManager.myReferrals.isEmpty {
                    statsSection
                }
                
                // Meine Einladungen
                if !referralManager.myReferrals.isEmpty {
                    referralsListSection
                }
            }
            .padding(TDSpacing.md)
        }
        .background(TDGradients.mainBackground.ignoresSafeArea())
        .navigationTitle(T("Freunde einladen"))
        .task {
            if let user = userManager.currentUser {
                isLoadingCode = true
                _ = await referralManager.getOrCreateReferralCode(for: user.id, userName: user.name)
                await referralManager.loadMyReferrals(userId: user.id)
                isLoadingCode = false
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ReferralShareSheet(items: [referralManager.getShareText()])
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: TDSpacing.md) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 50))
                .foregroundColor(Color.accentGold)
            
            Text(T("Freunde einladen"))
                .font(TDTypography.title1)
                .fontWeight(.bold)
            
            Text(T("Teile deinen Code und verdiene DanceCoins für jeden Freund, der sich registriert!"))
                .font(TDTypography.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(TDSpacing.lg)
    }
    
    private var myCodeSection: some View {
        VStack(spacing: TDSpacing.md) {
            Text(T("Dein Einladungscode"))
                .font(TDTypography.headline)
                .foregroundColor(.secondary)
            
            if isLoadingCode {
                ProgressView()
                    .frame(height: 60)
            } else {
                Text(referralManager.myReferralCode)
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.accentGold)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(TDRadius.md)
            }
            
            HStack(spacing: TDSpacing.md) {
                Button {
                    UIPasteboard.general.string = referralManager.myReferralCode
                } label: {
                    HStack {
                        Image(systemName: "doc.on.doc")
                        Text(T("Kopieren"))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.tdSecondary)
                
                Button {
                    showShareSheet = true
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text(T("Teilen"))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.tdPrimary)
            }
        }
        .padding(TDSpacing.md)
        .glassBackground()
    }
    
    private var rewardsSection: some View {
        VStack(alignment: .leading, spacing: TDSpacing.md) {
            Text(T("Belohnungen"))
                .font(TDTypography.headline)
                .foregroundColor(.secondary)
            
            RewardRow(
                icon: "gift.fill",
                title: "Du erhältst",
                coins: ReferralConfig.referrerRewardOnSignup,
                description: "sofort nach der Registrierung"
            )
            
            RewardRow(
                icon: "person.badge.plus",
                title: "Dein Freund erhält",
                coins: ReferralConfig.referredRewardOnSignup,
                description: "als Willkommensbonus"
            )
            
            RewardRow(
                icon: "cart.fill",
                title: "Bonus bei erstem Kauf",
                coins: ReferralConfig.firstPurchaseBonusReferrer,
                description: "nur einmal pro Freund, für beide"
            )
        }
        .padding(TDSpacing.md)
        .glassBackground()
    }
    
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: TDSpacing.md) {
            Text(T("Deine Statistiken"))
                .font(TDTypography.headline)
                .foregroundColor(.secondary)
            
            HStack(spacing: TDSpacing.lg) {
                ReferralStatBox(value: "\(referralManager.stats.successfulReferrals)", label: "Eingeladen")
                ReferralStatBox(value: "\(referralManager.stats.pendingReferrals)", label: "Ausstehend")
                ReferralStatBox(value: "\(referralManager.stats.totalCoinsEarned)", label: "Coins verdient")
            }
        }
        .padding(TDSpacing.md)
        .glassBackground()
    }
    
    private var referralsListSection: some View {
        VStack(alignment: .leading, spacing: TDSpacing.md) {
            Text(T("Deine Einladungen"))
                .font(TDTypography.headline)
                .foregroundColor(.secondary)
            
            ForEach(referralManager.myReferrals) { referral in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(referral.referredUserName)
                            .font(TDTypography.body)
                        Text(referral.createdAt.formatted(date: .abbreviated, time: .omitted))
                            .font(TDTypography.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    ReferralStatusBadge(status: referral.status)
                }
                .padding(.vertical, TDSpacing.xs)
                
                if referral.id != referralManager.myReferrals.last?.id {
                    Divider()
                }
            }
        }
        .padding(TDSpacing.md)
        .glassBackground()
    }
}

// MARK: - Supporting Views

private struct RewardRow: View {
    let icon: String
    let title: String
    let coins: Int
    let description: String
    
    var body: some View {
        HStack(spacing: TDSpacing.md) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(Color.accentGold)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(title)
                        .font(TDTypography.body)
                    Text("+\(coins) Coins")
                        .font(TDTypography.body)
                        .fontWeight(.bold)
                        .foregroundColor(Color.accentGold)
                }
                Text(description)
                    .font(TDTypography.caption1)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, TDSpacing.xs)
    }
}

private struct ReferralStatBox: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(TDTypography.title2)
                .fontWeight(.bold)
                .foregroundColor(Color.accentGold)
            Text(label)
                .font(TDTypography.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ReferralStatusBadge: View {
    let status: Referral.ReferralStatus
    
    var body: some View {
        Text(statusText)
            .font(TDTypography.caption2)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor)
            .cornerRadius(TDRadius.sm)
    }
    
    private var statusText: String {
        switch status {
        case .pending: return "Ausstehend"
        case .verified: return "Verifiziert"
        case .completed: return "Abgeschlossen"
        case .expired: return "Abgelaufen"
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .pending: return .orange
        case .verified: return .blue
        case .completed: return .green
        case .expired: return .gray
        }
    }
}

// MARK: - Simple Share Sheet for Referral

private struct ReferralShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        ReferralView()
    }
}
