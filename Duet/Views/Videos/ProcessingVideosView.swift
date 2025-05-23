//
//  ProcessingVideosView.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 23/05/2025.
//

import SwiftUI

struct ProcessingVideosView: View {
    @ObservedObject var viewModel: DateIdeaViewModel
    
    var body: some View {
        if !viewModel.processingVideos.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Text("Processing Videos")
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Text("\(activeProcessingCount)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.appPrimary)
                        .cornerRadius(12)
                }
                
                // Processing cards
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.processingVideos) { video in
                        ProcessingVideoCard(
                            video: video,
                            onRemove: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    viewModel.removeProcessedVideo(video)
                                }
                            }
                        )
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
    }
    
    private var activeProcessingCount: Int {
        viewModel.processingVideos.filter { video in
            if case .processing = video.status { return true }
            return false
        }.count
    }
}

struct ProcessingVideoCard: View {
    @EnvironmentObject private var toast: ToastManager
    let video: ProcessingVideo
    let onRemove: () -> Void
    
    @State private var animationOffset: CGFloat = 0
    
    private var urlText: some View {
        Text(cleanUrl)
            .font(.system(.footnote, design: .monospaced))
            .fontWeight(.medium)
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .minimumScaleFactor(0.7)
            .foregroundStyle(.primary)
    }
    
