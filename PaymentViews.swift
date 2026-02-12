//
//  PaymentViews.swift
//  Tanzen mit Tatiana Drexler
//
//  Views für PayPal-Zahlungen und Zahlungsstatus
//

import SwiftUI
import Combine

// MARK: - Payment Button (für User)
struct PayPalPaymentButton: View {
    let booking: PrivateLessonBooking
    @StateObject private var paypalService = PayPalService.shared
    @State private var showPaymentSheet = false
    
    var body: some View {
        if booking.canPay, let paymentLink = booking.paymentLink {
            Button {
                showPaymentSheet = true
            } label: {
                HStack(spacing: TDSpacing.sm) {
                    Image(systemName: "creditcard.fill")
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(T("Jetzt bezahlen"))
                            .font(TDTypography.headline)
                        Text(booking.price.formatted(.currency(code: "EUR")))
                            .font(TDTypography.caption1)
                    }
                    
                    Spacer()
                    
                    Image("paypal_logo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 24)
                        .opacity(0.9)
                }
                .padding(TDSpacing.md)
                .background(Color(red: 0.0, green: 0.48, blue: 0.8)) // PayPal Blau
                .foregroundColor(.white)
                .cornerRadius(TDRadius.md)
            }
            .sheet(isPresented: $showPaymentSheet) {
                PaymentWebView(
                    url: paymentLink,
                    booking: booking
                )
            }
        }
    }
}

// MARK: - Payment Status Badge
struct PaymentStatusBadge: View {
    let status: PaymentStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
            Text(status.rawValue)
        }
        .font(TDTypography.caption1)
        .fontWeight(.medium)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(status.color.opacity(0.2))
        .foregroundColor(status.color)
        .cornerRadius(TDRadius.sm)
    }
}

// MARK: - Payment Deadline View
struct PaymentDeadlineView: View {
    let deadline: Date
    @StateObject private var paypalService = PayPalService.shared
    @State private var timeRemaining: String = ""
    
    let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    
    var isExpired: Bool {
        Date() > deadline
    }
    
    var body: some View {
        HStack(spacing: TDSpacing.sm) {
            Image(systemName: isExpired ? "exclamationmark.triangle.fill" : "clock.fill")
                .foregroundColor(isExpired ? .red : .orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(isExpired ? "Zahlungsfrist abgelaufen" : "Zahlungsfrist")
                    .font(TDTypography.caption1)
                    .foregroundColor(.secondary)
                
                if isExpired {
                    Text(T("Die Buchung wird automatisch storniert"))
                        .font(TDTypography.caption2)
                        .foregroundColor(.red)
                } else {
                    Text(T("Noch %@", timeRemaining))
                        .font(TDTypography.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                }
            }
        }
        .onAppear {
            updateTimeRemaining()
        }
        .onReceive(timer) { _ in
            updateTimeRemaining()
        }
    }
    
    private func updateTimeRemaining() {
        timeRemaining = paypalService.formatTimeRemaining(until: deadline)
    }
}

// MARK: - Payment Info Card (für Buchungsdetails)
struct PaymentInfoCard: View {
    let booking: PrivateLessonBooking
    @StateObject private var lessonManager = PrivateLessonManager.shared
    @State private var showPayPalSheet = false
    
    var paypalLink: URL? {
        PayPalConfig.paypalMeLink(amount: booking.price, description: booking.paypalDescription)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: TDSpacing.md) {
            // Header mit Status
            HStack {
                Image(systemName: "creditcard.fill")
                    .foregroundColor(Color.accentGold)
                Text(T("Zahlung erforderlich"))
                    .font(TDTypography.headline)
                Spacer()
                PaymentStatusBadge(status: booking.paymentStatus)
            }
            
            Divider()
            
            // Buchungsinfo
            VStack(alignment: .leading, spacing: 4) {
                Text(booking.bookingNumber)
                    .font(TDTypography.caption1)
                    .foregroundColor(.secondary)
                
                if let confirmedDate = booking.confirmedDate {
                    HStack {
                        Image(systemName: "calendar")
                            .font(.caption)
                        Text(confirmedDate.formatted(date: .abbreviated, time: .shortened))
                    }
                    .font(TDTypography.caption1)
                    .foregroundColor(.secondary)
                }
            }
            
            // Preis groß anzeigen
            HStack {
                Text(T("Zu zahlen:"))
                    .font(TDTypography.body)
                Spacer()
                Text(booking.price.formatted(.currency(code: "EUR")))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Color.accentGold)
            }
            .padding(.vertical, 8)
            
