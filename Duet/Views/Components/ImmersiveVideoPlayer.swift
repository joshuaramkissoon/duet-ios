//
//  ImmersiveVideoPlayer.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 19/05/2025.
//

import SwiftUI
import AVKit

// MARK: - Custom Video Player with Progress Bar
struct CustomVideoPlayer: View {
    let player: AVQueuePlayer
    @Binding var isPlaying: Bool
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var isDragging = false
    @State private var showControls = false
    @State private var hideControlsTimer: Timer?
    
    var body: some View {
        ZStack {
            VideoPlayer(player: player)
                .onTapGesture {
                    togglePlayback()
                    showControlsTemporarily()
                }
                .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { _ in
                    if !isDragging {
                        updateProgress()
                    }
                }
            
            // Progress bar overlay
            VStack {
                Spacer()
                
                if showControls || isDragging {
                    HStack(spacing: 12) {
                        Text(timeString(from: currentTime))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.5), radius: 2)
                        
                        // Custom progress slider
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background track
                                Rectangle()
                                    .fill(Color.white.opacity(0.3))
                                    .frame(height: 3)
                                    .cornerRadius(1.5)
                                
                                // Progress track
                                Rectangle()
                                    .fill(Color.white)
                                    .frame(width: geometry.size.width * progress, height: 3)
                                    .cornerRadius(1.5)
                                
                                // Thumb
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 12, height: 12)
                                    .offset(x: geometry.size.width * progress - 6)
                                    .shadow(color: .black.opacity(0.3), radius: 2)
                            }
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        isDragging = true
                                        let newProgress = max(0, min(1, value.location.x / geometry.size.width))
                                        let newTime = newProgress * duration
                                        currentTime = newTime
                                        player.seek(to: CMTime(seconds: newTime, preferredTimescale: 600))
                                    }
                                    .onEnded { _ in
                                        isDragging = false
                                    }
                            )
                        }
                        .frame(height: 12)
                        
                        Text(timeString(from: duration))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.5), radius: 2)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                    .transition(.opacity.animation(.easeInOut(duration: 0.2)))
                }
            }
        }
    }
    
    private var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }
    
    private func togglePlayback() {
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }
    
    private func showControlsTemporarily() {
        showControls = true
        hideControlsTimer?.invalidate()
        hideControlsTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            withAnimation(.easeOut(duration: 0.3)) {
                showControls = false
            }
        }
    }
    
    private func updateProgress() {
        currentTime = player.currentTime().seconds
        if let item = player.currentItem {
            duration = item.duration.seconds
        }
    }
    
    private func timeString(from seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

// MARK: - Immersive Video View (TikTok Style) - Fixed with Vertical ScrollView
struct ImmersiveVideoView: View {
    let activities: [DateIdeaResponse]
    @Binding var selectedIndex: Int
    let onDetailTap: () -> Void
    let onBackTap: () -> Void
    
    @State private var players: [Int: AVQueuePlayer] = [:]
    @State private var loopingPlayers: [Int: LoopingPlayer] = [:]
    @State private var currentlyPlaying: [Int: Bool] = [:]
    @State private var preloadedIndexes: Set<Int> = []
    @State private var scrollViewIndex: Int? = nil
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                    .ignoresSafeArea(.container, edges: .top) // Only ignore top, not bottom for tab bar
                
                // Use vertical ScrollView for TikTok-style vertical scrolling
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(activities.enumerated()), id: \.element.id) { index, activity in
                                ImmersiveVideoCell(
                                    activity: activity,
                                    index: index,
                                    isActive: index == selectedIndex,
                                    player: players[index],
                                    loopingPlayer: loopingPlayers[index],
                                    isPlaying: Binding(
                                        get: { currentlyPlaying[index] ?? false },
                                        set: { currentlyPlaying[index] = $0 }
                                    ),
                                    screenSize: geometry.size,
                                    onDetailTap: onDetailTap,
                                    onPlayerSetup: { player, loopingPlayer in
                                        players[index] = player
                                        loopingPlayers[index] = loopingPlayer
                                        preloadedIndexes.insert(index)
                                        
                                        if index == selectedIndex {
                                            player.play()
                                            currentlyPlaying[index] = true
                                        }
                                    },
                                    onPlayerCleanup: {
                                        if let loopingPlayer = loopingPlayers[index] {
                                            SmallPlayerPool.shared.recycle(loopingPlayer.player)
                                            loopingPlayers.removeValue(forKey: index)
                                        }
                                        players.removeValue(forKey: index)
                                        currentlyPlaying.removeValue(forKey: index)
                                        preloadedIndexes.remove(index)
                                    }
                                )
                                .frame(width: geometry.size.width, height: geometry.size.height - 49) // Subtract tab bar height
                                .clipped()
                                .id(index)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollTargetBehavior(.paging)
                    .scrollPosition(id: $scrollViewIndex)
                    .clipped() // Prevent content bleeding
                    .onAppear {
                        // Initialize scroll position
                        scrollViewIndex = selectedIndex
                        // Setup initial video
                        setupVideoForIndex(selectedIndex, activity: activities[selectedIndex])
                    }
                    .onChange(of: selectedIndex) { oldValue, newValue in
                        updatePlaybackForIndex(newValue)
                        preloadAdjacentVideos(currentIndex: newValue)
                        
                        // Update scroll position when selectedIndex changes
                        if scrollViewIndex != newValue {
                            scrollViewIndex = newValue
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(newValue, anchor: .top)
                            }
                        }
                    }
                    .onChange(of: scrollViewIndex) { oldValue, newValue in
                        // Update selectedIndex when scroll position changes
                        if let newValue = newValue, newValue != selectedIndex {
                            selectedIndex = newValue
                        }
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(false)
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.width > 100 && abs(value.translation.height) < 50 {
                        // Swipe right to go back
                        onBackTap()
                    }
                }
        )
        .onDisappear {
            // Clean up all players when view disappears
            cleanupAllPlayers()
        }
    }
    
    private func setupVideoForIndex(_ index: Int, activity: DateIdeaResponse) {
        guard players[index] == nil else { return }
        
        Task {
            do {
                guard let remote = URL(string: activity.cloudFrontVideoURL) else { return }
                let local = try await VideoCache.shared.localFile(for: remote)
                let asset = try await AssetPool.shared.asset(for: local)
                
                await MainActor.run {
                    let playerItem = AVPlayerItem(asset: asset)
                    let queuePlayer = SmallPlayerPool.shared.obtain()
                    let loopingPlayer = LoopingPlayer(player: queuePlayer, item: playerItem)
                    queuePlayer.isMuted = false
                    
                    players[index] = queuePlayer
                    loopingPlayers[index] = loopingPlayer
                    preloadedIndexes.insert(index)
                    
                    if index == selectedIndex {
                        queuePlayer.play()
                        currentlyPlaying[index] = true
                    }
                }
            } catch {
                print("❌ Failed to setup video for index \(index): \(error)")
            }
        }
    }
    
    private func preloadAdjacentVideos(currentIndex: Int) {
        let preloadRange = 1 // Preload 1 video ahead and behind for better performance
        
        for offset in -preloadRange...preloadRange {
            let index = currentIndex + offset
            if index >= 0 && index < activities.count && !preloadedIndexes.contains(index) {
                setupVideoForIndex(index, activity: activities[index])
            }
        }
        
        // Clean up videos that are too far away
        let cleanupRange = 3
        for (playerIndex, _) in players {
            if abs(playerIndex - currentIndex) > cleanupRange {
                cleanupPlayerAtIndex(playerIndex)
            }
        }
    }
    
    private func updatePlaybackForIndex(_ index: Int) {
        // Pause all other videos
        for (playerIndex, player) in players {
            if playerIndex == index {
                player.play()
                currentlyPlaying[playerIndex] = true
            } else {
                player.pause()
                currentlyPlaying[playerIndex] = false
            }
        }
    }
    
    private func cleanupPlayerAtIndex(_ index: Int) {
        if let loopingPlayer = loopingPlayers[index] {
            SmallPlayerPool.shared.recycle(loopingPlayer.player)
            loopingPlayers.removeValue(forKey: index)
        }
        players.removeValue(forKey: index)
        currentlyPlaying.removeValue(forKey: index)
        preloadedIndexes.remove(index)
        print("🧹 Cleaned up player at index \(index)")
    }
    
    private func cleanupAllPlayers() {
        for (_, loopingPlayer) in loopingPlayers {
            SmallPlayerPool.shared.recycle(loopingPlayer.player)
        }
        loopingPlayers.removeAll()
        players.removeAll()
        currentlyPlaying.removeAll()
        preloadedIndexes.removeAll()
        print("🧹 Cleaned up all immersive video players")
    }
}

