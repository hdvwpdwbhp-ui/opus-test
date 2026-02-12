//
//  TrainerEditRequestsView.swift
//  Tanzen mit Tatiana Drexler
//
//  Admin kann Trainer-Änderungsanfragen genehmigen oder ablehnen
//

import SwiftUI

struct TrainerEditRequestsView: View {
    @StateObject private var settingsManager = AppSettingsManager.shared
    @State private var filterStatus: TrainerEditRequest.RequestStatus?
    
    var filteredRequests: [TrainerEditRequest] {
        var requests = settingsManager.trainerEditRequests
        if let status = filterStatus {
            requests = requests.filter { $0.status == status }
        }
        return requests.sorted { $0.requestedAt > $1.requestedAt }
    }
    
    var body: some View {
        List {
            // Stats
            Section {
                HStack(spacing: TDSpacing.md) {
                    StatBox(count: settingsManager.trainerEditRequests.filter { $0.status == .pending }.count, title: "Ausstehend", color: .orange)
                    StatBox(count: settingsManager.trainerEditRequests.filter { $0.status == .approved }.count, title: "Genehmigt", color: .green)
                    StatBox(count: settingsManager.trainerEditRequests.filter { $0.status == .rejected }.count, title: "Abgelehnt", color: .red)
                }
            }
            
            // Filter
            Section {
                Picker("Status", selection: $filterStatus) {
                    Text(T("Alle")).tag(nil as TrainerEditRequest.RequestStatus?)
                    Text(T("Ausstehend")).tag(TrainerEditRequest.RequestStatus.pending as TrainerEditRequest.RequestStatus?)
                    Text(T("Genehmigt")).tag(TrainerEditRequest.RequestStatus.approved as TrainerEditRequest.RequestStatus?)
                    Text(T("Abgelehnt")).tag(TrainerEditRequest.RequestStatus.rejected as TrainerEditRequest.RequestStatus?)
                }
                .pickerStyle(.segmented)
            }
            
            // Requests
            Section {
                if filteredRequests.isEmpty {
                    ContentUnavailableView("Keine Anfragen", systemImage: "doc.text", description: Text(filterStatus == nil ? "Keine Änderungsanfragen vorhanden" : "Keine Anfragen mit diesem Status"))
                } else {
                    ForEach(filteredRequests) { request in
                        TrainerRequestRow(request: request)
                    }
                }
            } header: {
                Text(T("Anfragen (%@)", "\(filteredRequests.count)"))
            }
        }
        .navigationTitle(T("Trainer-Anfragen"))
        .refreshable {
            await settingsManager.loadFromCloud()
        }
    }
}

struct TrainerRequestRow: View {
    let request: TrainerEditRequest
    @StateObject private var settingsManager = AppSettingsManager.shared
    @State private var showApproveConfirm = false
    @State private var showRejectConfirm = false
    @State private var reviewNote = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text(request.courseName)
                    .font(TDTypography.headline)
                
                Spacer()
                
                TrainerRequestStatusBadge(status: request.status)
            }
            
            // Trainer Info
            Text(T("Trainer: %@", request.trainerName))
                .font(TDTypography.caption1)
                .foregroundColor(.secondary)
            
            // Change Details
            VStack(alignment: .leading, spacing: 4) {
                Text(T("Feld: %@", request.fieldName))
                    .font(TDTypography.subheadline)
                    .fontWeight(.medium)
                
                HStack(spacing: TDSpacing.sm) {
                    VStack(alignment: .leading) {
                        Text(T("Alt:"))
                            .font(TDTypography.caption2)
                            .foregroundColor(.secondary)
                        Text(request.oldValue.isEmpty ? "(leer)" : request.oldValue)
                            .font(TDTypography.caption1)
                            .foregroundColor(.red)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Image(systemName: "arrow.right")
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading) {
                        Text(T("Neu:"))
                            .font(TDTypography.caption2)
                            .foregroundColor(.secondary)
                        Text(request.newValue.isEmpty ? "(leer)" : request.newValue)
                            .font(TDTypography.caption1)
                            .foregroundColor(.green)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Timestamp
            Text(T("Angefragt: %@", request.requestedAt.formatted(date: .abbreviated, time: .shortened)))
                .font(TDTypography.caption2)
                .foregroundColor(.secondary)
            
            // Review Info (wenn bereits bearbeitet)
            if let reviewedAt = request.reviewedAt {
                Divider()
                VStack(alignment: .leading, spacing: 2) {
                    Text(T("Bearbeitet: %@", reviewedAt.formatted(date: .abbreviated, time: .shortened)))
                        .font(TDTypography.caption2)
                        .foregroundColor(.secondary)
                    if let note = request.reviewNote, !note.isEmpty {
                        Text(T("Notiz: %@", note))
                            .font(TDTypography.caption1)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
            }
            
            // Action Buttons (nur für ausstehende)
            if request.status == .pending {
                HStack(spacing: TDSpacing.md) {
                    Button {
                        showRejectConfirm = true
                    } label: {
                        HStack {
                            Image(systemName: "xmark")
                            Text(T("Ablehnen"))
                        }
                        .font(TDTypography.subheadline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.red)
                        .cornerRadius(TDRadius.sm)
                    }
                    
                    Button {
                        showApproveConfirm = true
                    } label: {
                        HStack {
                            Image(systemName: "checkmark")
                            Text(T("Genehmigen"))
                        }
                        .font(TDTypography.subheadline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.green)
                        .cornerRadius(TDRadius.sm)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
        .alert(T("Anfrage genehmigen?"), isPresented: $showApproveConfirm) {
            TextField(T("Notiz (optional)"), text: $reviewNote)
            Button(T("Abbrechen"), role: .cancel) { reviewNote = "" }
            Button(T("Genehmigen")) {
                Task {
                    _ = await settingsManager.approveTrainerEditRequest(requestId: request.id, note: reviewNote.isEmpty ? nil : reviewNote)
                    reviewNote = ""
                }
            }
        } message: {
            Text(T("Die Änderung wird durchgeführt."))
        }
        .alert(T("Anfrage ablehnen?"), isPresented: $showRejectConfirm) {
            TextField(T("Begründung (optional)"), text: $reviewNote)
            Button(T("Abbrechen"), role: .cancel) { reviewNote = "" }
            Button(T("Ablehnen"), role: .destructive) {
                Task {
                    _ = await settingsManager.rejectTrainerEditRequest(requestId: request.id, note: reviewNote.isEmpty ? nil : reviewNote)
                    reviewNote = ""
                }
            }
        } message: {
            Text(T("Die Änderung wird nicht durchgeführt."))
        }
    }
}

struct TrainerRequestStatusBadge: View {
    let status: TrainerEditRequest.RequestStatus
    
    var body: some View {
        Text(status.rawValue)
            .font(TDTypography.caption2)
            .fontWeight(.medium)
            .foregroundColor(statusColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.2))
            .cornerRadius(4)
    }
    
    private var statusColor: Color {
        switch status {
        case .pending: return .orange
        case .approved: return .green
        case .rejected: return .red
        }
    }
}

#Preview {
    NavigationStack {
        TrainerEditRequestsView()
    }
}