            // Zahlungsfrist
            if let deadline = booking.paymentDeadline {
                PaymentDeadlineView(deadline: deadline)
            }
            
            // PayPal Bezahlen Button
            if booking.canPay || booking.paymentStatus == .awaitingPayment {
                Button {
                    if let url = paypalLink {
                        UIApplication.shared.open(url)
                    } else if let linkString = booking.paymentLink, let url = URL(string: linkString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "p.circle.fill")
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(T("Mit PayPal bezahlen"))
                                .font(TDTypography.headline)
                            Text(T("Sicher und schnell"))
                                .font(TDTypography.caption2)
                                .opacity(0.9)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "arrow.up.forward")
                            .font(.caption)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.0, green: 0.48, blue: 0.8), Color(red: 0.0, green: 0.35, blue: 0.65)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(TDRadius.md)
                }
                .disabled(paypalLink == nil && booking.paymentLink == nil)
                
                // Hinweis
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(T("Nach der Zahlung erhältst du eine Bestätigung. Der Trainer wird über die Zahlung informiert."))
                        .font(TDTypography.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            }
            
            // Bezahlt-Status anzeigen
            if booking.paymentStatus == .completed, let paidAt = booking.paidAt {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                    VStack(alignment: .leading) {
                        Text(T("Bezahlt"))
                            .font(TDTypography.headline)
                            .foregroundColor(.green)
                        Text(paidAt.formatted(date: .abbreviated, time: .shortened))
                            .font(TDTypography.caption1)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
            }
        }
        .padding(TDSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: TDRadius.md)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
}

// MARK: - Payment Web View (Safari Controller)
struct PaymentWebView: View {
    let url: String
    let booking: PrivateLessonBooking
    @Environment(\.dismiss) var dismiss
    @StateObject private var lessonManager = PrivateLessonManager.shared
    @State private var showConfirmation = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Info Banner
                HStack(spacing: TDSpacing.sm) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                    Text(T("Du wirst zu PayPal weitergeleitet. Nach der Zahlung bestätige bitte hier."))
                        .font(TDTypography.caption1)
                        .foregroundColor(.secondary)
                }
                .padding(TDSpacing.md)
                .background(Color.blue.opacity(0.1))
                
                // WebView oder Link-Button
                VStack(spacing: TDSpacing.lg) {
                    Spacer()
                    
                    Image(systemName: "link.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(Color.accentGold)
                    
                    Text(T("Zahlung mit PayPal"))
                        .font(TDTypography.title2)
                    
                    Text(T("Tippe auf den Button um PayPal zu öffnen und die Zahlung abzuschließen"))
                        .font(TDTypography.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    // Preis
                    Text(booking.price.formatted(.currency(code: "EUR")))
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(Color.accentGold)
                    
                    // PayPal öffnen Button
                    if let paypalURL = URL(string: url) {
                        Link(destination: paypalURL) {
                            HStack {
                                Image(systemName: "arrow.up.right.square")
                                Text(T("PayPal öffnen"))
                            }
                            .font(TDTypography.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(red: 0.0, green: 0.48, blue: 0.8))
                            .cornerRadius(TDRadius.md)
                        }
                        .padding(.horizontal, TDSpacing.xl)
                    }
                    
                    Spacer()
                    
                    // Bestätigungs-Button
                    Button {
                        showConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle")
                            Text(T("Ich habe bezahlt"))
                        }
                        .font(TDTypography.headline)
                        .foregroundColor(Color.accentGold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentGold.opacity(0.15))
                        .cornerRadius(TDRadius.md)
                    }
                    .padding(.horizontal, TDSpacing.xl)
                    .padding(.bottom, TDSpacing.xl)
                }
            }
            .navigationTitle(T("Zahlung"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(T("Abbrechen")) { dismiss() }
                }
            }
            .alert(T("Zahlung bestätigen?"), isPresented: $showConfirmation) {
                Button(T("Abbrechen"), role: .cancel) { }
                Button(T("Ja, ich habe bezahlt")) {
                    // Info an User dass Admin/Trainer bestätigen muss
                    dismiss()
                }
            } message: {
                Text(T("Deine Zahlung wird vom Trainer geprüft und bestätigt. Du erhältst eine Benachrichtigung sobald die Zahlung verifiziert wurde."))
            }
        }
    }
}

