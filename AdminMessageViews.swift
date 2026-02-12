//
//  AdminMessageViews.swift
//  Tanzen mit Tatiana Drexler
//
//  Views für Admin-Nachrichten-System
//

import SwiftUI

// MARK: - User Popup View (zeigt Admin-Nachrichten an)

struct AdminMessagePopupView: View {
    let message: AdminMessage
    let onDismiss: () -> Void
    
    @StateObject private var messageManager = AdminMessageManager.shared
    
    private var typeColor: Color {
        switch message.messageType.color {
        case "blue": return .blue
        case "orange": return .orange
        case "red": return .red
        case "purple": return .purple
        case "green": return .green
        default: return .blue
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: message.messageType.icon)
                    .font(.title2)
                    .foregroundColor(typeColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(message.title)
                        .font(TDTypography.headline)
                        .foregroundColor(.primary)
                    Text(T("Von: %@", message.fromAdminName))
                        .font(TDTypography.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button {
                    Task {
                        await messageManager.dismissMessage(message.id)
                        onDismiss()
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(typeColor.opacity(0.1))
            
            // Content
            VStack(alignment: .leading, spacing: TDSpacing.md) {
                Text(message.message)
                    .font(TDTypography.body)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(message.createdAt, style: .relative)
                    .font(TDTypography.caption2)
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Action Button
            Button {
                Task {
                    await messageManager.markAsRead(message.id)
                    await messageManager.dismissMessage(message.id)
                    onDismiss()
                }
            } label: {
                Text(T("Verstanden"))
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(typeColor)
                    .foregroundColor(.white)
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(TDRadius.lg)
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        .padding(TDSpacing.lg)
        .onAppear {
            Task {
                await messageManager.markAsRead(message.id)
            }
        }
    }
}

// MARK: - Admin View: Send Message to User

struct AdminSendMessageView: View {
    let user: AppUser
    
    @StateObject private var messageManager = AdminMessageManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var messageText = ""
    @State private var messageType: AdminMessageType = .info
    @State private var isSending = false
    @State private var showSuccess = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section(T("Empfänger")) {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.title2)
                            .foregroundColor(.accentColor)
                        
                        VStack(alignment: .leading) {
                            Text(user.name)
                                .font(TDTypography.headline)
                            Text(user.email)
                                .font(TDTypography.caption1)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section(T("Nachricht")) {
                    TextField(T("Titel"), text: $title)
                    
                    TextEditor(text: $messageText)
                        .frame(minHeight: 120)
                    
                    Picker("Typ", selection: $messageType) {
                        ForEach(AdminMessageType.allCases, id: \.self) { type in
                            HStack {
                                Image(systemName: type.icon)
                                Text(type.displayName)
                            }
                            .tag(type)
                        }
                    }
                }
                
                Section {
                    HStack {
                        Image(systemName: messageType.icon)
                            .foregroundColor(typeColor)
                        Text(T("Vorschau"))
                            .font(TDTypography.caption1)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(title.isEmpty ? "Titel" : title)
                            .font(TDTypography.headline)
                            .foregroundColor(title.isEmpty ? .secondary : .primary)
                        
                        Text(messageText.isEmpty ? "Nachricht..." : messageText)
                            .font(TDTypography.body)
                            .foregroundColor(messageText.isEmpty ? .secondary : .primary)
                    }
                    .padding()
                    .background(typeColor.opacity(0.1))
                    .cornerRadius(TDRadius.md)
                }
            }
            .navigationTitle(T("Nachricht senden"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(T("Abbrechen")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(T("Senden")) {
                        Task { await sendMessage() }
                    }
                    .disabled(title.isEmpty || messageText.isEmpty || isSending)
                }
            }
            .alert(T("Nachricht gesendet!"), isPresented: $showSuccess) {
                Button(T("OK")) { dismiss() }
            } message: {
                Text("\(user.name) erhält die Nachricht beim nächsten App-Start.")
            }
        }
    }
    
    private var typeColor: Color {
        switch messageType.color {
        case "blue": return .blue
        case "orange": return .orange
        case "red": return .red
        case "purple": return .purple
        case "green": return .green
        default: return .blue
        }
    }
    
    private func sendMessage() async {
        isSending = true
        defer { isSending = false }
        
        let success = await messageManager.sendMessage(
            to: user,
            title: title,
            message: messageText,
            type: messageType
        )
        
        if success {
            showSuccess = true
        }
    }
}

// MARK: - Admin View: Broadcast Message

struct AdminBroadcastMessageView: View {
    @StateObject private var messageManager = AdminMessageManager.shared
    @StateObject private var userManager = UserManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var messageText = ""
    @State private var messageType: AdminMessageType = .info
    @State private var targetGroup: UserGroup? = nil
    @State private var isSending = false
    @State private var showSuccess = false
    @State private var sentCount = 0
    
    var body: some View {
        NavigationStack {
            Form {
                Section(T("Empfänger")) {
                    Picker("Zielgruppe", selection: $targetGroup) {
                        Text(T("Alle User")).tag(nil as UserGroup?)
                        ForEach(UserGroup.allCases, id: \.self) { group in
                            Text(group.displayName).tag(group as UserGroup?)
                        }
                    }
                    
                    let count = targetUsers.count
                    Text("\(count) Empfänger")
                        .font(TDTypography.caption1)
                        .foregroundColor(.secondary)
                }
                
                Section(T("Nachricht")) {
                    TextField(T("Titel"), text: $title)
                    
                    TextEditor(text: $messageText)
                        .frame(minHeight: 120)
                    
                    Picker("Typ", selection: $messageType) {
                        ForEach(AdminMessageType.allCases, id: \.self) { type in
                            HStack {
                                Image(systemName: type.icon)
                                Text(type.displayName)
                            }
                            .tag(type)
                        }
                    }
                }
            }
            .navigationTitle(T("Broadcast senden"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(T("Abbrechen")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(T("Senden")) {
                        Task { await sendBroadcast() }
                    }
                    .disabled(title.isEmpty || messageText.isEmpty || isSending)
                }
            }
            .alert(T("Broadcast gesendet!"), isPresented: $showSuccess) {
                Button(T("OK")) { dismiss() }
            } message: {
                Text("\(sentCount) Nachrichten wurden versendet.")
            }
        }
    }
    
    private var targetUsers: [AppUser] {
        if let group = targetGroup {
            return userManager.allUsers.filter { $0.group == group }
        }
        return userManager.allUsers.filter { $0.group == .user }
    }
    
    private func sendBroadcast() async {
        isSending = true
        defer { isSending = false }
        
        sentCount = await messageManager.sendBroadcast(
            title: title,
            message: messageText,
            type: messageType,
            toUserGroup: targetGroup
        )
        
        if sentCount > 0 {
            showSuccess = true
        }
    }
}

// MARK: - Admin View: Message History

struct AdminMessageHistoryView: View {
    @StateObject private var messageManager = AdminMessageManager.shared
    
    var body: some View {
        List {
            if messageManager.allMessages.isEmpty {
                ContentUnavailableView(
                    "Keine Nachrichten",
                    systemImage: "envelope",
                    description: Text(T("Noch keine Admin-Nachrichten gesendet"))
                )
            } else {
                ForEach(messageManager.allMessages) { message in
                    AdminMessageRow(message: message)
                }
                .onDelete(perform: deleteMessages)
            }
        }
        .navigationTitle(T("Nachrichtenverlauf"))
        .overlay {
            if messageManager.isLoading {
                ProgressView()
            }
        }
        .refreshable {
            await messageManager.loadAllMessages()
        }
        .task {
            await messageManager.loadAllMessages()
        }
    }
    
    private func deleteMessages(at offsets: IndexSet) {
        Task {
            for index in offsets {
                let message = messageManager.allMessages[index]
                _ = await messageManager.deleteMessage(message.id)
            }
        }
    }
}

struct AdminMessageRow: View {
    let message: AdminMessage
    
    private var typeColor: Color {
        switch message.messageType.color {
        case "blue": return .blue
        case "orange": return .orange
        case "red": return .red
        case "purple": return .purple
        case "green": return .green
        default: return .blue
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: message.messageType.icon)
                    .foregroundColor(typeColor)
                
                Text(message.title)
                    .font(TDTypography.headline)
                
                Spacer()
                
                if message.isRead {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                } else {
                    Circle()
                        .fill(typeColor)
                        .frame(width: 8, height: 8)
                }
            }
            
            Text(T("An: %@", message.toUserName))
                .font(TDTypography.caption1)
                .foregroundColor(.secondary)
            
            Text(message.message)
                .font(TDTypography.body)
                .lineLimit(2)
                .foregroundColor(.secondary)
            
            Text(message.createdAt, style: .relative)
                .font(TDTypography.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    AdminMessagePopupView(
        message: AdminMessage(
            title: "Wichtige Mitteilung",
            message: "Dies ist eine Test-Nachricht vom Admin-Team. Wir möchten dich über neue Features informieren!",
            fromAdminId: "admin1",
            fromAdminName: "Admin",
            toUserId: "user1",
            toUserName: "Test User",
            messageType: .info
        ),
        onDismiss: {}
    )
}