    private var cardContent: some View {
        VStack(spacing: 0) {
            // Main content row
            HStack(spacing: 14) {
                // Status indicator
                if case .completed = video.status {
                    
                }
                else {
                    
                }
                statusIndicator
                
                VStack(alignment: .leading, spacing: 8) {
                    if case .completed(let response) = video.status {
                        // For completed: Title first, then URL
                        if let tb64 = response.thumbnail_b64 {
                            Base64ImageView(base64String: tb64, thumbWidth: 80)
                        }
                        else {
                            PlaceholderImageView(thumbWidth: 80)
                        }
                        
                        Text(response.summary.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .lineLimit(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .foregroundStyle(.primary)

                    } else {
                        // For processing/failed: URL first (original layout)
                        urlText
                    }
                    
                    // Status and timing row
                    HStack {
                        statusText
                        
                        Spacer()
                        
                        if case .processing = video.status {
                            
                        }
                        else {
                            processingTimer
                        }
                        
                    }
                }
                
                // Action button
                actionButton
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .onAppear {
            if case .processing = video.status {
                startLoadingAnimation()
            }
        }
    }
    
    var body: some View {
        Group {
            if case .completed(let response) = video.status {
                NavigationLink(destination: DateIdeaDetailView(
                    dateIdea: response,
                    viewModel: DateIdeaViewModel(toast: toast, videoUrl: response.video_url)
                )) {
                    cardContent
                }
                .buttonStyle(.plain)
            } else {
                cardContent
            }
        }
    }
    
    // MARK: - Status Indicator
    
    @ViewBuilder
    private var statusIndicator: some View {
        ZStack {
            Circle()
                .fill(statusColor.opacity(0.15))
                .frame(width: 40, height: 40)
            
            switch video.status {
            case .processing:
                LoadingSpinner(color: statusColor)
                    .frame(width: 20, height: 20)
                
            case .completed:
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(statusColor)
                
            case .failed:
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(statusColor)
            }
        }
    }
    
    // MARK: - Status Text
    
    @ViewBuilder
    private var statusText: some View {
        switch video.status {
        case .processing:
            HStack(spacing: 4) {
                Text("Processing")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Animated dots
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(Color.secondary)
                            .frame(width: 3, height: 3)
                            .opacity(animationOffset == CGFloat(index) ? 1.0 : 0.3)
                    }
                }
            }
            
        case .completed(let response):
            HStack {
                Image(systemName: "link")
                    .resizable()
                    .frame(width: 12, height: 12)
                Text(cleanUrl)
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(.secondary)
            }
            
        case .failed(let error):
            VStack(alignment: .leading, spacing: 2) {
                Text("Failed to process")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(statusColor)
                
                if !error.isEmpty && error != "Failed to process" {
                    Text(error)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
    
    // MARK: - Processing Timer
    
    @ViewBuilder
    private var processingTimer: some View {
        Text(formatDuration(liveProcessingDuration))
            .font(.caption2.monospacedDigit())
            .fontWeight(.medium)
            .foregroundColor(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(6)
    }
    
    // Live processing duration calculation
    private var liveProcessingDuration: TimeInterval {
        return video.processingDuration
    }
    
    // MARK: - Action Button
    
    @ViewBuilder
    private var actionButton: some View {
        Button(action: onRemove) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(.gray.opacity(0.5))
        }
    }
    
    // MARK: - Computed Properties
    
    private var statusColor: Color {
        switch video.status {
        case .processing: return .appPrimary
        case .completed: return Color(hex: "#456455")
        case .failed: return .red
        }
    }
    
    private var cardBackground: some View {
        switch video.status {
        case .processing:
            return Color.white
        case .completed:
            return Color.green.opacity(0.1)
        case .failed:
            return Color.red.opacity(0.05)
        }
    }
    
    // Clean URL without truncation but still readable
    private var cleanUrl: String {
        let displayUrl = video.url
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "www.", with: "")
        
        // Only truncate if extremely long (>80 chars)
        if displayUrl.count > 80 {
            let start = displayUrl.prefix(20)
            let end = displayUrl.suffix(20)
            return "\(start)...\(end)"
        }
        
        return displayUrl
    }
    
    // MARK: - Helper Methods
    
    private func startLoadingAnimation() {
        withAnimation(
            .linear(duration: 1.5)
            .repeatForever(autoreverses: false)
        ) {
            animationOffset = 2
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let seconds = Int(duration)
        if seconds < 60 {
            return "\(seconds)s"
        } else {
            let minutes = seconds / 60
            let remainingSeconds = seconds % 60
            return "\(minutes):\(String(format: "%02d", remainingSeconds))"
        }
    }
}

// MARK: - Loading Spinner Component

struct LoadingSpinner: View {
    let color: Color
    @State private var isAnimating = false
    
    var body: some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(
                color,
                style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
            )
            .rotationEffect(.degrees(isAnimating ? 360 : 0))
            .animation(
                .linear(duration: 1.0)
                .repeatForever(autoreverses: false),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
            .fixedSize()
    }
}



// MARK: - Preview

struct ProcessingVideosView_Previews: PreviewProvider {
    static var previews: some View {
        let toast = ToastManager()
        let viewModel = DateIdeaViewModel(toast: toast)
        
        // Add sample processing videos
        viewModel.processingVideos = [
            ProcessingVideo(
                url: "https://www.tiktok.com/@user/video/1234567890",
                startTime: Date().addingTimeInterval(-10),
                status: .processing
            ),
            ProcessingVideo(
                url: "https://www.instagram.com/reel/ABC123DEF456/?query=buildingmyquery&anothervalue=123",
                startTime: Date().addingTimeInterval(-30),
                endTime: Date().addingTimeInterval(30),
                status: .completed(
                    DateIdeaResponse(
                        id: UUID().uuidString,
                        summary: DateIdea(
                            title: "Romantic Dinner out on the town with long night",
                            summary: "A lovely evening out",
                            sales_pitch: "Perfect date!",
                            activity: Activity(title: "Outdoors", icon: "leaf"),
                            location: "Paris",
                            season: .summer,
                            duration: "2 hours",
                            cost_level: .medium,
                            required_items: [],
                            tags: []
                        ),
                        title: "Dinner",
                        description: "Romantic dinner",
                        thumbnail_b64: nil,
                        thumbnail_url: nil,
                        video_url: "test",
                        original_source_url: ""
                    )
                )
            ),
            ProcessingVideo(
                url: "https://www.youtube.com/watch?v=invalidvideo",
                startTime: Date().addingTimeInterval(-45),
                endTime: Date().addingTimeInterval(-35),
                status: .failed("Invalid video format")
            ),
            ProcessingVideo(
                url: "https://www.youtube.com/watch?v=invalidvideosuperlongvideowith even more textandmoretext",
                startTime: Date().addingTimeInterval(-45),
                endTime: Date(),
                status: .failed("Invalid video format")
            )
        ]
        
        return ProcessingVideosView(viewModel: viewModel)
            .environmentObject(toast)
            .padding()
            .withAppBackground()
    }
}

//#Preview {
//    ProcessingVideosView()
//}
