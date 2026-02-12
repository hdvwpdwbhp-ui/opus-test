//
//  CommentsView.swift
//  Tanzen mit Tatiana Drexler
//
//  Kommentare unter Videos mit Moderation
//

import SwiftUI

struct CommentsView: View {
    let lessonId: String
    let courseId: String
    
    @StateObject private var commentManager = CommentManager.shared
    @StateObject private var userManager = UserManager.shared
    
    @State private var newComment = ""
    @State private var isLoading = false
    @State private var showLoginAlert = false
    
    var comments: [VideoComment] {
        commentManager.commentsFor(lessonId: lessonId)
    }
    
    var canModerate: Bool {
        userManager.canModerateCourse(courseId)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(T("Kommentare"))
                    .font(TDTypography.headline)
                
                Text("(\(comments.filter { !$0.isHidden }.count))")
                    .font(TDTypography.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if canModerate {
                    let hiddenCount = commentManager.hiddenCommentsFor(courseId: courseId).filter { $0.lessonId == lessonId }.count
                    if hiddenCount > 0 {
                        Text("\(hiddenCount) versteckt")
                            .font(TDTypography.caption1)
                            .foregroundColor(.orange)
                    }
                }
            }
            .padding()
            
            Divider()
            
            // Kommentarliste
            if comments.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: TDSpacing.md) {
                        ForEach(comments) { comment in
                            CommentRow(comment: comment, courseId: courseId)
                        }
                    }
                    .padding()
                }
            }
            
            Divider()
            
            // Eingabe
            inputSection
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: TDSpacing.md) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text(T("Noch keine Kommentare"))
                .font(TDTypography.subheadline)
                .foregroundColor(.secondary)
            
            Text(T("Sei der Erste!"))
                .font(TDTypography.caption1)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var inputSection: some View {
        VStack(spacing: 8) {
            if userManager.currentUser == nil {
                Button {
                    showLoginAlert = true
                } label: {
                    Text(T("Melde dich an um zu kommentieren"))
                        .font(TDTypography.subheadline)
                        .foregroundColor(Color.accentGold)
                }
                .padding()
            } else {
                HStack(spacing: TDSpacing.sm) {
                    TextField(T("Kommentar schreiben..."), text: $newComment, axis: .vertical)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(20)
                        .lineLimit(1...4)
                    
                    Button {
                        Task { await postComment() }
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(newComment.isEmpty ? Color.gray : Color.accentGold)
                            .clipShape(Circle())
                    }
                    .disabled(newComment.isEmpty || isLoading)
                }
                .padding()
            }
        }
        .background(Color(.systemBackground))
        .alert(T("Anmelden erforderlich"), isPresented: $showLoginAlert) {
            Button(T("OK"), role: .cancel) { }
        } message: {
            Text(T("Du musst angemeldet sein um Kommentare zu schreiben."))
        }
    }
    
    private func postComment() async {
        let content = newComment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        
        isLoading = true
        newComment = ""
        
        _ = await commentManager.addComment(lessonId: lessonId, courseId: courseId, content: content)
        
        isLoading = false
    }
}

// MARK: - Comment Row
struct CommentRow: View {
    let comment: VideoComment
    let courseId: String
    
    @StateObject private var commentManager = CommentManager.shared
    @StateObject private var userManager = UserManager.shared
    
    @State private var showActions = false
    @State private var showDeleteConfirm = false
    @State private var showHideDialog = false
    @State private var hideReason = ""
    @State private var isEditing = false
    @State private var editedContent = ""
    @State private var selectedUser: AdminUserSelection?
    
    var isOwn: Bool {
        comment.userId == userManager.currentUser?.id
    }
    
