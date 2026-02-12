//
//  GoogleSignInHelper.swift
//  Tanzen mit Tatiana Drexler
//
//  Google Sign-In Integration mittels ASWebAuthenticationSession
//  Funktioniert ohne Google Sign-In SDK
//

import Foundation
import UIKit
import AuthenticationServices
import FirebaseAuth
import SwiftUI
import Combine

@MainActor
class GoogleSignInHelper: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = GoogleSignInHelper()
    
    @Published var isSigningIn = false
    @Published var errorMessage: String?
    
    private var webAuthSession: ASWebAuthenticationSession?
    
    // Diese IDs müssen aus GoogleService-Info.plist kommen
    private var clientID: String? {
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let clientID = plist["CLIENT_ID"] as? String else {
            return nil
        }
        return clientID
    }
    
    private var reversedClientID: String? {
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let reversedID = plist["REVERSED_CLIENT_ID"] as? String else {
            // Fallback: Erstelle aus CLIENT_ID
            guard let clientID = clientID else { return nil }
            let parts = clientID.components(separatedBy: ".")
            return parts.reversed().joined(separator: ".")
        }
        return reversedID
    }
    
    private override init() {
        super.init()
    }
    
    // MARK: - ASWebAuthenticationPresentationContextProviding
    
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
    
    // MARK: - Google Sign In via Web OAuth
    
    /// Startet Google Sign-In über OAuth Web-Flow mit ASWebAuthenticationSession
    func signIn(presenting viewController: UIViewController) async -> (success: Bool, idToken: String?, accessToken: String?, error: String?) {
        
        guard let clientID = clientID else {
            return (false, nil, nil, "Google Sign-In ist nicht konfiguriert.\n\nBitte aktiviere Google Sign-In in der Firebase Console und lade eine neue GoogleService-Info.plist herunter.")
        }
        
        isSigningIn = true
        errorMessage = nil
        
        // Callback URL Schema (basierend auf reversed client ID)
        let callbackScheme = reversedClientID ?? "com.googleusercontent.apps.\(clientID.components(separatedBy: ".").reversed().joined(separator: "."))"
        
        // OAuth URL erstellen
        let scope = "email profile openid"
        let redirectURI = "\(callbackScheme):/oauth2callback"
        let state = UUID().uuidString
        let nonce = UUID().uuidString
        
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "id_token token"),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "nonce", value: nonce),
            URLQueryItem(name: "prompt", value: "select_account")
        ]
        
        guard let authURL = components.url else {
            isSigningIn = false
            return (false, nil, nil, "Ungültige OAuth URL")
        }
        
        // ASWebAuthenticationSession verwenden
        return await withCheckedContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: callbackScheme
            ) { [weak self] callbackURL, error in
                self?.isSigningIn = false
                
                if let error = error as? ASWebAuthenticationSessionError {
                    if error.code == .canceledLogin {
                        continuation.resume(returning: (false, nil, nil, nil)) // User cancelled
                    } else {
                        continuation.resume(returning: (false, nil, nil, error.localizedDescription))
                    }
                    return
                }
                
                guard let callbackURL = callbackURL else {
                    continuation.resume(returning: (false, nil, nil, "Keine Callback-URL erhalten"))
                    return
                }
                
                // Parse the callback URL for tokens
                // Format: scheme:/oauth2callback#access_token=...&id_token=...&token_type=Bearer&expires_in=...&state=...
                guard let fragment = callbackURL.fragment else {
                    continuation.resume(returning: (false, nil, nil, "Keine Tokens in der Antwort"))
                    return
                }
                
                var params: [String: String] = [:]
                for param in fragment.components(separatedBy: "&") {
                    let parts = param.components(separatedBy: "=")
                    if parts.count == 2 {
                        params[parts[0]] = parts[1].removingPercentEncoding ?? parts[1]
                    }
                }
                
                guard let idToken = params["id_token"],
                      let accessToken = params["access_token"] else {
                    continuation.resume(returning: (false, nil, nil, "Tokens konnten nicht extrahiert werden"))
                    return
                }
                
                // Verify state matches
                if let returnedState = params["state"], returnedState != state {
                    continuation.resume(returning: (false, nil, nil, "Sicherheitsfehler: State stimmt nicht überein"))
                    return
                }
                
                continuation.resume(returning: (true, idToken, accessToken, nil))
            }
            
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false // Allow saved credentials
            
            self.webAuthSession = session
            
            if !session.start() {
                self.isSigningIn = false
                continuation.resume(returning: (false, nil, nil, "Konnte Web-Authentifizierung nicht starten"))
            }
        }
    }
    
    /// Prüft ob Google Sign-In verfügbar ist
    var isGoogleSignInAvailable: Bool {
        return clientID != nil
    }
    
    /// Fehler-Nachricht wenn nicht verfügbar
    var unavailableMessage: String {
        if clientID == nil {
            return """
            Google Sign-In ist noch nicht konfiguriert.
            
            Schritte zur Aktivierung:
            1. Öffne Firebase Console
            2. Authentication → Sign-in method
            3. Google aktivieren
            4. Neue GoogleService-Info.plist herunterladen
            5. In Xcode ersetzen
            """
        }
        return ""
    }
}

// MARK: - Google Sign-In Button View

struct GoogleSignInButton: View {
    let action: () -> Void
    @StateObject private var helper = GoogleSignInHelper.shared
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Google "G" Logo
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 24, height: 24)
                    
                    Text(T("G"))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .green, .yellow, .red],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                Text(T("Mit Google fortfahren"))
                    .fontWeight(.medium)
            }
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .disabled(helper.isSigningIn)
        .opacity(helper.isSigningIn ? 0.6 : 1)
    }
}

// MARK: - Extension for FirebaseAuthService

extension FirebaseAuthService {
    
    /// Zeigt Info wenn Google Sign-In nicht verfügbar ist
    func showGoogleSignInUnavailable() -> String {
        return GoogleSignInHelper.shared.unavailableMessage
    }
    
    /// Prüft ob Google Sign-In verfügbar ist
    var isGoogleSignInConfigured: Bool {
        return GoogleSignInHelper.shared.isGoogleSignInAvailable
    }
}
