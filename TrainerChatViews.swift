import SwiftUI

struct TrainerChatInboxView: View {
    @StateObject private var chatManager = TrainerChatManager.shared
    @StateObject private var userManager = UserManager.shared

    var body: some View {
        NavigationStack {
            ZStack {
                TDGradients.mainBackground.ignoresSafeArea()

                if chatManager.conversations.isEmpty {
                    ContentUnavailableView("Keine Nachrichten", systemImage: "bubble.left.and.bubble.right", description: Text(T("Noch keine Anfragen von Schülern")))
                } else {
                    List {
                        ForEach(chatManager.conversations) { convo in
                            NavigationLink(destination: TrainerChatDetailView(conversation: convo)) {
                                TrainerChatRow(conversation: convo)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(T("Trainer-Postfach"))
            .task {
                if let trainerId = userManager.currentUser?.id {
                    await chatManager.loadConversationsForTrainer(trainerId: trainerId)
                }
            }
        }
    }
}

struct TrainerChatRow: View {
    let conversation: TrainerChatConversation

    var body: some View {
        HStack(spacing: TDSpacing.md) {
            ZStack {
                Circle()
                    .fill(Color.accentGold.opacity(0.2))
                    .frame(width: 44, height: 44)
                Text(String(conversation.userName.prefix(1)))
                    .font(.title3)
                    .foregroundColor(Color.accentGold)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(conversation.userName)
                    .font(TDTypography.body)
                Text(conversation.lastMessageAt.formatted(date: .abbreviated, time: .shortened))
                    .font(TDTypography.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 6)
    }
}

struct TrainerChatDetailView: View {
    let conversation: TrainerChatConversation
    @StateObject private var chatManager = TrainerChatManager.shared
    @StateObject private var userManager = UserManager.shared
    @State private var message = ""

    private var messages: [TrainerChatMessage] {
        chatManager.messages[conversation.id] ?? []
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: TDSpacing.sm) {
                        ForEach(messages) { msg in
                            TrainerChatBubble(message: msg, isMine: msg.senderId == userManager.currentUser?.id)
                                .id(msg.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _, _ in
                    if let last = messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            Divider()

            HStack(spacing: TDSpacing.sm) {
                TextField(T("Nachricht..."), text: $message)
                    .textFieldStyle(.roundedBorder)

                Button {
                    Task {
                        let text = message.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !text.isEmpty else { return }
                        if await chatManager.sendMessage(conversation: conversation, content: text) {
                            message = ""
                        }
                    }
                } label: {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(Color.accentGold)
                }
                .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
        .navigationTitle(conversation.userName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            chatManager.startListening(conversationId: conversation.id)
        }
        .onDisappear {
            chatManager.stopListening(conversationId: conversation.id)
        }
    }
}

struct TrainerChatBubble: View {
    let message: TrainerChatMessage
    let isMine: Bool

    var body: some View {
        VStack(alignment: isMine ? .trailing : .leading, spacing: 4) {
            Text(message.content)
                .padding(10)
                .background(isMine ? Color.accentGold.opacity(0.2) : Color.gray.opacity(0.1))
                .cornerRadius(10)

            Text(message.createdAt.formatted(date: .omitted, time: .shortened))
                .font(TDTypography.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: isMine ? .trailing : .leading)
    }
}
