//
//  ExploreView.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 19/05/2025.
//

import SwiftUI
import AVKit

struct ExploreView: View {
    @ObservedObject var viewModel: ExploreViewModel
    @State private var selectedActivity: DateIdeaResponse?
    @State private var showDetailView = false
    @FocusState private var isSearchFocused: Bool
    @State private var keyboardHeight: CGFloat = 0

    var body: some View {
        NavigationStack {
            ZStack {
                // Background color
                Color.appBackground
                    .ignoresSafeArea(.all)
                
                if viewModel.isLoading && viewModel.displayItems.isEmpty && !viewModel.isSearchFieldVisible {
                    loadingStateView
                }
                else if let error = viewModel.errorMessage {
                    ErrorView(message: error) {
                        viewModel.refresh()
                    }
                }
                else {
                    BrowseModeView(
                        viewModel: viewModel,
                        isSearchFocused: $isSearchFocused,
                        keyboardHeight: keyboardHeight,
                        onVideoTap: { activity, index in
                            selectedActivity = activity
                            showDetailView = true
                        }
                    )
                }
            }
            .navigationDestination(isPresented: $showDetailView) {
                if let selectedActivity = selectedActivity {
                    DateIdeaDetailView(
                        dateIdea: selectedActivity,
                        viewModel: DateIdeaViewModel(toast: ToastManager(), videoUrl: selectedActivity.cloudFrontVideoURL)
                    )
                    .navigationBarBackButtonHidden(false)
                }
            }
        }
        .navigationBarHidden(true)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue {
                keyboardHeight = keyboardFrame.cgRectValue.height
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardHeight = 0
        }
        .onReceive(NotificationCenter.default.publisher(for: .exploreTabTapped)) { _ in
            // Reset to top when explore tab is tapped while already on explore
            // Since there's no mode switching, we could scroll to top or refresh
            viewModel.refresh()
        }
    }
    
    private var loadingStateView: some View {
        Group {
            if viewModel.isSearchActive {
                SearchingView()
            } else {
                LoadingFeedView()
            }
        }
    }
}

// MARK: - Browse Mode View
struct BrowseModeView: View {
    @ObservedObject var viewModel: ExploreViewModel
    let isSearchFocused: FocusState<Bool>.Binding
    let keyboardHeight: CGFloat
    let onVideoTap: (DateIdeaResponse, Int) -> Void
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Always show search section
                        searchSection
                            .id("searchSection")
                    
                    // Content
                    if viewModel.isLoading && (viewModel.isSearchActive ? viewModel.searchResults.isEmpty : viewModel.feedItems.isEmpty) {
                        loadingContent
                    }
                    else if viewModel.isSearchActive && viewModel.hasSearched && viewModel.searchResults.isEmpty {
                        EmptySearchView()
                    }
                    else if !viewModel.isSearchActive && viewModel.feedItems.isEmpty {
                        EmptyFeedView()
                    }
                    else {
                        contentGrid
                    }
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .refreshable {
                // Only refresh if keyboard is not visible
                if keyboardHeight == 0 {
                    viewModel.refresh()
                }
            }
        }
    }
    
    @ViewBuilder
    private var searchSection: some View {
        VStack(spacing: 16) {
            // Beautiful Search Field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 16))
                
                TextField("Search ideas...", text: $viewModel.query)
                    .focused(isSearchFocused)
                    .disableAutocorrection(true)
                    .submitLabel(.return)
                    .onSubmit {
                        viewModel.showSearchField()
                        isSearchFocused.wrappedValue = false
                        if !viewModel.query.trimmingCharacters(in: .whitespaces).isEmpty {
                            let trimmed = viewModel.query.trimmingCharacters(in: .whitespaces)
                            viewModel.performSearch(with: trimmed)
                        }
                    }
                    .onChange(of: viewModel.query) { _, newValue in
                        let trimmed = newValue.trimmingCharacters(in: .whitespaces)
                        if trimmed.isEmpty {
                            viewModel.clearSearch()
                        } else if trimmed.count >= 3 {
                            viewModel.showSearchField()
                            viewModel.performSearch(with: trimmed)
                        }
                    }
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") {
                                isSearchFocused.wrappedValue = false
                            }
                            .foregroundColor(.appPrimary)
                        }
                    }
                
                if !viewModel.query.isEmpty {
                    Button(action: { 
                        viewModel.query = ""
                        viewModel.hideSearchField()
                        isSearchFocused.wrappedValue = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 16))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.adaptiveCardBackground)
                    .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(isSearchFocused.wrappedValue ? Color.appPrimary : Color.clear, lineWidth: 2)
                    )
            )
            
            // Preset Query Cards (show when search is focused and query is empty)
            if isSearchFocused.wrappedValue && viewModel.query.isEmpty {
                PresetQueryCardsSection(
                    presetQueries: viewModel.presetQueries,
                    onQueryTap: { query in
                        isSearchFocused.wrappedValue = false
                        viewModel.showSearchField()
                        viewModel.query = query
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.performSearch(with: query)
                        }
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 20)
    }
    
    @ViewBuilder
    private var loadingContent: some View {
        VStack(spacing: 24) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color.appPrimary))
                .scaleEffect(1.2)
            
            Text(viewModel.isSearchActive ? "Searching for \(viewModel.query.lowercased())" : "Loading global feed")
                .font(.headline)
                .foregroundColor(.appPrimary)
        }
        .padding(.top, 60)
    }
    
    // Computed property to determine which activities to show
    private var activitesToShow: [DateIdeaResponse] {
        if viewModel.isSearchActive {
            return viewModel.searchResults
        } else {
            return viewModel.feedItems
        }
    }
    
    @ViewBuilder
    private var contentGrid: some View {
        let activities = activitesToShow
        ReusableMasonryGrid(
            activities: activities,
            style: .explore,
            onVideoTap: onVideoTap,
            onLoadMore: {
                // Load next page when approaching the end (for feed only, not search)
                if !viewModel.isSearchActive {
                    viewModel.loadNextFeedPage()
                }
            }
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
        
        // Loading indicator for pagination (only for feed, not search)
        if !viewModel.isSearchActive && viewModel.hasMorePages && viewModel.isLoadingFeed {
            ProgressView()
                .padding()
        }
    }
}

