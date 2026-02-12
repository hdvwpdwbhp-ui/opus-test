//
//  CertificateView.swift
//  Tanzen mit Tatiana Drexler
//
//  Zertifikate für abgeschlossene Kurse
//

import SwiftUI
import PDFKit
import Combine

// MARK: - Certificate Model
struct Certificate: Codable, Identifiable {
    let id: String
    let courseId: String
    let courseTitle: String
    let userId: String
    let userName: String
    let completedAt: Date
    let lessonsCompleted: Int
    let totalWatchTime: TimeInterval
    let certificateNumber: String
    
    static func generate(courseId: String, courseTitle: String, userId: String, userName: String, lessonsCompleted: Int, watchTime: TimeInterval) -> Certificate {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        let certNumber = "CERT-\(dateFormatter.string(from: Date()))-\(String(Int.random(in: 1000...9999)))"
        
        return Certificate(
            id: UUID().uuidString,
            courseId: courseId,
            courseTitle: courseTitle,
            userId: userId,
            userName: userName,
            completedAt: Date(),
            lessonsCompleted: lessonsCompleted,
            totalWatchTime: watchTime,
            certificateNumber: certNumber
        )
    }
}

// MARK: - Certificate Manager
@MainActor
class CertificateManager: ObservableObject {
    static let shared = CertificateManager()
    
    @Published var certificates: [Certificate] = []
    
    private let storageKey = "user_certificates"
    
    private init() {
        loadCertificates()
    }
    
    func generateCertificate(courseId: String, courseTitle: String, userId: String, userName: String, lessonsCompleted: Int, watchTime: TimeInterval) -> Certificate {
        // Check if certificate already exists
        if let existing = certificates.first(where: { $0.courseId == courseId && $0.userId == userId }) {
            return existing
        }
        
        let cert = Certificate.generate(
            courseId: courseId,
            courseTitle: courseTitle,
            userId: userId,
            userName: userName,
            lessonsCompleted: lessonsCompleted,
            watchTime: watchTime
        )
        
        certificates.append(cert)
        saveCertificates()
        
        return cert
    }
    
    func getCertificate(for courseId: String, userId: String) -> Certificate? {
        certificates.first { $0.courseId == courseId && $0.userId == userId }
    }
    
    func hasCertificate(for courseId: String, userId: String) -> Bool {
        certificates.contains { $0.courseId == courseId && $0.userId == userId }
    }
    
    private func loadCertificates() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let certs = try? JSONDecoder().decode([Certificate].self, from: data) {
            certificates = certs
        }
    }
    
    private func saveCertificates() {
        if let data = try? JSONEncoder().encode(certificates) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}

