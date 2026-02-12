//
//  EmailVerificationView.swift
//  Tanzen mit Tatiana Drexler
//
//  View für E-Mail-Verifizierung
//

import SwiftUI

struct EmailVerificationView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var userManager = UserManager.shared
    @State private var isChecking = false
    @State private var showResendSuccess = false
    @State private var showResendError = false
    @State private var errorMessage = ""
    @State private var checkTimer: Timer?
    @State private var cooldownSeconds = 0
    @State private var cooldownTimer: Timer?
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color("AccentColor").opacity(0.1), Color.white],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Spacer()
                
                // Icon
                ZStack {
                    Circle()
                        .fill(Color("AccentColor").opacity(0.15))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "envelope.badge.shield.half.filled")
                        .font(.system(size: 50))
                        .foregroundColor(Color("AccentColor"))
                }
                
                // Titel
                Text(T("E-Mail bestätigen"))
                    .font(.title)
                    .fontWeight(.bold)
                
                // Beschreibung
                VStack(spacing: 12) {
                    Text(T("Wir haben eine Bestätigungs-E-Mail an"))
                        .foregroundColor(.secondary)
                    
                    Text(userManager.currentUser?.email ?? "deine E-Mail-Adresse")
                        .fontWeight(.semibold)
                        .foregroundColor(Color("AccentColor"))
                    
                    Text(T("gesendet. Bitte klicke auf den Link in der E-Mail, um dein Konto zu aktivieren."))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 30)
                
                Spacer()
                
                // Buttons
                VStack(spacing: 16) {
                    // Prüfen Button
                    Button {
                        Task {
                            await checkVerification()
                        }
                    } label: {
                        HStack {
                            if isChecking {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                            Text(isChecking ? "Prüfe..." : "Verifizierung prüfen")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color("AccentColor"))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isChecking)
                    
                    // Erneut senden Button
                    Button {
                        Task {
                            await resendEmail()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "envelope.arrow.triangle.branch")
                            if cooldownSeconds > 0 {
                                Text(T("Erneut senden (%@s)", "\(cooldownSeconds)"))
                            } else {
                                Text(T("E-Mail erneut senden"))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .foregroundColor(cooldownSeconds > 0 ? .secondary : Color("AccentColor"))
                        .cornerRadius(12)
                    }
                    .disabled(cooldownSeconds > 0)
                    
                    // Später Button / Logout
                    Button {
                        userManager.logout()
                    } label: {
                        Text(T("Mit anderem Konto anmelden"))
                            .foregroundColor(.secondary)
                            .font(.footnote)
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 30)
                
                // Hinweis
                VStack(spacing: 8) {
                    Text(T("Keine E-Mail erhalten?"))
                        .font(.footnote)
                        .foregroundColor(.secondary)

                    Text(T("BITTE AUCH IM SPAM-ORDNER PRUEFEN"))
                        .font(.footnote)
                        .fontWeight(.bold)
                        .foregroundColor(Color("AccentColor"))
                        .multilineTextAlignment(.center)

                    Text(T("Pruefe deinen Spam-Ordner oder sende die E-Mail erneut."))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 30)
            }
        }
        .onAppear {
            startAutoCheck()
        }
        .onDisappear {
            stopAutoCheck()
        }
        .alert(T("E-Mail gesendet"), isPresented: $showResendSuccess) {
            Button(T("OK"), role: .cancel) { }
        } message: {
            Text(T("Eine neue Bestätigungs-E-Mail wurde gesendet."))
        }
        .alert(T("Fehler"), isPresented: $showResendError) {
            Button(T("OK"), role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Actions
    
    private func checkVerification() async {
        isChecking = true
        defer { isChecking = false }
        
        let verified = await userManager.checkEmailVerification()
        
        if verified {
            // Verifizierung erfolgreich - View schließen
            print("✅ E-Mail verifiziert!")
            stopAutoCheck()
            dismiss()
        }
    }
    
    private func resendEmail() async {
        // Cooldown prüfen
        guard cooldownSeconds == 0 else { return }
        
        let (success, message) = await userManager.resendVerificationEmail()
        
        if success {
            showResendSuccess = true
            // 60 Sekunden Cooldown starten
            startCooldown()
        } else {
            errorMessage = message
            showResendError = true
        }
    }
    
    // MARK: - Auto-Check
    
    private func startAutoCheck() {
        // Prüfe alle 3 Sekunden automatisch
        checkTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            Task { @MainActor in
                await checkVerification()
            }
        }
    }
    
    private func stopAutoCheck() {
        checkTimer?.invalidate()
        checkTimer = nil
    }
    
    private func startCooldown() {
        cooldownSeconds = 60
        cooldownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                if cooldownSeconds > 0 {
                    cooldownSeconds -= 1
                } else {
                    cooldownTimer?.invalidate()
                    cooldownTimer = nil
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    EmailVerificationView()
}
