//
//  OnboardingView.swift
//  Tanzen mit Tatiana Drexler
//
//  Willkommens-Bildschirm für neue Benutzer
//

import SwiftUI

struct OnboardingView: View {
    @Binding var hasSeenOnboarding: Bool
    @State private var currentPage = 0
    @State private var showAuth = false
    @StateObject private var userManager = UserManager.shared
    
    let pages: [OnboardingPage] = [
        OnboardingPage(
            image: "figure.dance",
            title: "Willkommen bei\nTanzen mit Tatiana",
            description: "Lerne Tanzen von zu Hause mit professionellen Video-Kursen.",
            color: Color.accentGold
        ),
        OnboardingPage(
            image: "play.circle.fill",
            title: "Hochwertige\nVideo-Kurse",
            description: "Detaillierte Anleitungen für Walzer, Tango, Salsa und viele weitere Tänze.",
            color: Color.blue
        ),
        OnboardingPage(
            image: "person.2.fill",
            title: "Privatstunden\nmit Trainern",
            description: "Buchen Sie persönliche Video-Privatstunden mit unseren professionellen Trainern.",
            color: Color.green
        ),
        OnboardingPage(
            image: "arrow.down.circle.fill",
            title: "Offline\nverfügbar",
            description: "Laden Sie Videos herunter und tanzen Sie auch ohne Internet.",
            color: Color.orange
        ),
        OnboardingPage(
            image: "crown.fill",
            title: "Premium\nAbonnement",
            description: "Schalten Sie alle Kurse frei mit einem günstigen Monats- oder Jahresabo.",
            color: Color.purple
        )
    ]
    
    var body: some View {
        ZStack {
            TDGradients.mainBackground
                .ignoresSafeArea()
            
            VStack {
                // Skip Button
                HStack {
                    Spacer()
                    Button(T("Überspringen")) {
                        completeOnboarding()
                    }
                    .foregroundColor(Color.accentGold)
                    .padding()
                }
                
                // Page Content
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPageView(page: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                // Page Indicators
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(currentPage == index ? Color.accentGold : Color.gray.opacity(0.5))
                            .frame(width: 8, height: 8)
                            .animation(.easeInOut, value: currentPage)
                    }
                }
                .padding(.bottom, TDSpacing.md)
                
                // Buttons
                VStack(spacing: TDSpacing.sm) {
                    // Next/Start Button
                    Button {
                        if currentPage < pages.count - 1 {
                            withAnimation {
                                currentPage += 1
                            }
                        } else {
                            completeOnboarding()
                        }
                    } label: {
                        Text(currentPage < pages.count - 1 ? "Weiter" : "Los geht's!")
                            .font(TDTypography.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(TDSpacing.md)
                            .background(Color.accentGold)
                            .cornerRadius(TDRadius.md)
                    }
                    
                    // Account erstellen Button (nur auf letzter Seite)
                    if currentPage == pages.count - 1 {
                        Button {
                            showAuth = true
                        } label: {
                            Text(T("Account erstellen"))
                                .font(TDTypography.subheadline)
                                .foregroundColor(Color.accentGold)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, TDSpacing.lg)
                .padding(.bottom, TDSpacing.xl)
            }
        }
        .sheet(isPresented: $showAuth) {
            AuthView()
        }
        .onChange(of: userManager.isLoggedIn) { _, isLoggedIn in
            if isLoggedIn {
                showAuth = false
                completeOnboarding()
            }
        }
    }
    
    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
        withAnimation {
            hasSeenOnboarding = true
        }
    }
}

// MARK: - Onboarding Page Model
struct OnboardingPage {
    let image: String
    let title: String
    let description: String
    var color: Color = Color.accentGold
}

// MARK: - Onboarding Page View
struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: TDSpacing.xl) {
            Spacer()
            
            // Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [page.color, page.color.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 150, height: 150)
                
                Image(systemName: page.image)
                    .font(.system(size: 60))
                    .foregroundColor(.white)
            }
            
            // Title
            Text(page.title)
                .font(TDTypography.largeTitle)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            
            // Description
            Text(page.description)
                .font(TDTypography.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, TDSpacing.xl)
            
            Spacer()
            Spacer()
        }
    }
}

#Preview {
    OnboardingView(hasSeenOnboarding: .constant(false))
}
