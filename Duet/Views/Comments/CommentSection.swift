import SwiftUI
import FirebaseAuth

struct CommentSection: View {
    let ideaId: String
    let groupId: String?
    @StateObject private var viewModel: CommentsViewModel
    @EnvironmentObject private var authVM: AuthenticationViewModel

    @State private var isExpanded: Bool = false
    @State private var replyingTo: Comment? = nil
    @State private var replyText: String = ""
    @State private var expandedReplies: Set<String> = []
    @State private var keyboardHeight: CGFloat = 0
    
    @FocusState private var isTextFieldFocused: Bool

    init(ideaId: String, groupId: String? = nil) {
        self.ideaId = ideaId
        self.groupId = groupId
        _viewModel = StateObject(wrappedValue: CommentsViewModel(ideaId: ideaId, groupId: groupId))
    }

    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                // Header section
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Comments")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        if viewModel.hasTopLevelComments {
                            Button(action: {
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                    isExpanded.toggle()
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Text(isExpanded ? "Less" : "More")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.appPrimary)
                                    
                                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.appPrimary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.appPrimary.opacity(0.1))
                                .cornerRadius(20)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 16)
                    
                    Divider()
                        .padding(.horizontal, 16)
                }

                // Comments content
                if !isExpanded {
                    // Collapsed view - show comments without "Overview" title
                    CommentsCollapsedSection(
                        comments: viewModel.topLevelComments,
                        replies: viewModel.replies,
                        onReply: { comment in
                            handleReply(to: comment)
                        },
                        ideaId: ideaId,
                        groupId: groupId
                    )
                    .padding(.horizontal, 16)
                } else {
                    // Expanded content
                    VStack(spacing: 0) {
                        if viewModel.hasTopLevelComments {
                            Divider()
                                .padding(.horizontal, 16)
                                .transition(.opacity)
                            
                            CommentsExpandedSection(
                                comments: viewModel.topLevelComments,
                                replies: viewModel.replies,
                                expandedReplies: $expandedReplies,
                                onReply: { comment in
                                    handleReply(to: comment)
                                },
                                ideaId: ideaId,
                                groupId: groupId
                            )
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .move(edge: .bottom).combined(with: .opacity)
                            ))
                        } else {
                            // Empty state for expanded view
                            EmptyCommentsView()
                                .padding(.horizontal, 16)
                                .padding(.vertical, 32)
                        }
                    }
                }

                // Input section
                ModernCommentInputSection(
                    newCommentText: $viewModel.newCommentText,
                    replyText: $replyText,
                    replyingTo: $replyingTo,
                    currentUser: authVM.currentUser,
                    isTextFieldFocused: $isTextFieldFocused,
                    onSend: { text, parentId in
                        if let parentId = parentId {
                            viewModel.addComment(withText: text, parentId: parentId) {
                                replyingTo = nil
                                replyText = ""
                            }
                        } else {
                            viewModel.addComment {
                                replyingTo = nil
                                replyText = ""
                            }
                        }
                    }
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .id("commentInput") // ID for ScrollViewReader
            }
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
            .onChange(of: viewModel.hasTopLevelComments) { _, hasComments in
                // Reset expanded state when top-level comments become empty
                if !hasComments && isExpanded {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        isExpanded = false
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
                if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                    keyboardHeight = keyboardFrame.height
                    
                    // Scroll to input field when keyboard appears
                    if isTextFieldFocused {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo("commentInput", anchor: .bottom)
                        }
                    }
                }
            }
            .onChange(of: isTextFieldFocused) { _, focused in
                if focused {
                    // Delay to ensure keyboard height is updated
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo("commentInput", anchor: .bottom)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helper Functions
    
    private func handleReply(to comment: Comment) {
        // If replying to a reply, find the parent comment instead (max 1 level nesting)
        let targetParentId: String?
        if let parentId = comment.parentCommentId {
            // This is a reply, so find the original parent comment
            targetParentId = parentId
            // Find the parent comment to get the author name
            if let parentComment = viewModel.comments.first(where: { $0.id == parentId }) {
                replyingTo = parentComment
                let displayName = displayName(for: comment)
                replyText = "<mention>\(comment.userId)|\(displayName)</mention> "
            } else {
                replyingTo = comment
                let displayName = displayName(for: comment)
                replyText = "<mention>\(comment.userId)|\(displayName)</mention> "
            }
        } else {
            // This is a top-level comment, reply directly to it
            targetParentId = comment.id
            replyingTo = comment
            let displayName = displayName(for: comment)
            replyText = "<mention>\(comment.userId)|\(displayName)</mention> "
        }
        
        // Store the actual parent ID for the reply
        replyingTo?.id = targetParentId
        isTextFieldFocused = true
    }

    private func displayName(for comment: Comment) -> String {
        if let author = comment.author {
            if comment.userId == Auth.auth().currentUser?.uid {
                return "You"
            }
            return author.displayName
        }
        return String(comment.userId.prefix(6))
    }
    
    private func loadCurrentUser() {
        // No longer needed - using AuthenticationViewModel.currentUser
    }
}

// MARK: - Empty Comments View

struct EmptyCommentsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left")
                .font(.title)
                .foregroundColor(.secondary)
            Text("No comments yet")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            Text("Be the first to comment!")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Collapsed Comments Section

struct CommentsCollapsedSection: View {
    let comments: [Comment]
    let replies: (String) -> [Comment]
    let onReply: (Comment) -> Void
    let ideaId: String
    let groupId: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if comments.isEmpty {
                EmptyCommentsView()
                    .padding(.vertical, 24)
            } else {
                VStack(spacing: 16) {
                    ForEach(Array(comments.prefix(3).enumerated()), id: \.element.id) { index, comment in
                        let commentReplies = replies(comment.id ?? "")
                        
                        VStack(alignment: .leading, spacing: 8) {
                            CommentRow(comment: comment, onReply: onReply, ideaId: self.ideaId, groupId: self.groupId, isCollapsed: true)
                            
                            // Show reply count if any
                            if !commentReplies.isEmpty {
                                HStack {
                                    Text("── \(commentReplies.count) \(commentReplies.count == 1 ? "reply" : "replies")")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                .padding(.leading, 48)
                            }
                        }
                        
                        if index < min(2, comments.count - 1) {
                            Divider()
                                .padding(.leading, 48)
                        }
                    }
                    
                    if comments.count > 3 {
                        let moreCount = comments.count - 3
                        HStack {
                            Spacer()
                            Text("+ \(moreCount) more \(moreCount == 1 ? "comment" : "comments")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding(.bottom, 12)
        .padding(.top, 16)
    }
}

// MARK: - Expanded Comments Section

struct CommentsExpandedSection: View {
    let comments: [Comment]
    let replies: (String) -> [Comment]
    @Binding var expandedReplies: Set<String>
    let onReply: (Comment) -> Void
    let ideaId: String
    let groupId: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(comments) { comment in
                VStack(alignment: .leading, spacing: 12) {
                    CommentRow(comment: comment, onReply: onReply, ideaId: self.ideaId, groupId: self.groupId, isCollapsed: false)
                    
                    // Replies section
                    let commentReplies = replies(comment.id ?? "")
                    if !commentReplies.isEmpty {
                        let isExpanded = expandedReplies.contains(comment.id ?? "")
                        let repliesToShow = isExpanded ? commentReplies : Array(commentReplies.prefix(2))
                        
                        VStack(spacing: 8) {
                            ForEach(repliesToShow) { reply in
                                CommentRow(comment: reply, onReply: onReply, ideaId: self.ideaId, groupId: self.groupId, isCollapsed: false, isReply: true)
                            }
                        }
                        .padding(.leading, 48)
                        
                        // Show more/less replies button
                        if commentReplies.count > 2 {
                            Button(action: {
                                withAnimation(.easeInOut) {
                                    if isExpanded {
                                        expandedReplies.remove(comment.id ?? "")
                                    } else {
                                        expandedReplies.insert(comment.id ?? "")
                                    }
                                }
                            }) {
                                HStack {
                                    Text(isExpanded ? "Hide replies" : "Show \(commentReplies.count - 2) more replies")
                                        .font(.caption)
                                        .foregroundColor(.appPrimary)
                                    Spacer()
                                }
                            }
                            .padding(.leading, 48)
                        }
                    }
                }
                
                if comment.id != comments.last?.id {
                    Divider()
                        .padding(.vertical, 8)
                }
            }
        }
    }
}

// MARK: - Comment Row

struct CommentRow: View {
    let comment: Comment
    let onReply: (Comment) -> Void
    var ideaId: String
    var groupId: String?
    var isCollapsed: Bool = false
    var isReply: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar
            if let author = comment.author {
                ProfileImage(user: author, diam: isReply ? 28 : 36)
            } else {
                Circle()
                    .fill(Color.appPrimary.opacity(0.2))
                    .frame(width: isReply ? 28 : 36, height: isReply ? 28 : 36)
                    .overlay(
                        Text(String(comment.userId.prefix(2)).uppercased())
                            .font(isReply ? .caption2 : .caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.appPrimary)
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(displayName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(relativeDate)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }

                // Comment content with @ highlighting
                Text(attributedContent)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(isCollapsed ? nil : nil) // Show full comment when collapsed
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .background(Color.clear) // Add transparent background
        .contentShape(Rectangle()) // Make entire area tappable
        .contextMenu {
            Button(action: { onReply(comment) }) {
                Label("Reply", systemImage: "arrowshape.turn.up.left")
            }
            if canDelete {
                Button(role: .destructive) {
                    deleteComment()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    private var displayName: String {
        if let author = comment.author {
            if comment.userId == Auth.auth().currentUser?.uid {
                return "You"
            }
            return author.displayName
        }
        return String(comment.userId.prefix(6))
    }

    private var relativeDate: String {
        return timeAgoString(from: comment.createdAt)
    }
    
    private var attributedContent: AttributedString {
        var attributedString = AttributedString("")
        var remainingText = comment.content
        
        // Parse content for mention tags: <mention>userId|displayName</mention>
        while !remainingText.isEmpty {
            if let mentionStart = remainingText.range(of: "<mention>"),
               let mentionEnd = remainingText.range(of: "</mention>", range: mentionStart.upperBound..<remainingText.endIndex) {
                
                // Add text before mention
                let textBeforeMention = String(remainingText[..<mentionStart.lowerBound])
                if !textBeforeMention.isEmpty {
                    attributedString.append(AttributedString(textBeforeMention))
                }
                
                // Extract mention data
                let mentionContent = String(remainingText[mentionStart.upperBound..<mentionEnd.lowerBound])
                let mentionParts = mentionContent.split(separator: "|", maxSplits: 1)
                
                if mentionParts.count >= 2 {
                    // We have userId and displayName
                    let displayName = String(mentionParts[1])
                    var mentionAttrString = AttributedString("@\(displayName)")
                    mentionAttrString.foregroundColor = .appPrimary
                    mentionAttrString.font = .subheadline.weight(.medium)
                    attributedString.append(mentionAttrString)
                } else {
                    // Fallback - just show the content
                    attributedString.append(AttributedString("@\(mentionContent)"))
                }
                
                // Move to text after mention
                remainingText = String(remainingText[mentionEnd.upperBound...])
            } else {
                // No more mentions, add remaining text
                attributedString.append(AttributedString(remainingText))
                break
            }
        }
        
        // Fallback: if no attributed string was built, just return plain content
        if attributedString.characters.count == 0 {
            return AttributedString(comment.content)
        }
        
        return attributedString
    }

    // MARK: - Delete Logic
    private var canDelete: Bool {
        let currentId = SharedUserManager.shared.currentUserId ?? Auth.auth().currentUser?.uid
        return comment.userId == currentId
    }

    private func deleteComment() {
        guard let cid = comment.id else { return }
        CommentsService.shared.deleteComment(ideaId: ideaId, groupId: groupId, commentId: cid) { err in
            if let err = err {
                print("❌ Delete comment error: \(err)")
            }
        }
    }
}

// MARK: - Modern Comment Input Section

struct ModernCommentInputSection: View {
    @Binding var newCommentText: String
    @Binding var replyText: String
    @Binding var replyingTo: Comment?
    let currentUser: User?
    @FocusState.Binding var isTextFieldFocused: Bool
    let onSend: (String, String?) -> Void

    // Raw text binding (contains mention tags if any)
    private var rawText: Binding<String> {
        replyingTo == nil ? $newCommentText : $replyText
    }

    // Visible text binding for the TextField (strips mention tags)
    private var displayText: Binding<String> {
        Binding<String>(
            get: {
                return convertRawToDisplay(rawText.wrappedValue)
            },
            set: { newVal in
                rawText.wrappedValue = convertDisplayToRaw(newVal)
            }
        )
    }

    private var isTextEmpty: Bool {
        rawText.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 12) {
            if let replyingTo = replyingTo {
                replyIndicator(replyingTo)
            }

            HStack(alignment: .center, spacing: 12) {
                profileThumb

                ZStack(alignment: .bottomTrailing) {
                    TextField(replyingTo != nil ? "Write a reply..." : "Add a comment...",
                              text: displayText,
                              axis: .vertical)
                        .font(.subheadline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .padding(.trailing, 50)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(20)
                        .lineLimit(1...6)
                        .focused($isTextFieldFocused)

                    sendButton
                }
            }
        }
        .padding(.top, 16)
    }

    // MARK: - Subviews
    private var profileThumb: some View {
        Group {
            if let user = currentUser {
                ProfileImage(user: user, diam: 32)
            } else {
                Circle()
                    .fill(Color.appPrimary.opacity(0.2))
                    .frame(width: 32, height: 32)
                    .overlay(Text("?").font(.caption).fontWeight(.semibold).foregroundColor(.appPrimary))
            }
        }
    }

    private func replyIndicator(_ comment: Comment) -> some View {
        HStack {
            Image(systemName: "arrowshape.turn.up.left")
                .font(.caption)
                .foregroundColor(.appPrimary)
            Text("Replying to \(replyDisplayName(for: comment))")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Button("Cancel") {
                replyingTo = nil
                replyText = ""
                isTextFieldFocused = false
            }
            .font(.caption)
            .foregroundColor(.appPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.appPrimary.opacity(0.08))
        .cornerRadius(8)
    }

    private var sendButton: some View {
        Button {
            onSend(rawText.wrappedValue, replyingTo?.id)
            isTextFieldFocused = false
        } label: {
            Image(systemName: "paperplane.fill")
                .font(.body.bold())
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(Circle().fill(isTextEmpty ? Color.gray.opacity(0.3) : Color.appPrimary))
                .rotationEffect(.degrees(45))
        }
        .disabled(isTextEmpty)
        .padding(.trailing, 6)
        .padding(.bottom, 6)
        .animation(.easeInOut(duration: 0.2), value: isTextEmpty)
    }

    // MARK: - Conversion Helpers
    private func convertRawToDisplay(_ raw: String) -> String {
        var text = raw
        while let start = text.range(of: "<mention>"),
              let end = text.range(of: "</mention>", range: start.upperBound..<text.endIndex) {
            let tagContent = String(text[start.upperBound..<end.lowerBound])
            let parts = tagContent.split(separator: "|", maxSplits: 1)
            let name = parts.count >= 2 ? String(parts[1]) : tagContent
            text.replaceSubrange(start.lowerBound..<end.upperBound, with: "@\(name)")
        }
        return text
    }

    private func convertDisplayToRaw(_ display: String) -> String {
        guard let replyingTo = replyingTo else { return display }
        let mentionName = displayName(for: replyingTo)
        let mentionTag = "<mention>\(replyingTo.userId)|\(mentionName)</mention>"
        // If the user kept the @mention prefix, include the tag, otherwise treat as plain text
        if display.hasPrefix("@\(mentionName)") {
            var text = display
            text.removeFirst("@\(mentionName)".count)
            return mentionTag + text
        } else {
            // Mention removed – no tag
            return display
        }
    }

    private func displayName(for comment: Comment) -> String {
        if let author = comment.author {
            if comment.userId == Auth.auth().currentUser?.uid { return "You" }
            return author.displayName
        }
        return String(comment.userId.prefix(6))
    }
    
    private func replyDisplayName(for comment: Comment) -> String {
        if let author = comment.author {
            if comment.userId == Auth.auth().currentUser?.uid { return "yourself" }
            return author.displayName
        }
        return String(comment.userId.prefix(6))
    }
}

#Preview {
    CommentSection(ideaId: "mock")
        .padding()
        .background(Color(.systemGroupedBackground))
} 
