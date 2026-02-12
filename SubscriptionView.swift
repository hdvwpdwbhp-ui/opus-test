//
//  SubscriptionView.swift
//  Tanzen mit Tatiana Drexler
//
//  Ansicht für Abo-Optionen (Monatlich/Jährlich)
//

import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @EnvironmentObject var storeViewModel: StoreViewModel
    @StateObject private var userManager = UserManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPlan: StoreViewModel.SubscriptionType = .yearly
    @State private var isPurchasing = false
    @State private var showAuthView = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                TDGradients.mainBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: TDSpacing.lg) {
                        // Header
                        headerSection
                        
                        // Benefits
                        benefitsSection
                        
                        // Plan Selection
                        planSelectionSection
                        
                        // Subscribe Button
                        subscribeButton
                        
                        // Terms
                        termsSection
                    }
                    .padding(TDSpacing.md)
                }
            }
            .navigationTitle(T("Premium Abo"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(T("Schließen")) {
                        dismiss()
                    }
                    .foregroundColor(Color.accentGold)
                }
            }
        }
    }
    
    // MARK: - Header
    private var headerSection: some View {
        VStack(spacing: TDSpacing.md) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.accentGold, Color.accentGoldLight],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                
                Image(systemName: "crown.fill")
                    .font(.system(size: 45))
                    .foregroundColor(.white)
            }
            
            Text(T("Alle Kurse freischalten"))
                .font(TDTypography.title1)
                .foregroundColor(.primary)
            
            Text(T("Erhalte unbegrenzten Zugriff auf alle Tanzkurse mit einem Abo"))
                .font(TDTypography.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, TDSpacing.lg)
    }
    
    // MARK: - Benefits
    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: TDSpacing.md) {
            BenefitRow(icon: "play.circle.fill", text: "Zugriff auf alle \(MockData.courses.count) Kurse")
            BenefitRow(icon: "film.fill", text: "Alle Videos in HD-Qualität")
            BenefitRow(icon: "arrow.down.circle.fill", text: "Videos offline herunterladen")
            BenefitRow(icon: "sparkles", text: "Neue Kurse sofort verfügbar")
            BenefitRow(icon: "xmark.circle.fill", text: "Jederzeit kündbar")
        }
        .padding(TDSpacing.md)
        .glassBackground()
    }
    
    // MARK: - Plan Selection
    private var planSelectionSection: some View {
        VStack(spacing: TDSpacing.md) {
            // Yearly Plan (empfohlen)
            SubscriptionPlanCard(
                type: .yearly,
                product: storeViewModel.yearlySubscription,
                isSelected: selectedPlan == .yearly,
                savingsPercent: storeViewModel.yearlySavingsPercent,
                monthlyPrice: storeViewModel.yearlyMonthlyPrice
            ) {
                selectedPlan = .yearly
            }
            
            // Monthly Plan
            SubscriptionPlanCard(
                type: .monthly,
                product: storeViewModel.monthlySubscription,
                isSelected: selectedPlan == .monthly,
                savingsPercent: nil,
                monthlyPrice: nil
            ) {
                selectedPlan = .monthly
            }
        }
    }
    
    // MARK: - Subscribe Button
    private var subscribeButton: some View {
        VStack(spacing: TDSpacing.sm) {
            // Hinweis wenn nicht eingeloggt
            if !userManager.isLoggedIn {
                HStack(spacing: TDSpacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(T("Bitte erstelle zuerst einen Account"))
                        .font(TDTypography.caption1)
                        .foregroundColor(.orange)
                }
                .padding(TDSpacing.sm)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(TDRadius.sm)
            }
            
            Button {
                if userManager.isLoggedIn {
                    Task {
                        isPurchasing = true
                        _ = await storeViewModel.purchaseSubscription(selectedPlan)
                        isPurchasing = false
                        
                        if storeViewModel.hasActiveSubscription {
                            dismiss()
                        }
                    }
                } else {
                    showAuthView = true
                }
            } label: {
                HStack {
                    if isPurchasing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text(userManager.isLoggedIn ? "Jetzt abonnieren" : "Anmelden / Registrieren")
                    }
                }
                .font(TDTypography.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(TDSpacing.md)
                .background(userManager.isLoggedIn ? Color.accentGold : Color.blue)
                .cornerRadius(TDRadius.md)
            }
            .disabled(isPurchasing)
        }
        .sheet(isPresented: $showAuthView) {
            AuthView()
        }
    }
    
    // MARK: - Terms
    private var termsSection: some View {
        VStack(spacing: TDSpacing.sm) {
            Text(T("Das Abo verlängert sich automatisch, wenn es nicht mindestens 24 Stunden vor Ende der aktuellen Periode gekündigt wird."))
                .font(TDTypography.caption1)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: TDSpacing.md) {
                Button(T("Nutzungsbedingungen")) {
                    // Open terms
                }
                .font(TDTypography.caption1)
                .foregroundColor(Color.accentGold)
                
                Text(T("•"))
                    .foregroundColor(.secondary)
                
                Button(T("Datenschutz")) {
                    // Open privacy
                }
                .font(TDTypography.caption1)
                .foregroundColor(Color.accentGold)
            }
            
            if storeViewModel.hasActiveSubscription {
                Button(T("Abo verwalten")) {
                    Task {
                        await storeViewModel.manageSubscription()
                    }
                }
                .font(TDTypography.caption1)
                .foregroundColor(Color.accentGold)
                .padding(.top, TDSpacing.sm)
            }
        }
        .padding(.top, TDSpacing.md)
    }
}