// MARK: - Existing Components (preserved)
struct LoadingFeedView: View {
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Image("duet")
              .resizable()
              .scaledToFit()
              .clipShape(
                RoundedRectangle(cornerRadius: 36, style: .continuous)
              )
              .padding(.horizontal, 40)
              .padding(.top, 20)
            
            Text("Loading global feed")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.appPrimary)
            
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color.appPrimary))
                .scaleEffect(1.5)
                .padding(.top, 16)
            
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .withAppBackground()
    }
}

struct SearchingView: View {
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Image("duet")
              .resizable()
              .scaledToFit()
              .clipShape(
                RoundedRectangle(cornerRadius: 36, style: .continuous)
              )
              .padding(.horizontal, 40)
              .padding(.top, 20)
            
            Text("Searching for similar ideas")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.appPrimary)
            
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color.appPrimary))
                .scaleEffect(1.5)
                .padding(.top, 16)
            
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .withAppBackground()
    }
}

struct EmptySearchView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No ideas found")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Try adjusting your search or explore our preset categories")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.top, 60)
    }
}

struct EmptyFeedView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundColor(.appPrimary)
            
            Text("No ideas in the feed yet")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Check back later for new ideas from the community!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.top, 60)
    }
}

struct ErrorView: View {
    let message: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("Something went wrong")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button("Try Again") {
                onRetry()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.appPrimary)
            .foregroundColor(.white)
            .cornerRadius(12)
            .fontWeight(.medium)
        }
        .padding(.top, 60)
    }
}

struct ExploreCard: View {
    @EnvironmentObject private var toast: ToastManager
    @EnvironmentObject private var authVM: AuthenticationViewModel
    let activity: DateIdeaResponse
    @Binding var selectedActivity: DateIdeaResponse?
    var hideNavigationBar: Bool = false
    
    @State private var player: AVPlayer?
    @State private var looping: LoopingPlayer?
    @State private var isActive = false
    @State private var showVideo = false
    @StateObject private var commentsViewModel: CommentsViewModel
    @StateObject private var dateIdeaViewModel: DateIdeaViewModel
    @State private var localActivity: DateIdeaResponse
    @State private var isDeleted: Bool = false
    
    // State for user data fetching
    @State private var authorUser: User?
    
    // Add task tracking to prevent race conditions
    @State private var loadingTask: Task<Void, Never>?

    init(activity: DateIdeaResponse, selectedActivity: Binding<DateIdeaResponse?>, hideNavigationBar: Bool = false) {
        self.activity = activity
        self._selectedActivity = selectedActivity
        self.hideNavigationBar = hideNavigationBar
        self._commentsViewModel = StateObject(wrappedValue: CommentsViewModel(ideaId: activity.id, groupId: nil))
        self._dateIdeaViewModel = StateObject(wrappedValue: DateIdeaViewModel(toast: ToastManager(), videoUrl: activity.cloudFrontVideoURL))
        self._localActivity = State(initialValue: activity)
    }

