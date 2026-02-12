//
//  LegalView.swift
//  Tanzen mit Tatiana Drexler
//
//  Datenschutzerklärung, AGB und Impressum
//

import SwiftUI

// MARK: - Privacy Policy View
struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                TDGradients.mainBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: TDSpacing.lg) {
                        Text(privacyPolicyText)
                            .font(TDTypography.body)
                            .foregroundColor(.primary)
                    }
                    .padding(TDSpacing.md)
                }
            }
            .navigationTitle(T("Datenschutz"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(T("Fertig")) { dismiss() }
                        .foregroundColor(Color.accentGold)
                }
            }
        }
    }
    
    private var privacyPolicyText: String {
        """
        DATENSCHUTZERKLÄRUNG
        
        Stand: Februar 2026
        
        1. VERANTWORTLICHER
        
        Tatiana Drexler
        [Adresse einfügen]
        E-Mail: [E-Mail einfügen]
        
        2. ERHOBENE DATEN
        
        Wir erheben folgende Daten:
        • Geräteinformationen (für App-Funktionalität)
        • Kaufhistorie (über Apple App Store)
        • Nutzungsdaten (lokal auf Ihrem Gerät)
        
        3. VERWENDUNGSZWECK
        
        Ihre Daten werden verwendet für:
        • Bereitstellung der App-Funktionen
        • Abwicklung von In-App-Käufen
        • Verbesserung unserer Dienste
        
        4. DATENSPEICHERUNG
        
        • Lokale Daten werden auf Ihrem Gerät gespeichert
        • Kaufdaten werden von Apple verwaltet
        • Kursdaten werden von unserem Cloud-Dienst bereitgestellt
        
        5. IHRE RECHTE
        
        Sie haben das Recht auf:
        • Auskunft über Ihre Daten
        • Berichtigung unrichtiger Daten
        • Löschung Ihrer Daten
        • Widerspruch gegen die Verarbeitung
        
        6. KONTAKT
        
        Bei Fragen zum Datenschutz kontaktieren Sie uns unter:
        [E-Mail einfügen]
        
        7. ÄNDERUNGEN
        
        Wir behalten uns vor, diese Datenschutzerklärung zu aktualisieren.
        """
    }
}

// MARK: - Terms of Service View
struct TermsOfServiceView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                TDGradients.mainBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: TDSpacing.lg) {
                        Text(termsText)
                            .font(TDTypography.body)
                            .foregroundColor(.primary)
                    }
                    .padding(TDSpacing.md)
                }
            }
            .navigationTitle(T("Nutzungsbedingungen"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(T("Fertig")) { dismiss() }
                        .foregroundColor(Color.accentGold)
                }
            }
        }
    }
    
    private var termsText: String {
        """
        NUTZUNGSBEDINGUNGEN
        
        Stand: Februar 2026
        
        1. GELTUNGSBEREICH
        
        Diese Nutzungsbedingungen gelten für die App "Tanzen mit Tatiana Drexler".
        
        2. LEISTUNGSBESCHREIBUNG
        
        Die App bietet:
        • Video-Tanzkurse zum Streaming und Download
        • Einzelkurse zum Kauf
        • Abonnements für Vollzugriff
        
        3. IN-APP-KÄUFE
        
        • Einzelkurse: Einmaliger Kauf, unbegrenzter Zugriff
        • Monatsabo: Monatliche Zahlung, jederzeit kündbar
        • Jahresabo: Jährliche Zahlung mit Rabatt
        
        Käufe werden über den Apple App Store abgewickelt.
        
        4. ABONNEMENTS
        
        • Abos verlängern sich automatisch
        • Kündigung bis 24h vor Ablauf möglich
        • Verwaltung über App Store Einstellungen
        
        5. URHEBERRECHT
        
        Alle Inhalte sind urheberrechtlich geschützt:
        • Videos dürfen nicht kopiert werden
        • Screenshots/Aufnahmen sind nicht erlaubt
        • Weitergabe an Dritte ist untersagt
        
        6. HAFTUNG
        
        • Die Nutzung erfolgt auf eigenes Risiko
        • Wir haften nicht für Verletzungen beim Tanzen
        • Konsultieren Sie bei Unsicherheiten einen Arzt
        
        7. KÜNDIGUNG
        
        Wir behalten uns vor, den Zugang zu sperren bei:
        • Verstoß gegen diese Bedingungen
        • Missbrauch der App
        • Weitergabe von Zugangsdaten
        
        8. ÄNDERUNGEN
        
        Wir können diese Bedingungen jederzeit ändern.
        
        9. KONTAKT
        
        [E-Mail einfügen]
        """
    }
}

// MARK: - Impressum View
struct ImpressumView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                TDGradients.mainBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: TDSpacing.lg) {
                        Text(impressumText)
                            .font(TDTypography.body)
                            .foregroundColor(.primary)
                    }
                    .padding(TDSpacing.md)
                }
            }
            .navigationTitle(T("Impressum"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(T("Fertig")) { dismiss() }
                        .foregroundColor(Color.accentGold)
                }
            }
        }
    }
    
    private var impressumText: String {
        """
        IMPRESSUM
        
        Angaben gemäß § 5 TMG:
        
        Tatiana Drexler
        [Straße und Hausnummer]
        [PLZ und Ort]
        Deutschland
        
        KONTAKT
        
        E-Mail: [E-Mail einfügen]
        Telefon: [Telefon einfügen]
        
        UMSATZSTEUER-ID
        
        [Falls vorhanden einfügen]
        
        VERANTWORTLICH FÜR DEN INHALT
        
        Tatiana Drexler
        [Adresse]
        
        STREITSCHLICHTUNG
        
        Die Europäische Kommission stellt eine Plattform zur 
        Online-Streitbeilegung (OS) bereit:
        https://ec.europa.eu/consumers/odr
        
        Wir sind nicht bereit oder verpflichtet, an 
        Streitbeilegungsverfahren vor einer 
        Verbraucherschlichtungsstelle teilzunehmen.
        """
    }
}

#Preview {
    PrivacyPolicyView()
}
