//
//  ActivityHistoryCard.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 17/05/2025.
//

import SwiftUI
import FirebaseAuth
import AVKit

struct ActivityHistoryCard: View {
    @EnvironmentObject private var toast: ToastManager
    @EnvironmentObject private var authVM: AuthenticationViewModel
    let activity: DateIdeaResponse
    var showAuthor: Bool = false
    var author: User? = nil
    var sharedAt: Date? = nil
    var onRemove: (() async -> Void)? = nil
    
    @State private var player: AVPlayer?
    @State private var looping: LoopingPlayer?
    @State private var isActive = false
    @State private var showVideo = false

    var body: some View {
        NavigationLink(destination: DateIdeaDetailView(dateIdea: activity, viewModel: DateIdeaViewModel(toast: toast, videoUrl: activity.video_url))) {
            cardContent
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let onRemove {
                Button(role: .destructive) {
                    Task { await onRemove() }
                } label: {
                    Label("Remove from group", systemImage: "trash")
                }
            }
        }
    }
    
    private var videoThumbnail: some View {
        Group {
            if let tb64 = activity.thumbnail_b64 {
                Base64ImageView(base64String: tb64)
                    .opacity(1)
            }
            else {
                PlaceholderImageView()
            }
        }
    }
    
    @ViewBuilder
    private func authorSection(_ author: User?) -> some View {
        let anonName = "Anonymous user"
        let currentUserId = authVM.user?.uid
        let displayName: String = {
            guard let author else { return anonName }
            return author.id == currentUserId ? "You" : author.displayName
        }()
        
        HStack(spacing: 8) {
            // Author avatar
            ProfileImage(user: author ?? User(id: "anonymous user", name: anonName), diam: 28)
            
            // "Shared by" text
            HStack(spacing: 4) {
                Text("Shared by")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            // Optional: Time indicator (if you have timestamp data)
            if let timestamp = sharedAt {
                Text(timeAgoString(from: timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.bottom, 4)
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Author section if needed
            if showAuthor {
                authorSection(author)
            }
            
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    if let player {
                        VideoPlayer(player: player)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 3)
                            .opacity(isActive ? 1 : 0)
                    }
                    if !showVideo {
                        // Cheap thumbnail while video offscreen if needed
                        videoThumbnail
                    }
                }
                .frame(width: 140, height: 140 * 16/9)
                .overlay(
                    VisibilityDetector { visible in
                        Task { await updateActivity(visible: visible) }
                    }
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text(activity.summary.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

                    Label(activity.summary.location, systemImage: "mappin.and.ellipse")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 6) {
                        CategoryPill(text: activity.summary.activity.title, icon: activity.summary.activity.icon)
                        CategoryPill(text: activity.summary.cost_level.displayName, icon: activity.summary.cost_level.icon)
                    }
                }
                .layoutPriority(1)
            }

            Text(activity.summary.summary)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                ForEach(activity.summary.tags.prefix(3), id: \.title) { tag in
                    CategoryPill(text: tag.title, icon: tag.icon)
                }
            }
        }
        .padding()
        .frame(width: UIScreen.main.bounds.width - 32)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
        .padding(.vertical, 8)
        .onDisappear {
            if let lp = looping {
                SmallPlayerPool.shared.recycle(lp.player)
                looping = nil
                player  = nil
            }
        }
        .background(
            GeometryReader { proxy in
                Color.clear
                    .preference(key: CardHeightKey.self,
                                value: proxy.size.height)
            }
        )
    }
    
//    @MainActor
//    private func updateActivity(visible: Bool) async {
//        guard visible else {
//            isActive = false
//            return
//        }
//        
//        if looping == nil {
//            let q = SmallPlayerPool.shared.obtain()
//            
//            let local = try? await VideoCache.shared.localFile(for: URL(string: activity.video_url)!)
//            guard let local else { return }
//            let asset = try? await AssetPool.shared.asset(for: local)
//            let item  = AVPlayerItem(asset: asset!)
//            
//            looping = LoopingPlayer(player: q, item: item)       // keeps looper
//            q.isMuted = true
//            q.play()
//            player = q                                           // drive VideoPlayer
//        }
//        isActive = true
//    }
    
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
                guard let remote = URL(string: activity.video_url) else { return }
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

}


struct CardHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        // take the max of all reported heights
        value = max(value, nextValue())
    }
}

// Helper for rounded corners
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    let mockDateIdea = DateIdea(
        title: "Sunset Picnic in the Park doing fun things with long title",
        summary: "Enjoy a romantic evening with your partner watching the sunset while having a picnic at a local park. Bring along wine, cheese, and fruits for a perfect evening.",
        sales_pitch: "Create an unforgettable evening under the fading sky with delicious treats and the one you love!",
        activity: Activity(title: "Outdoors", icon: "sun.max"),
        location: "Central Park, NYC",
        season: .summer,
        duration: "2-3 hours",
        cost_level: .low,
        required_items: ["Picnic blanket", "Wine and glasses", "Cheese and crackers", "Portable speaker"],
        tags: [Tag(title: "Romantic", icon: "heart.fill"), Tag(title: "relaxing", icon: "moon"), Tag(title: "nature", icon: "leaf")],
        suggested_itinerary: []
    )
    ActivityHistoryCard(activity: DateIdeaResponse(id: "", summary: mockDateIdea, title: mockDateIdea.title, description: "desc", thumbnail_b64: nil, thumbnail_url: nil, video_url: "", original_source_url: nil))
        .environmentObject(ToastManager())
}
