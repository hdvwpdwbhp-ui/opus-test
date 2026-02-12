//
//  AdminLoginView.swift
//  Tanzen mit Tatiana Drexler
//
//  Login-Screen für den Admin-Bereich
//

import SwiftUI

struct AdminLoginView: View {
    @StateObject private var authManager = AdminAuthManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var username = ""
    @State private var password = ""
    @State private var isLoggingIn = false
    @State private var showPassword = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                TDGradients.mainBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: TDSpacing.xl) {
                        // Header
                        headerSection
                        
                        // Login Form
                        loginForm
                        
                        // Login Button
                        loginButton
                        
                        // Error Message
                        if authManager.showLoginError {
                            errorMessage
                        }
                    }
                    .padding(TDSpacing.lg)
                }
            }
            .navigationTitle(T("Admin-Login"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(T("Abbrechen")) {
                        dismiss()
                    }
                    .foregroundColor(Color.accentGold)
                }
            }
            .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
                if isAuthenticated {
                    dismiss()
                }
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: TDSpacing.md) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.accentGold, Color.accentGoldLight],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 35))
                    .foregroundColor(.white)
            }
            
            Text(T("Admin-Bereich"))
                .font(TDTypography.title2)
                .foregroundColor(.primary)
            
            Text(T("Bitte melde dich an, um auf die Admin-Funktionen zuzugreifen."))
                .font(TDTypography.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, TDSpacing.xl)
    }
    
    // MARK: - Login Form
    private var loginForm: some View {
        VStack(spacing: TDSpacing.md) {
            // Username
            VStack(alignment: .leading, spacing: TDSpacing.xs) {
                Text(T("Benutzername"))
                    .font(TDTypography.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Image(systemName: "person.fill")
                        .foregroundColor(Color.accentGold)
                    
                    TextField(T("E-Mail oder Benutzername"), text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                }
                .padding(TDSpacing.md)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(TDRadius.md)
            }
            
            // Password
            VStack(alignment: .leading, spacing: TDSpacing.xs) {
                Text(T("Passwort"))
                    .font(TDTypography.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Image(systemName: "lock.fill")
                        .foregroundColor(Color.accentGold)
                    
                    if showPassword {
                        TextField(T("Passwort eingeben"), text: $password)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .textContentType(.password)
                    } else {
                        SecureField(T("Passwort"), text: $password)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .textContentType(.password)
                    }
                    
                    Button {
                        showPassword.toggle()
                    } label: {
                        Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(TDSpacing.md)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(TDRadius.md)
            }
        }
        .padding(TDSpacing.md)
        .glassBackground()
    }
    
    // MARK: - Login Button
    private var loginButton: some View {
        Button {
            Task { await login() }
        } label: {
            HStack {
                Spacer()
                if isLoggingIn {
                    ProgressView().tint(.white)
                } else {
                    Text(T("Anmelden"))
                        .fontWeight(.semibold)
                }
                Spacer()
            }
        }
        .disabled(username.isEmpty || password.isEmpty || isLoggingIn)
        .padding()
        .background(Color.accentGold)
        .foregroundColor(.white)
        .cornerRadius(TDRadius.md)
    }
    
    // MARK: - Error Message
    private var errorMessage: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            
            Text(T("Ungültige Anmeldedaten. Bitte versuche es erneut."))
                .font(TDTypography.subheadline)
                .foregroundColor(.red)
        }
        .padding(TDSpacing.md)
        .background(Color.red.opacity(0.1))
        .cornerRadius(TDRadius.md)
    }
    
    // MARK: - Helpers
    private var canLogin: Bool {
        !username.isEmpty && !password.isEmpty
    }
    
    private func login() async {
        isLoggingIn = true
        let success = await authManager.login(username: username, password: password)
        isLoggingIn = false
        if !success {
            password = ""
        }
    }
}

#Preview {
    AdminLoginView()
}
