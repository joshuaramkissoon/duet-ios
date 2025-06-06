import SwiftUI
import AVKit

/// Displays the list of ideas that belong to a group using a masonry grid layout similar to ExploreView.
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
                    // Masonry Grid
                    GroupMasonryGrid(
                        ideas: filteredIdeas,
                        viewModel: viewModel,
                        onVideoTap: { activity, index in
                            onVideoTap?(activity, index)
                        },
                        onRemoveIdea: { ideaId in
                            await removeIdea(ideaID: ideaId)
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
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

// MARK: - Group Masonry Grid
struct GroupMasonryGrid: View {
    let ideas: [GroupIdea]
    let viewModel: GroupDetailViewModel
    let onVideoTap: (DateIdeaResponse, Int) -> Void
    let onRemoveIdea: (String) async -> Void
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 2)
    
    // Track active players for memory management
    @State private var activePlayers: Set<String> = []
    private let maxConcurrentPlayers = 4 // Limit concurrent video players
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Array(ideas.enumerated()), id: \.element.id) { index, idea in
                let response = DateIdeaResponse.fromGroupIdea(idea)
                let author = viewModel.getAuthor(authorId: idea.addedBy)
                
                GroupMasonryCard(
                    activity: response,
                    author: author,
                    sharedAt: idea.addedAt,
                    cardId: idea.id,
                    activePlayers: $activePlayers,
                    maxConcurrentPlayers: maxConcurrentPlayers,
                    onTap: {
                        onVideoTap(response, index)
                    },
                    onRemove: {
                        await onRemoveIdea(idea.id)
                    }
                )
            }
        }
    }
}

// MARK: - Group Masonry Card
struct GroupMasonryCard: View {
    @EnvironmentObject private var authVM: AuthenticationViewModel
    let activity: DateIdeaResponse
    let author: User?
    let sharedAt: Date?
    let cardId: String
    @Binding var activePlayers: Set<String>
    let maxConcurrentPlayers: Int
    let onTap: () -> Void
    let onRemove: () async -> Void
    
    @State private var authorUser: User?
    @State private var isLoadingAuthor = false
    
