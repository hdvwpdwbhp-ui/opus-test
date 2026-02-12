//
//  TrainerPlanSettingsView.swift
//  Tanzen mit Tatiana Drexler
//
//  Created on 09.02.2026.
//

import SwiftUI

// MARK: - Trainer Settings for Training Plans

struct TrainerPlanSettingsView: View {
    @StateObject private var planManager = TrainingPlanManager.shared
    @EnvironmentObject var userManager: UserManager
    
    @State private var settings = TrainerPlanSettings()
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var showSaveSuccess = false
    @State private var newSpecialization = ""
    
    var body: some View {
        Form {
            // Enable/Disable Section
            Section {
                Toggle("Trainingspläne anbieten", isOn: $settings.offersTrainingPlans)
                    .tint(.accentColor)
            } header: {
                Text(T("Verfügbarkeit"))
            } footer: {
                Text(T("Wenn aktiviert, können Kunden personalisierte Trainingspläne bei dir bestellen."))
            }
            
            if settings.offersTrainingPlans {
                // Plan Types Section
                Section {
                    ForEach(TrainingPlanType.allCases, id: \.self) { planType in
                        Toggle(planType.displayName, isOn: Binding(
                            get: { settings.availablePlanTypes.contains(planType) },
                            set: { isOn in
                                if isOn {
                                    if !settings.availablePlanTypes.contains(planType) {
                                        settings.availablePlanTypes.append(planType)
                                    }
                                } else {
                                    settings.availablePlanTypes.removeAll { $0 == planType }
                                }
                            }
                        ))
                        .tint(.accentColor)
                    }
                } header: {
                    Text(T("Angebotene Pläne"))
                } footer: {
                    Text(T("Wähle aus, welche Plan-Typen du anbieten möchtest. Die Preise werden vom Admin festgelegt."))
                }
                
                // Specializations Section
                Section {
                    ForEach(settings.specializations, id: \.self) { spec in
                        HStack {
                            Text(spec)
                            Spacer()
                            Button {
                                settings.specializations.removeAll { $0 == spec }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    
                    HStack {
                        TextField(T("Neue Spezialisierung"), text: $newSpecialization)
                        Button {
                            if !newSpecialization.isEmpty {
                                settings.specializations.append(newSpecialization)
                                newSpecialization = ""
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.accentColor)
                        }
                        .disabled(newSpecialization.isEmpty)
                    }
                } header: {
                    Text(T("Spezialisierungen"))
                } footer: {
                    Text(T("Z.B. 'Salsa', 'Hochzeitstanz', 'Wettkampf-Vorbereitung'"))
                }
                
                // Delivery Settings Section
                Section {
                    Stepper("Max. \(settings.maxActiveOrders) aktive Bestellungen", value: $settings.maxActiveOrders, in: 1...20)
                    
                    Stepper("~\(settings.averageDeliveryDays) Tage Lieferzeit", value: $settings.averageDeliveryDays, in: 1...30)
                } header: {
                    Text(T("Kapazität & Lieferzeit"))
                } footer: {
                    Text(T("Begrenze die Anzahl gleichzeitiger Bestellungen und gib eine realistische Lieferzeit an."))
                }
                
                // Custom Intro Section
                Section {
                    TextField(T("Persönliche Nachricht für Kunden..."), text: Binding(
                        get: { settings.customIntroText ?? "" },
                        set: { settings.customIntroText = $0.isEmpty ? nil : $0 }
                    ), axis: .vertical)
                    .lineLimit(3...6)
                } header: {
                    Text(T("Einleitung"))
                } footer: {
                    Text(T("Diese Nachricht wird Kunden angezeigt, wenn sie einen Plan bei dir bestellen möchten."))
                }
            }
            
            // Save Button
            Section {
                Button {
                    saveSettings()
                } label: {
                    HStack {
                        Spacer()
                        if isSaving {
                            ProgressView()
                        } else {
                            Text(T("Speichern"))
                                .fontWeight(.semibold)
                        }
                        Spacer()
                    }
                }
                .disabled(isSaving)
            }
        }
        .navigationTitle(T("Trainingsplan-Einstellungen"))
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if isLoading {
                ProgressView("Lädt...")
            }
        }
        .alert(T("Gespeichert"), isPresented: $showSaveSuccess) {
            Button(T("OK"), role: .cancel) {}
        } message: {
            Text(T("Deine Einstellungen wurden erfolgreich gespeichert."))
        }
        .task {
            await loadSettings()
        }
    }
    
    private func loadSettings() async {
        guard let trainerId = userManager.currentUser?.id else { return }
        
        if let loadedSettings = await planManager.loadTrainerPlanSettings(trainerId: trainerId) {
            await MainActor.run {
                settings = loadedSettings
            }
        }
        
        await MainActor.run {
            isLoading = false
        }
    }
    
    private func saveSettings() {
        guard let trainerId = userManager.currentUser?.id else { return }
        
        isSaving = true
        
        Task {
            do {
                try await planManager.updateTrainerPlanSettings(trainerId: trainerId, settings: settings)
                await MainActor.run {
                    isSaving = false
                    showSaveSuccess = true
                }
            } catch {
                print("Error saving settings: \(error)")
                await MainActor.run {
                    isSaving = false
                }
            }
        }
    }
}

// MARK: - Trainer Orders View

struct TrainerPlanOrdersView: View {
    @StateObject private var planManager = TrainingPlanManager.shared
    @EnvironmentObject var userManager: UserManager
    
    @State private var selectedFilter: TrainingPlanOrderStatus? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // Filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChipView(
                        title: "Alle",
                        isSelected: selectedFilter == nil
                    ) {
                        selectedFilter = nil
                    }
                    
                    ForEach([TrainingPlanOrderStatus.paid, .inProgress, .delivered, .completed], id: \.self) { status in
                        FilterChipView(
                            title: status.displayName,
                            isSelected: selectedFilter == status
                        ) {
                            selectedFilter = status
                        }
                    }
                }
                .padding()
            }
            
            // Orders List
            List {
                ForEach(filteredOrders) { order in
                    NavigationLink(destination: TrainerOrderDetailView(order: order)) {
                        TrainerOrderRow(order: order)
                    }
                }
            }
            .listStyle(.plain)
        }
        .navigationTitle(T("Bestellungen"))
        .task {
            if let trainerId = userManager.currentUser?.id {
                await planManager.loadTrainerOrders(trainerId: trainerId)
            }
        }
    }
    
    private var filteredOrders: [TrainingPlanOrder] {
        if let filter = selectedFilter {
            return planManager.trainerOrders.filter { $0.status == filter }
        }
        return planManager.trainerOrders
    }
}

