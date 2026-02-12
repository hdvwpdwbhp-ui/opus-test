//
//  TrainingPlanViews.swift
//  Tanzen mit Tatiana Drexler
//
//  Trainingspläne - Trainerunabhängig, nur vom Admin verwaltet
//

import SwiftUI
import StoreKit

// MARK: - Main Training Plan Overview

struct TrainingPlanOverviewView: View {
    @StateObject private var planManager = TrainingPlanManager.shared
    @StateObject private var userManager = UserManager.shared
    
    @State private var showOrderForm = false
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    
                    if !planManager.myOrders.isEmpty {
                        myOrdersSection
                    }
                    
                    planTypesSection
                    howItWorksSection
                    orderButtonSection
                }
                .padding()
            }
            .navigationTitle(T("Trainingspläne"))
            .overlay {
                if isLoading {
                    ProgressView("Lädt...")
                }
            }
            .sheet(isPresented: $showOrderForm) {
                TrainingPlanOrderFormSimple()
            }
            .task {
                await loadData()
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 50))
                .foregroundColor(.accentColor)
            
            Text(T("Personalisierte Trainingspläne"))
                .font(.title2)
                .fontWeight(.bold)
            
            Text(T("Erhalte einen maßgeschneiderten Trainingsplan"))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private var myOrdersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(T("Meine Bestellungen"))
                    .font(.headline)
                Spacer()
                NavigationLink("Alle anzeigen") {
                    MyTrainingPlanOrdersView()
                }
                .font(.subheadline)
            }
            
            ForEach(planManager.myOrders.prefix(3)) { order in
                NavigationLink(destination: TrainingPlanOrderDetailView(order: order)) {
                    TrainingPlanOrderRow(order: order)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var planTypesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(T("Verfügbare Pläne"))
                .font(.headline)
            
            ForEach(TrainingPlanType.allCases, id: \.self) { planType in
                PlanTypeCardSimple(planType: planType, pricing: planManager.pricing)
            }
        }
    }
    
    private var orderButtonSection: some View {
        Button {
            showOrderForm = true
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text(T("Trainingsplan bestellen"))
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.accentColor)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .padding(.top)
    }
    
    private var howItWorksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(T("So funktioniert's"))
                .font(.headline)
            
            let steps = [
                ("Formular ausfüllen", "Erzähl uns von deinen Zielen"),
                ("Plan-Typ wählen", "2, 4, 8 oder 12 Wochen"),
                ("Mit Coins bezahlen", "Sichere Zahlung"),
                ("Plan erhalten", "Innerhalb weniger Tage")
            ]
            
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(width: 24, height: 24)
                        .background(Color.accentColor)
                        .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(step.0)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(step.1)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func loadData() async {
        isLoading = true
        if let userId = userManager.currentUser?.id {
            await planManager.loadMyOrders(userId: userId)
        }
        isLoading = false
    }
}

// MARK: - Simple Plan Type Card

struct PlanTypeCardSimple: View {
    let planType: TrainingPlanType
    let pricing: TrainingPlanPricing
    