    var canModerate: Bool {
        userManager.canModerateCourse(courseId)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Hidden Warning (für Moderatoren)
            if comment.isHidden {
                HStack {
                    Image(systemName: "eye.slash")
                    Text(T("Versteckt: %@", comment.hiddenReason ?? T("Kein Grund")))
                    
                    Spacer()
                    
                    Button(T("Einblenden")) {
                        Task {
                            _ = await commentManager.unhideComment(commentId: comment.id)
                        }
                    }
                    .font(TDTypography.caption2)
                }
                .font(TDTypography.caption2)
                .foregroundColor(.orange)
                .padding(8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Header
            HStack {
                // Avatar
                ZStack {
                    Circle()
                        .fill(groupColor.opacity(0.2))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: comment.userGroup.icon)
                        .font(.system(size: 14))
                        .foregroundColor(groupColor)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Button {
                            guard userManager.isAdmin else { return }
                            selectedUser = AdminUserSelection(id: comment.userId)
                        } label: {
                            Text(comment.userName)
                                .font(TDTypography.subheadline)
                                .fontWeight(.medium)
                        }
                        .buttonStyle(.plain)
                        
                        if comment.userGroup.isTrainer {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Text(comment.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(TDTypography.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Actions Menu
                if isOwn || canModerate {
                    Menu {
                        if isOwn {
                            Button {
                                editedContent = comment.content
                                isEditing = true
                            } label: {
                                Label(T("Bearbeiten"), systemImage: "pencil")
                            }
                        }
                        
                        if isOwn || canModerate {
                            Button(role: .destructive) {
                                showDeleteConfirm = true
                            } label: {
                                Label(T("Löschen"), systemImage: "trash")
                            }
                        }
                        
                        if canModerate && !isOwn && !comment.isHidden {
                            Button {
                                showHideDialog = true
                            } label: {
                                Label(T("Verstecken"), systemImage: "eye.slash")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.secondary)
                            .padding(8)
                    }
                }
            }
            
            // Content
            if isEditing {
                VStack(spacing: 8) {
                    TextEditor(text: $editedContent)
                        .frame(minHeight: 60)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    
                    HStack {
                        Button(T("Abbrechen")) {
                            isEditing = false
                        }
                        .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button(T("Speichern")) {
                            Task {
                                _ = await commentManager.editComment(commentId: comment.id, newContent: editedContent)
                                isEditing = false
                            }
                        }
                        .foregroundColor(Color.accentGold)
                    }
                    .font(TDTypography.subheadline)
                }
            } else {
                Text(comment.content)
                    .font(TDTypography.body)
                
                if comment.editedAt != nil {
                    Text(T("(bearbeitet)"))
                        .font(TDTypography.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Actions
            HStack(spacing: TDSpacing.lg) {
                // Like Button
                Button {
                    Task {
                        _ = await commentManager.toggleLike(commentId: comment.id)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: commentManager.hasLiked(commentId: comment.id) ? "heart.fill" : "heart")
                            .foregroundColor(commentManager.hasLiked(commentId: comment.id) ? .red : .secondary)
                        
                        if comment.likes > 0 {
                            Text("\(comment.likes)")
                                .font(TDTypography.caption1)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .disabled(userManager.currentUser == nil)
                
                Spacer()
            }
        }
        .padding()
        .background(comment.isHidden ? Color.orange.opacity(0.05) : Color.gray.opacity(0.05))
        .cornerRadius(TDRadius.md)
        .alert(T("Kommentar löschen?"), isPresented: $showDeleteConfirm) {
            Button(T("Abbrechen"), role: .cancel) { }
            Button(T("Löschen"), role: .destructive) {
                Task {
                    _ = await commentManager.deleteComment(commentId: comment.id)
                }
            }
        }
        .alert(T("Kommentar verstecken"), isPresented: $showHideDialog) {
            TextField(T("Grund (optional)"), text: $hideReason)
            Button(T("Abbrechen"), role: .cancel) { }
            Button(T("Verstecken")) {
                Task {
                    _ = await commentManager.hideComment(commentId: comment.id, reason: hideReason)
                    hideReason = ""
                }
            }
        } message: {
            Text(T("Gib optional einen Grund an, warum der Kommentar versteckt wird."))
        }
        .sheet(item: $selectedUser) { selection in
            AdminUserDetailLoaderView(userId: selection.id)
        }
    }
    
    private var groupColor: Color {
        switch comment.userGroup {
        case .admin: return .red
        case .support: return .purple
        case .trainer: return .blue
        case .premium: return .orange
        case .user: return .gray
        }
    }
}

private struct AdminUserSelection: Identifiable {
    let id: String
}

// MARK: - Comments Section for Video Player
struct CommentsSection: View {
    let lessonId: String
    let courseId: String
    
    @State private var isExpanded = false
    @StateObject private var commentManager = CommentManager.shared
    
    var commentCount: Int {
        commentManager.commentCountFor(lessonId: lessonId)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Toggle Button
            Button {
                withAnimation {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "bubble.left.and.bubble.right")
                    Text(T("Kommentare"))
                    Text("(\(commentCount))")
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                }
                .font(TDTypography.subheadline)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(TDRadius.md)
            }
            .foregroundColor(.primary)
            
            // Comments
            if isExpanded {
                CommentsView(lessonId: lessonId, courseId: courseId)
                    .frame(maxHeight: 400)
            }
        }
    }
}

#Preview {
    CommentsView(lessonId: "lesson_001_01", courseId: "course_001")
}