struct FilterChipView: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

struct TrainerOrderRow: View {
    let order: TrainingPlanOrder
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(order.orderNumber)
                    .font(.headline)
                Spacer()
                TrainingPlanStatusBadge(status: order.status)
            }
            
            Text(order.userName)
                .font(.subheadline)
            
            HStack {
                Text(order.planType.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(formatDate(order.createdAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

struct TrainingPlanStatusBadge: View {
    let status: TrainingPlanOrderStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
                .font(.caption2)
            Text(status.displayName)
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.1))
        .foregroundColor(statusColor)
        .cornerRadius(8)
    }
    
    private var statusColor: Color {
        switch status.color {
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
}

// MARK: - Trainer Order Detail View

struct TrainerOrderDetailView: View {
    let order: TrainingPlanOrder
    @StateObject private var planManager = TrainingPlanManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var notes = ""
    @State private var isUpdating = false
    @State private var showDeliverySheet = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Status
                statusSection
                
                // Customer Info
                customerInfoSection
                
                // Form Data
                formDataSection
                
                // Actions
                actionsSection
            }
            .padding()
        }
        .navigationTitle(order.orderNumber)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showDeliverySheet) {
            DeliverySheetView(order: order)
        }
    }
    
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: order.status.icon)
                    .font(.title)
                    .foregroundColor(statusColor)
                
                VStack(alignment: .leading) {
                    Text(order.status.displayName)
                        .font(.headline)
                    if let paidAt = order.paidAt {
                        Text(T("Bezahlt: %@", formatDate(paidAt)))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Text(formatPrice(order.price))
                    .font(.title2)
                    .fontWeight(.bold)
            }
        }
        .padding()
        .background(statusColor.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var customerInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(T("Kunde"))
                .font(.headline)
            
            HStack {
                Image(systemName: "person.fill")
                    .foregroundColor(.secondary)
                Text(order.userName)
            }
            
            HStack {
                Image(systemName: "envelope.fill")
                    .foregroundColor(.secondary)
                Text(order.userEmail)
            }
            
            HStack {
                Image(systemName: "doc.text.fill")
                    .foregroundColor(.secondary)
                Text("\(order.planType.displayName) (\(order.planType.durationWeeks) Wochen)")
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var formDataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(T("Kundenangaben"))
                .font(.headline)
            
            Group {
                infoRow("Alter", "\(order.formData.age) Jahre")
                infoRow("Geschlecht", order.formData.gender.displayName)
                infoRow("Größe/Gewicht", "\(order.formData.height) cm / \(order.formData.weight) kg")
                infoRow("Tanzerfahrung", order.formData.danceExperience.displayName)
                infoRow("Fitness-Level", order.formData.fitnessLevel.displayName)
                infoRow("Hauptziel", order.formData.primaryGoal.displayName)
                infoRow("Training/Woche", "\(order.formData.trainingDaysPerWeek) Tage à \(order.formData.minutesPerSession) Min")
                infoRow("Lernstil", order.formData.learningStyle.displayName)
            }
            
            if !order.formData.targetDanceStyles.isEmpty {
                infoRow("Ziel-Tanzstile", order.formData.targetDanceStyles.joined(separator: ", "))
            }
            
            if !order.formData.currentDanceStyles.isEmpty {
                infoRow("Aktuelle Stile", order.formData.currentDanceStyles.joined(separator: ", "))
            }
            
            if let health = order.formData.healthIssues {
                infoRow("Gesundheit", health)
            }
            
            if let notes = order.formData.additionalNotes {
                VStack(alignment: .leading, spacing: 4) {
                    Text(T("Zusätzliche Anmerkungen"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(notes)
                        .font(.subheadline)
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var actionsSection: some View {
        VStack(spacing: 12) {
            if order.status == .paid {
                Button {
                    updateStatus(.inProgress)
                } label: {
                    Label(T("Mit Bearbeitung beginnen"), systemImage: "hammer")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
            
            if order.status == .inProgress {
                Button {
                    showDeliverySheet = true
                } label: {
                    Label(T("Plan liefern"), systemImage: "paperplane.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
            
            // Notes
            VStack(alignment: .leading, spacing: 8) {
                Text(T("Notizen"))
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                TextField(T("Interne Notizen..."), text: $notes, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...5)
                
                if !notes.isEmpty {
                    Button {
                        saveNotes()
                    } label: {
                        Text(T("Notizen speichern"))
                            .font(.subheadline)
                    }
                }
            }
        }
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
    
    private func updateStatus(_ status: TrainingPlanOrderStatus) {
        isUpdating = true
        
        Task {
            do {
                try await planManager.updateOrderStatus(orderId: order.id, status: status, notes: notes.isEmpty ? nil : notes)
                await MainActor.run {
                    isUpdating = false
                }
            } catch {
                print("Error updating status: \(error)")
                isUpdating = false
            }
        }
    }
    
    private func saveNotes() {
        Task {
            try? await planManager.updateOrderStatus(orderId: order.id, status: order.status, notes: notes)
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
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatPrice(_ price: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        return formatter.string(from: NSNumber(value: price)) ?? "\(price) €"
    }
}

// MARK: - Delivery Sheet

struct DeliverySheetView: View {
    let order: TrainingPlanOrder
    @StateObject private var planManager = TrainingPlanManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var trainerMessage = ""
    @State private var pdfUrl = ""
    @State private var isDelivering = false
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField(T("Nachricht an den Kunden"), text: $trainerMessage, axis: .vertical)
                        .lineLimit(5...10)
                } header: {
                    Text(T("Persönliche Nachricht"))
                }
                
                Section {
                    TextField(T("Link zum PDF"), text: $pdfUrl)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                } header: {
                    Text(T("Trainingsplan PDF"))
                } footer: {
                    Text(T("Lade den PDF-Trainingsplan hoch und füge den Link hier ein."))
                }
                
                Section {
                    Button {
                        deliverPlan()
                    } label: {
                        HStack {
                            Spacer()
                            if isDelivering {
                                ProgressView()
                            } else {
                                Label(T("Plan liefern"), systemImage: "paperplane.fill")
                            }
                            Spacer()
                        }
                    }
                    .disabled(isDelivering || pdfUrl.isEmpty)
                }
            }
            .navigationTitle(T("Plan liefern"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(T("Abbrechen")) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func deliverPlan() {
        isDelivering = true
        
        let plan = DeliveredTrainingPlan(
            id: UUID().uuidString,
            createdAt: Date(),
            weeks: [], // In der echten App würde hier der Plan-Builder sein
            pdfUrl: pdfUrl.isEmpty ? nil : pdfUrl,
            additionalVideos: nil,
            musicPlaylist: nil,
            trainerMessage: trainerMessage.isEmpty ? nil : trainerMessage
        )
        
        Task {
            do {
                try await planManager.deliverPlan(orderId: order.id, plan: plan)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("Error delivering plan: \(error)")
                isDelivering = false
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        TrainerPlanSettingsView()
    }
    .environmentObject(UserManager.shared)
}
