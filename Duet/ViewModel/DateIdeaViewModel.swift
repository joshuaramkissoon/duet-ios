//
//  DateIdeaViewModel.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 17/05/2025.
//

import Foundation
import Combine

class DateIdeaViewModel: ObservableObject {
    @Published var urlText: String = ""
    @Published var videoUrl: String = ""
    @Published var dateIdea: DateIdea? = nil
    @Published var dateIdeaResponse: DateIdeaResponse? = nil
    @Published var processingVideos: [ProcessingVideo] = []
    
    private let toast: ToastManager
    private weak var activityVM: ActivityHistoryViewModel?
    private var cancellables = Set<AnyCancellable>()
    
    init(toast: ToastManager, activityHistoryVM: ActivityHistoryViewModel? = nil, videoUrl: String = "", urlText: String = "") {
        self.toast = toast
        self.videoUrl = videoUrl
        self.urlText  = urlText
        self.activityVM = activityHistoryVM
        setupAutoCleanup()
    }
    
    private func sortProcessingVideos() {
        processingVideos.sort { a, b in
            let aIsProcessing = (a.status == .processing)
            let bIsProcessing = (b.status == .processing)
            
            // 1) processing first
            if aIsProcessing != bIsProcessing {
                return aIsProcessing
            }
            
            // 2) if both processing, newest startTime first
            if aIsProcessing {
                return a.startTime > b.startTime
            }
            
            // 3) otherwise, newest endTime first
            //    (if endTime ever nil, push it to the back)
            let aEnd = a.endTime ?? .distantPast
            let bEnd = b.endTime ?? .distantPast
            return aEnd > bEnd
        }
        print("After sorting: \(processingVideos)")
    }
    
    func summariseVideo() {
        // Validate URL input
        let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let _ = URL(string: trimmed) else {
            toast.error("Please enter a valid URL")
            return
        }
        
        // Format URL if needed
        let formattedUrl = formatUrl(trimmed)
        
        // Create processing video entry
        let processingVideo = ProcessingVideo(
            url: formattedUrl,
            startTime: Date(),
            status: .processing
        )
        
        // Add to processing list
        processingVideos.insert(processingVideo, at: 0)
        
        resetUrlInput()
        
        // Update UI state
        toast.loading("Processing video")
        
        // Make the API call using NetworkClient
        NetworkClient.shared.summarizeVideo(url: formattedUrl) { [weak self] result in
            print("GOT RESULT: \(result)")
            DispatchQueue.main.async {
                self?.handleVideoProcessingResult(videoId: processingVideo.id, result: result)
            }
        }
    }
    
    func removeProcessedVideo(_ video: ProcessingVideo) {
        processingVideos.removeAll { $0.id == video.id }
    }
    
    private func setupAutoCleanup() {
        // Clean up completed/failed videos after 30 seconds
        Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.cleanupOldProcessedVideos()
            }
            .store(in: &cancellables)
    }
    
    private func cleanupOldProcessedVideos() {
        let cutoffTime = Date().addingTimeInterval(-120) // 2 mins ago
        
        processingVideos.removeAll { video in
            switch video.status {
            case .processing:
                return false // Keep processing videos
            case .completed, .failed:
                if let end = video.endTime {
                    return end < cutoffTime // Remove old completed/failed videos
                }
                return false
            }
        }
    }
    
    private func handleVideoProcessingResult(videoId: UUID, result: Result<DateIdeaResponse, NetworkError>) {
        guard let index = processingVideos.firstIndex(where: { $0.id == videoId }) else { return }
        
        switch result {
        case .success(let response):
            processingVideos[index].status = .completed(response)
            processingVideos[index].endTime = Date()
            
            // Set as latest result
            dateIdeaResponse = response
            dateIdea = response.summary
            videoUrl = response.video_url
            
            // Refresh activity history
            activityVM?.loadActivities()
            
            // Show success toast
            toast.success("✨ \(response.summary.title)")
            
        case .failure(let error):
            processingVideos[index].status = .failed(error.localizedDescription)
            processingVideos[index].endTime = Date()
            toast.error("Failed to process video")
        }
        sortProcessingVideos()
    }

    // MARK: - Helper Methods

    private func formatUrl(_ urlString: String) -> String {
        if !urlString.lowercased().hasPrefix("http") {
            return "https://\(urlString)"
        }
        return urlString
    }

    private func handleSuccessResponse(_ response: DateIdeaResponse) {
        dateIdeaResponse = response
        toast.success(response.summary.title)
        dateIdea = response.summary
        videoUrl = response.video_url
        activityVM?.loadActivities()
    }

    private func handleError(_ error: NetworkError) {
        toast.error("Oops! Something went wrong.")
    }
    
    func resetUrlInput() {
        urlText = ""
    }
}

struct DateIdeaResponse: Codable, Identifiable {
    let id: String
    let summary: DateIdea
    let title: String
    let description: String
    let thumbnail_b64: String?
    let thumbnail_url: String?
    let video_url: String
    let original_source_url: String?
    
    func toGroupIdea() -> GroupIdea {
        return GroupIdea(id: id, dateIdea: summary, videoUrl: video_url, originalSourceUrl: original_source_url, thumbnailB64: thumbnail_b64, addedBy: "me", addedAt: Date())
    }
    
    static func fromGroupIdea(_ idea: GroupIdea) -> DateIdeaResponse {
        return DateIdeaResponse(id: idea.id, summary: idea.dateIdea, title: idea.dateIdea.title, description: idea.dateIdea.summary, thumbnail_b64: idea.thumbnailB64, thumbnail_url: nil, video_url: idea.videoUrl, original_source_url: idea.originalSourceUrl)
    }
}