    // Video playing state
    @State private var player: AVQueuePlayer?
    @State private var looping: LoopingPlayer?
    @State private var isActive = false
    @State private var showVideo = false
    @State private var loadingTask: Task<Void, Never>?
    @State private var isVisible = false
    @State private var hasBeenVisible = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Video/thumbnail with aspect ratio (no author section at top)
                ZStack {
                    // Show video only while it's actively playing. Fade using `showVideo`.
                    if isActive, let player {
                        VideoPlayer(player: player)
                            .aspectRatio(contentMode: .fill)
                            .opacity(showVideo ? 1 : 0)
                    }

                    // Show thumbnail whenever video is not active or until the fade completes.
                    if !isActive || !showVideo {
                        AsyncImage(url: URL(string: activity.thumbnail_url ?? "")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            if let tb64 = activity.thumbnail_b64 {
                                Base64ImageView(base64String: tb64, thumbWidth: cardWidth, thumbHeight: cardHeight)
                            } else {
                                PlaceholderImageView(thumbWidth: cardWidth, thumbHeight: cardHeight)
                            }
                        }
                    }
                }
                .frame(width: cardWidth, height: cardHeight)
                .clipped()
                .background(
                    // Enhanced visibility detector with better reliability
                    GeometryReader { geometry in
                        Color.clear
                            .onAppear {
                                // Initial visibility check
                                DispatchQueue.main.async {
                                    checkVisibility(geometry: geometry)
                                }
                            }
                            .onChange(of: geometry.frame(in: .global)) { _, newFrame in
                                checkVisibility(geometry: geometry)
                            }
                    }
                )
                .overlay(
                    // Text overlay with gradient (similar to ExploreView but different content)
                    VStack {
                        Spacer()
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(activity.summary.title)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            
                            // Author info with "Shared" prefix like ExploreView but different content
                            if let author = author, let sharedAt = sharedAt {
                                HStack(spacing: 6) {
                                    ProfileImage(user: author, diam: 16)
                                    
                                    Text("Shared \(formattedSharedDate(sharedAt))")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.white.opacity(0.9))
                                    
                                    Spacer()
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.clear,
                                    Color.black.opacity(0.3),
                                    Color.black.opacity(0.7)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                )
            }
        }
        .buttonStyle(.plain)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .contextMenu {
            Button(role: .destructive) {
                Task { await onRemove() }
            } label: {
                Label("Remove from group", systemImage: "trash")
            }
        }
        .onAppear {
            authorUser = author
            hasBeenVisible = false
            // Check visibility on appear with a small delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let geometry = findGeometry() {
                    checkVisibility(geometry: geometry)
                }
            }
        }
        .onDisappear {
            // Aggressive cleanup when card disappears from view
            cleanupVideo()
        }
        .onChange(of: isVisible) { _, newVisibility in
            if newVisibility {
                hasBeenVisible = true
                startVideoIfNeeded()
            } else {
                // Stop when not visible to save memory
                stopVideo()
            }
        }
    }
    
    private func findGeometry() -> GeometryProxy? {
        // This is a fallback - the real geometry comes from the GeometryReader
        return nil
    }
    
    private func checkVisibility(geometry: GeometryProxy) {
        let frame = geometry.frame(in: .global)
        let screenBounds = UIScreen.main.bounds
        
        // Less strict visibility check - require only 50% of card to be visible
        let visibleHeight = screenBounds.intersection(frame).height
        let visibilityRatio = visibleHeight / frame.height
        
        // Require 50% of card to be visible (reduced from 70% for better responsiveness)
        let newVisibility = visibilityRatio > 0.5
        
        if newVisibility != isVisible {
            print("📱 Card \(cardId) visibility changed: \(isVisible) → \(newVisibility) (ratio: \(String(format: "%.2f", visibilityRatio)))")
            isVisible = newVisibility
        }
    }
    
    private func startVideoIfNeeded() {
        guard isVisible, !isActive else { return }
        
        if activePlayers.count < maxConcurrentPlayers {
            // Start immediately if under limit
            startVideo()
        } else {
            // If at limit, try to stop a less visible video and start this one
            print("🎬 Player limit reached (\(activePlayers.count)/\(maxConcurrentPlayers)), trying to make room for card \(cardId)")
            // For now, just try again after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if self.isVisible && !self.isActive && self.activePlayers.count < self.maxConcurrentPlayers {
                    self.startVideo()
                }
            }
        }
    }
    
    private func startVideo() {
        guard !isActive, loadingTask == nil, isVisible else { 
            print("🚫 Cannot start video for card \(cardId): active=\(isActive), hasTask=\(loadingTask != nil), visible=\(isVisible)")
            return 
        }
        
        // Add this card to active players
        activePlayers.insert(cardId)
        
        loadingTask = Task {
            do {
                try Task.checkCancellation()
                
                // Fetch or download file
                guard let remote = URL(string: activity.cloudFrontVideoURL) else { 
                    await MainActor.run { activePlayers.remove(cardId) }
                    return 
                }
                let local = try await VideoCache.shared.localFile(for: remote)

                try Task.checkCancellation()

                // Get asset
                let asset = try await AssetPool.shared.asset(for: local)

                try Task.checkCancellation()

                // Main actor for player setup
                await MainActor.run {
                    guard !Task.isCancelled, looping == nil, isVisible else {
                        activePlayers.remove(cardId)
                        print("🚫 Video setup cancelled for card \(cardId): cancelled=\(Task.isCancelled), hasLooping=\(looping != nil), visible=\(isVisible)")
                        return
                    }
                    
                    let queue = SmallPlayerPool.shared.obtain()
                    let item = AVPlayerItem(asset: asset)
                    looping = LoopingPlayer(player: queue, item: item)

                    // ALWAYS ensure muted
                    queue.isMuted = true
                    queue.volume = 0.0
                    
                    queue.play()
                    player = queue
                    isActive = true

                    // Shorter delay for faster responsiveness
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        if isVisible { // Double-check still visible
                            withAnimation(.easeInOut(duration: 0.1)) {
                                showVideo = true
                            }
                        }
                    }
                    
                    print("🎬 Started video for card \(cardId) (\(activePlayers.count)/\(maxConcurrentPlayers) active)")
                }
            } catch is CancellationError {
                await MainActor.run { activePlayers.remove(cardId) }
                print("🚫 Video loading cancelled for card \(cardId)")
            } catch {
                await MainActor.run { activePlayers.remove(cardId) }
                print("❌ Failed to load video for card \(cardId): \(error)")
            }
        }
    }
    
    private func stopVideo() {
        guard isActive else { return }
        
        // Cancel loading task
        loadingTask?.cancel()
        loadingTask = nil
        
        // Remove from active players
        activePlayers.remove(cardId)
        
        // Stop and recycle player
        if let lp = looping {
            lp.player.pause()
            SmallPlayerPool.shared.recycle(lp.player)
            looping = nil
            player = nil
        }
        
        isActive = false
        showVideo = false
        
        print("🛑 Stopped video for card \(cardId) (\(activePlayers.count)/\(maxConcurrentPlayers) active)")
    }
    
    private func cleanupVideo() {
        stopVideo()
        
        // Clear any remaining state
        authorUser = nil
        hasBeenVisible = false
        // Force visibility reset so that on re-appearance, visibility detection
        // will trigger again and restart video playback automatically
        isVisible = false
        
        print("🧹 Cleaned up card \(cardId)")
    }
    
    private var cardWidth: CGFloat {
        // Screen width minus padding and spacing
        (UIScreen.main.bounds.width - 32 - 8) / 2
    }
    
    private var cardHeight: CGFloat {
        if let metadata = activity.videoMetadata {
            return cardWidth / metadata.aspectRatio
        } else {
            // Default to square for unknown aspect ratios
            return cardWidth
        }
    }
    
    @MainActor
    private func stopPlayback() {
        // Legacy method - now delegates to stopVideo
        stopVideo()
    }
    
    private func updateActivity(visible: Bool) {
        // Legacy method - now handled by onChange(of: isVisible)
        // Keeping for compatibility but functionality moved to new system
    }
    
    // Helper for human-readable shared date
    private func formattedSharedDate(_ date: Date) -> String {
        let now = Date()
        let calendar = Calendar.current
        if let days = calendar.dateComponents([.day], from: date, to: now).day, days > 7 {
            let year = calendar.component(.year, from: date)
            let currentYear = calendar.component(.year, from: now)
            let formatter = DateFormatter()
            if year == currentYear {
                formatter.dateFormat = "dd MMMM" // e.g. 29 May
            } else {
                formatter.dateFormat = "dd MMMM yyyy" // e.g. 29 May 2024
            }
            return formatter.string(from: date)
        } else {
            return timeAgoString(from: date)
        }
    }
} 
