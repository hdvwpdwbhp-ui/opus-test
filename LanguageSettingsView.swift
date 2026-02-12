//
//  LanguageSettingsView.swift
//  Tanzen mit Tatiana Drexler
//
//  View zur Sprachauswahl
//

import SwiftUI

// MARK: - Sprachauswahl in Einstellungen
struct LanguageSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedLanguage = LanguageManager.shared.currentLanguage
    
    var body: some View {
        List {
            Section {
                ForEach(AppLanguage.allCases) { language in
                    LanguageRow(
                        language: language,
                        isSelected: selectedLanguage == language
                    ) {
                        withAnimation {
                            selectedLanguage = language
                            LanguageManager.shared.setLanguage(language)
                        }
                    }
                }
            } header: {
                Text(String.localized(.selectLanguageText))
            }
        }
        .navigationTitle(String.localized(.changeLanguage))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Sprachauswahl beim Onboarding (Vollbild)
struct LanguageSelectionView: View {
    var onContinue: () -> Void
    
    @State private var selectedLanguage: AppLanguage = LanguageManager.shared.currentLanguage
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: TDSpacing.md) {
                Image(systemName: "globe")
                    .font(.system(size: 60))
                    .foregroundColor(Color.accentGold)
                
                Text(String.localized(.selectLanguage))
                    .font(TDTypography.largeTitle)
                    .fontWeight(.bold)
                
                Text(String.localized(.selectLanguageText))
                    .font(TDTypography.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, TDSpacing.xxl)
            .padding(.bottom, TDSpacing.xl)
            
            // Sprachauswahl
            ScrollView {
                VStack(spacing: TDSpacing.sm) {
                    ForEach(AppLanguage.allCases) { language in
                        LanguageSelectionCard(
                            language: language,
                            isSelected: selectedLanguage == language
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                selectedLanguage = language
                                LanguageManager.shared.setLanguage(language)
                            }
                        }
                    }
                }
                .padding(.horizontal, TDSpacing.lg)
            }
            
            Spacer()
            
            // Continue Button
            Button {
                onContinue()
            } label: {
                Text(String.localized(.continueButton))
                    .font(TDTypography.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentGold)
                    .cornerRadius(TDRadius.md)
            }
            .padding(.horizontal, TDSpacing.lg)
            .padding(.bottom, TDSpacing.xl)
        }
        .background(TDGradients.mainBackground.ignoresSafeArea())
    }
}

// MARK: - Sprach-Karte für Onboarding
struct LanguageSelectionCard: View {
    let language: AppLanguage
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: TDSpacing.md) {
                // Flagge
                Text(language.flag)
                    .font(.system(size: 36))
                
                // Sprache
                Text(language.displayName)
                    .font(TDTypography.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Auswahlindikator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(Color.accentGold)
                } else {
                    Image(systemName: "circle")
                        .font(.title2)
                        .foregroundColor(.gray.opacity(0.4))
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: TDRadius.md)
                    .fill(isSelected ? Color.accentGold.opacity(0.1) : Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: TDRadius.md)
                            .stroke(isSelected ? Color.accentGold : Color.gray.opacity(0.2), lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Sprach-Zeile für Einstellungen
struct LanguageRow: View {
    let language: AppLanguage
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: TDSpacing.md) {
                Text(language.flag)
                    .font(.title2)
                
                Text(language.displayName)
                    .font(TDTypography.body)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundColor(Color.accentGold)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Text Extension für lokalisierte Strings
extension Text {
    static func localized(_ key: LocalizedStringKey) -> Text {
        Text(LanguageManager.shared.string(key))
    }
}

// MARK: - Preview
#Preview("Language Settings") {
    NavigationStack {
        LanguageSettingsView()
    }
}

#Preview("Language Selection") {
    LanguageSelectionView {
        print("Continue tapped")
    }
}
