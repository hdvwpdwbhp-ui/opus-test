//
//  MarketingSettingsView.swift
//  Tanzen mit Tatiana Drexler
//
//  Einstellungen für Marketing-E-Mails und Benachrichtigungen
//

import SwiftUI

struct MarketingSettingsView: View {
    @StateObject private var userManager = UserManager.shared
    @StateObject private var emailService = SaleEmailService.shared
    
    @State private var marketingConsent: Bool = false
    @State private var isSaving = false
    @State private var showSaveSuccess = false
    
    var body: some View {
        Form {
            Section {
                Toggle(isOn: $marketingConsent) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(T("Sale-Benachrichtigungen"))
                            .font(TDTypography.body)
                        Text(T("Erhalte E-Mails über Rabattaktionen und Angebote"))
                            .font(TDTypography.caption1)
                            .foregroundColor(.secondary)
                    }
                }
                .tint(Color.accentGold)
                .onChange(of: marketingConsent) { _, newValue in
                    Task { await saveConsent(newValue) }
                }
            } header: {
                Text(T("E-Mail-Benachrichtigungen"))
            } footer: {
                Text(T("Wir senden dir nur E-Mails, wenn es besondere Angebote oder Sales gibt. Du kannst dich jederzeit abmelden."))
            }
            
            Section {
                HStack {
                    Image(systemName: "envelope.badge.fill")
                        .foregroundColor(Color.accentGold)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(T("E-Mail-Adresse"))
                            .font(TDTypography.body)
                        Text(userManager.currentUser?.email ?? "Nicht angemeldet")
                            .font(TDTypography.caption1)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text(T("Deine E-Mail"))
            } footer: {
                Text(T("Benachrichtigungen werden an diese E-Mail-Adresse gesendet."))
            }
            
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    InfoRowItem(
                        icon: "tag.fill",
                        title: "Sale-Ankündigungen",
                        description: "Werde informiert, wenn neue Rabattaktionen starten"
                    )
                    
                    InfoRowItem(
                        icon: "gift.fill",
                        title: "Exklusive Angebote",
                        description: "Erhalte spezielle Angebote nur für Newsletter-Abonnenten"
                    )
                    
                    InfoRowItem(
                        icon: "clock.fill",
                        title: "Zeitlich begrenzt",
                        description: "Verpasse keine zeitlich begrenzten Aktionen"
                    )
                }
                .padding(.vertical, 8)
            } header: {
                Text(T("Was du erhältst"))
            }
            
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "hand.raised.fill")
                            .foregroundColor(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(T("Datenschutz"))
                                .font(TDTypography.subheadline)
                                .fontWeight(.medium)
                            Text(T("Wir geben deine E-Mail-Adresse niemals an Dritte weiter und nutzen sie ausschließlich für App-bezogene Mitteilungen."))
                                .font(TDTypography.caption1)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(T("Jederzeit abmelden"))
                                .font(TDTypography.subheadline)
                                .fontWeight(.medium)
                            Text(T("Du kannst dich jederzeit von den Benachrichtigungen abmelden - hier oder über den Link in jeder E-Mail."))
                                .font(TDTypography.caption1)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 8)
            } header: {
                Text(T("Hinweise"))
            }
        }
        .navigationTitle(T("E-Mail-Einstellungen"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            marketingConsent = userManager.currentUser?.marketingConsent ?? false
        }
        .overlay {
            if isSaving {
                ProgressView()
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                    .shadow(radius: 4)
            }
        }
        .alert(T("Gespeichert"), isPresented: $showSaveSuccess) {
            Button(T("OK"), role: .cancel) {}
        } message: {
            Text(marketingConsent ? 
                "Du erhältst ab jetzt E-Mails über Sales und Angebote." : 
                "Du erhältst keine Marketing-E-Mails mehr.")
        }
    }
    
    private func saveConsent(_ consent: Bool) async {
        guard let userId = userManager.currentUser?.id else { return }
        
        isSaving = true
        defer { isSaving = false }
        
        let success = await emailService.updateMarketingConsent(userId: userId, consent: consent)
        
        if success {
            // Lokale Kopie aktualisieren
            userManager.currentUser?.marketingConsent = consent
            showSaveSuccess = true
        }
    }
}

struct InfoRowItem: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(Color.accentGold)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(TDTypography.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(TDTypography.caption1)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        MarketingSettingsView()
    }
}
