//
//  SupportChangesView.swift
//  Tanzen mit Tatiana Drexler
//
//  Admin kann alle Support-Änderungen einsehen und rückgängig machen
//

import SwiftUI

struct SupportChangesView: View {
    @StateObject private var settingsManager = AppSettingsManager.shared
    @State private var filterType: SupportChange.ChangeType?
    @State private var showRevertConfirm = false
    @State private var selectedChange: SupportChange?
    
    var filteredChanges: [SupportChange] {
        var changes = settingsManager.supportChanges
        if let type = filterType {
            changes = changes.filter { $0.changeType == type }
        }
        return changes.sorted { $0.timestamp > $1.timestamp }
    }
    
    var body: some View {
        List {
            // Stats
            Section {
                HStack(spacing: TDSpacing.md) {
                    StatBox(count: settingsManager.supportChanges.count, title: "Gesamt", color: .blue)
                    StatBox(count: settingsManager.supportChanges.filter { !$0.isReverted }.count, title: "Aktiv", color: .green)
                    StatBox(count: settingsManager.supportChanges.filter { $0.isReverted }.count, title: "Rückgängig", color: .red)
                }
            }
            
            // Filter
            Section {
                Picker("Filter", selection: $filterType) {
                    Text(T("Alle")).tag(nil as SupportChange.ChangeType?)
                    ForEach([SupportChange.ChangeType.courseUnlocked, .courseLocked, .userEdited, .premiumGranted, .premiumRevoked, .other], id: \.self) { type in
                        Text(type.rawValue).tag(type as SupportChange.ChangeType?)
                    }
                }
                .pickerStyle(.menu)
            }
            
            // Changes List
            Section {
                if filteredChanges.isEmpty {
                    ContentUnavailableView("Keine Änderungen", systemImage: "doc.text", description: Text(T("Noch keine Support-Änderungen dokumentiert")))
                } else {
                    ForEach(filteredChanges) { change in
                        SupportChangeRow(change: change) {
                            selectedChange = change
                            showRevertConfirm = true
                        }
                    }
                }
            } header: {
                Text(T("Änderungen (%@)", "\(filteredChanges.count)"))
            }
        }
        .navigationTitle(T("Support-Änderungen"))
        .alert(T("Änderung rückgängig machen?"), isPresented: $showRevertConfirm) {
            Button(T("Abbrechen"), role: .cancel) { }
            Button(T("Rückgängig"), role: .destructive) {
                if let change = selectedChange {
                    Task {
                        _ = await settingsManager.revertSupportChange(changeId: change.id)
                    }
                }
            }
        } message: {
            if let change = selectedChange {
                Text(T("Die Änderung '%@' wird als rückgängig markiert.", change.description))
            }
        }
        .refreshable {
            await settingsManager.loadFromCloud()
        }
    }
}

struct SupportChangeRow: View {
    let change: SupportChange
    let onRevert: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: changeIcon)
                    .foregroundColor(change.isReverted ? .gray : changeColor)
                
                Text(change.changeType.rawValue)
                    .font(TDTypography.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(change.isReverted ? .gray : .primary)
                
                Spacer()
                
                if change.isReverted {
                    Text(T("RÜCKGÄNGIG"))
                        .font(TDTypography.caption2)
                        .foregroundColor(.red)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            
            // Description
            Text(change.description)
                .font(TDTypography.body)
                .foregroundColor(change.isReverted ? .secondary : .primary)
            
            // Details
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(T("Support: %@", change.supportUserName))
                        .font(TDTypography.caption1)
                        .foregroundColor(.secondary)
                    Text(T("Benutzer: %@", change.targetUserName))
                        .font(TDTypography.caption1)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(change.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(TDTypography.caption2)
                    .foregroundColor(.secondary)
            }
            
            // Old/New Values
            if let oldValue = change.oldValue, let newValue = change.newValue {
                HStack(spacing: TDSpacing.sm) {
                    Text(T("Alt: %@", oldValue))
                        .font(TDTypography.caption2)
                        .foregroundColor(.red)
                    
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(T("Neu: %@", newValue))
                        .font(TDTypography.caption2)
                        .foregroundColor(.green)
                }
            }
            
            // Revert Button (wenn nicht schon rückgängig)
            if !change.isReverted {
                Button {
                    onRevert()
                } label: {
                    HStack {
                        Image(systemName: "arrow.uturn.backward")
                        Text(T("Rückgängig machen"))
                    }
                    .font(TDTypography.caption1)
                    .foregroundColor(.red)
                }
                .padding(.top, 4)
            } else if let revertedAt = change.revertedAt {
                Text(T("Rückgängig am %@", revertedAt.formatted(date: .abbreviated, time: .shortened)))
                    .font(TDTypography.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .opacity(change.isReverted ? 0.7 : 1.0)
    }
    
    private var changeIcon: String {
        switch change.changeType {
        case .courseUnlocked: return "lock.open"
        case .courseLocked: return "lock"
        case .userEdited: return "person.text.rectangle"
        case .premiumGranted: return "crown"
        case .premiumRevoked: return "crown.fill"
        case .other: return "doc.text"
        }
    }
    
    private var changeColor: Color {
        switch change.changeType {
        case .courseUnlocked: return .green
        case .courseLocked: return .red
        case .userEdited: return .blue
        case .premiumGranted: return .orange
        case .premiumRevoked: return .red
        case .other: return .gray
        }
    }
}

struct StatBox: View {
    let count: Int
    let title: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(TDTypography.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(title)
                .font(TDTypography.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(TDRadius.sm)
    }
}

#Preview {
    NavigationStack {
        SupportChangesView()
    }
}