    private var coinPrice: Int {
        DanceCoinConfig.coinsForPrice(Decimal(pricing.price(for: planType)))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(planType.displayName)
                        .font(.headline)
                    Text("\(planType.durationWeeks) Wochen")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "bitcoinsign.circle.fill")
                            .foregroundColor(.accentColor)
                        Text("\(coinPrice)")
                            .font(.headline)
                            .foregroundColor(.accentColor)
                    }
                    Text(T("DanceCoins"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Text(planType.description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Simple Order Form

struct TrainingPlanOrderFormSimple: View {
    @StateObject private var planManager = TrainingPlanManager.shared
    @StateObject private var userManager = UserManager.shared
    @StateObject private var coinManager = CoinManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedPlanType: TrainingPlanType = .standard
    @State private var experience: DanceExperience = .beginner
    @State private var fitnessLevel: FitnessLevel = .moderate
    @State private var trainingDays: Int = 3
    @State private var notes: String = ""
    @State private var isProcessing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section(T("Plan auswählen")) {
                    Picker("Plan-Typ", selection: $selectedPlanType) {
                        ForEach(TrainingPlanType.allCases, id: \.self) { type in
                            HStack {
                                Text(type.displayName)
                                Text("(\(type.durationWeeks) Wo.)")
                                    .foregroundColor(.secondary)
                            }
                            .tag(type)
                        }
                    }
                    
                    HStack {
                        Text(T("Preis"))
                        Spacer()
                        Text("\(DanceCoinConfig.coinsForPrice(Decimal(planManager.pricing.price(for: selectedPlanType)))) DC")
                            .fontWeight(.bold)
                            .foregroundColor(.accentColor)
                    }
                }
                
                Section(T("Deine Erfahrung")) {
                    Picker("Tanzerfahrung", selection: $experience) {
                        ForEach(DanceExperience.allCases, id: \.self) { exp in
                            Text(exp.displayName).tag(exp)
                        }
                    }
                    
                    Picker("Fitness-Level", selection: $fitnessLevel) {
                        ForEach(FitnessLevel.allCases, id: \.self) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                }
                
                Section(T("Verfügbarkeit")) {
                    Stepper("Training pro Woche: \(trainingDays) Tage", value: $trainingDays, in: 1...7)
                }
                
                Section(T("Wünsche (optional)")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
                
                Section {
                    HStack {
                        Text(T("Dein Guthaben"))
                        Spacer()
                        Text("\(coinManager.balance) DC")
                            .fontWeight(.bold)
                    }
                }
            }
            .navigationTitle(T("Trainingsplan bestellen"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(T("Abbrechen")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(T("Bestellen")) {
                        Task { await submitOrder() }
                    }
                    .disabled(isProcessing)
                }
            }
            .alert(T("Fehler"), isPresented: $showError) {
                Button(T("OK")) { }
            } message: {
                Text(errorMessage)
            }
            .alert(T("Bestellung erfolgreich!"), isPresented: $showSuccess) {
                Button(T("OK")) { dismiss() }
            } message: {
                Text(T("Dein Trainingsplan wird erstellt und du wirst benachrichtigt."))
            }
        }
    }
    
    private func submitOrder() async {
        guard let user = userManager.currentUser else {
            errorMessage = "Du musst angemeldet sein"
            showError = true
            return
        }
        
        let price = planManager.pricing.price(for: selectedPlanType)
        let coinAmount = DanceCoinConfig.coinsForPrice(Decimal(price))
        
        guard coinManager.balance >= coinAmount else {
            errorMessage = "Nicht genug DanceCoins. Du brauchst \(coinAmount) DC."
            showError = true
            return
        }
        
        isProcessing = true
        
        // Create simple form data
        var formData = TrainingPlanFormData()
        formData.danceExperience = experience
        formData.fitnessLevel = fitnessLevel
        formData.trainingDaysPerWeek = trainingDays
        formData.additionalNotes = notes.isEmpty ? nil : notes
        
        let order = TrainingPlanOrder(
            userId: user.id,
            userName: user.name,
            userEmail: user.email,
            trainerId: "admin",
            trainerName: "Tanzen mit Tatiana",
            formData: formData,
            planType: selectedPlanType,
            price: price,
            coinAmount: coinAmount
        )
        
        do {
            _ = try await planManager.createOrder(userId: user.id, userName: user.name, userEmail: user.email, trainerId: "admin", trainerName: "Tanzen mit Tatiana", formData: formData, planType: selectedPlanType)
            _ = await coinManager.spendCoins(coinAmount, reason: .trainingPlanCharge, description: "Trainingsplan: \(selectedPlanType.displayName)")
            
            await MainActor.run {
                isProcessing = false
                showSuccess = true
            }
        } catch {
            await MainActor.run {
                errorMessage = "Fehler: \(error.localizedDescription)"
                showError = true
                isProcessing = false
            }
        }
    }
}

// MARK: - Order Row

struct TrainingPlanOrderRow: View {
    let order: TrainingPlanOrder
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: order.status.icon)
                .font(.title2)
                .foregroundColor(statusColor)
                .frame(width: 44, height: 44)
                .background(statusColor.opacity(0.1))
                .cornerRadius(12)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(order.orderNumber)
                    .font(.headline)
                Text(order.planType.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(order.status.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(statusColor)
                
                Text(formatDate(order.createdAt))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var statusColor: Color {
        switch order.status.color {
        case "orange": return .orange
        case "blue": return .blue
        case "purple": return .purple
        case "green": return .green
        case "red": return .red
        default: return .gray
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - My Orders View

struct MyTrainingPlanOrdersView: View {
    @StateObject private var planManager = TrainingPlanManager.shared
    @StateObject private var userManager = UserManager.shared
    
    var body: some View {
        List {
            ForEach(planManager.myOrders) { order in
                NavigationLink(destination: TrainingPlanOrderDetailView(order: order)) {
                    TrainingPlanOrderRow(order: order)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(T("Meine Bestellungen"))
        .task {
            if let userId = userManager.currentUser?.id {
                await planManager.loadMyOrders(userId: userId)
            }
        }
    }
}

// MARK: - Order Detail View

struct TrainingPlanOrderDetailView: View {
    let order: TrainingPlanOrder
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Status
                HStack {
                    Image(systemName: order.status.icon)
                        .font(.largeTitle)
                        .foregroundColor(statusColor)
                    
                    VStack(alignment: .leading) {
                        Text(order.status.displayName)
                            .font(.headline)
                        Text(order.createdAt, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding()
                .background(statusColor.opacity(0.1))
                .cornerRadius(12)
                
                // Details
                VStack(alignment: .leading, spacing: 12) {
                    Text(T("Bestelldetails"))
                        .font(.headline)
                    
                    TrainingPlanDetailRow(label: "Bestellnummer", value: order.orderNumber)
                    TrainingPlanDetailRow(label: "Plan", value: order.planType.displayName)
                    TrainingPlanDetailRow(label: "Dauer", value: "\(order.planType.durationWeeks) Wochen")
                    TrainingPlanDetailRow(label: "Preis", value: "\(order.coinAmount) DC")
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Delivered Plan
                if let plan = order.deliveredPlan {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(T("Dein Trainingsplan"))
                            .font(.headline)
                        
                        if let message = plan.trainerMessage {
                            Text(message)
                                .font(.subheadline)
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
        .navigationTitle(order.orderNumber)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var statusColor: Color {
        switch order.status.color {
        case "orange": return .orange
        case "blue": return .blue
        case "purple": return .purple
        case "green": return .green
        case "red": return .red
        default: return .gray
        }
    }
}

struct TrainingPlanDetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    TrainingPlanOverviewView()
}