// MARK: - Benefit Row
struct BenefitRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: TDSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(Color.accentGold)
                .frame(width: 28)
            
            Text(text)
                .font(TDTypography.body)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}

// MARK: - Subscription Plan Card
struct SubscriptionPlanCard: View {
    let type: StoreViewModel.SubscriptionType
    let product: Product?
    let isSelected: Bool
    let savingsPercent: Int?
    let monthlyPrice: Decimal?
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.accentGold : Color.gray.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Circle()
                            .fill(Color.accentGold)
                            .frame(width: 14, height: 14)
                    }
                }
                
                VStack(alignment: .leading, spacing: TDSpacing.xxs) {
                    HStack {
                        Text(type.displayName)
                            .font(TDTypography.headline)
                            .foregroundColor(.primary)
                        
                        if let savings = savingsPercent {
                            Text("-\(savings)%")
                                .font(TDTypography.caption2)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green)
                                .cornerRadius(4)
                        }
                    }
                    
                    if let monthly = monthlyPrice {
                        Text("nur \(formatPrice(monthly))/Monat")
                            .font(TDTypography.caption1)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Price
                VStack(alignment: .trailing) {
                    if let product = product {
                        Text(product.displayPrice)
                            .font(TDTypography.title3)
                            .foregroundColor(.primary)
                        
                        Text(type == .yearly ? "/Jahr" : "/Monat")
                            .font(TDTypography.caption1)
                            .foregroundColor(.secondary)
                    } else {
                        Text(T("Laden..."))
                            .font(TDTypography.caption1)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(TDSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: TDRadius.md)
                    .fill(Color.gray.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: TDRadius.md)
                            .stroke(isSelected ? Color.accentGold : Color.clear, lineWidth: 2)
                    )
            )
        }
    }
    
    private func formatPrice(_ price: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.string(from: price as NSDecimalNumber) ?? "€\(price)"
    }
}

// MARK: - Current Subscription Badge
struct SubscriptionBadge: View {
    @EnvironmentObject var storeViewModel: StoreViewModel
    
    var body: some View {
        if storeViewModel.hasActiveSubscription {
            HStack(spacing: TDSpacing.xs) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 12))
                
                Text(T("Premium"))
                    .font(TDTypography.caption2)
            }
            .foregroundColor(.white)
            .padding(.horizontal, TDSpacing.sm)
            .padding(.vertical, 4)
            .background(Color.accentGold)
            .cornerRadius(TDRadius.sm)
        }
    }
}

#Preview {
    SubscriptionView()
        .environmentObject(StoreViewModel())
}
