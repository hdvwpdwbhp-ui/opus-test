//
//  AuthView.swift
//  Tanzen mit Tatiana Drexler
//
//  Login und Registrierung mit Firebase Auth
//

import SwiftUI
import AuthenticationServices
import Combine

struct AuthView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var userManager = UserManager.shared
    private var authService = FirebaseAuthService.shared
    
    @State private var isLoginMode = true
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showPassword = false
    @State private var marketingConsent = false
    
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var needsEmailVerification = false
    
    @State private var showForgotPassword = false
    @State private var resetEmail = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                TDGradients.mainBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        headerSection
                        tabSwitcher
                        formSection
                        mainButton
                        dividerSection
                        socialLoginSection
                        if isLoginMode { forgotPasswordButton }
                    }
                    .padding(24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(T("Abbrechen")) { dismiss() }
                        .foregroundColor(Color.accentGold)
                }
            }
            .alert(alertTitle, isPresented: $showAlert) {
                Button(T("OK"), role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
            .sheet(isPresented: $needsEmailVerification) {
                EmailVerificationView()
            }
            .sheet(isPresented: $showForgotPassword) {
                ForgotPasswordSheet(email: $resetEmail)
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.dance")
                .font(.system(size: 50))
                .foregroundColor(Color.accentGold)
            Text(T("Tanzen mit Tatiana"))
                .font(.title2).fontWeight(.bold)
            Text(isLoginMode ? "Willkommen zurück!" : "Erstelle deinen Account")
                .font(.subheadline).foregroundColor(.secondary)
        }
        .padding(.top, 20)
    }
    
    private var tabSwitcher: some View {
        HStack(spacing: 0) {
            Button { withAnimation { isLoginMode = true } } label: {
                Text(T("Anmelden"))
                    .fontWeight(isLoginMode ? .semibold : .regular)
                    .foregroundColor(isLoginMode ? .white : .secondary)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(isLoginMode ? Color.accentGold : Color.clear)
                    .cornerRadius(8)
            }
            Button { withAnimation { isLoginMode = false } } label: {
                Text(T("Registrieren"))
                    .fontWeight(!isLoginMode ? .semibold : .regular)
                    .foregroundColor(!isLoginMode ? .white : .secondary)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(!isLoginMode ? Color.accentGold : Color.clear)
                    .cornerRadius(8)
            }
        }
        .background(Color.gray.opacity(0.2)).cornerRadius(10)
    }
    
    private var formSection: some View {
        VStack(spacing: 16) {
            if !isLoginMode {
                formField(title: "Name", icon: "person.fill", text: $name, capitalize: true)
            }
            formField(title: "E-Mail", icon: "envelope.fill", text: $email, capitalize: false, keyboard: .emailAddress)
            passwordField(title: "Passwort", text: $password, showPassword: $showPassword)
            if !isLoginMode {
                secureFormField(title: "Passwort bestätigen", text: $confirmPassword)
                if !confirmPassword.isEmpty && password != confirmPassword {
                    Text(T("Passwörter stimmen nicht überein")).font(.caption).foregroundColor(.red)
                }
                Toggle(isOn: $marketingConsent) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(T("Angebote per E-Mail")).font(.subheadline)
                        Text(T("Über Sales und Neuigkeiten informiert werden")).font(.caption).foregroundColor(.secondary)
                    }
                }.tint(Color.accentGold)
            }
        }
    }
    
    private func formField(title: String, icon: String, text: Binding<String>, capitalize: Bool, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundColor(.secondary)
            HStack {
                Image(systemName: icon).foregroundColor(.secondary)
                TextField(title, text: text)
                    .keyboardType(keyboard)
                    .textInputAutocapitalization(capitalize ? .words : .never)
                    .autocorrectionDisabled(true)
            }
            .padding().background(Color.gray.opacity(0.1)).cornerRadius(10)
        }
    }
    
    private func passwordField(title: String, text: Binding<String>, showPassword: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundColor(.secondary)
            HStack {
                Image(systemName: "lock.fill").foregroundColor(.secondary)
                if showPassword.wrappedValue {
                    TextField(title, text: text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                } else {
                    SecureField(title, text: text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                }
                Button { showPassword.wrappedValue.toggle() } label: {
                    Image(systemName: showPassword.wrappedValue ? "eye.slash.fill" : "eye.fill").foregroundColor(.secondary)
                }
            }
            .padding().background(Color.gray.opacity(0.1)).cornerRadius(10)
        }
    }
    
    private func secureFormField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundColor(.secondary)
            HStack {
                Image(systemName: "lock.fill").foregroundColor(.secondary)
                SecureField(title, text: text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
            }
            .padding().background(Color.gray.opacity(0.1)).cornerRadius(10)
        }
    }
    
    private var mainButton: some View {
        Button { Task { await submit() } } label: {
            HStack {
                if isLoading {
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text(isLoginMode ? "Anmelden" : "Registrieren").fontWeight(.semibold)
                }
            }
            .foregroundColor(.white).frame(maxWidth: .infinity).frame(height: 50)
            .background(canSubmit ? Color.accentGold : Color.gray).cornerRadius(12)
        }
        .disabled(!canSubmit || isLoading)
    }
    
    private var dividerSection: some View {
        HStack {
            Rectangle().fill(Color.gray.opacity(0.3)).frame(height: 1)
            Text(T("oder")).font(.caption).foregroundColor(.secondary)
            Rectangle().fill(Color.gray.opacity(0.3)).frame(height: 1)
        }
    }
    
    private var socialLoginSection: some View {
        VStack(spacing: 12) {
            SignInWithAppleButton(.continue) { request in
                let nonce = authService.prepareAppleSignIn()
                request.requestedScopes = [.email, .fullName]
                request.nonce = nonce
            } onCompletion: { result in
                Task { await handleAppleSignIn(result) }
            }
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 50).cornerRadius(12)
            
            googleSignInButton
        }
    }
    
    private var googleSignInButton: some View {
        Button { Task { await handleGoogleSignIn() } } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Color.white).frame(width: 24, height: 24)
                    Text(T("G")).font(.system(size: 14, weight: .bold))
                        .foregroundStyle(LinearGradient(colors: [.blue, .green, .yellow, .red], startPoint: .topLeading, endPoint: .bottomTrailing))
                }
                Text(T("Mit Google fortfahren")).fontWeight(.medium)
            }
            .foregroundColor(.primary).frame(maxWidth: .infinity).frame(height: 50)
            .background(Color(.systemGray6)).cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.3), lineWidth: 1))
        }
    }
    
    private var forgotPasswordButton: some View {
        Button { resetEmail = email; showForgotPassword = true } label: {
            Text(T("Passwort vergessen?")).font(.subheadline).foregroundColor(Color.accentGold)
        }
    }
    
    private var canSubmit: Bool {
        isLoginMode ? (!email.isEmpty && !password.isEmpty) : (!name.isEmpty && !email.isEmpty && password.count >= 6 && password == confirmPassword)
    }
    
    private func submit() async {
        isLoading = true
        defer { isLoading = false }
        if isLoginMode { await performLogin() } else { await performRegistration() }
    }
    
    private func performLogin() async {
        let (success, message, needsVerification) = await userManager.loginWithFirebase(email: email, password: password)
        if success && needsVerification { needsEmailVerification = true }
        else if success { dismiss() }
        else { alertTitle = "❌ Fehler"; alertMessage = message; showAlert = true }
    }
    
    private func performRegistration() async {
        guard password == confirmPassword else {
            alertTitle = "❌ Fehler"; alertMessage = "Passwörter stimmen nicht überein"; showAlert = true
            return
        }
        let result = await userManager.registerWithFirebase(name: name, email: email, password: password, marketingConsent: marketingConsent)
        if result.success { needsEmailVerification = true }
        else { alertTitle = "❌ Fehler"; alertMessage = result.message; showAlert = true }
    }
    
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let authorization):
            isLoading = true
            let (success, message, _) = await authService.handleAppleSignIn(authorization: authorization)
            isLoading = false
            if success { await userManager.syncWithFirebaseUser(); dismiss() }
            else { alertTitle = "❌ Fehler"; alertMessage = message; showAlert = true }
        case .failure(let error):
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                alertTitle = "❌ Fehler"; alertMessage = error.localizedDescription; showAlert = true
            }
        }
    }
    
    private func handleGoogleSignIn() async {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let viewController = windowScene.windows.first?.rootViewController else { return }
        isLoading = true
        let (success, idToken, accessToken, error) = await GoogleSignInHelper.shared.signIn(presenting: viewController)
        if success, let idToken = idToken, let accessToken = accessToken {
            let (authSuccess, message, _) = await authService.handleGoogleSignIn(idToken: idToken, accessToken: accessToken)
            isLoading = false
            if authSuccess { await userManager.syncWithFirebaseUser(); dismiss() }
            else { alertTitle = "❌ Fehler"; alertMessage = message; showAlert = true }
        } else {
            isLoading = false
            if let error = error { alertTitle = "❌ Fehler"; alertMessage = error; showAlert = true }
        }
    }
}

