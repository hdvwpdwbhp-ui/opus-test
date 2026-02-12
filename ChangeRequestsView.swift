//
//  ChangeRequestsView.swift
//  Tanzen mit Tatiana Drexler
//
//  Admin-Ansicht zum Genehmigen/Ablehnen von Änderungsanfragen
//

import SwiftUI

struct ChangeRequestsView: View {
    @StateObject private var changeManager = ChangeRequestManager.shared
    @StateObject private var authManager = AdminAuthManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedRequest: ChangeRequest?
    @State private var showRejectDialog = false
    @State private var rejectionReason = ""
    @State private var requestToReject: ChangeRequest?
    @State private var filterStatus: ChangeRequest.ChangeStatus? = .pending
    
    var filteredRequests: [ChangeRequest] {
        if let status = filterStatus {
            return changeManager.allRequests.filter { $0.status == status }
        }
        return changeManager.allRequests
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                TDGradients.mainBackground
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Filter Tabs
                    filterTabs
                    
                    if filteredRequests.isEmpty {
                        emptyState
                    } else {
                        requestsList
                    }
                }
            }
            .navigationTitle(T("Änderungsanfragen"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(T("Fertig")) {
                        dismiss()
                    }
                    .foregroundColor(Color.accentGold)
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    if changeManager.isSyncing {
                        ProgressView()
                    } else {
                        Button {
                            Task {
                                await changeManager.refresh()
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(Color.accentGold)
                        }
                    }
                }
            }
            .sheet(item: $selectedRequest) { request in
                ChangeRequestDetailView(request: request)
            }
            .alert(T("Änderung ablehnen"), isPresented: $showRejectDialog) {
                TextField(T("Grund für Ablehnung"), text: $rejectionReason)
                Button(T("Abbrechen"), role: .cancel) {
                    rejectionReason = ""
                    requestToReject = nil
                }
                Button(T("Ablehnen"), role: .destructive) {
                    if let request = requestToReject {
                        Task {
                            await changeManager.rejectRequest(
                                request.id,
                                by: "Admin",
                                reason: rejectionReason.isEmpty ? "Keine Begründung" : rejectionReason
                            )
                            rejectionReason = ""
                            requestToReject = nil
                        }
                    }
                }
            } message: {
                Text(T("Bitte gib einen Grund für die Ablehnung an."))
            }
            .onAppear {
                Task {
                    await changeManager.refresh()
                }
            }
        }
    }
    
    // MARK: - Filter Tabs
    private var filterTabs: some View {
        HStack(spacing: 0) {
            FilterTab(title: "Ausstehend", count: changeManager.pendingRequests.count, isSelected: filterStatus == .pending) {
                filterStatus = .pending
            }
            FilterTab(title: "Genehmigt", count: nil, isSelected: filterStatus == .approved) {
                filterStatus = .approved
            }
            FilterTab(title: "Abgelehnt", count: nil, isSelected: filterStatus == .rejected) {
                filterStatus = .rejected
            }
            FilterTab(title: "Alle", count: nil, isSelected: filterStatus == nil) {
                filterStatus = nil
            }
        }
        .padding(TDSpacing.sm)
        .background(Color.gray.opacity(0.1))
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: TDSpacing.lg) {
            Spacer()
            
            Image(systemName: filterStatus == .pending ? "checkmark.circle" : "doc.text")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text(filterStatus == .pending ? "Keine ausstehenden Anfragen" : "Keine Anfragen")
                .font(TDTypography.title2)
                .foregroundColor(.primary)
            
            Text(filterStatus == .pending ? "Alle Änderungsanfragen wurden bearbeitet" : "Keine Anfragen in dieser Kategorie")
                .font(TDTypography.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .padding(TDSpacing.lg)
    }
    
    // MARK: - Requests List
    private var requestsList: some View {
        ScrollView {
            LazyVStack(spacing: TDSpacing.md) {
                ForEach(filteredRequests.sorted(by: { $0.createdAt > $1.createdAt })) { request in
                    ChangeRequestCard(
                        request: request,
                        onApprove: {
                            Task {
                                await changeManager.approveRequest(request.id, by: "Admin")
                            }
                        },
                        onReject: {
                            requestToReject = request
                            showRejectDialog = true
                        },
                        onTap: {
                            selectedRequest = request
                        }
                    )
                }
            }
            .padding(TDSpacing.md)
        }
    }
}

