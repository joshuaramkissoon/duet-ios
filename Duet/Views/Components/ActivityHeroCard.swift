import SwiftUI
import AVKit

struct ActivityHeroCard: View {
    let activity: DateIdeaResponse
    
    @State private var player: AVQueuePlayer?
    @State private var looping: LoopingPlayer?
    @State private var isActive = false
    @State private var showVideo = false
    @State private var loadingTask: Task<Void, Never>?
    
    var body: some View {
        ZStack {
            // Video/thumbnail with aspect ratio
            ZStack {
                // Show video only while it's actively playing. Fade using `showVideo`.
                if isActive, let player {
                    VideoPlayer(player: player, videoOverlay: {
                        EmptyView()
                    })
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
                            Base64ImageView(base64String: tb64, thumbWidth: heroWidth, thumbHeight: heroHeight)
                        } else {
                            PlaceholderImageView(thumbWidth: heroWidth, thumbHeight: heroHeight)
                        }
                    }
                }
            }
            .frame(width: heroWidth, height: heroHeight)
            .clipped()
            .overlay(
                VisibilityDetector { visible in
                    Task { await updateActivity(visible: visible) }
                }
            )
            .overlay(
                // Minimal text overlay with gradient
                VStack {
                    Spacer()
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            // Title
                            Text(activity.summary.title)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            
                            HStack(spacing: 12) {
                                // For recipe activities: show cuisine type pill
                                if let recipeMetadata = activity.summary.recipe_metadata,
                                   let cuisineType = recipeMetadata.cuisine_type {
                                    HStack(spacing: 4) {
                                        Image(systemName: "globe")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.9))
                                        
                                        Text(cuisineType)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.white.opacity(0.9))
                                            .lineLimit(1)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(.ultraThinMaterial)
                                    )
                                } else {
                                    // Location pill for non-recipe activities
                                    HStack(spacing: 4) {
                                        Image(systemName: "mappin.and.ellipse")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.9))
                                        
                                        Text(activity.summary.location)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.white.opacity(0.9))
                                            .lineLimit(1)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(.ultraThinMaterial)
                                    )
                                }
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.clear,
                                Color.clear,
                                Color.black.opacity(0.3),
                                Color.black.opacity(0.7),
                                Color.black.opacity(0.8)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
        .id(activity.cloudFrontVideoURL) // Force view recreation when video URL changes
        .onChange(of: activity.cloudFrontVideoURL) { oldValue, newValue in
            // Reset video player when URL changes (e.g., when processing completes)
            if oldValue != newValue {
                Task { await MainActor.run { stopPlayback() } }
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
    
    private var heroWidth: CGFloat {
        UIScreen.main.bounds.width - 32 // Full width minus padding
    }
    
    private var heroHeight: CGFloat {
        if let metadata = activity.videoMetadata {
            return heroWidth / metadata.aspectRatio
        } else {
            // Default to 9:16 aspect ratio for hero card (portrait)
            return heroWidth * 16 / 9
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

                    // delay thumbnail removal by 0.5 s
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
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
                print("❌ video load error for hero card:", error)
            }
        }
    }
}

#Preview("Recipe Activity") {
    let sampleRecipeMetadata = RecipeMetadata(
        cuisine_type: "Italian",
        difficulty_level: "Easy",
        servings: "4",
        prep_time: "15 minutes",
        cook_time: "30 minutes",
        ingredients: [
            "2 cups pasta",
            "1 jar marinara sauce",
            "1 lb ground beef",
            "1 onion, diced",
            "2 cloves garlic, minced",
            "1 cup mozzarella cheese"
        ],
        instructions: [
            "Bring a large pot of salted water to boil and cook pasta",
            "Brown the ground beef in a large skillet",
            "Add onion and garlic, cook until translucent",
            "Stir in marinara sauce and simmer for 10 minutes",
            "Serve pasta topped with meat sauce and cheese"
        ]
    )
    
    let mockRecipeIdea = DateIdea(
        title: "Homemade Spaghetti Bolognese",
        summary: "A delicious and comforting Italian pasta dish perfect for a cozy dinner at home. This classic recipe combines perfectly seasoned ground beef with rich marinara sauce.",
        content_type: .recipe,
        sales_pitch: "Create a romantic Italian dinner at home with this authentic and delicious recipe!",
        activity: Activity(title: "Cooking", icon: "fork.knife"),
        location: "At home",
        season: .indoor,
        duration: "45 minutes",
        cost_level: .low,
        required_items: ["Large pot", "Skillet", "Wooden spoon", "Strainer"],
        tags: [
            Tag(title: "Romantic", icon: "heart.fill"),
            Tag(title: "Comfort Food", icon: "house.fill"),
            Tag(title: "Italian", icon: "globe")
        ],
        recipe_metadata: sampleRecipeMetadata
    )
    
    let mockRecipeActivity = DateIdeaResponse(
        id: "recipe-1",
        summary: mockRecipeIdea,
        title: mockRecipeIdea.title,
        description: mockRecipeIdea.summary,
        thumbnail_b64: nil,
        thumbnail_url: "https://example.com/recipe-thumbnail.jpg",
        video_url: "https://example.com/recipe-video.mp4",
        videoMetadata: VideoMetadata(ratio_width: 16, ratio_height: 9),
        original_source_url: "https://tasty.co/recipe/spaghetti-bolognese",
        user_id: "user-123",
        user_name: "Chef Mario",
        created_at: Float(Date().timeIntervalSince1970 - 3600), // 1 hour ago
        isPublic: true
    )
    
    return ActivityHeroCard(activity: mockRecipeActivity)
        .padding()
        .withAppBackground()
}

#Preview("Date Idea Activity") {
    let mockDateIdea = DateIdea(
        title: "Sunset Picnic in Central Park",
        summary: "Enjoy a romantic evening with your partner watching the sunset while having a picnic at Central Park. Bring along wine, cheese, and fruits for a perfect evening under the fading sky.",
        content_type: .dateIdea,
        sales_pitch: "Create an unforgettable evening under the fading sky with delicious treats and the one you love!",
        activity: Activity(title: "Outdoors", icon: "sun.max"),
        location: "Central Park, NYC",
        season: .summer,
        duration: "2-3 hours",
        cost_level: .medium,
        required_items: ["Picnic blanket", "Wine and glasses", "Cheese and crackers", "Portable speaker"],
        tags: [
            Tag(title: "Romantic", icon: "heart.fill"),
            Tag(title: "Relaxing", icon: "leaf"),
            Tag(title: "Nature", icon: "tree")
        ]
    )
    
    let mockDateActivity = DateIdeaResponse(
        id: "date-1",
        summary: mockDateIdea,
        title: mockDateIdea.title,
        description: mockDateIdea.summary,
        thumbnail_b64: nil,
        thumbnail_url: "https://example.com/picnic-thumbnail.jpg",
        video_url: "https://example.com/picnic-video.mp4",
        videoMetadata: VideoMetadata(ratio_width: 9, ratio_height: 16), // Portrait video
        original_source_url: "https://instagram.com/perfect_picnic_spots",
        user_id: "user-456",
        user_name: "Sarah Johnson",
        created_at: Float(Date().timeIntervalSince1970 - 7200), // 2 hours ago
        isPublic: true
    )
    
    return ActivityHeroCard(activity: mockDateActivity)
        .padding()
        .withAppBackground()
} 
