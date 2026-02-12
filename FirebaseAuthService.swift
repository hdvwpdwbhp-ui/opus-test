//
//  FirebaseAuthService.swift
//  Tanzen mit Tatiana Drexler
//
//  Firebase Authentication Service mit E-Mail, Google & Apple Sign-In
//

import Foundation
import FirebaseAuth
import AuthenticationServices
import CryptoKit
import Combine

@MainActor
class FirebaseAuthService: ObservableObject {
    static let shared = FirebaseAuthService()
    
    // MARK: - Published Properties
    @Published var currentFirebaseUser: FirebaseAuth.User?
    @Published var isAuthenticated = false
    @Published var isEmailVerified = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var authProvider: AuthProvider = .none
    
    private var authStateListener: AuthStateDidChangeListenerHandle?
    
    // Für Apple Sign-In
    private var currentNonce: String?
    
    // MARK: - Auth Provider
    enum AuthProvider: String, Codable {
        case none
        case email
        case google
        case apple
        
        var displayName: String {
            switch self {
            case .none: return "Nicht angemeldet"
            case .email: return "E-Mail"
            case .google: return "Google"
            case .apple: return "Apple"
            }
        }
        
        var icon: String {
            switch self {
            case .none: return "person.slash"
            case .email: return "envelope.fill"
            case .google: return "g.circle.fill"
            case .apple: return "apple.logo"
            }
        }
    }
    