    var body: some View {
        if isDeleted {
            EmptyView()
        } else {
            NavigationLink(destination: DateIdeaDetailView(dateIdea: activity, hideNavigationBar: hideNavigationBar, viewModel: dateIdeaViewModel)) {
                cardContent
            }
            .buttonStyle(.plain)
            .onAppear {
                // Update the viewModel with the correct toast manager from environment
                dateIdeaViewModel.updateToastManager(toast)
                // Load author from cache since it should already be cached by ExploreViewModel
                loadAuthorFromCache()
            }
            .onReceive(NotificationCenter.default.publisher(for: .userProfileUpdated)) { notification in
                // If the updated user is the author of this activity, clear local state to trigger refresh
                if let updatedUser = notification.userInfo?["updatedUser"] as? User,
                   let authorId = localActivity.user_id,
                   updatedUser.id == authorId {
                    authorUser = updatedUser // Update immediately with new data
                    print("🔄 Updated author user for activity \(localActivity.id) with new profile image")
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .ideaVisibilityUpdated)) { notification in
                // Update local state if this idea's visibility was changed
                if let ideaId = notification.userInfo?["ideaId"] as? String,
                   let isPublic = notification.userInfo?["isPublic"] as? Bool,
                   ideaId == localActivity.id {
                    // Update the local activity data
                    var updatedActivity = localActivity
                    updatedActivity = DateIdeaResponse(
                        id: updatedActivity.id,
                        summary: updatedActivity.summary,
                        title: updatedActivity.title,
                        description: updatedActivity.description,
                        thumbnail_b64: updatedActivity.thumbnail_b64,
                        thumbnail_url: updatedActivity.thumbnail_url,
                        video_url: updatedActivity.video_url,
                        videoMetadata: updatedActivity.videoMetadata,
                        original_source_url: updatedActivity.original_source_url,
                        user_id: updatedActivity.user_id,
                        user_name: updatedActivity.user_name,
                        created_at: updatedActivity.created_at,
                        isPublic: isPublic
                    )
                    localActivity = updatedActivity
                    print("🔄 Updated visibility for idea \(ideaId) in ExploreCard: \(isPublic ? "Public" : "Private")")
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .ideaMetadataUpdated)) { notification in
                // Update local state if this idea's metadata was changed
                if let ideaId = notification.userInfo?["ideaId"] as? String,
                   ideaId == localActivity.id,
                   let updatedIdea = notification.userInfo?["updatedIdea"] as? DateIdeaResponse {
                    localActivity = updatedIdea
                    print("🔄 Updated metadata for idea \(ideaId) in ExploreCard")
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .ideaDeleted)) { notification in
                // Hide this card if its idea was deleted
                if let ideaId = notification.userInfo?["ideaId"] as? String,
                   ideaId == localActivity.id {
                    isDeleted = true
                    print("🗑️ Hiding deleted idea \(ideaId) in ExploreCard")
                }
            }
            .onDisappear {
                // Cancel any ongoing loading task
                loadingTask?.cancel()
                loadingTask = nil
                
                if let lp = looping {
                    SmallPlayerPool.shared.recycle(lp.player)
                    looping = nil
                    player  = nil
                }
            }
        }
    }
    
    private var videoThumbnail: some View {
        Group {
            if let tb64 = localActivity.thumbnail_b64 {
                Base64ImageView(base64String: tb64, thumbWidth: videoWidth, thumbHeight: videoHeight)
                    .opacity(1)
            }
            else {
                PlaceholderImageView(thumbWidth: videoWidth, thumbHeight: videoHeight)
            }
        }
    }
    
