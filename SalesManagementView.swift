//
//  SalesManagementView.swift
//  Tanzen mit Tatiana Drexler
//
//  Admin-View für Rabattaktionen/Sales
//

import SwiftUI

struct SalesManagementView: View {
    @StateObject private var settingsManager = AppSettingsManager.shared
    @State private var showCreateSale = false
    
    var activeSalesFiltered: [CourseSale] {
        settingsManager.settings.activeSales.filter { $0.isCurrentlyActive }
    }
    
    var pastSales: [CourseSale] {
        settingsManager.settings.activeSales.filter { !$0.isCurrentlyActive }
    }
    
    var body: some View {
        List {
            Section {
                if activeSalesFiltered.isEmpty {
                    ContentUnavailableView("Keine aktiven Sales", systemImage: "tag.slash", description: Text(T("Erstelle einen neuen Sale")))
                } else {
                    ForEach(activeSalesFiltered) { sale in
                        SaleRow(sale: sale)
                    }
                }
            } header: {
                Text(T("Aktive Rabattaktionen"))
            }
            
            if !pastSales.isEmpty {
                Section(T("Vergangene/Inaktive")) {
                    ForEach(pastSales) { sale in
                        SaleRow(sale: sale)
                    }
                }
            }
        }
        .navigationTitle(T("Sales verwalten"))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showCreateSale = true } label: {
                    Label(T("Neuer Sale"), systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showCreateSale) {
            CreateSaleView()
        }
    }
}

struct SaleRow: View {
    let sale: CourseSale
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(sale.title)
                    .font(TDTypography.headline)
                
                if sale.isCurrentlyActive {
                    Text(T("AKTIV"))
                        .font(TDTypography.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green)
                        .cornerRadius(4)
                }
            }
            
            Text("\(sale.discountPercent)% Rabatt")
                .font(TDTypography.title2)
                .foregroundColor(Color.accentGold)
            
            Text("\(sale.startDate.formatted(date: .abbreviated, time: .omitted)) - \(sale.endDate.formatted(date: .abbreviated, time: .omitted))")
                .font(TDTypography.caption1)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct CreateSaleView: View {
    @StateObject private var settingsManager = AppSettingsManager.shared
    @StateObject private var emailService = SaleEmailService.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedCourseIds: Set<String> = []
    @State private var discountPercent = 20
    @State private var title = ""
    @State private var description = ""
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(7*24*60*60)
    @State private var isCreating = false
    @State private var showAlert = false
    @State private var sendEmailNotification = true
    @State private var alertMessage = ""
    @State private var subscriberCount = 0
    
    var body: some View {
        NavigationStack {
            Form {
                Section(T("Kurse auswählen")) {
                    ForEach(MockData.courses) { course in
                        HStack {
                            Text(course.title)
                            Spacer()
                            Image(systemName: selectedCourseIds.contains(course.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(selectedCourseIds.contains(course.id) ? Color.accentGold : .gray)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedCourseIds.contains(course.id) {
                                selectedCourseIds.remove(course.id)
                            } else {
                                selectedCourseIds.insert(course.id)
                            }
                        }
                    }
                    
                    Text(T("Leer = alle Kurse")).font(TDTypography.caption2).foregroundColor(.secondary)
                }
                
                Section(T("Details")) {
                    TextField(T("Titel (z.B. 'Sommer-Sale')"), text: $title)
                    TextField(T("Beschreibung"), text: $description)
                    Stepper("\(discountPercent)% Rabatt", value: $discountPercent, in: 5...90, step: 5)
                }
                
                Section(T("Zeitraum")) {
                    DatePicker("Start", selection: $startDate, displayedComponents: .date)
                    DatePicker("Ende", selection: $endDate, in: startDate..., displayedComponents: .date)
                }
                
                Section {
                    Toggle(isOn: $sendEmailNotification) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(T("E-Mail-Benachrichtigung senden"))
                                .font(TDTypography.body)
                            Text(T("An %@ Abonnenten senden", "\(subscriberCount)"))
                                .font(TDTypography.caption1)
                                .foregroundColor(.secondary)
                        }
                    }
                    .tint(Color.accentGold)
                } header: {
                    Text(T("Benachrichtigungen"))
                } footer: {
                    Text(T("Nur User, die zugestimmt haben, erhalten E-Mails über Sales."))
                }
                
                Section {
                    Button { Task { await createSale() } } label: {
                        HStack {
                            Spacer()
                            if isCreating { ProgressView().tint(.white) }
                            else { Text(T("Sale erstellen")).fontWeight(.semibold) }
                            Spacer()
                        }
                    }
                    .disabled(title.isEmpty || isCreating)
                    .listRowBackground(title.isEmpty ? Color.gray : Color.accentGold)
                    .foregroundColor(.white)
                }
            }
            .navigationTitle(T("Neuer Sale"))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(T("Abbrechen")) { dismiss() }
                }
            }
            .alert(T("Sale erstellt!"), isPresented: $showAlert) {
                Button(T("OK")) { dismiss() }
            } message: {
                Text(alertMessage)
            }
            .task {
                // Lade Anzahl der Subscriber
                let subscribers = await emailService.getMarketingSubscribers()
                subscriberCount = subscribers.count
            }
        }
    }
    
    private func createSale() async {
        isCreating = true
        defer { isCreating = false }
        
        let sale = await settingsManager.createSale(
            courseIds: Array(selectedCourseIds),
            discountPercent: discountPercent,
            title: title,
            description: description,
            startDate: startDate,
            endDate: endDate
        )
        
        // E-Mail-Benachrichtigung senden wenn gewünscht
        if sendEmailNotification, let createdSale = sale {
            let convertedSale = Sale(
                id: createdSale.id,
                title: createdSale.title,
                description: createdSale.description,
                discountPercent: createdSale.discountPercent,
                startDate: createdSale.startDate,
                endDate: createdSale.endDate,
                appliesTo: createdSale.courseIds.isEmpty ? .allCourses : .specificCourses(createdSale.courseIds)
            )
            
            let result = await emailService.sendSaleNotification(sale: convertedSale)
            alertMessage = "✅ Sale erstellt!\n\n\(result.message)"
        } else {
            alertMessage = "✅ Sale erstellt!"
        }
        
        showAlert = true
    }
}

// MARK: - Sale Model for Email

struct Sale {
    let id: String
    let title: String
    let description: String
    let discountPercent: Int
    let startDate: Date
    let endDate: Date
    let appliesTo: SaleAppliesTo
    
    var isAllCourses: Bool {
        if case .allCourses = appliesTo {
            return true
        }
        return false
    }
    
    enum SaleAppliesTo {
        case allCourses
        case specificCourses([String])
    }
}
