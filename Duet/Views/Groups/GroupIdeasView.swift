import SwiftUI

/// Displays the list of ideas that belong to a group and mirrors the behaviour seen in `ActivityHistoryView`.
/// - Important: Uses `ActivityHistoryCard` so the video autoplay / thumbnail swap logic remains consistent across the app.
struct GroupIdeasView: View {
    @EnvironmentObject private var toast: ToastManager
    @EnvironmentObject private var processingManager: ProcessingManager
    @ObservedObject var viewModel: GroupDetailViewModel
    
    // Search functionality
    let filteredIdeas: [GroupIdea]
    let showingSearch: Bool
    let onShowSearch: () -> Void
    let onHideSearch: () -> Void
    @Binding var searchQuery: String

    // Default initializer for backwards compatibility
    init(viewModel: GroupDetailViewModel) {
        self.viewModel = viewModel
        self.filteredIdeas = viewModel.ideas
        self.showingSearch = false
        self.onShowSearch = {}
        self.onHideSearch = {}
        self._searchQuery = .constant("")
    }
    
    // Search-enabled initializer
    init(viewModel: GroupDetailViewModel, 
         filteredIdeas: [GroupIdea],
         showingSearch: Bool,
         onShowSearch: @escaping () -> Void,
         onHideSearch: @escaping () -> Void,
         searchQuery: Binding<String>) {
        self.viewModel = viewModel
        self.filteredIdeas = filteredIdeas
        self.showingSearch = showingSearch
        self.onShowSearch = onShowSearch
        self.onHideSearch = onHideSearch
        self._searchQuery = searchQuery
    }

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
                    
                    // Search icon
                    if !showingSearch {
                        Button(action: onShowSearch) {
                            Image(systemName: "magnifyingglass")
                                .font(.title3)
                                .foregroundColor(.appPrimary)
                        }
                    }
                }
                .padding(.horizontal)

                // Search Field - shown when searching
                if showingSearch {
                    VStack(spacing: 12) {
                        HStack {
                            // Search Field
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 16))
                                
                                TextField("Search shared ideas...", text: $searchQuery)
                                    .disableAutocorrection(true)
                                    .submitLabel(.return)
                                
                                if !$searchQuery.wrappedValue.isEmpty {
                                    Button(action: { $searchQuery.wrappedValue = "" }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.secondary)
                                            .font(.system(size: 16))
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
                            )
                            
                            // Clear button
                            Button(action: onHideSearch) {
                                Text("Clear")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.appPrimary)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
                }

                // Empty state
                if filteredIdeas.isEmpty && !viewModel.isLoadingMembers {
                    if $searchQuery.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        emptyState
                    } else {
                        emptySearchState
                    }
                } else {
                    ideasList
                }
            }
        }
    }

    // MARK: - Sub-views
    private var ideasList: some View {
        LazyVStack(spacing: 16) {
            ForEach(filteredIdeas, id: \.id) { idea in
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

    private var emptySearchState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.largeTitle)
                .foregroundColor(.appPrimary)
            Text("No ideas found")
                .font(.headline)
            Text("Try different keywords or refine your search.")
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