// MARK: - Admin Payment Confirmation View
struct AdminPaymentConfirmationView: View {
    let booking: PrivateLessonBooking
    @StateObject private var lessonManager = PrivateLessonManager.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var transactionId = ""
    @State private var isConfirming = false
    @State private var showResult = false
    @State private var resultSuccess = false
    @State private var resultMessage = ""
    @State private var showPayPalInstructions = false
    
    var body: some View {
        NavigationStack {
            Form {
                // Buchungsinfo
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(booking.bookingNumber)
                                .font(TDTypography.headline)
                                .foregroundColor(Color.accentGold)
                            Spacer()
                            Text(booking.price.formatted(.currency(code: "EUR")))
                                .font(TDTypography.title2)
                                .fontWeight(.bold)
                        }
                        
                        Text("\(booking.userName) • \((booking.confirmedDate ?? booking.requestedDate).formatted(date: .abbreviated, time: .shortened))")
                            .font(TDTypography.caption1)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                
                // Aktueller Status
                Section(T("Zahlungsstatus")) {
                    HStack {
                        PaymentStatusBadge(status: booking.paymentStatus)
                        Spacer()
                        if booking.paymentStatus == .awaitingPayment {
                            Text(T("Warte auf Zahlung"))
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                // Anleitung für PayPal
                if booking.paymentStatus == .awaitingPayment {
                    Section {
                        Button {
                            showPayPalInstructions.toggle()
                        } label: {
                            HStack {
                                Image(systemName: "questionmark.circle.fill")
                                    .foregroundColor(.blue)
                                Text(T("So findest du die Zahlung in PayPal"))
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: showPayPalInstructions ? "chevron.up" : "chevron.down")
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if showPayPalInstructions {
                            VStack(alignment: .leading, spacing: 12) {
                                instructionStep(number: 1, text: "Öffne PayPal.com oder die PayPal App")
                                instructionStep(number: 2, text: "Gehe zu 'Aktivitäten' oder 'Transaktionen'")
                                instructionStep(number: 3, text: "Suche nach: \(booking.bookingNumber)")
                                instructionStep(number: 4, text: "Klicke auf die Zahlung für Details")
                                instructionStep(number: 5, text: "Kopiere die Transaktions-ID")
                                
                                Divider()
                                
                                Text(T("💡 Tipp: Die Buchungsnummer steht in der Zahlungsbeschreibung"))
                                    .font(TDTypography.caption1)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    
                    // Transaktions-ID eingeben
                    Section(T("Zahlung bestätigen")) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(T("PayPal Transaktions-ID"))
                                .font(TDTypography.caption1)
                                .foregroundColor(.secondary)
                            
                            TextField(T("z.B. 1AB23456CD789012E"), text: $transactionId)
                                .textInputAutocapitalization(.characters)
                                .font(.system(.body, design: .monospaced))
                        }
                        
                        if !transactionId.isEmpty {
                            HStack {
                                Image(systemName: "checkmark.circle")
                                    .foregroundColor(.green)
                                Text(T("Transaktions-ID eingegeben"))
                                    .font(TDTypography.caption1)
                            }
                        }
                    }
                    
                    // Bestätigen Button
                    Section {
                        Button {
                            Task { await confirmPayment() }
                        } label: {
                            HStack {
                                Spacer()
                                if isConfirming {
                                    ProgressView().tint(.white)
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text(T("Zahlung als erhalten markieren"))
                                        .fontWeight(.semibold)
                                }
                                Spacer()
                            }
                        }
                        .listRowBackground(transactionId.isEmpty ? Color.gray : Color.green)
                        .foregroundColor(.white)
                        .disabled(transactionId.isEmpty || isConfirming)
                    }
                    
                    // Warnung
                    Section {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(T("Bestätige die Zahlung nur, wenn du sie in deinem PayPal-Konto siehst!"))
                                .font(TDTypography.caption1)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Bereits bezahlt
                if booking.paymentStatus == .completed {
                    Section {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.title)
                                .foregroundColor(.green)
                            VStack(alignment: .leading) {
                                Text(T("Zahlung bestätigt"))
                                    .font(TDTypography.headline)
                                if let paidAt = booking.paidAt {
                                    Text(paidAt.formatted(date: .long, time: .shortened))
                                        .font(TDTypography.caption1)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        if let transactionId = booking.paypalTransactionId {
                            LabeledContent("Transaktions-ID", value: transactionId)
                        }
                    }
                }
            }
            .navigationTitle(T("Zahlung verwalten"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(T("Fertig")) { dismiss() }
                }
            }
            .alert(resultSuccess ? "✅ Erfolg" : "❌ Fehler", isPresented: $showResult) {
                Button(T("OK")) {
                    if resultSuccess { dismiss() }
                }
            } message: {
                Text(resultMessage)
            }
        }
    }
    
    private func instructionStep(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption.bold())
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Color.accentGold)
                .clipShape(Circle())
            Text(text)
                .font(TDTypography.caption1)
        }
    }
    
    private func confirmPayment() async {
        isConfirming = true
        defer { isConfirming = false }
        
        let result = await lessonManager.confirmManualPayment(bookingId: booking.id, transactionId: transactionId)
        resultSuccess = result.success
        resultMessage = result.message
        showResult = true
    }
}

// MARK: - PayPal Configuration Status View (für Admin)
struct PayPalConfigStatusView: View {
    @StateObject private var paypalService = PayPalService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: TDSpacing.md) {
            HStack {
                Image(systemName: paypalService.isReady ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(paypalService.isReady ? .green : .orange)
                
                Text(T("PayPal Status"))
                    .font(TDTypography.headline)
            }
            
            Text(paypalService.configurationStatus)
                .font(TDTypography.body)
                .foregroundColor(.secondary)
            
            if !PayPalConfig.isConfigured {
                Divider()
                
                VStack(alignment: .leading, spacing: TDSpacing.sm) {
                    Text(T("Einrichtung:"))
                        .font(TDTypography.subheadline)
                        .fontWeight(.medium)
                    
                    Text(T("1. Erstelle einen PayPal Business Account"))
                    Text(T("2. Gehe zum PayPal Developer Dashboard"))
                    Text(T("3. Erstelle eine App und kopiere die Credentials"))
                    Text(T("4. Trage sie in PayPalConfig.swift ein"))
                }
                .font(TDTypography.caption1)
                .foregroundColor(.secondary)
                
                if PayPalConfig.isPayPalMeConfigured {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        Text(T("PayPal.me ist konfiguriert - Zahlungen müssen manuell bestätigt werden"))
                            .font(TDTypography.caption1)
                    }
                    .padding(.top, TDSpacing.sm)
                }
            }
        }
        .padding(TDSpacing.md)
        .glassBackground()
    }
}