    @ViewBuilder
    private func authorSection() -> some View {
        if let userId = localActivity.user_id, let userName = localActivity.user_name {
            let currentUserId = authVM.user?.uid
            let displayName = userId == currentUserId ? "You" : userName
            
            HStack(spacing: 8) {
                // Author avatar
                let user = authorUser ?? User(id: userId, name: userName)
                ProfileImage(user: user, diam: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {                        
                        Text(displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)

                    if let createdAtTimestamp = localActivity.created_at {
                        Spacer()
                        let createdAtDate = Date(timeIntervalSince1970: TimeInterval(createdAtTimestamp))
                        Text(timeAgoString(from: createdAtDate))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.trailing, 4)
                    }
                    }
                }
                
                Spacer()
            }
            .padding(.bottom, 4)
        } else {
            // Debug: Show when user info is missing
            #if DEBUG
            if localActivity.user_id == nil && localActivity.user_name == nil {
                HStack {
                    Text("No author info available")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .opacity(0.7)
                    Spacer()
                }
                .padding(.bottom, 2)
            }
            #endif
        }
    }
    
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Author section if user info is available
            authorSection()
            
            // Video Player Section
            ZStack {
                // Show video only while it's actively playing. Fade using `showVideo`.
                if isActive, let player {
                    VideoPlayer(player: player)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 3)
                        .opacity(showVideo ? 1 : 0)
                }

                // Show thumbnail whenever video is not active or until the fade completes.
                if !isActive || !showVideo {
                    videoThumbnail
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .frame(width: videoWidth, height: videoHeight)
            .overlay(
                VisibilityDetector { visible in
                    Task { await updateActivity(visible: visible) }
                }
            )
            
            // Content Section
            VStack(alignment: .leading, spacing: 8) {
                Text(localActivity.summary.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(localActivity.summary.sales_pitch)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    
                // Tags (removed visibility indicator since explore feed only shows public ideas)
                HStack(spacing: 6) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(localActivity.summary.tags.prefix(3), id: \.title) { tag in
                                CategoryPill(text: tag.title, icon: tag.icon)
                            }
                        }
                        .padding(.leading, 4)
                        .padding(.trailing, 4)
                    }
                }
            }
            .padding(.horizontal, 4)

            // Reactions and Comments bar
            VStack(alignment: .leading, spacing: 8) {
                // Reaction bar above
                ReactionBar(ideaId: localActivity.id, groupId: nil)
                
                // Comment icon with count - tappable to scroll to comments
                NavigationLink(destination: DateIdeaDetailView(dateIdea: localActivity, scrollToComments: true, hideNavigationBar: hideNavigationBar, viewModel: dateIdeaViewModel)) {
                    HStack(spacing: 4) {
                        Image(systemName: "message")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        
                        if commentsViewModel.comments.count > 0 {
                            Text("\(commentsViewModel.comments.count)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.adaptiveCardBackground)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
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
            player  = nil
        }
        isActive  = false
        showVideo = false
    }
    
    private func updateActivity(visible: Bool) {
        guard visible else {
            showVideo = false
            Task { await MainActor.run { stopPlayback() } }
            return
        }

        // Already set up? Just flag active.
        if looping != nil { return }

        // Cancel any existing loading task before starting a new one
        loadingTask?.cancel()
        
        loadingTask = Task {               // runs on a background executor by default
            do {
                // Check if task was cancelled before proceeding
                try Task.checkCancellation()
                
                // 1️⃣  Fetch or download file (inside VideoCache actor)
                guard let remote = URL(string: localActivity.cloudFrontVideoURL) else { return }
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
                    let item  = AVPlayerItem(asset: asset)
                    looping   = LoopingPlayer(player: queue, item: item)

                    queue.isMuted = true
                    queue.play()
                    player  = queue
                    isActive = true

                    // delay thumbnail removal by 0.3 s
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            showVideo = true             // fade thumbnail out
                        }
                    }
                }
            } catch is CancellationError {
                // Task was cancelled, this is expected behavior
            } catch {
                print("❌ video load:", error)
            }
        }
    }
    
    // MARK: - User Data Fetching
    
    private func loadAuthorFromCache() {
        guard let userId = localActivity.user_id else { return }
        
        // Look up user from cache (should already be cached by ExploreViewModel)
        if let cachedUser = UserCache.shared.getUser(id: userId, allowStaleProfileData: true) {
            authorUser = cachedUser
        } else {
            // Fallback to basic user object if not in cache
            authorUser = User(id: userId, name: localActivity.user_name)
        }
    }
    
    // MARK: - Computed Properties
    
    private var videoWidth: CGFloat {
        if let meta = localActivity.videoMetadata, meta.isLandscape {
            // Wider card width with padding similar to ActivityHistoryCard
            return UIScreen.main.bounds.width - 32 - 60
        } else {
            return 140
        }
    }

    private var videoHeight: CGFloat {
        if let metadata = localActivity.videoMetadata {
            return videoWidth / metadata.aspectRatio
        } else {
            return videoWidth * 9 / 16
        }
    }
}

#Preview {
    NavigationView {
        ExploreView(viewModel: ExploreViewModel())
    }
}

// MARK: - Preset Query Components
struct PresetQueryCard: View {
    let query: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(query)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .frame(height: 52)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.adaptiveCardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.appPrimary.opacity(0.2), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

struct PresetQueryCardsSection: View {
    let presetQueries: [String]
    let onQueryTap: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Popular searches")
                    .font(.headline)
                    .fontWeight(.semibold)
                .foregroundColor(.primary)
                .padding(.horizontal, 4)
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ], spacing: 8) {
                ForEach(presetQueries, id: \.self) { query in
                    PresetQueryCard(query: query) {
                        onQueryTap(query)
                    }
                }
            }
        }
    }
}