// MARK: - Certificate View
struct CertificateView: View {
    let certificate: Certificate
    @Environment(\.dismiss) var dismiss
    @State private var showShareSheet = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: TDSpacing.lg) {
                    // Certificate Card
                    certificateCard
                    
                    // Actions
                    actionButtons
                    
                    // Details
                    detailsSection
                }
                .padding()
            }
            .background(TDGradients.mainBackground.ignoresSafeArea())
            .navigationTitle(T("Zertifikat"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(T("Fertig")) { dismiss() }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                CertificateShareSheet(certificate: certificate)
            }
        }
    }
    
    // MARK: - Certificate Card
    private var certificateCard: some View {
        VStack(spacing: TDSpacing.lg) {
            // Header with Gold Border
            VStack(spacing: TDSpacing.sm) {
                Image(systemName: "seal.fill")
                    .font(.system(size: 50))
                    .foregroundColor(Color.accentGold)
                
                Text(T("ZERTIFIKAT"))
                    .font(.system(size: 28, weight: .bold, design: .serif))
                    .foregroundColor(Color.accentGold)
                
                Text(T("Kursabschluss"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Divider()
                .frame(width: 100)
                .background(Color.accentGold)
            
            // Name
            VStack(spacing: 4) {
                Text(T("Hiermit wird bescheinigt, dass"))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                Text(certificate.userName)
                    .font(.system(size: 24, weight: .semibold, design: .serif))
            }
            
            // Course
            VStack(spacing: 4) {
                Text(T("den Kurs"))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                Text(certificate.courseTitle)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(Color.accentGold)
                    .multilineTextAlignment(.center)
                
                Text(T("erfolgreich abgeschlossen hat."))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Divider()
                .frame(width: 100)
                .background(Color.accentGold)
            
            // Stats
            HStack(spacing: TDSpacing.xl) {
                StatItem(label: "Lektionen", value: "\(certificate.lessonsCompleted)")
                StatItem(label: "Lernzeit", value: formatWatchTime(certificate.totalWatchTime))
            }
            
            // Date & Number
            VStack(spacing: 4) {
                Text(certificate.completedAt.formatted(date: .long, time: .omitted))
                    .font(.system(size: 14, weight: .medium))
                
                Text(certificate.certificateNumber)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            
            // Signature
            VStack(spacing: 4) {
                Image(systemName: "signature")
                    .font(.system(size: 30))
                    .foregroundColor(Color.accentGold.opacity(0.5))
                
                Text(T("Tanzen mit Tatiana Drexler"))
                    .font(.system(size: 12, weight: .medium))
            }
        }
        .padding(TDSpacing.xl)
        .background(
            RoundedRectangle(cornerRadius: TDRadius.lg)
                .fill(Color.white)
                .shadow(color: Color.accentGold.opacity(0.3), radius: 20, x: 0, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: TDRadius.lg)
                .stroke(
                    LinearGradient(
                        colors: [Color.accentGold, Color.accentGold.opacity(0.5), Color.accentGold],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )
        )
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        HStack(spacing: TDSpacing.md) {
            Button {
                showShareSheet = true
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text(T("Teilen"))
                }
                .fontWeight(.medium)
                .foregroundColor(Color.accentGold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentGold.opacity(0.1))
                .cornerRadius(TDRadius.md)
            }
            
            Button {
                saveToPDF()
            } label: {
                HStack {
                    Image(systemName: "arrow.down.doc")
                    Text(T("Als PDF"))
                }
                .fontWeight(.medium)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentGold)
                .cornerRadius(TDRadius.md)
            }
        }
    }
    
    // MARK: - Details Section
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: TDSpacing.sm) {
            Text(T("Zertifikat-Details"))
                .font(TDTypography.headline)
            
            VStack(spacing: TDSpacing.sm) {
                CertificateDetailRow(label: "Zertifikat-Nr.", value: certificate.certificateNumber)
                CertificateDetailRow(label: "Ausgestellt am", value: certificate.completedAt.formatted(date: .long, time: .omitted))
                CertificateDetailRow(label: "Kurs", value: certificate.courseTitle)
                CertificateDetailRow(label: "Teilnehmer", value: certificate.userName)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(TDRadius.md)
        }
    }
    
    // MARK: - Helper Functions
    
    private func formatWatchTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes) Min"
    }
    
    private func saveToPDF() {
        // In a real app, generate actual PDF
        // For now, just show share sheet
        showShareSheet = true
    }
}

// MARK: - Supporting Views

struct StatItem: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }
}

struct CertificateDetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(TDTypography.caption1)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(TDTypography.body)
        }
    }
}

// MARK: - Certificate Share Sheet
struct CertificateShareSheet: View {
    let certificate: Certificate
    @Environment(\.dismiss) var dismiss
    