// MARK: - Filter Tab
struct FilterTab: View {
    let title: String
    let count: Int?
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(TDTypography.caption1)
                
                if let count = count, count > 0 {
                    Text("\(count)")
                        .font(TDTypography.caption2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .clipShape(Capsule())
                }
            }
            .foregroundColor(isSelected ? Color.accentGold : .secondary)
            .padding(.horizontal, TDSpacing.md)
            .padding(.vertical, TDSpacing.sm)
            .background(isSelected ? Color.accentGold.opacity(0.1) : Color.clear)
            .cornerRadius(TDRadius.sm)
        }
    }
}

// MARK: - Change Request Card
struct ChangeRequestCard: View {
    let request: ChangeRequest
    let onApprove: () -> Void
    let onReject: () -> Void
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: TDSpacing.md) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(request.courseName)
                        .font(TDTypography.headline)
                        .foregroundColor(.primary)
                    
                    Text("\(request.changeType.rawValue) ändern")
                        .font(TDTypography.caption1)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                StatusBadge(status: request.status)
            }
            
            // Editor Info
            HStack {
                Image(systemName: "person.circle.fill")
                    .foregroundColor(Color.accentGold)
                Text(request.editorName)
                    .font(TDTypography.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(request.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(TDTypography.caption1)
                    .foregroundColor(.secondary)
            }
            
            // Change Preview
            VStack(alignment: .leading, spacing: TDSpacing.xs) {
                Text(T("Änderung:"))
                    .font(TDTypography.caption1)
                    .foregroundColor(.secondary)
                
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(T("Alt:"))
                            .font(TDTypography.caption2)
                            .foregroundColor(.red)
                        Text(request.oldValue.prefix(100) + (request.oldValue.count > 100 ? "..." : ""))
                            .font(TDTypography.caption1)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Image(systemName: "arrow.right")
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(T("Neu:"))
                            .font(TDTypography.caption2)
                            .foregroundColor(.green)
                        Text(request.newValue.prefix(100) + (request.newValue.count > 100 ? "..." : ""))
                            .font(TDTypography.caption1)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(TDSpacing.sm)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(TDRadius.sm)
            }
            
            // Actions (nur für pending)
            if request.status == .pending {
                HStack(spacing: TDSpacing.md) {
                    Button {
                        onReject()
                    } label: {
                        HStack {
                            Image(systemName: "xmark")
                            Text(T("Ablehnen"))
                        }
                        .font(TDTypography.subheadline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(TDSpacing.sm)
                        .background(Color.red)
                        .cornerRadius(TDRadius.sm)
                    }
                    
                    Button {
                        onApprove()
                    } label: {
                        HStack {
                            Image(systemName: "checkmark")
                            Text(T("Genehmigen"))
                        }
                        .font(TDTypography.subheadline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(TDSpacing.sm)
                        .background(Color.green)
                        .cornerRadius(TDRadius.sm)
                    }
                }
            }
            
            // Rejection Reason
            if request.status == .rejected, let reason = request.rejectionReason {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(T("Grund: %@", reason))
                        .font(TDTypography.caption1)
                        .foregroundColor(.red)
                }
                .padding(TDSpacing.sm)
                .background(Color.red.opacity(0.1))
                .cornerRadius(TDRadius.sm)
            }
        }
        .padding(TDSpacing.md)
        .glassBackground()
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Status Badge
struct StatusBadge: View {
    let status: ChangeRequest.ChangeStatus
    
    var color: Color {
        switch status {
        case .pending: return .orange
        case .approved: return .green
        case .rejected: return .red
        }
    }
    
    var icon: String {
        switch status {
        case .pending: return "clock"
        case .approved: return "checkmark"
        case .rejected: return "xmark"
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(status.rawValue)
                .font(TDTypography.caption2)
        }
        .foregroundColor(color)
        .padding(.horizontal, TDSpacing.sm)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(TDRadius.sm)
    }
}

// MARK: - Change Request Detail View
struct ChangeRequestDetailView: View {
    let request: ChangeRequest
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                TDGradients.mainBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: TDSpacing.lg) {
                        // Status
                        HStack {
                            StatusBadge(status: request.status)
                            Spacer()
                            Text(request.createdAt.formatted())
                                .font(TDTypography.caption1)
                                .foregroundColor(.secondary)
                        }
                        
                        // Course Info
                        VStack(alignment: .leading, spacing: TDSpacing.sm) {
                            Text(T("Kurs"))
                                .font(TDTypography.caption1)
                                .foregroundColor(.secondary)
                            Text(request.courseName)
                                .font(TDTypography.headline)
                                .foregroundColor(.primary)
                        }
                        .padding(TDSpacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassBackground()
                        
                        // Editor Info
                        VStack(alignment: .leading, spacing: TDSpacing.sm) {
                            Text(T("Editor"))
                                .font(TDTypography.caption1)
                                .foregroundColor(.secondary)
                            HStack {
                                Image(systemName: "person.circle.fill")
                                    .foregroundColor(Color.accentGold)
                                Text(request.editorName)
                                    .font(TDTypography.body)
                                    .foregroundColor(.primary)
                            }
                        }
                        .padding(TDSpacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassBackground()
                        
                        // Change Type
                        VStack(alignment: .leading, spacing: TDSpacing.sm) {
                            Text(T("Änderungstyp"))
                                .font(TDTypography.caption1)
                                .foregroundColor(.secondary)
                            Text(request.changeType.rawValue)
                                .font(TDTypography.body)
                                .foregroundColor(.primary)
                        }
                        .padding(TDSpacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassBackground()
                        
                        // Old Value
                        VStack(alignment: .leading, spacing: TDSpacing.sm) {
                            Text(T("Alter Wert"))
                                .font(TDTypography.caption1)
                                .foregroundColor(.red)
                            Text(request.oldValue)
                                .font(TDTypography.body)
                                .foregroundColor(.primary)
                        }
                        .padding(TDSpacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.05))
                        .cornerRadius(TDRadius.md)
                        
                        // New Value
                        VStack(alignment: .leading, spacing: TDSpacing.sm) {
                            Text(T("Neuer Wert"))
                                .font(TDTypography.caption1)
                                .foregroundColor(.green)
                            Text(request.newValue)
                                .font(TDTypography.body)
                                .foregroundColor(.primary)
                        }
                        .padding(TDSpacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.green.opacity(0.05))
                        .cornerRadius(TDRadius.md)
                        
                        // Review Info (if reviewed)
                        if let reviewedAt = request.reviewedAt {
                            VStack(alignment: .leading, spacing: TDSpacing.sm) {
                                Text(T("Bearbeitet"))
                                    .font(TDTypography.caption1)
                                    .foregroundColor(.secondary)
                                Text(reviewedAt.formatted())
                                    .font(TDTypography.body)
                                    .foregroundColor(.primary)
                                if let reason = request.rejectionReason {
                                    Text(T("Grund: %@", reason))
                                        .font(TDTypography.body)
                                        .foregroundColor(.red)
                                }
                            }
                            .padding(TDSpacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .glassBackground()
                        }
                    }
                    .padding(TDSpacing.md)
                }
            }
            .navigationTitle(T("Änderungsdetails"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(T("Fertig")) {
                        dismiss()
                    }
                    .foregroundColor(Color.accentGold)
                }
            }
        }
    }
}

#Preview {
    ChangeRequestsView()
}
