import SwiftUI
import AVKit

// MARK: - Masonry Grid Styles
enum MasonryGridStyle {
    case recentActivity
    case explore 
    case groupIdea
    case library
}

// MARK: - Reusable Masonry Grid
struct ReusableMasonryGrid: View {
    let activities: [DateIdeaResponse]
    let style: MasonryGridStyle
    let onVideoTap: ((DateIdeaResponse, Int) -> Void)?
    let onLoadMore: (() -> Void)?
    let onDeleteTap: ((DateIdeaResponse) -> Void)?
    
    // Group-specific data
    let authors: [String: User]?
    let sharedDates: [String: Date]?
    let groupId: String?
    
    // Alternative: Group ideas with view model for author lookup
    let groupIdeas: [GroupIdea]?
    let groupDetailViewModel: GroupDetailViewModel?
    
    // State to prevent duplicate load more calls
    @State private var lastLoadMoreIndex: Int = -1
    @State private var isLoadingMore: Bool = false
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 2)
    
    init(
        activities: [DateIdeaResponse],
        style: MasonryGridStyle,
        onVideoTap: ((DateIdeaResponse, Int) -> Void)? = nil,
        onLoadMore: (() -> Void)? = nil,
        onDeleteTap: ((DateIdeaResponse) -> Void)? = nil,
        authors: [String: User]? = nil,
        sharedDates: [String: Date]? = nil,
        groupId: String? = nil
    ) {
        self.activities = activities
        self.style = style
        self.onVideoTap = onVideoTap
        self.onLoadMore = onLoadMore
        self.onDeleteTap = onDeleteTap
        self.authors = authors
        self.sharedDates = sharedDates
        self.groupId = groupId
        self.groupIdeas = nil
        self.groupDetailViewModel = nil
    }
    
    // Group ideas initializer
    init(
        groupIdeas: [GroupIdea],
        groupDetailViewModel: GroupDetailViewModel,
        style: MasonryGridStyle = .groupIdea,
        onVideoTap: ((DateIdeaResponse, Int) -> Void)? = nil,
        onDeleteTap: ((DateIdeaResponse) -> Void)? = nil
    ) {
        self.activities = []
        self.style = style
        self.onVideoTap = onVideoTap
        self.onLoadMore = nil
        self.onDeleteTap = onDeleteTap
        self.authors = nil
        self.sharedDates = nil
        self.groupId = groupDetailViewModel.group.id
        self.groupIdeas = groupIdeas
        self.groupDetailViewModel = groupDetailViewModel
    }
    
    // Computed property to get the items to display
    private var displayItems: [(activity: DateIdeaResponse, author: User?, sharedAt: Date?)] {
        if let groupIdeas = groupIdeas, let viewModel = groupDetailViewModel {
            // Use group ideas with proper author lookup
            return groupIdeas.enumerated().map { index, idea in
                let response = DateIdeaResponse.fromGroupIdea(idea)
                let author = viewModel.getAuthor(authorId: idea.addedBy)
                return (activity: response, author: author, sharedAt: idea.addedAt)
            }
        } else {
            // Use regular activities with existing logic
            return activities.enumerated().map { index, activity in
                let author = effectiveAuthor(for: activity)
                let sharedAt = sharedDates?[activity.id]
                return (activity: activity, author: author, sharedAt: sharedAt)
            }
        }
    }
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Array(displayItems.enumerated()), id: \.element.activity.id) { index, item in
                ReusableMasonryCard(
                    activity: item.activity,
                    style: style,
                    author: item.author,
                    sharedAt: item.sharedAt,
                    groupId: groupId,
                    onTap: onVideoTap != nil ? {
                        onVideoTap!(item.activity, index)
                    } : nil,
                    onDelete: style == .library || style == .groupIdea ? {
                        onDeleteTap?(item.activity)
                    } : nil
                )
                .onAppear {
                    // Only handle load more for regular activities (not group ideas)
                    if groupIdeas == nil && !isLoadingMore {
                        let loadMoreThreshold = activities.count - 4
                        if index >= loadMoreThreshold && lastLoadMoreIndex < loadMoreThreshold {
                            lastLoadMoreIndex = index
                            isLoadingMore = true
                            onLoadMore?()
                        }
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
        .onChange(of: activities.count) { oldCount, newCount in
            // Reset the load more tracker when new activities are loaded
            // This allows triggering load more again when we approach the new end
            if newCount > oldCount {
                lastLoadMoreIndex = -1
                isLoadingMore = false
            }
        }
    }
    
    // Get the effective author for an activity, prioritizing passed authors, then cached users, then fallback
    private func effectiveAuthor(for activity: DateIdeaResponse) -> User? {
        guard let userId = activity.user_id else { return nil }
        
        // First check passed authors (for group-specific data)
        if let passedAuthor = authors?[userId] {
            return passedAuthor
        }
        
        // Then check UserCache for cached user data
        if let cachedUser = UserCache.shared.getUser(id: userId, allowStaleProfileData: true) {
            return cachedUser
        }
        
        // Fallback to basic user info from activity
        return activity.user_name != nil ? User(id: userId, name: activity.user_name) : nil
    }
}

// MARK: - Reusable Masonry Card
struct ReusableMasonryCard: View {
    @EnvironmentObject private var authVM: AuthenticationViewModel
    let activity: DateIdeaResponse
    let style: MasonryGridStyle
    let author: User?
    let sharedAt: Date?
    let groupId: String?
    let onTap: (() -> Void)?
    let onDelete: (() -> Void)?
    
    // Video playing state (currently unused but kept for future reference)
    @State private var player: AVQueuePlayer?
    @State private var looping: LoopingPlayer?
    @State private var isActive = false
    @State private var showVideo = false
    @State private var loadingTask: Task<Void, Never>?
    
    var body: some View {
        Group {
            if let onTap = onTap {
                // Use Button with callback for complex navigation flows (like ExploreView)
                Button(action: onTap) {
                    cardContent
                }
                .buttonStyle(.plain)
            } else {
                // Use NavigationLink for simple navigation (like ActivityHistoryView)
                NavigationLink(destination: DateIdeaDetailView(
                    dateIdea: activity,
                    groupId: groupId,
                    viewModel: DateIdeaViewModel(toast: ToastManager(), videoUrl: activity.cloudFrontVideoURL)
                )) {
                    cardContent
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: cardWidth, height: cardHeight) // Explicit frame to constrain hit area
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous)) // Explicit hit testing shape
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .contextMenu {
            if style == .library, let onDelete = onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete Idea", systemImage: "trash")
                }
            } else if style == .groupIdea, let onDelete = onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Remove from group", systemImage: "trash")
                }
            }
        }
        .onAppear {
            // Cancel any ongoing loading task
            loadingTask?.cancel()
            loadingTask = nil
            
            if let lp = looping {
                SmallPlayerPool.shared.recycle(lp.player)
                looping = nil
                player = nil
            }
        }
        .onDisappear {
            // Cancel any ongoing loading task
            loadingTask?.cancel()
            loadingTask = nil
            
            if let lp = looping {
                SmallPlayerPool.shared.recycle(lp.player)
                looping = nil
                player = nil
            }
        }
    }
    
    @ViewBuilder
    private var cardContent: some View {
        VStack(spacing: 0) {
            // Video/thumbnail with aspect ratio
            ZStack {
                // Show video only while it's actively playing. Fade using `showVideo`.
                // if isActive, let player {
                //     VideoPlayer(player: player)
                //         .aspectRatio(contentMode: .fill)
                //         .opacity(showVideo ? 1 : 0)
                // }

                // Show thumbnail whenever video is not active or until the fade completes.
                if let tb64 = activity.thumbnail_b64 {
                            Base64ImageView(base64String: tb64, thumbWidth: cardWidth, thumbHeight: cardHeight)
                        } else {
                            PlaceholderImageView(thumbWidth: cardWidth, thumbHeight: cardHeight)
                        }
                // if !isActive || !showVideo {
                //     AsyncImage(url: URL(string: activity.thumbnail_url ?? "")) { image in
                //         image
                //             .resizable()
                //             .aspectRatio(contentMode: .fill)
                //     } placeholder: {
                //         if let tb64 = activity.thumbnail_b64 {
                //             Base64ImageView(base64String: tb64, thumbWidth: cardWidth, thumbHeight: cardHeight)
                //         } else {
                //             PlaceholderImageView(thumbWidth: cardWidth, thumbHeight: cardHeight)
                //         }
                //     }
                // }
            }
            .frame(width: cardWidth, height: cardHeight)
            .clipped()
            .overlay(
                // Text overlay with gradient
                VStack {
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(activity.summary.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        
                        // Style-specific bottom content
                        overlayContent
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
                .allowsHitTesting(false) // Prevent text overlay from interfering with taps
            )
        }
        .frame(width: cardWidth, height: cardHeight) // Constrain entire card content
    }
    
    @ViewBuilder
    private var overlayContent: some View {
        switch style {
        case .recentActivity:
            if let createdAt = activity.created_at {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.9))
                    
                    Text(friendlyTimeAgoString(from: Date(timeIntervalSince1970: TimeInterval(createdAt))))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.9))
                    
                    Spacer()
                }
            }
            
        case .explore:
            if let userId = activity.user_id, let userName = activity.user_name {
                let currentUserId = authVM.user?.uid
                let displayName = userId == currentUserId ? "You" : userName
                
                HStack(spacing: 6) {
                    if let user = author {
                        ProfileImage(user: user, diam: 16)
                    }
                    
                    Text(displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.9))
                    
                    Spacer()
                }
            }
            
        case .groupIdea:
            // Show content even if some data is missing
            HStack(spacing: 6) {
                if let author = author {
                    ProfileImage(user: author, diam: 16)
                } else if let userId = activity.user_id, let userName = activity.user_name {
                    // Fallback: show a placeholder or text-based indicator
                    Text(String(userName.prefix(1)).uppercased())
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(width: 16, height: 16)
                        .background(Color.gray.opacity(0.6))
                        .clipShape(Circle())
                }
                
                if let sharedAt = sharedAt {
                    Text("Shared \(formattedSharedDate(sharedAt))")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.9))
                } else if let author = author {
                    Text("Shared by \(author.displayName)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.9))
                } else if let userName = activity.user_name {
                    Text("Shared by \(userName)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.9))
                }
                
                Spacer()
            }
            
        case .library:
            if let createdAt = activity.created_at {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.9))
                    
                    Text(friendlyTimeAgoString(from: Date(timeIntervalSince1970: TimeInterval(createdAt))))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.9))
                    
                    Spacer()
                }
            }
        }
    }
    
    private var cardWidth: CGFloat {
        // Screen width minus padding and spacing
        (UIScreen.main.bounds.width - 32 - 8) / 2
    }
    
    private var cardHeight: CGFloat {
        if let metadata = activity.videoMetadata {
            return cardWidth / metadata.aspectRatio
        } else {
            // Default to portrait aspect ratio (9:16) for unknown aspect ratios
            return cardWidth * 16 / 9
        }
    }
    
    @MainActor
    private func stopPlayback() {
        // Cancel any ongoing loading task first
        loadingTask?.cancel()
        loadingTask = nil
        
        if let lp = looping {
            lp.player.pause()
            SmallPlayerPool.shared.recycle(lp.player)
            looping = nil
            player = nil
        }
        isActive = false
        showVideo = false
    }
    
    private func updateActivity(visible: Bool) {
        guard visible else {
            showVideo = false
            Task { await MainActor.run { stopPlayback() } }
            return
        }

        // Already set up? Just flag active and ensure muted.
        if let existingLooping = looping {
            existingLooping.player.isMuted = true // Ensure always muted
            return
        }

        // Cancel any existing loading task before starting a new one
        loadingTask?.cancel()
        
        loadingTask = Task {               // runs on a background executor by default
            do {
                // Check if task was cancelled before proceeding
                try Task.checkCancellation()
                
                // 1️⃣  Fetch or download file (inside VideoCache actor)
                guard let remote = URL(string: activity.cloudFrontVideoURL) else { return }
                let local = try await VideoCache.shared.localFile(for: remote)

                // Check cancellation again after potentially long-running operation
                try Task.checkCancellation()

                // 2️⃣  Get (or build) asset — heavy work is inside AssetPool actor
                let asset = try await AssetPool.shared.asset(for: local)

                // Check cancellation one more time before UI updates
                try Task.checkCancellation()

                // 3️⃣  Hop to MainActor for the lightweight player wiring
                await MainActor.run {
                    // Double-check that we haven't been cancelled and state is still valid
                    guard !Task.isCancelled, looping == nil else {
                        print("🚫 Video setup cancelled or already configured")
                        return
                    }
                    
                    let queue = SmallPlayerPool.shared.obtain()
                    let item = AVPlayerItem(asset: asset)
                    looping = LoopingPlayer(player: queue, item: item)

                    // ALWAYS ensure muted - multiple safeguards
                    queue.isMuted = true
                    queue.volume = 0.0
                    
                    queue.play()
                    player = queue
                    isActive = true

                    // delay thumbnail removal by 0.3 s
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            showVideo = true             // fade thumbnail out
                        }
                        
                        // Double-check muted state after a delay
                        queue.isMuted = true
                        queue.volume = 0.0
                    }
                }
            } catch is CancellationError {
                // Task was cancelled, this is expected behavior
            } catch {
                print("❌ video load:", error)
            }
        }
    }
    
    // Helper for human-readable shared date
    private func formattedSharedDate(_ date: Date) -> String {
        return friendlyTimeAgoString(from: date)
    }
} 