// MARK: - Forgot Password Sheet
struct ForgotPasswordSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var email: String
    @State private var isLoading = false
    @State private var showSuccess = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "key.fill").font(.system(size: 50)).foregroundColor(Color.accentGold)
                Text(T("Passwort zurücksetzen")).font(.title2).fontWeight(.bold)
                Text(T("Gib deine E-Mail-Adresse ein.")).font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
                TextField(T("E-Mail-Adresse"), text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never).autocorrectionDisabled(true)
                    .padding().background(Color.gray.opacity(0.1)).cornerRadius(10)
                if let error = errorMessage { Text(error).font(.caption).foregroundColor(.red) }
                if showSuccess {
                    HStack {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                        Text(T("E-Mail gesendet!")).font(.subheadline).foregroundColor(.green)
                    }.padding().background(Color.green.opacity(0.1)).cornerRadius(10)
                }
                Button { Task { await sendReset() } } label: {
                    HStack {
                        if isLoading { ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)) }
                        else { Text(T("Link senden")).fontWeight(.semibold) }
                    }
                    .foregroundColor(.white).frame(maxWidth: .infinity).frame(height: 50)
                    .background(!email.isEmpty ? Color.accentGold : Color.gray).cornerRadius(12)
                }.disabled(email.isEmpty || isLoading)
                Spacer()
            }
            .padding(24)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button(T("Fertig")) { dismiss() }.foregroundColor(Color.accentGold) } }
        }
    }
    
    private func sendReset() async {
        isLoading = true; errorMessage = nil
        let (success, message) = await UserManager.shared.sendPasswordReset(email: email)
        isLoading = false
        if success { showSuccess = true } else { errorMessage = message }
    }
}

#Preview { AuthView() }
