import SwiftUI
import AVKit

/// Displays the list of ideas that belong to a group using a masonry grid layout similar to ExploreView.
struct GroupIdeasView: View {
    @EnvironmentObject private var toast: ToastManager
    @EnvironmentObject private var processingManager: ProcessingManager
    @ObservedObject var viewModel: GroupDetailViewModel
    @FocusState private var isSearchFocused: Bool
    
    // Search functionality
    let filteredIdeas: [GroupIdea]
    let showingSearch: Bool
    let onShowSearch: () -> Void
    let onHideSearch: () -> Void
    @Binding var searchQuery: String
    let onVideoTap: ((DateIdeaResponse, Int) -> Void)?
    
    // Default initializer for backwards compatibility
    init(viewModel: GroupDetailViewModel) {
        self.viewModel = viewModel
        self.filteredIdeas = viewModel.ideas
        self.showingSearch = false
        self.onShowSearch = {}
        self.onHideSearch = {}
        self._searchQuery = .constant("")
        self.onVideoTap = nil
    }
    
    // Search-enabled initializer
    init(viewModel: GroupDetailViewModel, 
         filteredIdeas: [GroupIdea],
         showingSearch: Bool,
         onShowSearch: @escaping () -> Void,
         onHideSearch: @escaping () -> Void,
         searchQuery: Binding<String>,
         onVideoTap: ((DateIdeaResponse, Int) -> Void)? = nil) {
        self.viewModel = viewModel
        self.filteredIdeas = filteredIdeas
        self.showingSearch = showingSearch
        self.onShowSearch = onShowSearch
        self.onHideSearch = onHideSearch
        self._searchQuery = searchQuery
        self.onVideoTap = onVideoTap
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
                                    .focused($isSearchFocused)
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
                                    .fill(Color.adaptiveCardBackground)
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
                    // Masonry Grid using Group Ideas
                    ReusableMasonryGrid(
                        groupIdeas: filteredIdeas,
                        groupDetailViewModel: viewModel,
                        onVideoTap: { activity, index in
                            onVideoTap?(activity, index)
                        },
                        onDeleteTap: { activity in
                            // Find the GroupIdea ID from the DateIdeaResponse
                            if let groupIdea = filteredIdeas.first(where: { $0.id == activity.id }) {
                                Task {
                                    await removeIdea(ideaID: groupIdea.id)
                                }
                            }
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
            }
        }
        .onChange(of: showingSearch) { _, isShowing in
            if isShowing {
                // Add a small delay to ensure the search field is rendered before focusing
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isSearchFocused = true
                }
            } else {
                // Clear focus when hiding search
                isSearchFocused = false
            }
        }
    }

    // MARK: - Sub-views
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
