import SwiftUI
import FirebaseAuth

struct ReactionBar: View {
    private let defaultEmojis = ["👍","❤️","😂","🔥","💡","👎"]
    let ideaId: String
    let groupId: String?

    @StateObject private var viewModel: ReactionsViewModel
    @State private var showEmojiBar: Bool = false

    init(ideaId: String, groupId: String? = nil) {
        self.ideaId = ideaId
        self.groupId = groupId
        _viewModel = StateObject(wrappedValue: ReactionsViewModel(ideaId: ideaId, groupId: groupId))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Always show active reactions first (if any exist)
            if hasActiveReactions {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(activeEmojis, id: \.self) { emoji in
                            activeReactionCapsule(for: emoji)
                                .transition(.scale(scale: 0.8).combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 4)
                }
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                    removal: .opacity
                ))
                .animation(.easeInOut(duration: 0.3), value: hasActiveReactions)
            }
            
            // Emoji selection bar (show/hide based on state) - only show if user hasn't reacted
            if showEmojiBar && !userHasAnyReaction {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(defaultEmojis, id: \.self) { emoji in
                            reactionCapsule(for: emoji)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 4)
                }
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.8).combined(with: .opacity),
                    removal: .scale(scale: 0.8).combined(with: .opacity)
                ))
            }
            
            // React button - only show if user hasn't reacted to anything
            if !userHasAnyReaction {
                HStack {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showEmojiBar.toggle()
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
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.appPrimary.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(showEmojiBar ? Color.appPrimary : Color.clear, lineWidth: 1.5)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: userHasAnyReaction)
        .animation(.easeInOut(duration: 0.25), value: showEmojiBar)
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
    
    // Check if current user has reacted to any emoji
    private var userHasAnyReaction: Bool {
        guard let uid = Auth.auth().currentUser?.uid else { return false }
        return viewModel.reactions.values.contains { users in
            users.contains(uid)
        }
    }

    // MARK: - Emoji Capsules
    
    private func reactionCapsule(for emoji: String) -> some View {
        Button {
            // First toggle the reaction
            viewModel.toggleReaction(emoji)
            HapticFeedbacks.soft()
            
            // Then hide emoji bar immediately
            withAnimation(.easeOut(duration: 0.2)) {
                showEmojiBar = false
            }
        } label: {
            Text(emoji)
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(Color.gray.opacity(0.1))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
    
    private func activeReactionCapsule(for emoji: String) -> some View {
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
        }
        .buttonStyle(.plain)
        .animation(.easeInOut, value: count)
        .animation(.easeInOut, value: reacted)
    }
}

#Preview {
    VStack(spacing: 20) {
        ReactionBar(ideaId: "mock1")
        ReactionBar(ideaId: "mock2")
    }
    .padding()
} 