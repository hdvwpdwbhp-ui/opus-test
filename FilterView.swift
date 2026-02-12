//
//  FilterView.swift
//  Tanzen mit Tatiana Drexler
//
//  Course Filter Sheet
//

import SwiftUI

struct FilterView: View {
    @EnvironmentObject var courseViewModel: CourseViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                TDGradients.mainBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: TDSpacing.lg) {
                        // Level Filter
                        filterSection(title: "Schwierigkeitsgrad") {
                            ForEach(CourseLevel.allCases) { level in
                                FilterToggleRow(
                                    title: level.rawValue,
                                    icon: level.icon,
                                    isSelected: courseViewModel.filter.levels.contains(level)
                                ) {
                                    courseViewModel.toggleLevelFilter(level)
                                }
                            }
                        }
                        
                        // Style Filter
                        filterSection(title: "Tanzstil") {
                            ForEach(DanceStyle.allCases) { style in
                                FilterToggleRow(
                                    title: style.rawValue,
                                    icon: style.icon,
                                    isSelected: courseViewModel.filter.styles.contains(style)
                                ) {
                                    courseViewModel.toggleStyleFilter(style)
                                }
                            }
                        }
                        
                        // Language Filter
                        filterSection(title: "Sprache") {
                            ForEach(CourseLanguage.allCases) { language in
                                FilterToggleRow(
                                    title: "\(language.flag) \(language.rawValue)",
                                    icon: "globe",
                                    isSelected: courseViewModel.filter.languages.contains(language)
                                ) {
                                    courseViewModel.toggleLanguageFilter(language)
                                }
                            }
                        }
                        
                        // Purchase Status
                        filterSection(title: "Status") {
                            FilterToggleRow(
                                title: "Nur gekaufte Kurse",
                                icon: "checkmark.circle.fill",
                                isSelected: courseViewModel.filter.showPurchasedOnly
                            ) {
                                courseViewModel.filter.showPurchasedOnly.toggle()
                                if courseViewModel.filter.showPurchasedOnly {
                                    courseViewModel.filter.showUnpurchasedOnly = false
                                }
                            }
                            
                            FilterToggleRow(
                                title: "Nur nicht gekaufte Kurse",
                                icon: "circle",
                                isSelected: courseViewModel.filter.showUnpurchasedOnly
                            ) {
                                courseViewModel.filter.showUnpurchasedOnly.toggle()
                                if courseViewModel.filter.showUnpurchasedOnly {
                                    courseViewModel.filter.showPurchasedOnly = false
                                }
                            }
                        }
                    }
                    .padding(TDSpacing.md)
                }
            }
            .navigationTitle(T("Filter"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(T("Zurücksetzen")) {
                        courseViewModel.clearFilters()
                    }
                    .foregroundColor(Color.accentGold)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(T("Fertig")) {
                        dismiss()
                    }
                    .foregroundColor(Color.accentGold)
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    // MARK: - Filter Section
    private func filterSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: TDSpacing.sm) {
            Text(title)
                .font(TDTypography.headline)
                .foregroundColor(.secondary)
                .padding(.leading, TDSpacing.sm)
            
            VStack(spacing: 0) {
                content()
            }
            .glassBackground()
        }
    }
}

// MARK: - Filter Toggle Row
struct FilterToggleRow: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: TDSpacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? Color.accentGold : .secondary)
                    .frame(width: 28)
                
                Text(title)
                    .font(TDTypography.body)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? Color.accentGold : .secondary)
            }
            .padding(TDSpacing.md)
        }
    }
}

#Preview {
    FilterView()
        .environmentObject(CourseViewModel())
}
