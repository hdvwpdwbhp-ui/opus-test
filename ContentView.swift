//
//  ContentView.swift
//  Tanzen mit Tatiana Drexler
//
//  Created by App on 07.02.26.
//

import SwiftUI

struct ContentView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @StateObject private var userManager = UserManager.shared
    @StateObject private var languageManager = LanguageManager.shared
    @StateObject private var adminMessageManager = AdminMessageManager.shared
    @State private var showUsernameSetup = false
    @State private var showAdminMessage = false
    
    var body: some View {
        Group {
            if !languageManager.hasSelectedLanguage {
                // Sprachauswahl beim ersten Start
                LanguageSelectionView {
                    languageManager.hasSelectedLanguage = true
                }
            } else if !hasSeenOnboarding {
                // Onboarding für neue User
                OnboardingView(hasSeenOnboarding: $hasSeenOnboarding)
            } else if userManager.isLoggedIn && !userManager.isEmailVerified && userManager.currentUser?.firebaseUid != nil {
                // User eingeloggt aber E-Mail nicht verifiziert (nur für Firebase-User)
                EmailVerificationView()
            } else {
                // Normale App
                ZStack {
                    MainTabView()
                        .sheet(isPresented: $showUsernameSetup) {
                            UsernameSetupView()
                        }
                        .onAppear {
                            checkUsernameSetup()
                            startAdminMessageListener()
                        }
                        .onChange(of: userManager.isLoggedIn) { _, newValue in
                            checkUsernameSetup()
                            if newValue {
                                startAdminMessageListener()
                            } else {
                                adminMessageManager.stopListening()
                            }
                        }
                        .onChange(of: userManager.isEmailVerified) { _, _ in
                            checkUsernameSetup()
                        }
                    
                    // Admin-Nachricht Popup Overlay
                    if let message = adminMessageManager.currentPopupMessage {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                            .onTapGesture { }  // Prevent dismissing by tap
                        
                        AdminMessagePopupView(message: message) {
                            // Popup wurde geschlossen
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.spring(), value: adminMessageManager.currentPopupMessage != nil)
            }
        }
        .id(languageManager.currentLanguage) // View neu laden bei Sprachwechsel
    }
    
    private func checkUsernameSetup() {
        // Verzögert prüfen, damit die UI sich erst aufbauen kann
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if userManager.shouldShowUsernameSetup {
                showUsernameSetup = true
            }
        }
    }
    
    private func startAdminMessageListener() {
        if let userId = userManager.currentUser?.id {
            adminMessageManager.startListening(for: userId)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(CourseViewModel())
        .environmentObject(StoreViewModel())
}
