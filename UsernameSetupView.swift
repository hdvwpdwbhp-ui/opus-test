//
//  UsernameSetupView.swift
//  Tanzen mit Tatiana Drexler
//
//  Wird nach der Registrierung angezeigt, um einen öffentlichen Username zu wählen
//

import SwiftUI

struct UsernameSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var userManager = UserManager.shared
    
    @State private var username = ""
    @State private var isChecking = false
    @State private var isAvailable: Bool?
    @State private var errorMessage: String?
    @State private var isSaving = false
    
    // Debounce für Username-Prüfung
    @State private var checkTask: Task<Void, Never>?
    
    var body: some View {
        NavigationStack {
            ZStack {
                TDGradients.mainBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Header
                        headerSection
                        
                        // Username Input
                        usernameInputSection
                        
                        // Regeln
                        rulesSection
                        
                        // Speichern Button
                        saveButton
                        
                        // Später Button
                        skipButton
                    }
                    .padding(24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(true) // Verhindert Wischen zum Schließen
        }
    }
    
    // MARK: - Header
    private var headerSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.accentGold.opacity(0.2))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "at.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(Color.accentGold)
            }
            
            Text(T("Wähle einen Benutzernamen"))
                .font(.title2)
                .fontWeight(.bold)
            
            Text(T("Dein Benutzername wird anderen Nutzern angezeigt, z.B. in Kommentaren und im Leaderboard."))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 20)
    }
    
    // MARK: - Username Input
    private var usernameInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(T("Benutzername"))
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                Text("@")
                    .font(.title3)
                    .foregroundColor(.secondary)
                
                TextField("dein_username", text: $username)
                    .font(.title3)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .onChange(of: username) { _, newValue in
                        // Nur erlaubte Zeichen
                        let filtered = newValue.lowercased().filter { 
                            $0.isLetter || $0.isNumber || $0 == "_" 
                        }
                        if filtered != newValue {
                            username = filtered
                        }
                        
                        // Prüfung starten
                        checkUsernameAvailability()
                    }
                
                // Status Indicator
                if isChecking {
                    ProgressView()
                        .scaleEffect(0.8)
                } else if let available = isAvailable {
                    Image(systemName: available ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(available ? .green : .red)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            
            // Verfügbarkeits-Meldung
            if let available = isAvailable, !username.isEmpty {
                HStack {
                    Image(systemName: available ? "checkmark" : "xmark")
                    Text(available ? "Benutzername ist verfügbar!" : "Benutzername ist bereits vergeben")
                }
                .font(.caption)
                .foregroundColor(available ? .green : .red)
            }
            
            // Error Message
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
    
    // MARK: - Rules
    private var rulesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(T("Regeln für Benutzernamen:"))
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 4) {
                RuleRow(text: "3-20 Zeichen lang", isMet: username.count >= 3 && username.count <= 20)
                RuleRow(text: "Nur Buchstaben, Zahlen und Unterstriche", isMet: isValidFormat)
                RuleRow(text: "Muss einzigartig sein", isMet: isAvailable == true)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var isValidFormat: Bool {
        let regex = "^[a-z0-9_]+$"
        return username.range(of: regex, options: .regularExpression) != nil && !username.isEmpty
    }
    
    // MARK: - Save Button
    private var saveButton: some View {
        Button {
            Task { await saveUsername() }
        } label: {
            HStack {
                if isSaving {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text(T("Benutzernamen speichern"))
                        .fontWeight(.semibold)
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(canSave ? Color.accentGold : Color.gray)
            .cornerRadius(12)
        }
        .disabled(!canSave || isSaving)
    }
    
    private var canSave: Bool {
        username.count >= 3 && 
        username.count <= 20 && 
        isValidFormat && 
        isAvailable == true
    }
    
    // MARK: - Skip Button
    private var skipButton: some View {
        Button {
            dismiss()
        } label: {
            Text(T("Später festlegen"))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Check Username
    private func checkUsernameAvailability() {
        // Cancel previous task
        checkTask?.cancel()
        
        // Reset state
        isAvailable = nil
        errorMessage = nil
        
        guard username.count >= 3 else { return }
        
        isChecking = true
        
        // Debounce: Warte 500ms bevor wir prüfen
        checkTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            guard !Task.isCancelled else { return }
            
            // Prüfe ob Username bereits existiert
            let exists = userManager.allUsers.contains { 
                $0.username.lowercased() == username.lowercased() 
            }
            
            await MainActor.run {
                isChecking = false
                isAvailable = !exists
            }
        }
    }
    
    // MARK: - Save Username
    private func saveUsername() async {
        isSaving = true
        errorMessage = nil
        
        let (success, message) = await userManager.updateProfile(username: username)
        
        isSaving = false
        
        if success {
            dismiss()
        } else {
            errorMessage = message
        }
    }
}

// MARK: - Rule Row
struct RuleRow: View {
    let text: String
    let isMet: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isMet ? "checkmark.circle.fill" : "circle")
                .font(.caption)
                .foregroundColor(isMet ? .green : .secondary)
            
            Text(text)
                .font(.caption)
                .foregroundColor(isMet ? .primary : .secondary)
        }
    }
}

#Preview {
    UsernameSetupView()
}