    var shareText: String {
        """
        🎓 Ich habe den Kurs "\(certificate.courseTitle)" bei Tanzen mit Tatiana Drexler erfolgreich abgeschlossen!
        
        📊 \(certificate.lessonsCompleted) Lektionen absolviert
        🏅 Zertifikat: \(certificate.certificateNumber)
        
        Lerne auch Tanzen mit der App "Tanzen mit Tatiana Drexler"!
        """
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: TDSpacing.xl) {
                // Preview
                VStack(spacing: TDSpacing.md) {
                    Image(systemName: "seal.fill")
                        .font(.system(size: 50))
                        .foregroundColor(Color.accentGold)
                    
                    Text(certificate.courseTitle)
                        .font(TDTypography.headline)
                        .multilineTextAlignment(.center)
                    
                    Text(T("Abgeschlossen am %@", certificate.completedAt.formatted(date: .abbreviated, time: .omitted)))
                        .font(TDTypography.caption1)
                        .foregroundColor(.secondary)
                }
                .padding()
                
                // Share Options
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: TDSpacing.lg) {
                    ShareButton(icon: "message.fill", label: "Nachricht", color: .green) {
                        shareViaSystem()
                    }
                    
                    ShareButton(icon: "camera.fill", label: "Instagram", color: .pink) {
                        shareViaSystem()
                    }
                    
                    ShareButton(icon: "doc.on.doc", label: "Kopieren", color: .gray) {
                        UIPasteboard.general.string = shareText
                        dismiss()
                    }
                }
                
                Spacer()
                
                // System Share
                Button {
                    shareViaSystem()
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text(T("Weitere Optionen"))
                    }
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentGold)
                    .cornerRadius(TDRadius.md)
                }
            }
            .padding()
            .navigationTitle(T("Zertifikat teilen"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(T("Fertig")) { dismiss() }
                }
            }
        }
    }
    
    private func shareViaSystem() {
        let activityVC = UIActivityViewController(
            activityItems: [shareText],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

struct ShareButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(color)
                }
                
                Text(label)
                    .font(TDTypography.caption1)
                    .foregroundColor(.primary)
            }
        }
    }
}

// MARK: - My Certificates View
struct MyCertificatesView: View {
    @StateObject private var certificateManager = CertificateManager.shared
    @StateObject private var userManager = UserManager.shared
    @State private var selectedCertificate: Certificate?
    
    var myCertificates: [Certificate] {
        guard let userId = userManager.currentUser?.id else { return [] }
        return certificateManager.certificates.filter { $0.userId == userId }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: TDSpacing.lg) {
                if myCertificates.isEmpty {
                    ContentUnavailableView(
                        "Noch keine Zertifikate",
                        systemImage: "seal",
                        description: Text(T("Schließe einen Kurs ab, um dein erstes Zertifikat zu erhalten!"))
                    )
                } else {
                    // Stats Header
                    HStack(spacing: TDSpacing.xl) {
                        CertStatCard(value: "\(myCertificates.count)", label: "Zertifikate", icon: "seal.fill")
                        CertStatCard(value: "\(totalLessons)", label: "Lektionen", icon: "play.rectangle.fill")
                    }
                    
                    // Certificate List
                    ForEach(myCertificates) { cert in
                        CertificateListCard(certificate: cert) {
                            selectedCertificate = cert
                        }
                    }
                }
            }
            .padding()
        }
        .background(TDGradients.mainBackground.ignoresSafeArea())
        .navigationTitle(T("Meine Zertifikate"))
        .sheet(item: $selectedCertificate) { cert in
            CertificateView(certificate: cert)
        }
    }
    
    var totalLessons: Int {
        myCertificates.reduce(0) { $0 + $1.lessonsCompleted }
    }
}

struct CertStatCard: View {
    let value: String
    let label: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(Color.accentGold)
            
            Text(value)
                .font(.system(size: 28, weight: .bold))
            
            Text(label)
                .font(TDTypography.caption1)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .glassBackground()
    }
}

struct CertificateListCard: View {
    let certificate: Certificate
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: TDSpacing.md) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.accentGold.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "seal.fill")
                        .foregroundColor(Color.accentGold)
                }
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(certificate.courseTitle)
                        .font(TDTypography.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(certificate.completedAt.formatted(date: .abbreviated, time: .omitted))
                        .font(TDTypography.caption1)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(TDRadius.md)
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
    }
}

#Preview {
    NavigationStack {
        CertificateView(certificate: Certificate.generate(
            courseId: "test",
            courseTitle: "Salsa für Anfänger",
            userId: "user1",
            userName: "Max Mustermann",
            lessonsCompleted: 12,
            watchTime: 3600
        ))
    }
}
