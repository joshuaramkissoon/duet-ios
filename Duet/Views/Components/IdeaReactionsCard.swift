import SwiftUI
import FirebaseAuth

struct IdeaReactionsCard: View {
    private let defaultEmojis = ["👍","❤️","😂","🔥","💡","👎"]
    let ideaId: String
    let groupId: String?
    
    @StateObject private var viewModel: ReactionsViewModel
    @State private var showEmojiSelector: Bool = false
    @State private var reactedUsers: [User] = []
    
    init(ideaId: String, groupId: String? = nil) {
        self.ideaId = ideaId
        self.groupId = groupId
        _viewModel = StateObject(wrappedValue: ReactionsViewModel(ideaId: ideaId, groupId: groupId))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Show different layouts based on whether there are reactions
            if hasActiveReactions {
                // Full layout with reactions
                fullReactionsLayout
            } else {
                // Compact empty state
                emptyStateLayout
            }
            
            // Emoji selection overlay (shown for both states)
            if showEmojiSelector {
                emojiSelectionView
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.9).combined(with: .opacity),
                        removal: .scale(scale: 0.9).combined(with: .opacity)
                    ))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
        )
        .animation(.easeInOut(duration: 0.25), value: showEmojiSelector)
        .animation(.easeInOut(duration: 0.3), value: hasActiveReactions)
        .onChange(of: firstReactedUserIds) { newUserIds in
            fetchUsersForReactions(userIds: newUserIds)
        }
        .onAppear {
            // Fetch users on initial load if there are reactions
            if !firstReactedUserIds.isEmpty {
                fetchUsersForReactions(userIds: firstReactedUserIds)
            }
        }
    }
    
    // MARK: - Layout Views
    
    private var emptyStateLayout: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header label
            Text("Reactions")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Divider()
            
            // Centered empty state content
            VStack(spacing: 12) {
                Text("Be the first to react to this idea!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                // Centered React button
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showEmojiSelector.toggle()
                    }
                    HapticFeedbacks.soft()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "face.smiling")
                            .font(.system(size: 16, weight: .medium))
                        Text("React")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.appPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.appPrimary.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(showEmojiSelector ? Color.appPrimary : Color.clear, lineWidth: 1.5)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }
    
    private var fullReactionsLayout: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header label
            Text("Reactions")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            // Reactions row with user avatars
            HStack(spacing: 12) {
                // Active reactions
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(activeEmojis, id: \.self) { emoji in
                            reactionCapsuleWithCount(for: emoji)
                        }
                    }
                    .padding(.horizontal, 4)
                }
                
                Spacer()
                
                // User avatars (first few users who reacted)
                if !reactedUsers.isEmpty {
                    userAvatarsStack
                }
                
                // Add reaction button (+) - only show if user hasn't reacted to anything
                if !userHasAnyReaction {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showEmojiSelector.toggle()
                        }
                        HapticFeedbacks.soft()
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.appPrimary)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(Color.appPrimary.opacity(0.1))
                                    .overlay(
                                        Circle()
                                            .stroke(showEmojiSelector ? Color.appPrimary : Color.clear, lineWidth: 1.5)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var emojiSelectionView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(defaultEmojis, id: \.self) { emoji in
                    Button {
                        viewModel.toggleReaction(emoji)
                        HapticFeedbacks.soft()
                        
                        withAnimation(.easeOut(duration: 0.2)) {
                            showEmojiSelector = false
                        }
                    } label: {
                        Text(emoji)
                            .font(.title2)
                            .frame(width: 44, height: 44)
                            .background(Color.appPrimaryLightBackground)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
    
    private var userAvatarsStack: some View {
        HStack(spacing: -8) {
            ForEach(Array(reactedUsers.prefix(3).enumerated()), id: \.offset) { index, user in
                ProfileImage(user: user, diam: 24)
                    .overlay(
                        Circle()
                            .stroke(Color(.systemBackground), lineWidth: 2)
                    )
                    .zIndex(Double(3 - index))
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func reactionCapsuleWithCount(for emoji: String) -> some View {
        let count = viewModel.count(for: emoji)
        let reacted = viewModel.userHasReacted(emoji)
        
        return Button {
            viewModel.toggleReaction(emoji)
            HapticFeedbacks.soft()
        } label: {
            HStack(spacing: 4) {
                Text(emoji)
                    .font(.subheadline)
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .fontWeight(.medium)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(reacted ? Color.appPrimary.opacity(0.2) : Color.gray.opacity(0.1))
            .foregroundColor(reacted ? .appPrimary : .primary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(reacted ? Color.appPrimary.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut, value: count)
        .animation(.easeInOut, value: reacted)
    }
    
    // MARK: - Helper Methods
    
    private func fetchUsersForReactions(userIds: [String]) {
        guard !userIds.isEmpty else {
            reactedUsers = []
            return
        }
        
        NetworkClient.shared.getUsers(with: userIds) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let users):
                    self.reactedUsers = users
                case .failure(let error):
                    print("❌ Failed to fetch users for reactions: \(error)")
                    self.reactedUsers = []
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var hasActiveReactions: Bool {
        !viewModel.reactions.isEmpty && viewModel.reactions.values.contains { !$0.isEmpty }
    }
    
    private var activeEmojis: [String] {
        viewModel.reactions.compactMap { emoji, users in
            users.isEmpty ? nil : emoji
        }.sorted()
    }
    
    private var firstReactedUserIds: [String] {
        let allUserIds = viewModel.reactions.values.flatMap { $0 }
        return Array(Set(allUserIds)).sorted()
    }
    
    // Check if current user has reacted to any emoji
    private var userHasAnyReaction: Bool {
        guard let uid = Auth.auth().currentUser?.uid else { return false }
        return viewModel.reactions.values.contains { users in
            users.contains(uid)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        IdeaReactionsCard(ideaId: "mock1")
        IdeaReactionsCard(ideaId: "mock2")
    }
    .padding()
    .background(Color.appBackground)
} 
