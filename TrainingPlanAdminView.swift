//
//  TrainingPlanAdminView.swift
//  Tanzen mit Tatiana Drexler
//
//  Created on 09.02.2026.
//

import SwiftUI

// MARK: - Admin Dashboard for Training Plans

struct TrainingPlanAdminView: View {
    @StateObject private var planManager = TrainingPlanManager.shared
    @EnvironmentObject var userManager: UserManager
    
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab Selection
            Picker("", selection: $selectedTab) {
                Text(T("Preise")).tag(0)
                Text(T("Bestellungen")).tag(1)
                Text(T("Statistiken")).tag(2)
            }
            .pickerStyle(.segmented)
            .padding()
            
            // Content
            TabView(selection: $selectedTab) {
                PricingAdminView()
                    .tag(0)
                
                AllOrdersAdminView()
                    .tag(1)
                
                PlanStatisticsView()
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .navigationTitle(T("Trainingspläne verwalten"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Pricing Admin View

struct PricingAdminView: View {
    @StateObject private var planManager = TrainingPlanManager.shared
    @EnvironmentObject var userManager: UserManager
    
    @State private var basicPrice: Double = 29.99
    @State private var standardPrice: Double = 49.99
    @State private var premiumPrice: Double = 89.99
    @State private var intensivePrice: Double = 149.99
    
    @State private var isSaving = false
    @State private var showSaveSuccess = false
    @State private var errorMessage: String?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Info Banner
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                    Text(T("Diese Preise gelten für alle Trainer. Änderungen werden sofort wirksam."))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
                
                // Price Cards
                PriceEditCard(
                    planType: .basic,
                    price: $basicPrice,
                    description: "2 Wochen Trainingsplan"
                )
                
                PriceEditCard(
                    planType: .standard,
                    price: $standardPrice,
                    description: "4 Wochen Trainingsplan"
                )
                
                PriceEditCard(
                    planType: .premium,
                    price: $premiumPrice,
                    description: "8 Wochen Trainingsplan"
                )
                
                PriceEditCard(
                    planType: .intensive,
                    price: $intensivePrice,
                    description: "12 Wochen Trainingsplan"
                )
                
                // Last Updated Info
                if !planManager.pricing.updatedBy.isEmpty {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.secondary)
                        Text(T("Zuletzt aktualisiert: %@", formatDate(planManager.pricing.lastUpdated)))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Save Button
                Button {
                    savePricing()
                } label: {
                    HStack {
                        if isSaving {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                            Text(T("Preise speichern"))
                        }
                    }
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isSaving)
            }
            .padding()
        }
        .onAppear {
            loadCurrentPricing()
        }
        .alert(T("Preise gespeichert"), isPresented: $showSaveSuccess) {
            Button(T("OK"), role: .cancel) {}
        } message: {
            Text(T("Die neuen Preise wurden erfolgreich gespeichert und sind ab sofort aktiv."))
        }
        .alert(T("Fehler"), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(T("OK"), role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Unbekannter Fehler")
        }
    }
    
    private func loadCurrentPricing() {
        basicPrice = planManager.pricing.basicPrice
        standardPrice = planManager.pricing.standardPrice
        premiumPrice = planManager.pricing.premiumPrice
        intensivePrice = planManager.pricing.intensivePrice
    }
    
    private func savePricing() {
        guard let adminId = userManager.currentUser?.id else { return }
        
        isSaving = true
        
        var pricing = TrainingPlanPricing()
        pricing.basicPrice = basicPrice
        pricing.standardPrice = standardPrice
        pricing.premiumPrice = premiumPrice
        pricing.intensivePrice = intensivePrice
        
        Task {
            do {
                try await planManager.updatePricing(pricing, by: adminId)
                await MainActor.run {
                    isSaving = false
                    showSaveSuccess = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSaving = false
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct PriceEditCard: View {
    let planType: TrainingPlanType
    @Binding var price: Double
    let description: String
    
    @State private var priceText = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(planType.displayName)
                        .font(.headline)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Price Input
                HStack(spacing: 4) {
                    TextField(T("0.00"), text: $priceText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: priceText) { _, newValue in
                            if let value = Double(newValue.replacingOccurrences(of: ",", with: ".")) {
                                price = value
                            }
                        }
                    
                    Text(T("€"))
                        .fontWeight(.medium)
                }
            }
            
            // Features Preview
            HStack(spacing: 16) {
                ForEach(planType.features.prefix(3), id: \.self) { feature in
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.caption2)
                            .foregroundColor(.green)
                        Text(feature)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .onAppear {
            priceText = String(format: "%.2f", price)
        }
    }
}

// MARK: - All Orders Admin View

struct AllOrdersAdminView: View {
    @StateObject private var planManager = TrainingPlanManager.shared
    
    @State private var selectedStatus: TrainingPlanOrderStatus? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // Filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    AdminFilterChip(
                        title: "Alle",
                        count: planManager.orders.count,
                        isSelected: selectedStatus == nil
                    ) {
                        selectedStatus = nil
                    }
                    
                    ForEach(TrainingPlanOrderStatus.allCases, id: \.self) { status in
                        AdminFilterChip(
                            title: status.displayName,
                            count: planManager.orders.filter { $0.status == status }.count,
                            isSelected: selectedStatus == status
                        ) {
                            selectedStatus = status
                        }
                    }
                }
                .padding()
            }
            
            // Orders List
            if filteredOrders.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    Text(T("Keine Bestellungen"))
                        .font(.headline)
                }
                .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(filteredOrders) { order in
                        NavigationLink(destination: AdminOrderDetailView(order: order)) {
                            AdminOrderRow(order: order)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .task {
            await planManager.loadAllOrders()
        }
    }
    
    private var filteredOrders: [TrainingPlanOrder] {
        if let status = selectedStatus {
            return planManager.orders.filter { $0.status == status }
        }
        return planManager.orders
    }
}

struct AdminFilterChip: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Text(title)
                if count > 0 {
                    Text("(\(count))")
                        .font(.caption2)
                }
            }
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor : Color(.systemGray5))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
        }
    }
}

