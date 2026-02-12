import SwiftUI

struct SupportDashboardView: View {
    @StateObject private var chatManager = SupportChatManager.shared
    var openConvs: [SupportConversation] { chatManager.conversations.filter { $0.status == .open } }
    var body: some View {
        List {
            Section { HStack { SupportStat(title: "Offen", count: openConvs.count, color: .orange) } }
            if !openConvs.isEmpty {
                Section(T("Offene Anfragen")) { ForEach(openConvs) { c in NavigationLink(destination: SupportChatDetail(id: c.id)) { SupportRow(c: c) } } }
            }
            if chatManager.conversations.isEmpty { ContentUnavailableView("Keine Anfragen", systemImage: "checkmark.circle") }
        }
        .navigationTitle(T("Support"))
        .refreshable { await chatManager.loadFromCloud() }
    }
}

struct SupportStat: View {
    let title: String; let count: Int; let color: Color
    var body: some View { VStack { Text("\(count)").font(.title2).foregroundColor(color); Text(title).font(.caption2) }.frame(maxWidth: .infinity).padding(8).background(color.opacity(0.1)).cornerRadius(8) }
}

struct SupportRow: View {
    let c: SupportConversation
    var body: some View { VStack(alignment: .leading) { Text(c.userName).font(.headline); Text(c.subject).font(.caption).foregroundColor(.secondary) } }
}

struct SupportChatDetail: View {
    let id: String
    @StateObject private var chatManager = SupportChatManager.shared
    @StateObject private var userManager = UserManager.shared
    @State private var msg = ""
    var conversation: SupportConversation? { chatManager.conversations.first { $0.id == id } }
    var messages: [SupportMessage] { chatManager.messages[id] ?? [] }
    var body: some View {
        VStack(spacing: 0) {
            ScrollView { LazyVStack { ForEach(messages) { m in ChatBubble(m: m, isMine: m.senderId == userManager.currentUser?.id) } }.padding() }
            Divider()
            HStack { TextField(T("Nachricht"), text: $msg).textFieldStyle(.roundedBorder)
                Button { Task { if await chatManager.sendMessage(conversationId: id, content: msg) { msg = "" } } } label: { Image(systemName: "paperplane.fill") }.disabled(msg.isEmpty)
            }.padding()
        }
        .navigationTitle(conversation?.subject ?? "Chat")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu { Button { Task { await setStatus(.inProgress) } } label: { Label(T("In Bearbeitung"), systemImage: "clock") }
                    Button { Task { await setStatus(.resolved) } } label: { Label(T("Gelöst"), systemImage: "checkmark") }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
    }
    private func setStatus(_ status: SupportConversation.ConversationStatus) async { _ = await chatManager.updateStatus(conversationId: id, status: status) }
}

struct ChatBubble: View {
    let m: SupportMessage; let isMine: Bool
    var body: some View { HStack { if isMine { Spacer() }; Text(m.content).padding(8).background(isMine ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2)).cornerRadius(8); if !isMine { Spacer() } } }
}

struct SupportUserListView: View {
    @StateObject private var userManager = UserManager.shared
    @State private var search = ""
    @State private var selectedId: String?
    @State private var showDetail = false
    var users: [AppUser] { userManager.allUsers.filter { $0.group == .user || $0.group == .premium }.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) } }
    var body: some View {
        List { ForEach(users) { u in Button { selectedId = u.id; showDetail = true } label: { HStack { Text(u.name); Spacer(); Text("\(u.unlockedCourseIds?.count ?? 0) Kurse").foregroundColor(.secondary) } } } }
        .searchable(text: $search).navigationTitle(T("User")).sheet(isPresented: $showDetail) { if let id = selectedId { SupportUserDetail(userId: id) } }
    }
}

struct SupportUserDetail: View {
    let userId: String
    @StateObject private var userManager = UserManager.shared
    @StateObject private var settingsManager = AppSettingsManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var unlocked: Set<String> = []
    @State private var reason = ""; @State private var showReason = false; @State private var pendingId: String?; @State private var isAdd = true
    var user: AppUser? { userManager.allUsers.first { $0.id == userId } }
    var body: some View {
        NavigationStack {
            if let u = user {
                List { Section { Text(u.name).font(.headline); Text(u.email).foregroundColor(.secondary) }
                    Section(T("Kurse")) { ForEach(MockData.courses) { c in HStack { Text(c.title); Spacer(); Button { pendingId = c.id; isAdd = !unlocked.contains(c.id); showReason = true } label: { Image(systemName: unlocked.contains(c.id) ? "checkmark.circle.fill" : "circle").foregroundColor(unlocked.contains(c.id) ? .green : .gray) } } } }
                }.navigationTitle(T("User")).toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button(T("Fertig")) { dismiss() } } }
                .onAppear { unlocked = Set(u.unlockedCourseIds ?? []) }
                .alert(T("Begründung"), isPresented: $showReason) { TextField(T("Grund"), text: $reason); Button(T("Abbrechen"), role: .cancel) { reason = "" }; Button(T("OK")) { Task { await apply() } } }
            }
        }
    }
    private func apply() async { guard let id = pendingId, let u = user else { return }; if isAdd { unlocked.insert(id) } else { unlocked.remove(id) }
        await settingsManager.logSupportChange(targetUserId: userId, targetUserName: u.name, changeType: isAdd ? .courseUnlocked : .courseLocked, description: reason.isEmpty ? "-" : reason, oldValue: nil, newValue: nil)
        _ = await userManager.setUnlockedCourses(userId: userId, courseIds: Array(unlocked)); reason = ""; pendingId = nil }
}
