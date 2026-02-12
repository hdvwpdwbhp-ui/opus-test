//
//  AdminUserDetailLoaderView.swift
//  Tanzen mit Tatiana Drexler
//
//  Lädt User-Daten und öffnet die User-Detail-Ansicht für Admins
//

import SwiftUI

struct AdminUserDetailLoaderView: View {
    let userId: String
    
    @StateObject private var userManager = UserManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var isLoading = true
    
    private var loadedUser: AppUser? {
        userManager.allUsers.first { $0.id == userId }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Lade User...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let user = loadedUser {
                    UserDetailView(user: user)
                } else {
                    ContentUnavailableView(
                        "User nicht gefunden",
                        systemImage: "person.slash",
                        description: Text(T("Der User konnte nicht geladen werden"))
                    )
                }
            }
            .navigationTitle(T("User"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(T("Schließen")) { dismiss() }
                }
            }
            .task {
                if userManager.allUsers.isEmpty {
                    await userManager.loadFromCloud()
                }
                isLoading = false
            }
        }
    }
}