struct AdminOrderRow: View {
    let order: TrainingPlanOrder
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(order.orderNumber)
                    .font(.headline)
                Spacer()
                TrainingPlanStatusBadge(status: order.status)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(T("Kunde: %@", order.userName))
                        .font(.subheadline)
                    Text(T("Trainer: %@", order.trainerName))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(formatPrice(order.price))
                    .fontWeight(.semibold)
            }
            
            HStack {
                Text(order.planType.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(4)
                
                Spacer()
                
                Text(formatDate(order.createdAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatPrice(_ price: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        return formatter.string(from: NSNumber(value: price)) ?? "\(price) €"
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

struct AdminOrderDetailView: View {
    let order: TrainingPlanOrder
    @StateObject private var planManager = TrainingPlanManager.shared
    
    @State private var showRefundAlert = false
    @State private var showCancelAlert = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Status Overview
                statusOverview
                
                // Customer Info
                sectionCard(title: "Kunde") {
                    infoRow("Name", order.userName)
                    infoRow("E-Mail", order.userEmail)
                }
                
                // Trainer Info
                sectionCard(title: "Trainer") {
                    infoRow("Name", order.trainerName)
                    infoRow("Trainer-ID", order.trainerId)
                }
                
                // Order Details
                sectionCard(title: "Bestellung") {
                    infoRow("Bestellnummer", order.orderNumber)
                    infoRow("Plan", order.planType.displayName)
                    infoRow("Dauer", "\(order.planType.durationWeeks) Wochen")
                    infoRow("Preis", formatPrice(order.price))
                    infoRow("Erstellt", formatDate(order.createdAt))
                    if let paidAt = order.paidAt {
                        infoRow("Bezahlt", formatDate(paidAt))
                    }
                    if let transactionId = order.transactionId {
                        infoRow("Transaktions-ID", transactionId)
                    }
                }
                
                // Form Summary
                sectionCard(title: "Kundenangaben (Zusammenfassung)") {
                    infoRow("Alter", "\(order.formData.age) Jahre")
                    infoRow("Erfahrung", order.formData.danceExperience.displayName)
                    infoRow("Fitness", order.formData.fitnessLevel.displayName)
                    infoRow("Hauptziel", order.formData.primaryGoal.displayName)
                }
                
                // Admin Actions
                adminActions
            }
            .padding()
        }
        .navigationTitle(order.orderNumber)
        .navigationBarTitleDisplayMode(.inline)
        .alert(T("Bestellung stornieren?"), isPresented: $showCancelAlert) {
            Button(T("Abbrechen"), role: .cancel) {}
            Button(T("Stornieren"), role: .destructive) {
                cancelOrder()
            }
        } message: {
            Text(T("Diese Aktion kann nicht rückgängig gemacht werden."))
        }
        .alert(T("Rückerstattung?"), isPresented: $showRefundAlert) {
            Button(T("Abbrechen"), role: .cancel) {}
            Button(T("Erstatten"), role: .destructive) {
                refundOrder()
            }
        } message: {
            Text(T("Der Betrag von %@ wird erstattet.", formatPrice(order.price)))
        }
    }
    
    private var statusOverview: some View {
        HStack {
            Image(systemName: order.status.icon)
                .font(.largeTitle)
                .foregroundColor(statusColor)
            
            VStack(alignment: .leading) {
                Text(order.status.displayName)
                    .font(.headline)
                Text(T("Status"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text(formatPrice(order.price))
                    .font(.title2)
                    .fontWeight(.bold)
                Text(T("Bestellwert"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(statusColor.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }
    
    private var adminActions: some View {
        VStack(spacing: 12) {
            if order.status == .paid || order.status == .inProgress {
                Button {
                    showCancelAlert = true
                } label: {
                    Label(T("Bestellung stornieren"), systemImage: "xmark.circle")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                        .cornerRadius(12)
                }
            }
            
            if order.status == .delivered || order.status == .completed {
                Button {
                    showRefundAlert = true
                } label: {
                    Label(T("Rückerstattung"), systemImage: "arrow.uturn.left.circle")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .foregroundColor(.orange)
                        .cornerRadius(12)
                }
            }
        }
    }
    
    private func cancelOrder() {
        Task {
            try? await planManager.updateOrderStatus(orderId: order.id, status: .cancelled)
        }
    }
    
    private func refundOrder() {
        Task {
            try? await planManager.updateOrderStatus(orderId: order.id, status: .refunded)
        }
    }
    
    private var statusColor: Color {
        switch order.status.color {
        case "orange": return .orange
        case "blue": return .blue
        case "purple": return .purple
        case "indigo": return .indigo
        case "green": return .green
        case "gray": return .gray
        case "red": return .red
        default: return .primary
        }
    }
    
    private func formatPrice(_ price: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        return formatter.string(from: NSNumber(value: price)) ?? "\(price) €"
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Statistics View

struct PlanStatisticsView: View {
    @StateObject private var planManager = TrainingPlanManager.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Revenue Overview
                HStack(spacing: 16) {
                    TrainingPlanStatCard(
                        title: "Gesamtumsatz",
                        value: formatPrice(totalRevenue),
                        icon: "eurosign.circle.fill",
                        color: .green
                    )
                    
                    TrainingPlanStatCard(
                        title: "Bestellungen",
                        value: "\(planManager.orders.count)",
                        icon: "doc.text.fill",
                        color: .blue
                    )
                }
                
                HStack(spacing: 16) {
                    TrainingPlanStatCard(
                        title: "Abgeschlossen",
                        value: "\(completedOrders)",
                        icon: "checkmark.circle.fill",
                        color: .green
                    )
                    
                    TrainingPlanStatCard(
                        title: "In Bearbeitung",
                        value: "\(inProgressOrders)",
                        icon: "hammer.fill",
                        color: .purple
                    )
                }
                
                // Plan Type Distribution
                VStack(alignment: .leading, spacing: 12) {
                    Text(T("Bestellungen nach Plan-Typ"))
                        .font(.headline)
                    
                    ForEach(TrainingPlanType.allCases, id: \.self) { planType in
                        let count = planManager.orders.filter { $0.planType == planType }.count
                        let percentage = planManager.orders.isEmpty ? 0 : Double(count) / Double(planManager.orders.count) * 100
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(planType.displayName)
                                    .font(.subheadline)
                                Spacer()
                                Text("\(count) (\(Int(percentage))%)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Rectangle()
                                        .fill(Color(.systemGray5))
                                        .frame(height: 8)
                                        .cornerRadius(4)
                                    
                                    Rectangle()
                                        .fill(Color.accentColor)
                                        .frame(width: geo.size.width * CGFloat(percentage / 100), height: 8)
                                        .cornerRadius(4)
                                }
                            }
                            .frame(height: 8)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Average Rating
                if averageRating > 0 {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(T("Durchschnittliche Bewertung"))
                            .font(.headline)
                        
                        HStack {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: star <= Int(averageRating.rounded()) ? "star.fill" : "star")
                                    .foregroundColor(.yellow)
                            }
                            Text(String(format: "%.1f", averageRating))
                                .fontWeight(.bold)
                            Text("(\(ratedOrders) Bewertungen)")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
            }
            .padding()
        }
        .task {
            await planManager.loadAllOrders()
        }
    }
    
    private var totalRevenue: Double {
        planManager.orders
            .filter { $0.status != .cancelled && $0.status != .refunded && $0.status != .pendingPayment }
            .reduce(0) { $0 + $1.price }
    }
    
    private var completedOrders: Int {
        planManager.orders.filter { $0.status == .completed || $0.status == .delivered }.count
    }
    
    private var inProgressOrders: Int {
        planManager.orders.filter { $0.status == .paid || $0.status == .inProgress }.count
    }
    
    private var averageRating: Double {
        let ratings = planManager.orders.compactMap { $0.rating }
        guard !ratings.isEmpty else { return 0 }
        return Double(ratings.reduce(0, +)) / Double(ratings.count)
    }
    
    private var ratedOrders: Int {
        planManager.orders.filter { $0.rating != nil }.count
    }
    
    private func formatPrice(_ price: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        return formatter.string(from: NSNumber(value: price)) ?? "\(price) €"
    }
}

struct TrainingPlanStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        TrainingPlanAdminView()
    }
    .environmentObject(UserManager.shared)
}