    // MARK: - Initialization
    private init() {
        setupAuthStateListener()
    }
    
    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }
    
    // MARK: - Auth State Listener
    private func setupAuthStateListener() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.currentFirebaseUser = user
                self?.isAuthenticated = user != nil
                self?.isEmailVerified = user?.isEmailVerified ?? false
                
                // Determine auth provider
                if let user = user {
                    self?.authProvider = self?.determineAuthProvider(user) ?? .none
                    print("🔐 Firebase Auth: User eingeloggt - \(user.email ?? "keine Email")")
                    print("   Provider: \(self?.authProvider.displayName ?? "unbekannt")")
                    print("   Email verifiziert: \(user.isEmailVerified)")
                } else {
                    self?.authProvider = .none
                }
            }
        }
    }
    
    private func determineAuthProvider(_ user: FirebaseAuth.User) -> AuthProvider {
        for info in user.providerData {
            switch info.providerID {
            case "google.com":
                return .google
            case "apple.com":
                return .apple
            case "password":
                return .email
            default:
                continue
            }
        }
        return .email
    }
    
    // MARK: - Registrierung
    
    /// Registriert einen neuen User und sendet Verifizierungs-E-Mail
    func register(email: String, password: String) async -> (success: Bool, message: String) {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        print("🔄 Starte Registrierung für: \(email)")
        
        do {
            // User erstellen
            print("📝 Erstelle Firebase User...")
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            print("✅ Firebase User erstellt: \(result.user.uid)")
            
            // Verifizierungs-E-Mail senden
            print("📧 Sende Verifizierungs-E-Mail...")
            try await result.user.sendEmailVerification()
            print("✅ Verifizierungs-E-Mail gesendet an: \(email)")
            
            return (true, "Registrierung erfolgreich! Bitte bestätige deine E-Mail-Adresse.")
            
        } catch let error as NSError {
            print("❌ Firebase Error Code: \(error.code)")
            print("❌ Firebase Error Domain: \(error.domain)")
            print("❌ Firebase Error Description: \(error.localizedDescription)")
            print("❌ Firebase Error UserInfo: \(error.userInfo)")
            
            let message = mapFirebaseError(error)
            errorMessage = message
            return (false, message)
        }
    }
    
    // MARK: - Login
    
    /// Loggt User ein und prüft E-Mail-Verifizierung
    func login(email: String, password: String) async -> (success: Bool, message: String, verified: Bool) {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            
            // Reload um aktuellen Verifizierungsstatus zu bekommen
            try await result.user.reload()
            
            isEmailVerified = result.user.isEmailVerified
            
            if result.user.isEmailVerified {
                print("✅ Login erfolgreich (verifiziert): \(email)")
                return (true, "Willkommen zurück!", true)
            } else {
                print("⚠️ Login erfolgreich aber nicht verifiziert: \(email)")
                return (true, "Bitte bestätige erst deine E-Mail-Adresse.", false)
            }
            
        } catch let error as NSError {
            let message = mapFirebaseError(error)
            errorMessage = message
            print("❌ Login fehlgeschlagen: \(message)")
            return (false, message, false)
        }
    }
    
    // MARK: - Logout
    
    func logout() {
        do {
            try Auth.auth().signOut()
            currentFirebaseUser = nil
            isAuthenticated = false
            isEmailVerified = false
            print("✅ Logout erfolgreich")
        } catch {
            print("❌ Logout fehlgeschlagen: \(error)")
        }
    }
    
    // MARK: - E-Mail Verifizierung
    
    /// Sendet Verifizierungs-E-Mail erneut
    func resendVerificationEmail() async -> (success: Bool, message: String) {
        guard let user = currentFirebaseUser else {
            return (false, "Kein User eingeloggt")
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await user.sendEmailVerification()
            print("📧 Verifizierungs-E-Mail erneut gesendet")
            return (true, "Verifizierungs-E-Mail wurde erneut gesendet!")
        } catch let error as NSError {
            let message = mapFirebaseError(error)
            return (false, message)
        }
    }
    
    /// Prüft ob E-Mail inzwischen verifiziert wurde
    func checkEmailVerification() async -> Bool {
        guard let user = currentFirebaseUser else { return false }
        
        do {
            try await user.reload()
            isEmailVerified = user.isEmailVerified
            return user.isEmailVerified
        } catch {
            print("❌ Reload fehlgeschlagen: \(error)")
            return false
        }
    }
    
    // MARK: - Passwort zurücksetzen
    
    func sendPasswordReset(email: String) async -> (success: Bool, message: String) {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            return (true, "E-Mail zum Zurücksetzen des Passworts wurde gesendet!")
        } catch let error as NSError {
            let message = mapFirebaseError(error)
            return (false, message)
        }
    }
    
    // MARK: - Passwort ändern
    
    func changePassword(currentPassword: String, newPassword: String) async -> (success: Bool, message: String) {
        guard let user = currentFirebaseUser, let email = user.email else {
            return (false, "Kein User eingeloggt")
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Re-Authentifizierung erforderlich
            let credential = EmailAuthProvider.credential(withEmail: email, password: currentPassword)
            try await user.reauthenticate(with: credential)
            
            // Passwort ändern
            try await user.updatePassword(to: newPassword)
            
            return (true, "Passwort erfolgreich geändert!")
        } catch let error as NSError {
            let message = mapFirebaseError(error)
            return (false, message)
        }
    }
    
    // MARK: - E-Mail ändern
    
    func changeEmail(newEmail: String, password: String) async -> (success: Bool, message: String) {
        guard let user = currentFirebaseUser, let currentEmail = user.email else {
            return (false, "Kein User eingeloggt")
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Re-Authentifizierung
            let credential = EmailAuthProvider.credential(withEmail: currentEmail, password: password)
            try await user.reauthenticate(with: credential)
            
            // E-Mail ändern (sendet automatisch Verifizierung an neue Adresse)
            try await user.sendEmailVerification(beforeUpdatingEmail: newEmail)
            
            return (true, "Bestätige die neue E-Mail-Adresse über den Link in deiner Inbox.")
        } catch let error as NSError {
            let message = mapFirebaseError(error)
            return (false, message)
        }
    }
    
    // MARK: - Account löschen
    
    func deleteAccount(password: String) async -> (success: Bool, message: String) {
        guard let user = currentFirebaseUser, let email = user.email else {
            return (false, "Kein User eingeloggt")
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Re-Authentifizierung
            let credential = EmailAuthProvider.credential(withEmail: email, password: password)
            try await user.reauthenticate(with: credential)
            
            // Account löschen
            try await user.delete()
            
            currentFirebaseUser = nil
            isAuthenticated = false
            isEmailVerified = false
            
            return (true, "Account wurde gelöscht.")
        } catch let error as NSError {
            let message = mapFirebaseError(error)
            return (false, message)
        }
    }
    
    // MARK: - Error Mapping
    
    private func mapFirebaseError(_ error: NSError) -> String {
        guard let errorCode = AuthErrorCode(rawValue: error.code) else {
            return error.localizedDescription
        }
        
        switch errorCode {
        case .invalidEmail:
            return "Ungültige E-Mail-Adresse"
        case .emailAlreadyInUse:
            return "Diese E-Mail-Adresse wird bereits verwendet"
        case .weakPassword:
            return "Das Passwort ist zu schwach (mind. 6 Zeichen)"
        case .wrongPassword:
            return "Falsches Passwort"
        case .userNotFound:
            return "Kein Account mit dieser E-Mail gefunden"
        case .userDisabled:
            return "Dieser Account wurde deaktiviert"
        case .tooManyRequests:
            return "Zu viele Anfragen. Bitte warte einen Moment."
        case .networkError:
            return "Netzwerkfehler. Bitte prüfe deine Internetverbindung."
        case .invalidCredential:
            return "Ungültige Anmeldedaten. Bitte versuche es erneut."
        case .requiresRecentLogin:
            return "Bitte logge dich erneut ein"
        case .credentialAlreadyInUse:
            return "Diese Anmeldemethode ist bereits mit einem anderen Account verknüpft"
        case .operationNotAllowed:
            return "Diese Anmeldemethode ist nicht aktiviert. Bitte kontaktiere den Support."
        case .missingOrInvalidNonce:
            return "Sicherheitsfehler. Bitte versuche es erneut."
        default:
            return error.localizedDescription
        }
    }
    
    // MARK: - Helper
    
    /// Firebase User ID
    var userId: String? {
        currentFirebaseUser?.uid
    }
    
    /// Firebase User Email
    var userEmail: String? {
        currentFirebaseUser?.email
    }
    
    // MARK: - Apple Sign In
    
    /// Generiert einen zufälligen Nonce für Apple Sign-In
    func prepareAppleSignIn() -> String {
        let nonce = randomNonceString()
        currentNonce = nonce
        return sha256(nonce)
    }
    
    /// Verarbeitet das Apple Sign-In Credential
    func handleAppleSignIn(authorization: ASAuthorization) async -> (success: Bool, message: String, isNewUser: Bool) {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            return (false, "Ungültiges Apple Credential", false)
        }
        
        guard let nonce = currentNonce else {
            return (false, "Ungültiger Nonce. Bitte versuche es erneut.", false)
        }
        
        guard let appleIDToken = appleIDCredential.identityToken else {
            return (false, "Kein Identity Token erhalten", false)
        }
        
        guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            return (false, "Token-Fehler", false)
        }
        
        // Firebase Credential erstellen (neue API)
        let credential = OAuthProvider.credential(
            providerID: AuthProviderID.apple,
            idToken: idTokenString,
            rawNonce: nonce
        )
        
        do {
            let result = try await Auth.auth().signIn(with: credential)
            
            // Prüfen ob neuer User
            let isNewUser = result.additionalUserInfo?.isNewUser ?? false
            
            // Name aktualisieren falls vorhanden (nur beim ersten Login)
            if isNewUser, let fullName = appleIDCredential.fullName {
                let displayName = [fullName.givenName, fullName.familyName]
                    .compactMap { $0 }
                    .joined(separator: " ")
                
                if !displayName.isEmpty {
                    let changeRequest = result.user.createProfileChangeRequest()
                    changeRequest.displayName = displayName
                    try? await changeRequest.commitChanges()
                }
            }
            
            isEmailVerified = true // Apple-Accounts sind immer verifiziert
            authProvider = .apple
            currentNonce = nil // Reset nonce after use
            
            print("✅ Apple Sign-In erfolgreich: \(result.user.email ?? "keine Email")")
            return (true, isNewUser ? "Willkommen!" : "Willkommen zurück!", isNewUser)
            
        } catch let error as NSError {
            let message = mapFirebaseError(error)
            errorMessage = message
            currentNonce = nil // Reset nonce on error
            print("❌ Apple Sign-In fehlgeschlagen: \(error.localizedDescription)")
            return (false, message, false)
        }
    }
    
    // MARK: - Google Sign In
    
    /// Verarbeitet das Google Sign-In (Credential muss von GoogleSignIn SDK kommen)
    func handleGoogleSignIn(idToken: String, accessToken: String) async -> (success: Bool, message: String, isNewUser: Bool) {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
        
        do {
            let result = try await Auth.auth().signIn(with: credential)
            let isNewUser = result.additionalUserInfo?.isNewUser ?? false
            
            isEmailVerified = true // Google-Accounts sind immer verifiziert
            authProvider = .google
            
            print("✅ Google Sign-In erfolgreich: \(result.user.email ?? "keine Email")")
            return (true, isNewUser ? "Willkommen!" : "Willkommen zurück!", isNewUser)
            
        } catch let error as NSError {
            let message = mapFirebaseError(error)
            errorMessage = message
            print("❌ Google Sign-In fehlgeschlagen: \(message)")
            return (false, message, false)
        }
    }
    
    // MARK: - Link Providers
    
    /// Verknüpft einen zusätzlichen Auth-Provider mit dem aktuellen Account
    func linkAppleAccount(authorization: ASAuthorization) async -> (success: Bool, message: String) {
        guard let user = currentFirebaseUser else {
            return (false, "Kein User eingeloggt")
        }
        
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let nonce = currentNonce,
              let appleIDToken = appleIDCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            return (false, "Ungültiges Credential")
        }
        
        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: appleIDCredential.fullName
        )
        
        do {
            try await user.link(with: credential)
            return (true, "Apple-Account erfolgreich verknüpft!")
        } catch let error as NSError {
            return (false, mapFirebaseError(error))
        }
    }
    
    func linkGoogleAccount(idToken: String, accessToken: String) async -> (success: Bool, message: String) {
        guard let user = currentFirebaseUser else {
            return (false, "Kein User eingeloggt")
        }
        
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
        
        do {
            try await user.link(with: credential)
            return (true, "Google-Account erfolgreich verknüpft!")
        } catch let error as NSError {
            return (false, mapFirebaseError(error))
        }
    }
    
    func linkEmailPassword(email: String, password: String) async -> (success: Bool, message: String) {
        guard let user = currentFirebaseUser else {
            return (false, "Kein User eingeloggt")
        }
        
        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
        
        do {
            try await user.link(with: credential)
            try await user.sendEmailVerification()
            return (true, "E-Mail/Passwort erfolgreich verknüpft! Bitte bestätige deine E-Mail.")
        } catch let error as NSError {
            return (false, mapFirebaseError(error))
        }
    }
    
    // MARK: - Unlink Providers
    
    func unlinkProvider(_ providerID: String) async -> (success: Bool, message: String) {
        guard let user = currentFirebaseUser else {
            return (false, "Kein User eingeloggt")
        }
        
        // Mindestens ein Provider muss verknüpft bleiben
        if user.providerData.count <= 1 {
            return (false, "Du musst mindestens einen Anmelde-Weg behalten")
        }
        
        do {
            try await user.unlink(fromProvider: providerID)
            return (true, "Provider erfolgreich entfernt")
        } catch let error as NSError {
            return (false, mapFirebaseError(error))
        }
    }
    
    // MARK: - Linked Providers
    
    var linkedProviders: [String] {
        currentFirebaseUser?.providerData.map { $0.providerID } ?? []
    }
    
    var hasEmailProvider: Bool {
        linkedProviders.contains("password")
    }
    
    var hasGoogleProvider: Bool {
        linkedProviders.contains("google.com")
    }
    
    var hasAppleProvider: Bool {
        linkedProviders.contains("apple.com")
    }
    
    // MARK: - Nonce Helpers for Apple Sign-In
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }
        return String(nonce)
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        return hashString
    }
}
