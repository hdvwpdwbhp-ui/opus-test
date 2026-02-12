//
//  LiveClassChatView.swift
//  Tanzen mit Tatiana Drexler
//

import SwiftUI

struct LiveClassChatView: View {
    let eventId: String
    @StateObject private var liveManager = LiveClassManager.shared
    @StateObject private var userManager = UserManager.shared
    @State private var message = ""
    @State private var selectedUser: AdminUserSelection?

    private var messages: [LiveClassChatMessage] {
        liveManager.chatMessages[eventId] ?? []
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(messages) { msg in
                            LiveClassChatBubble(
                                message: msg,
                                onUserTap: {
                                    guard userManager.isAdmin else { return }
                                    selectedUser = AdminUserSelection(id: msg.userId)
                                }
                            )
                            .contextMenu {
                                if userManager.currentUser?.group.isSupport == true {
                                    Button(T("Nachricht entfernen"), role: .destructive) {
                                        Task { _ = await liveManager.deleteChatMessage(eventId: eventId, messageId: msg.id) }
                                    }
                                }
                            }
                            .id(msg.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _, _ in
                    if let last = messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }

            Divider()

            HStack(spacing: 8) {
                TextField(T("Nachricht..."), text: $message)
                    .textFieldStyle(.roundedBorder)
                Button {
                    Task {
                        let text = message.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !text.isEmpty else { return }
                        if await liveManager.sendChatMessage(eventId: eventId, content: text) {
                            message = ""
                        }
                    }
                } label: {
                    Image(systemName: "paperplane.fill")
                }
            }
            .padding()
        }
        .sheet(item: $selectedUser) { selection in
            AdminUserDetailLoaderView(userId: selection.id)
        }
        .onAppear {
            liveManager.startListeningToChat(eventId: eventId)
        }
        .onDisappear {
            liveManager.stopListeningToChat(eventId: eventId)
        }
    }
}

private struct AdminUserSelection: Identifiable {
    let id: String
}

struct LiveClassChatBubble: View {
    let message: LiveClassChatMessage
    let onUserTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button(action: onUserTap) {
                Text(message.userName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            if message.isDeleted {
                Text(T("Nachricht entfernt"))
                    .font(.caption)
                    .italic()
                    .foregroundColor(.secondary)
            } else {
                Text(message.content)
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