// MARK: - Immersive Video Cell
struct ImmersiveVideoCell: View {
    let activity: DateIdeaResponse
    let index: Int
    let isActive: Bool
    let player: AVQueuePlayer?
    let loopingPlayer: LoopingPlayer?
    @Binding var isPlaying: Bool
    let screenSize: CGSize
    let onDetailTap: () -> Void
    let onPlayerSetup: (AVQueuePlayer, LoopingPlayer) -> Void
    let onPlayerCleanup: () -> Void
    
    @EnvironmentObject private var authVM: AuthenticationViewModel
    @State private var authorUser: User?
    @State private var isLoadingAuthor = false
    @State private var hasSetupPlayer = false
    @State private var loadingTask: Task<Void, Never>?
    
    var body: some View {
        ZStack {
            Color.black
            
            // Full-screen video - properly sized to prevent bleeding
            if let player = player {
                CustomVideoPlayer(player: player, isPlaying: $isPlaying)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                // Show thumbnail while loading
                if let tb64 = activity.thumbnail_b64 {
                    Base64ImageView(
                        base64String: tb64, 
                        thumbWidth: screenSize.width, 
                        thumbHeight: screenSize.height - 49
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                } else {
                    PlaceholderImageView(
                        thumbWidth: screenSize.width, 
                        thumbHeight: screenSize.height - 49
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                }
                
                // Loading indicator
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
            }
            
            // Content overlay (like TikTok)
            VStack {
                Spacer()
                
                HStack(alignment: .bottom) {
                    // Left side - Title and author info
                    VStack(alignment: .leading, spacing: 12) {
                        Text(activity.summary.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                            .shadow(color: .black.opacity(0.5), radius: 2)
                        
                        if let userId = activity.user_id, let userName = activity.user_name {
                            let currentUserId = authVM.user?.uid
                            let displayName = userId == currentUserId ? "You" : userName
                            
                            HStack(spacing: 8) {
                                if let user = authorUser {
                                    ProfileImage(user: user, diam: 32)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white, lineWidth: 2)
                                        )
                                } else {
                                    Circle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white, lineWidth: 2)
                                        )
                                }
                                
                                Text("@\(displayName)")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .shadow(color: .black.opacity(0.5), radius: 2)
                            }
                        }
                        
                        // Tags
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(activity.summary.tags.prefix(3), id: \.title) { tag in
                                    Text("#\(tag.title)")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.white.opacity(0.2))
                                        .foregroundColor(.white)
                                        .cornerRadius(16)
                                        .shadow(color: .black.opacity(0.3), radius: 2)
                                }
                            }
                            .padding(.leading, 4)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Spacer()
                    
                    // Right side - Action buttons
                    VStack(spacing: 20) {
                        Button(action: onDetailTap) {
                            VStack(spacing: 4) {
                                Image(systemName: "info.circle.fill")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundColor(.white)
                                    .shadow(color: .black.opacity(0.5), radius: 2)
                                
                                Text("Details")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .shadow(color: .black.opacity(0.5), radius: 2)
                            }
                        }
                        
                        // Could add more actions like save, share, etc.
                    }
                    .padding(.trailing, 8)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40) // Adjust for safe area
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
                    .frame(height: 300)
                )
            }
        }
        .overlay(
            VisibilityDetector { isVisible in
                if isVisible && !hasSetupPlayer {
                    setupVideo()
                } else if !isVisible && hasSetupPlayer {
                    cleanupVideo()
                }
            }
        )
        .onAppear {
            fetchAuthorUserIfNeeded()
        }
        .onDisappear {
            cleanupVideo()
        }
    }
    
    private func setupVideo() {
        guard !hasSetupPlayer else { return }
        
        loadingTask?.cancel()
        loadingTask = Task {
            do {
                try Task.checkCancellation()
                
                guard let remote = URL(string: activity.cloudFrontVideoURL) else { return }
                let local = try await VideoCache.shared.localFile(for: remote)
                
                try Task.checkCancellation()
                
                let asset = try await AssetPool.shared.asset(for: local)
                
                try Task.checkCancellation()
                
                await MainActor.run {
                    guard !Task.isCancelled, !hasSetupPlayer else { return }
                    
                    let playerItem = AVPlayerItem(asset: asset)
                    let queuePlayer = SmallPlayerPool.shared.obtain()
                    let loopingPlayer = LoopingPlayer(player: queuePlayer, item: playerItem)
                    queuePlayer.isMuted = false
                    
                    hasSetupPlayer = true
                    onPlayerSetup(queuePlayer, loopingPlayer)
                    
                    print("🎬 Setup video player for index \(index)")
                }
            } catch is CancellationError {
                print("🚫 Video setup cancelled for index \(index)")
            } catch {
                print("❌ Failed to setup video for index \(index): \(error)")
            }
        }
    }
    
    private func cleanupVideo() {
        guard hasSetupPlayer else { return }
        
        loadingTask?.cancel()
        loadingTask = nil
        hasSetupPlayer = false
        onPlayerCleanup()
        
        print("🧹 Cleaned up video for index \(index)")
    }
    
    private func fetchAuthorUserIfNeeded() {
        guard let userId = activity.user_id else { return }
        
        if authorUser != nil || isLoadingAuthor { return }
        
        if let cachedUser = UserCache.shared.getUser(id: userId, allowStaleProfileData: false) {
            authorUser = cachedUser
            return
        }
        
        isLoadingAuthor = true
        NetworkClient.shared.getUsers(with: [userId], forceRefreshStaleProfiles: true) { result in
            DispatchQueue.main.async {
                self.isLoadingAuthor = false
                switch result {
                case .success(let users):
                    self.authorUser = users.first ?? User(id: userId, name: self.activity.user_name)
                case .failure:
                    self.authorUser = User(id: userId, name: self.activity.user_name)
                }
            }
        }
    }
} 