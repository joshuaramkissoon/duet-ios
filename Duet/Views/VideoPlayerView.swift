//
//  VideoPlayerView.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 18/05/2025.
//

import Foundation
import AVKit
import Combine
import SwiftUI

struct VideoPlayerView: UIViewControllerRepresentable {
    let player: AVPlayer
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        controller.view.layer.cornerRadius = 16
        controller.view.layer.masksToBounds = true
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}
}

/// Grey rounded-rect that shows a subtle diagonal shimmer.
struct ShimmerPlaceholder: View {
    @State private var animate = false
    var cornerRadius: CGFloat = 12
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.gray.opacity(0.25))                           // base tint
            .overlay(                                                 // moving highlight
                LinearGradient(
                    gradient: Gradient(colors: [
                        .clear,
                        .white.opacity(0.55),
                        .clear
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .rotationEffect(.degrees(30))
                .offset(x: animate ? 350 : -350)                      // slide across
            )
            .mask(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .onAppear {
                withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                    animate = true
                }
            }
    }
}


struct CachedVideoView: View {
    let remoteURL: URL
    let aspectRatio: CGFloat
    let width: CGFloat
    let thumbnailB64: String?
    
    init(remoteURL: URL, thumbnailB64: String? = nil, aspectRatio: CGFloat = 16/9, width: CGFloat = 140, player: AVPlayer? = nil, isReady: Bool = false, statusCancellable: AnyCancellable? = nil) {
        self.remoteURL = remoteURL
        self.aspectRatio = aspectRatio
        self.width = width
        self.player = player
        self.isReady = isReady
        self.thumbnailB64 = thumbnailB64
        self.statusCancellable = statusCancellable
    }
    
    @State private var player: AVPlayer?
    @State private var isReady = false
    @State private var statusCancellable: AnyCancellable?
    @State private var loadingTask: Task<Void, Never>?

    
    var body: some View {
        ZStack {
            if let player {
                VideoPlayer(player: player)
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                    .frame(width: self.width, height: self.width / self.aspectRatio)
                    .onAppear { player.play() }
                    .onDisappear {
                        player.pause()
                        player.replaceCurrentItem(with: nil)
                        statusCancellable?.cancel()
                        statusCancellable = nil          // stop observing
                        loadingTask?.cancel()
                        loadingTask = nil
                    }
            }
            
            if !isReady {                               // thumbnail until ready
                VStack {
                    if let tb64 = thumbnailB64 {
                        Base64ImageView(base64String: tb64, thumbWidth: self.width, thumbHeight: self.width / self.aspectRatio)
                    }
                    else {
                        PlaceholderImageView(thumbWidth: self.width, thumbHeight: self.width / self.aspectRatio)
                    }
                }
                .frame(width: self.width, height: self.width / self.aspectRatio)
                .transition(.opacity)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .task {
            loadingTask = Task {
                do {
                    // 1. local cache
                    let local = try await VideoCache.shared.localFile(for: remoteURL)
                    // 2. shared asset
                    let asset = try await AssetPool.shared.asset(for: local)
                    // 3. fresh item for *this* view
                    let item  = AVPlayerItem(asset: asset)
                    
                    // 4. observe status → hide shimmer
                    statusCancellable = item.publisher(for: \.status)
                        .receive(on: DispatchQueue.main)
                        .sink { status in
                            if status == .readyToPlay {
                                withAnimation(.easeIn(duration: 0.2)) {
                                    isReady = true
                                }
                            }
                        }
                    
                    let p = AVPlayer(playerItem: item)
                    p.isMuted = false
                    player = p
                } catch {
                    print("❌ Video load error:", error)
                }
            }
        }
    }
}
