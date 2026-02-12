//
//  PurchaseHistoryView.swift
//  Tanzen mit Tatiana Drexler
//
//  Zeigt die Kaufhistorie für Admins an
//

import SwiftUI

struct PurchaseHistoryView: View {
    @State private var purchases: [PurchaseHistoryItem] = []
    @State private var selectedFilter: PurchasePaymentMethod?
    
    var filteredPurchases: [PurchaseHistoryItem] {
        if let filter = selectedFilter {
            return purchases.filter { $0.paymentMethod == filter }
        }
        return purchases
    }
    
    var body: some View {
        ZStack {
            TDGradients.mainBackground.ignoresSafeArea()
            
            if purchases.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: TDSpacing.md) {
                        // Filter
                        filterSection
                        
                        // Statistiken
                        statsSection

                        // Cashback Hinweis
                        cashbackHint

                        // Liste
                        purchaseList
                    }
                    .padding(TDSpacing.md)
                }
            }
        }
        .navigationTitle(T("Kaufhistorie"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            purchases = PushNotificationService.shared.getPurchaseHistory()
        }
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: TDSpacing.lg) {
            Image(systemName: "cart")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text(T("Keine Käufe"))
                .font(TDTypography.title2)
            
            Text(T("Hier werden alle Käufe angezeigt, sobald welche getätigt werden."))
                .font(TDTypography.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Filter Section
    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: TDSpacing.sm) {
                PurchaseFilterChip(title: "Alle", isSelected: selectedFilter == nil) {
                    selectedFilter = nil
                }
                
                PurchaseFilterChip(title: "In-App", isSelected: selectedFilter == .inAppPurchase) {
                    selectedFilter = .inAppPurchase
                }
                
                PurchaseFilterChip(title: "PayPal", isSelected: selectedFilter == .paypal) {
                    selectedFilter = .paypal
                }
                
                PurchaseFilterChip(title: "Codes", isSelected: selectedFilter == .redemptionCode) {
                    selectedFilter = .redemptionCode
                }
            }
            .padding(.horizontal, TDSpacing.sm)
        }
    }
    
    // MARK: - Stats Section
    private var statsSection: some View {
        HStack(spacing: TDSpacing.md) {
            StatCard(
                title: "Gesamt",
                value: "\(filteredPurchases.count)",
                icon: "cart.fill",
                color: .blue
            )
            
            StatCard(
                title: "Heute",
                value: "\(todayCount)",
                icon: "calendar",
                color: .green
            )
            
            StatCard(
                title: "Diese Woche",
                value: "\(weekCount)",
                icon: "calendar.badge.clock",
                color: .orange
            )
        }
    }
    
    private var todayCount: Int {
        let calendar = Calendar.current
        return filteredPurchases.filter { calendar.isDateInToday($0.date) }.count
    }
    
    private var weekCount: Int {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return filteredPurchases.filter { $0.date >= weekAgo }.count
    }
    
    // MARK: - Cashback Hint
    private var cashbackHint: some View {
        HStack(spacing: TDSpacing.sm) {
            Image(systemName: "percent")
                .foregroundColor(Color.accentGold)
            Text("5% DanceCoins Cashback bei jedem Kurskauf")
                .font(TDTypography.caption1)
                .foregroundColor(Color.accentGold)
            Spacer()
        }
        .padding(TDSpacing.md)
        .glassBackground()
    }

    // MARK: - Purchase List
    private var purchaseList: some View {
        LazyVStack(spacing: TDSpacing.sm) {
            ForEach(filteredPurchases) { purchase in
                PurchaseRow(purchase: purchase)
            }
        }
    }
}

// MARK: - Purchase Filter Chip
struct PurchaseFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(TDTypography.caption1)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, TDSpacing.md)
                .padding(.vertical, TDSpacing.sm)
                .background(isSelected ? Color.accentGold : Color.gray.opacity(0.2))
                .cornerRadius(20)
        }
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: TDSpacing.xs) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(value)
                .font(TDTypography.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(TDTypography.caption1)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(TDSpacing.md)
        .glassBackground()
    }
}

// MARK: - Purchase Row
struct PurchaseRow: View {
    let purchase: PurchaseHistoryItem
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "de_DE")
        return formatter
    }
    
    var body: some View {
        HStack(spacing: TDSpacing.md) {
            // Icon
            ZStack {
                Circle()
                    .fill(paymentMethodColor.opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Image(systemName: paymentMethodIcon)
                    .foregroundColor(paymentMethodColor)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(purchase.productName)
                    .font(TDTypography.headline)
                    .lineLimit(1)
                
                Text(purchase.buyerName)
                    .font(TDTypography.caption1)
                    .foregroundColor(.secondary)
                
                Text(dateFormatter.string(from: purchase.date))
                    .font(TDTypography.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Preis & Methode
            VStack(alignment: .trailing, spacing: 2) {
                Text(purchase.price)
                    .font(TDTypography.headline)
                    .foregroundColor(.green)
                
                Text(purchase.paymentMethod.displayName)
                    .font(TDTypography.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(TDSpacing.md)
        .glassBackground()
    }
    
    private var paymentMethodIcon: String {
        switch purchase.paymentMethod {
        case .inAppPurchase: return "apple.logo"
        case .paypal: return "p.circle.fill"
        case .coins: return "bitcoinsign.circle.fill"
        case .redemptionCode: return "ticket.fill"
        case .adminGrant: return "person.badge.key.fill"
        }
    }
    
    private var paymentMethodColor: Color {
        switch purchase.paymentMethod {
        case .inAppPurchase: return .blue
        case .paypal: return .indigo
        case .coins: return Color.accentGold
        case .redemptionCode: return .orange
        case .adminGrant: return .purple
        }
    }
}

#Preview {
    NavigationStack {
        PurchaseHistoryView()
    }
}
