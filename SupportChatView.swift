//
//  SupportChatView.swift
//  Tanzen mit Tatiana Drexler
//
//  Support-Chat zwischen Usern und Admin
//

import SwiftUI

// MARK: - Support Übersicht (für User)
struct SupportView: View {
    @StateObject private var chatManager = SupportChatManager.shared
    @StateObject private var userManager = UserManager.shared
    @State private var showNewConversation = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                TDGradients.mainBackground
                    .ignoresSafeArea()
                
                if chatManager.myConversations.isEmpty {
                    emptyState
                } else {
                    conversationList
                }
            }
            .navigationTitle(T("Support"))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showNewConversation = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .sheet(isPresented: $showNewConversation) {
                NewConversationView()
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: TDSpacing.lg) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text(T("Noch keine Nachrichten"))
                .font(TDTypography.headline)
                .foregroundColor(.secondary)
            
            Text(T("Hast du eine Frage? Schreib uns!"))
                .font(TDTypography.body)
                .foregroundColor(.secondary)
            
            Button {
                showNewConversation = true
            } label: {
                Label(T("Neue Nachricht"), systemImage: "square.and.pencil")
                    .padding()
                    .background(Color.accentGold)
                    .foregroundColor(.white)
                    .cornerRadius(TDRadius.md)
            }
        }
        .padding()
    }
    
    private var conversationList: some View {
        List {
            ForEach(chatManager.myConversations) { conversation in
                NavigationLink {
                    ChatDetailView(conversation: conversation)
                } label: {
                    ConversationRow(conversation: conversation)
                }
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Conversation Row
struct ConversationRow: View {
    let conversation: SupportConversation
    @StateObject private var chatManager = SupportChatManager.shared
    
    private var unreadCount: Int {
        let messages = chatManager.messagesFor(conversationId: conversation.id)
        guard let currentUser = UserManager.shared.currentUser else { return 0 }
        return messages.filter { !$0.isRead && $0.senderId != currentUser.id }.count
    }
    
    var body: some View {
        HStack(spacing: TDSpacing.md) {
            // Status Icon
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Image(systemName: conversation.status.icon)
                    .foregroundColor(statusColor)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.subject)
                        .font(TDTypography.body)
                        .fontWeight(unreadCount > 0 ? .bold : .regular)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(conversation.lastMessageAt.formatted(date: .abbreviated, time: .omitted))
                        .font(TDTypography.caption2)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text(conversation.status.rawValue)
                        .font(TDTypography.caption1)
                        .foregroundColor(statusColor)
                    
                    Spacer()
                    
                    if unreadCount > 0 {
                        Text("\(unreadCount)")
                            .font(TDTypography.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.accentGold)
                            .cornerRadius(10)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var statusColor: Color {
        switch conversation.status {
        case .open: return .orange
        case .inProgress: return .blue
        case .resolved: return .green
        case .closed: return .gray
        }
    }
}

// MARK: - New Conversation View
struct NewConversationView: View {
    @StateObject private var chatManager = SupportChatManager.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var subject = ""
    @State private var message = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section(T("Betreff")) {
                    TextField(T("Worum geht es?"), text: $subject)
                }
                
                Section(T("Nachricht")) {
                    TextEditor(text: $message)
                        .frame(minHeight: 150)
                }
                
                Section {
                    Button {
                        Task { await sendMessage() }
                    } label: {
                        HStack {
                            Spacer()
                            if isLoading {
                                ProgressView()
                            } else {
                                Text(T("Nachricht senden"))
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(subject.isEmpty || message.isEmpty || isLoading)
                    .listRowBackground(Color.accentGold)
                    .foregroundColor(.white)
                }
            }
            .navigationTitle(T("Neue Anfrage"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(T("Abbrechen")) { dismiss() }
                }
            }
        }
    }
    
    private func sendMessage() async {
        isLoading = true
        defer { isLoading = false }
        
        _ = await chatManager.createConversation(subject: subject, initialMessage: message)
        dismiss()
    }
}

// MARK: - Chat Detail View
struct ChatDetailView: View {
    let conversation: SupportConversation
    @StateObject private var chatManager = SupportChatManager.shared
    @StateObject private var userManager = UserManager.shared
    
    @State private var newMessage = ""
    @State private var isLoading = false
    
    var messages: [SupportMessage] {
        chatManager.messagesFor(conversationId: conversation.id)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: TDSpacing.sm) {
                        ForEach(messages) { message in
                            MessageBubble(message: message, isOwnMessage: message.senderId == userManager.currentUser?.id)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _, _ in
                    if let lastMessage = messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Status Bar (für Admin)
            if userManager.isAdmin {
                statusBar
            }
            
            // Input
            inputBar
        }
        .navigationTitle(conversation.subject)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await chatManager.markAsRead(conversationId: conversation.id)
        }
    }
    
    private var statusBar: some View {
        HStack {
            Text(T("Status:"))
                .font(TDTypography.caption1)
                .foregroundColor(.secondary)
            
            Menu {
                ForEach([SupportConversation.ConversationStatus.open,
                         .inProgress, .resolved, .closed], id: \.self) { status in
                    Button {
                        Task {
                            _ = await chatManager.updateStatus(conversationId: conversation.id, status: status)
                        }
                    } label: {
                        Label(status.rawValue, systemImage: status.icon)
                    }
                }
            } label: {
                HStack {
                    Image(systemName: conversation.status.icon)
                    Text(conversation.status.rawValue)
                }
                .font(TDTypography.caption1)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(TDRadius.sm)
            }
            
            Spacer()
            
            if conversation.assignedAdminId == nil {
                Button(T("Mir zuweisen")) {
                    Task {
                        _ = await chatManager.assignToSelf(conversationId: conversation.id)
                    }
                }
                .font(TDTypography.caption1)
                .foregroundColor(Color.accentGold)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.05))
    }
    
    private var inputBar: some View {
        HStack(spacing: TDSpacing.sm) {
            TextField(T("Nachricht schreiben..."), text: $newMessage, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(20)
                .lineLimit(1...5)
            
            Button {
                Task { await sendMessage() }
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(newMessage.isEmpty ? Color.gray : Color.accentGold)
                    .clipShape(Circle())
            }
            .disabled(newMessage.isEmpty || isLoading)
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    private func sendMessage() async {
        let content = newMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        
        isLoading = true
        newMessage = ""
        
        _ = await chatManager.sendMessage(conversationId: conversation.id, content: content)
        
        isLoading = false
    }
}

// MARK: - Message Bubble
struct MessageBubble: View {
    let message: SupportMessage
    let isOwnMessage: Bool
    
    var body: some View {
        HStack {
            if isOwnMessage { Spacer(minLength: 60) }
            
            VStack(alignment: isOwnMessage ? .trailing : .leading, spacing: 4) {
                if !isOwnMessage {
                    HStack(spacing: 4) {
                        Text(message.senderName)
                            .font(TDTypography.caption1)
                            .fontWeight(.medium)
                        
                        if message.senderGroup.isAdmin {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                    }
                    .foregroundColor(.secondary)
                }
                
                Text(message.content)
                    .font(TDTypography.body)
                    .padding(12)
                    .background(isOwnMessage ? Color.accentGold : Color.gray.opacity(0.15))
                    .foregroundColor(isOwnMessage ? .white : .primary)
                    .cornerRadius(16)
                
                Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(TDTypography.caption2)
                    .foregroundColor(.secondary)
            }
            
            if !isOwnMessage { Spacer(minLength: 60) }
        }
    }
}

// MARK: - Admin Support Overview
struct AdminSupportView: View {
    @StateObject private var chatManager = SupportChatManager.shared
    @State private var filterStatus: SupportConversation.ConversationStatus?
    
    var filteredConversations: [SupportConversation] {
        if let status = filterStatus {
            return chatManager.conversations.filter { $0.status == status }
        }
        return chatManager.conversations
    }
    
    var body: some View {
        List {
            // Stats
            Section {
                HStack(spacing: TDSpacing.md) {
                    StatBadge(count: chatManager.conversations.filter { $0.status == .open }.count, title: "Offen", color: .orange)
                    StatBadge(count: chatManager.conversations.filter { $0.status == .inProgress }.count, title: "In Arbeit", color: .blue)
                    StatBadge(count: chatManager.conversations.filter { $0.status == .resolved }.count, title: "Gelöst", color: .green)
                }
            }
            
            // Filter
            Section {
                Picker("Filter", selection: $filterStatus) {
                    Text(T("Alle")).tag(nil as SupportConversation.ConversationStatus?)
                    Text(T("Offen")).tag(SupportConversation.ConversationStatus.open as SupportConversation.ConversationStatus?)
                    Text(T("In Arbeit")).tag(SupportConversation.ConversationStatus.inProgress as SupportConversation.ConversationStatus?)
                    Text(T("Gelöst")).tag(SupportConversation.ConversationStatus.resolved as SupportConversation.ConversationStatus?)
                }
                .pickerStyle(.segmented)
            }
            
            // Conversations
            Section {
                ForEach(filteredConversations.sorted { $0.lastMessageAt > $1.lastMessageAt }) { conversation in
                    NavigationLink {
                        ChatDetailView(conversation: conversation)
                    } label: {
                        AdminConversationRow(conversation: conversation)
                    }
                }
            } header: {
                Text(T("Anfragen (%@)", "\(filteredConversations.count)"))
            }
        }
        .navigationTitle(T("Support-Anfragen"))
        .refreshable {
            await chatManager.loadFromCloud()
        }
    }
}

struct AdminConversationRow: View {
    let conversation: SupportConversation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(conversation.userName)
                    .font(TDTypography.body)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(conversation.status.rawValue)
                    .font(TDTypography.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(statusColor.opacity(0.2))
                    .foregroundColor(statusColor)
                    .cornerRadius(4)
            }
            
            Text(conversation.subject)
                .font(TDTypography.subheadline)
                .foregroundColor(.secondary)
            
            Text(conversation.lastMessageAt.formatted())
                .font(TDTypography.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    private var statusColor: Color {
        switch conversation.status {
        case .open: return .orange
        case .inProgress: return .blue
        case .resolved: return .green
        case .closed: return .gray
        }
    }
}

#Preview {
    SupportView()
}
