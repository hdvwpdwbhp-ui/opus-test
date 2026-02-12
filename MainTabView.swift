//
//  MainTabView.swift
//  Tanzen mit Tatiana Drexler
//
//  Main Tab Bar Navigation - Offline App with In-App Purchases
//

import SwiftUI

struct MainTabView: View {
    @StateObject private var courseViewModel = CourseViewModel()
    @StateObject private var storeViewModel = StoreViewModel()
    @StateObject private var coinManager = CoinManager.shared
    @StateObject private var userManager = UserManager.shared
    @StateObject private var languageManager = LanguageManager.shared
    @State private var selectedTab = 0
    @State private var showCoinWallet = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            DiscoverView()
                .tabItem {
                    Label(String.localized(.tabDiscover), systemImage: "sparkles")
                }
                .tag(0)
            
            MyCoursesView()
                .tabItem {
                    Label(String.localized(.myCourses), systemImage: "play.square.stack")
                }
                .tag(1)
            
            NavigationStack {
                PartnerMatchingView()
            }
            .tabItem {
                Label(T("Tanzpartner"), systemImage: "person.2.fill")
            }
            .tag(2)
            
            MyBookingsView()
                .tabItem {
                    Label(String.localized(.myBookings), systemImage: "calendar.badge.clock")
                }
                .tag(3)
            
            ProfileView()
                .tabItem {
                    Label(String.localized(.profile), systemImage: "person.circle")
                }
                .tag(4)
        }
        .environmentObject(courseViewModel)
        .environmentObject(storeViewModel)
        .tint(Color.accentGold)
        .id(languageManager.currentLanguage) // Tabs aktualisieren bei Sprachwechsel
        .overlay(alignment: .topTrailing) {
            if userManager.isLoggedIn {
                Button {
                    showCoinWallet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "bitcoinsign.circle.fill")
                            .foregroundColor(Color.accentGold)
                        Text("\(coinManager.balance)")
                            .font(TDTypography.caption1)
                            .fontWeight(.bold)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.accentGold.opacity(0.3), lineWidth: 1)
                    )
                }
                .padding(.trailing, 16)
                .padding(.top, 52) // Position below navigation bar
            }
        }
        .sheet(isPresented: $showCoinWallet) {
            CoinWalletView()
                .environmentObject(storeViewModel)
        }
        .task {
            // Wallet initialisieren beim App-Start
            if let userId = userManager.currentUser?.id, coinManager.wallet == nil {
                await coinManager.initialize(for: userId)
            }
        }
    }
}

#Preview {
    MainTabView()
}
