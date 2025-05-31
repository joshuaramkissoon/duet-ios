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
    @Published var isUpdatingRecipe: Bool = false
    
    private var toast: ToastManager
    private weak var activityVM: ActivityHistoryViewModel?
    private var processingManager: ProcessingManager?
    
    init(toast: ToastManager, activityHistoryVM: ActivityHistoryViewModel? = nil, videoUrl: String = "", urlText: String = "") {
        self.toast = toast
        self.videoUrl = videoUrl
        self.urlText  = urlText
        self.activityVM = activityHistoryVM
        // ProcessingManager will be set externally to avoid MainActor issues
    }
    
    /// Updates the toast manager - useful when the environment toast manager becomes available
    func updateToastManager(_ newToast: ToastManager) {
        self.toast = newToast
    }
    
    func setProcessingManager(_ manager: ProcessingManager) {
        self.processingManager = manager
    }
    
    /// Sets the current date idea response for tracking updates
    func setCurrentDateIdea(_ response: DateIdeaResponse) {
        dateIdeaResponse = response
        dateIdea = response.summary
    }
    
    /// Fetches the latest activity data from the backend and updates if different
    /// This runs in the background without showing a loading state
    func fetchLatestActivityData(for activityId: String) {
        Task {
            do {
                let latestData = try await NetworkClient.shared.getActivity(id: activityId)
                
                await MainActor.run {
                    // Only update if the data has actually changed
                    if let currentData = dateIdeaResponse, !areEqual(currentData, latestData) {
                        dateIdeaResponse = latestData
                        dateIdea = latestData.summary
                        print("🔄 Updated activity data from backend")
                    }
                }
            } catch {
                // Silently fail for background fetch - don't show errors to user
                print("⚠️ Background fetch failed for activity \(activityId): \(error.localizedDescription)")
            }
        }
    }
    
    /// Compares two DateIdeaResponse objects to check if they're meaningfully different
    private func areEqual(_ current: DateIdeaResponse, _ latest: DateIdeaResponse) -> Bool {
        // Compare key fields that might change
        return current.title == latest.title &&
               current.description == latest.description &&
               current.summary.summary == latest.summary.summary &&
               current.summary.duration == latest.summary.duration &&
               current.summary.location == latest.summary.location &&
               current.summary.required_items == latest.summary.required_items &&
               current.summary.recipe_metadata?.ingredients == latest.summary.recipe_metadata?.ingredients &&
               current.summary.recipe_metadata?.instructions == latest.summary.recipe_metadata?.instructions &&
               current.summary.suggested_itinerary?.count == latest.summary.suggested_itinerary?.count
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
        
        resetUrlInput()
        
        // Use ProcessingManager for new async processing
        Task {
            do {
                let response = try await processingManager?.processVideo(url: formattedUrl)
                await MainActor.run {
                    toast.success(response?.message ?? "Video processing started")
                }
            } catch {
                await MainActor.run {
                    if let processingError = error as? ProcessingError {
                        toast.error(processingError.localizedDescription)
                    } else {
                        toast.error("Failed to start video processing")
                    }
                }
            }
        }
    }
    
    // MARK: - Recipe Update Methods
    
    /// Updates recipe metadata for the current idea
    /// - Parameters:
    ///   - recipeMetadata: The updated recipe metadata
    ///   - requiredItems: The updated required items/equipment list
    ///   - groupId: The group ID if this is a shared group idea, nil for personal ideas
    func updateRecipe(
        ideaId: String,
        recipeMetadata: RecipeMetadata,
        requiredItems: [String],
        groupId: String? = nil
    ) {
        isUpdatingRecipe = true
        toast.loading("Saving recipe")
        
        Task {
            do {
                try await RecipeService.shared.updateRecipeMetadata(
                    ideaId: ideaId,
                    groupId: groupId,
                    recipeMetadata: recipeMetadata,
                    requiredItems: requiredItems
                )
                
                await MainActor.run {
                    isUpdatingRecipe = false
                    updateLocalRecipeData(metadata: recipeMetadata, items: requiredItems)
                    toast.success("Recipe updated successfully!")
                }
            } catch {
                await MainActor.run {
                    isUpdatingRecipe = false
                    toast.error("Failed to update recipe: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Handles recipe edit cancellation
    func cancelRecipeEdit() {
        
    }
    
    // MARK: - Private Helper Methods
    
    /// Updates local data after successful server update
    private func updateLocalRecipeData(metadata: RecipeMetadata, items: [String]) {
        guard var response = dateIdeaResponse else { return }
        
        // Update the local data to reflect the changes
        var updatedSummary = response.summary
        updatedSummary.recipe_metadata = metadata
        updatedSummary.required_items = items
        
        // Create updated response
        let updatedResponse = DateIdeaResponse(
            id: response.id,
            summary: updatedSummary,
            title: response.title,
            description: response.description,
            thumbnail_b64: response.thumbnail_b64,
            thumbnail_url: response.thumbnail_url,
            video_url: response.video_url,
            videoMetadata: response.videoMetadata,
            original_source_url: response.original_source_url,
            user_id: response.user_id,
            user_name: response.user_name,
            created_at: response.created_at
        )
        
        dateIdeaResponse = updatedResponse
        dateIdea = updatedSummary
    }

    // MARK: - Helper Methods

    private func formatUrl(_ urlString: String) -> String {
        if !urlString.lowercased().hasPrefix("http") {
            return "https://\(urlString)"
        }
        return urlString
    }
    
    func resetUrlInput() {
        urlText = ""
    }
}

struct VideoMetadata: Codable {
    let ratio_width: Int
    let ratio_height: Int
    let author_handle: String?
    let author_url: String?
    let platform: String?
    
    // Custom decoding to support both snake_case and camelCase keys
    private enum CodingKeys: String, CodingKey {
        case ratio_width
        case ratio_height
        case ratioWidth
        case ratioHeight
        case author_handle
        case authorHandle
        case author_url
        case authorUrl
        case platform
    }
    
    init(ratio_width: Int, ratio_height: Int, author_handle: String? = nil, author_url: String? = nil, platform: String? = nil) {
        self.ratio_width = ratio_width
        self.ratio_height = ratio_height
        self.author_handle = author_handle
        self.author_url = author_url
        self.platform = platform
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let w = try container.decodeIfPresent(Int.self, forKey: .ratio_width),
           let h = try container.decodeIfPresent(Int.self, forKey: .ratio_height) {
            ratio_width  = w
            ratio_height = h
        } else {
            ratio_width  = try container.decode(Int.self, forKey: .ratioWidth)
            ratio_height = try container.decode(Int.self, forKey: .ratioHeight)
        }
        if let author_handle = try container.decodeIfPresent(String.self, forKey: .author_handle),
           let author_url = try container.decodeIfPresent(String.self, forKey: .author_url) {
            self.author_handle = author_handle
            self.author_url = author_url
        } else {
            author_handle = try container.decodeIfPresent(String.self, forKey: .authorHandle)
            author_url = try container.decodeIfPresent(String.self, forKey: .authorUrl)
        }
        platform = try container.decodeIfPresent(String.self, forKey: .platform)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(ratio_width,  forKey: .ratio_width)
        try container.encode(ratio_height, forKey: .ratio_height)
        try container.encodeIfPresent(author_handle, forKey: .author_handle)
        try container.encodeIfPresent(author_url, forKey: .author_url)
        try container.encodeIfPresent(platform, forKey: .platform)
    }
    
    var aspectRatio: CGFloat {
        guard ratio_height != 0 else { return 1 }
        return CGFloat(ratio_width) / CGFloat(ratio_height)
    }
    
    var isPortrait: Bool { ratio_height > ratio_width }
    var isLandscape: Bool { ratio_width > ratio_height }
}

struct DateIdeaResponse: Codable, Identifiable {
    let id: String
    let summary: DateIdea
    let title: String
    let description: String
    let thumbnail_b64: String?
    let thumbnail_url: String?
    let video_url: String
    let videoMetadata: VideoMetadata?
    let original_source_url: String?
    let user_id: String?
    let user_name: String?
    let created_at: Float?
    
    /// Returns the CloudFront CDN URL for the video
    var cloudFrontVideoURL: String {
        return URLHelpers.convertToCloudFrontURL(video_url)
    }
    
    func toGroupIdea() -> GroupIdea {
        return GroupIdea(id: id, dateIdea: summary, videoUrl: cloudFrontVideoURL, originalSourceUrl: original_source_url, thumbnailB64: thumbnail_b64, videoMetadata: videoMetadata, addedBy: "me", addedAt: Date())
    }
    
    static func fromGroupIdea(_ idea: GroupIdea) -> DateIdeaResponse {
        return DateIdeaResponse(id: idea.id, summary: idea.dateIdea, title: idea.dateIdea.title, description: idea.dateIdea.summary, thumbnail_b64: idea.thumbnailB64, thumbnail_url: nil, video_url: idea.cloudFrontVideoURL, videoMetadata: idea.videoMetadata, original_source_url: idea.originalSourceUrl, user_id: nil, user_name: nil, created_at: nil)
    }

    private enum CodingKeys: String, CodingKey {
        case id, summary, title, description
        case thumbnail_b64 = "thumbnail_b64"
        case thumbnail_url = "thumbnail_url"
        case video_url = "video_url"
        case videoMetadata = "video_metadata"
        case original_source_url = "original_source_url"
        case user_id = "user_id"
        case user_name = "user_name"
        case created_at = "created_at"
    }
}
