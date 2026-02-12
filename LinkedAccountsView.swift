//
//  LinkedAccountsView.swift
//  Tanzen mit Tatiana Drexler
//
//  Verknüpfte Anmeldemethoden verwalten
//

import SwiftUI
import AuthenticationServices

struct LinkedAccountsView: View {
    @StateObject private var authService = FirebaseAuthService.shared
    @StateObject private var userManager = UserManager.shared
    @Environment(\.colorScheme) var colorScheme
    
    @State private var showLinkEmail = false
    @State private var linkEmail = ""
    @State private var linkPassword = ""
    @State private var confirmPassword = ""
    @State private var isProcessing = false
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    var body: some View {
        List {
            Section {
                // Current Auth Provider Info
                HStack {
                    Image(systemName: authService.authProvider.icon)
                        .font(.title2)
                        .foregroundColor(Color.accentGold)
                        .frame(width: 30)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(T("Aktuelle Anmeldung"))
                            .font(TDTypography.caption1)
                            .foregroundColor(.secondary)
                        Text(authService.authProvider.displayName)
                            .font(TDTypography.headline)
                    }
                }
            } header: {
                Text(T("Anmeldestatus"))
            }
            
            Section {
                // Email/Password
                ProviderRow(
                    icon: "envelope.fill",
                    title: "E-Mail & Passwort",
                    isLinked: authService.hasEmailProvider,
                    onLink: { showLinkEmail = true },
                    onUnlink: { Task { await unlinkProvider("password") } }
                )
                
                // Apple
                ProviderRow(
                    icon: "apple.logo",
                    title: "Apple",
                    isLinked: authService.hasAppleProvider,
                    onLink: nil, // Apple linking handled separately
                    onUnlink: { Task { await unlinkProvider("apple.com") } }
                )
                
                // Google
                ProviderRow(
                    icon: "g.circle.fill",
                    title: "Google",
                    isLinked: authService.hasGoogleProvider,
                    onLink: nil, // Google linking requires SDK
                    onUnlink: { Task { await unlinkProvider("google.com") } }
                )
            } header: {
                Text(T("Verknüpfte Anmeldemethoden"))
            } footer: {
                Text(T("Du kannst mehrere Anmeldemethoden mit deinem Account verknüpfen, um dich flexibel anzumelden."))
            }
            
            // Apple Sign In Button for linking
            if !authService.hasAppleProvider {
                Section {
                    SignInWithAppleButton(.continue) { request in
                        let nonce = authService.prepareAppleSignIn()
                        request.requestedScopes = [.email]
                        request.nonce = nonce
                    } onCompletion: { result in
                        Task {
                            await handleAppleLinking(result: result)
                        }
                    }
                    .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                    .frame(height: 44)
                } header: {
                    Text(T("Apple verknüpfen"))
                }
            }
            
            Section {
                HStack {
                    Image(systemName: "shield.checkmark.fill")
                        .foregroundColor(.green)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(T("Sichere Anmeldung"))
                            .font(TDTypography.subheadline)
                            .fontWeight(.medium)
                        Text(T("Deine Anmeldedaten werden sicher bei Firebase gespeichert und niemals im Klartext übertragen."))
                            .font(TDTypography.caption1)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text(T("Sicherheit"))
            }
        }
        .navigationTitle(T("Verknüpfte Accounts"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showLinkEmail) {
            LinkEmailSheet(
                email: $linkEmail,
                password: $linkPassword,
                confirmPassword: $confirmPassword,
                isProcessing: $isProcessing,
                onLink: linkEmailPassword
            )
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button(T("OK"), role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }
    
    private func unlinkProvider(_ providerId: String) async {
        isProcessing = true
        let (success, message) = await authService.unlinkProvider(providerId)
        isProcessing = false
        
        alertTitle = success ? "✅ Erfolgreich" : "❌ Fehler"
        alertMessage = message
        showAlert = true
    }
    
    private func linkEmailPassword() {
        guard !linkEmail.isEmpty, !linkPassword.isEmpty else { return }
        guard linkPassword == confirmPassword else {
            alertTitle = "❌ Fehler"
            alertMessage = "Passwörter stimmen nicht überein"
            showAlert = true
            return
        }
        
        isProcessing = true
        
        Task {
            let (success, message) = await authService.linkEmailPassword(email: linkEmail, password: linkPassword)
            
            await MainActor.run {
                isProcessing = false
                showLinkEmail = false
                alertTitle = success ? "✅ Erfolgreich" : "❌ Fehler"
                alertMessage = message
                showAlert = true
                
                if success {
                    linkEmail = ""
                    linkPassword = ""
                    confirmPassword = ""
                }
            }
        }
    }
    
    private func handleAppleLinking(result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let authorization):
            let (success, message) = await authService.linkAppleAccount(authorization: authorization)
            await MainActor.run {
                alertTitle = success ? "✅ Erfolgreich" : "❌ Fehler"
                alertMessage = message
                showAlert = true
            }
        case .failure(let error):
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                await MainActor.run {
                    alertTitle = "❌ Fehler"
                    alertMessage = error.localizedDescription
                    showAlert = true
                }
            }
        }
    }
}

// MARK: - Provider Row

struct ProviderRow: View {
    let icon: String
    let title: String
    let isLinked: Bool
    let onLink: (() -> Void)?
    let onUnlink: (() -> Void)?
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(isLinked ? Color.accentGold : .secondary)
                .frame(width: 30)
            
            Text(title)
                .font(TDTypography.body)
            
            Spacer()
            
            if isLinked {
                HStack(spacing: 8) {
                    Text(T("Verknüpft"))
                        .font(TDTypography.caption1)
                        .foregroundColor(.green)
                    
                    if let onUnlink = onUnlink {
                        Button {
                            onUnlink()
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                }
            } else {
                if let onLink = onLink {
                    Button {
                        onLink()
                    } label: {
                        Text(T("Verknüpfen"))
                            .font(TDTypography.caption1)
                            .foregroundColor(Color.accentGold)
                    }
                } else {
                    Text(T("Nicht verfügbar"))
                        .font(TDTypography.caption1)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - Link Email Sheet

struct LinkEmailSheet: View {
    @Environment(\.dismiss) var dismiss
    
    @Binding var email: String
    @Binding var password: String
    @Binding var confirmPassword: String
    @Binding var isProcessing: Bool
    let onLink: () -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(T("E-Mail-Adresse"), text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                    
                    SecureField(T("Passwort"), text: $password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .textContentType(.password)
                    
                    SecureField(T("Passwort bestätigen"), text: $confirmPassword)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .textContentType(.password)
                } header: {
                    Text(T("E-Mail & Passwort hinzufügen"))
                } footer: {
                    Text(T("Du erhältst eine Bestätigungs-E-Mail an diese Adresse."))
                }
                
                Section {
                    Button {
                        onLink()
                    } label: {
                        HStack {
                            Spacer()
                            if isProcessing {
                                ProgressView()
                            } else {
                                Text(T("Verknüpfen"))
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(email.isEmpty || password.isEmpty || password != confirmPassword || isProcessing)
                }
            }
            .navigationTitle(T("E-Mail verknüpfen"))
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
}

#Preview {
    NavigationStack {
        LinkedAccountsView()
    }
}
