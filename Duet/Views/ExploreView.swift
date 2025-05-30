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
    @FocusState private var isSearchFocused: Bool
    @State private var keyboardHeight: CGFloat = 0

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()
            
            if viewModel.isLoading && viewModel.displayItems.isEmpty && !viewModel.isSearchFieldVisible {
                if viewModel.isSearchActive {
                    SearchingView()
                } else {
                    LoadingFeedView()
                }
            }
            else if let error = viewModel.errorMessage {
                ErrorView(message: error) {
                    viewModel.refresh()
                }
            }
            else {
                mainContent
            }
        }
        .sheet(item: $selectedActivity) { activity in
            NavigationView {
                ActivityDetailLoader(activityId: activity.id)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue {
                keyboardHeight = keyboardFrame.cgRectValue.height
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardHeight = 0
        }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Search Section (when visible)
                    if viewModel.isSearchFieldVisible {
                        searchSection
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .id("searchSection")
                    }
                    
                    // Content
                    if viewModel.isLoading && viewModel.displayItems.isEmpty {
                        loadingContent
                    }
                    else if viewModel.isSearchActive && viewModel.hasSearched && viewModel.searchResults.isEmpty {
                        EmptySearchView()
                    }
                    else if !viewModel.isSearchActive && viewModel.feedItems.isEmpty {
                        EmptyFeedView()
                    }
                    else {
                        contentItems
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
            .onChange(of: viewModel.isSearchFieldVisible) { _, isVisible in
                if isVisible {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo("searchSection", anchor: .top)
                    }
                }
            }
        }
        .navigationTitle("Explore")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !viewModel.isSearchFieldVisible {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            viewModel.showSearchField()
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            isSearchFocused = true
                        }
                    }) {
                        Image(systemName: "magnifyingglass")
                            .font(.title2)
                            .foregroundColor(.appPrimary)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var searchSection: some View {
        VStack(spacing: 16) {
            // Search Field with Cancel
            HStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
                    
                    TextField("Search ideas...", text: $viewModel.query)
                        .focused($isSearchFocused)
                        .disableAutocorrection(true)
                        .submitLabel(.return)
                        .onSubmit {
                            isSearchFocused = false
                        }
                        .toolbar {
                            ToolbarItemGroup(placement: .keyboard) {
                                Spacer()
                                Button("Done") {
                                    isSearchFocused = false
                                }
                                .foregroundColor(.appPrimary)
                            }
                        }
                    
                    if !viewModel.query.isEmpty {
                        Button(action: { viewModel.query = "" }) {
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
                
                Button("Cancel") {
                    isSearchFocused = false
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.hideSearchField()
                    }
                }
                .foregroundColor(.appPrimary)
                .fontWeight(.medium)
            }
            
            // Preset Query Cards (only when not searching)
            if !viewModel.isSearchActive && viewModel.query.isEmpty {
                presetQueryCards
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
    
    @ViewBuilder
    private var presetQueryCards: some View {
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
                ForEach(viewModel.presetQueries, id: \.self) { query in
                    PresetQueryCard(query: query) {
                        isSearchFocused = false
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.performSearch(with: query)
                        }
                    }
                }
            }
        }
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
    
    @ViewBuilder
    private var contentItems: some View {
        LazyVStack(spacing: 16) {
            ForEach(viewModel.displayItems, id: \.id) { activity in
                ExploreCard(activity: activity, selectedActivity: $selectedActivity)
                    .onAppear {
                        // Load next page when approaching the end (for feed only)
                        if !viewModel.isSearchActive && 
                           activity.id == viewModel.feedItems.last?.id {
                            viewModel.loadNextFeedPage()
                        }
                    }
            }
            
            // Loading indicator for pagination
            if !viewModel.isSearchActive && viewModel.hasMorePages && viewModel.isLoadingFeed {
                ProgressView()
                    .padding()
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
}

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
                        .fill(Color(.systemBackground))
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
    @State private var isAnimating = false
    
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
    
    @State private var player: AVPlayer?
    @State private var looping: LoopingPlayer?
    @State private var isActive = false
    @State private var showVideo = false
    @StateObject private var commentsViewModel: CommentsViewModel

    init(activity: DateIdeaResponse, selectedActivity: Binding<DateIdeaResponse?>) {
        self.activity = activity
        self._selectedActivity = selectedActivity
        self._commentsViewModel = StateObject(wrappedValue: CommentsViewModel(ideaId: activity.id, groupId: nil))
    }

    var body: some View {
        NavigationLink(destination: DateIdeaDetailView(dateIdea: activity, viewModel: DateIdeaViewModel(toast: toast, videoUrl: activity.cloudFrontVideoURL))) {
            cardContent
        }
        .buttonStyle(.plain)
    }
    
    private var videoThumbnail: some View {
        Group {
            if let tb64 = activity.thumbnail_b64 {
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
        if let userId = activity.user_id, let userName = activity.user_name {
            let currentUserId = authVM.user?.uid
            let displayName = userId == currentUserId ? "You" : userName
            let user = User(id: userId, name: userName)
            
            HStack(spacing: 8) {
                // Author avatar
                ProfileImage(user: user, diam: 24)
                
                // "Created by" text
                HStack(spacing: 4) {
                    Text("Created by")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                
                Spacer()
            
                // Time indicator using created_at timestamp
                if let createdAtTimestamp = activity.created_at {
                    let createdAtDate = Date(timeIntervalSince1970: TimeInterval(createdAtTimestamp))
                    Text(timeAgoString(from: createdAtDate))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.bottom, 4)
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
                Text(activity.summary.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(activity.summary.sales_pitch)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 4)

            // Reactions and Comments bar
            HStack(spacing: 16) {
                ReactionBar(ideaId: activity.id, groupId: nil)
                
                // Comment icon with count - tappable to scroll to comments
                NavigationLink(destination: DateIdeaDetailView(dateIdea: activity, scrollToComments: true, viewModel: DateIdeaViewModel(toast: toast, videoUrl: activity.cloudFrontVideoURL))) {
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
                .fill(Color(.systemBackground))
        )
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
        .onDisappear {
            if let lp = looping {
                SmallPlayerPool.shared.recycle(lp.player)
                looping = nil
                player  = nil
            }
        }
    }
    
    @MainActor
    private func stopPlayback() {
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

        Task {               // runs on a background executor by default
            do {
                // 1️⃣  Fetch or download file (inside VideoCache actor)
                guard let remote = URL(string: activity.cloudFrontVideoURL) else { return }
                let local = try await VideoCache.shared.localFile(for: remote)

                // 2️⃣  Get (or build) asset — heavy work is inside AssetPool actor
                let asset = try await AssetPool.shared.asset(for: local)

                // 3️⃣  Hop to MainActor for the lightweight player wiring
                await MainActor.run {
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
            } catch {
                print("❌ video load:", error)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var videoWidth: CGFloat {
        if let meta = activity.videoMetadata, meta.isLandscape {
            // Wider card width with padding similar to ActivityHistoryCard
            return UIScreen.main.bounds.width - 32 - 60
        } else {
            return 140
        }
    }

    private var videoHeight: CGFloat {
        if let metadata = activity.videoMetadata {
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
