import SwiftUI

/// Displays the list of ideas that belong to a group and mirrors the behaviour seen in `ActivityHistoryView`.
/// - Important: Uses `ActivityHistoryCard` so the video autoplay / thumbnail swap logic remains consistent across the app.
struct GroupIdeasView: View {
    @EnvironmentObject private var toast: ToastManager
    @EnvironmentObject private var processingManager: ProcessingManager
    @ObservedObject var viewModel: GroupDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Group-level processing jobs first (if any)
            if let groupId = viewModel.group.id {
                GroupProcessingJobsView(
                    processingManager: processingManager,
                    groupId: groupId,
                    showOnlyActive: false
                )
                .environmentObject(viewModel)
                .padding(.horizontal)
            }

            // Ideas list header
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Shared Ideas")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(Color.midnightSlateSoft)

                    Spacer()
                }
                .padding(.horizontal)

                // Empty state
                if viewModel.ideas.isEmpty && !viewModel.isLoadingMembers {
                    emptyState
                } else {
                    ideasList
                }
            }
        }
    }

    // MARK: - Sub-views
    private var ideasList: some View {
        LazyVStack(spacing: 16) {
            ForEach(viewModel.ideas, id: \.id) { idea in
                let response = DateIdeaResponse.fromGroupIdea(idea)
                let author   = viewModel.getAuthor(authorId: idea.addedBy)

                ActivityHistoryCard(
                    activity: response,
                    showAuthor: true,
                    author: author,
                    sharedAt: idea.addedAt,
                    onRemove: {
                        await removeIdea(ideaID: idea.id)
                    },
                    groupId: viewModel.group.id
                )
            }
        }
        .padding(.horizontal)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.largeTitle)
                .foregroundColor(.appPrimary)
            Text("No ideas shared yet")
                .font(.headline)
            Text("When you share an idea to this group, it will appear in this list.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Helpers
    @MainActor
    private func removeIdea(ideaID: String) async {
        guard let gid = viewModel.group.id else { return }
        do {
            try await viewModel.deleteIdea(ideaId: ideaID, fromGroup: gid)
            toast.success("Idea removed")
        } catch {
            toast.error(error.localizedDescription)
        }
    }
} 