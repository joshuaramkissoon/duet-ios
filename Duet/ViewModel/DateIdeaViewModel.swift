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
    @Published var isUpdatingItinerary: Bool = false
    @Published var isUpdatingVisibility: Bool = false
    
    private var toast: ToastManager
    private weak var activityVM: ActivityHistoryViewModel?
    private var processingManager: ProcessingManager?
    private let creditService = CreditService.shared
    
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
        
        // Pre-emptive credit check with UI handling
        if !creditService.checkCreditsForAction(creditsRequired: 1) {
            toast.error("Not enough credits to process video")
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
                    // Optimistically deduct credits since the request succeeded
                    creditService.deductCredits(1)
                    toast.success(response?.message ?? "Video processing started")
                }
            } catch {
                await MainActor.run {
                    // Check if this is a credit error
                    if creditService.handleInsufficientCreditsError(error) {
                        toast.error("Not enough credits to process video")
                    } else if let processingError = error as? ProcessingError {
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
                    toast.success("Recipe updated!")
                    
                    // Notify other parts of the app that this idea's metadata changed
                    if let updatedIdea = dateIdeaResponse {
                        NotificationCenter.default.post(
                            name: .ideaMetadataUpdated,
                            object: nil,
                            userInfo: ["ideaId": ideaId, "updatedIdea": updatedIdea]
                        )
                    }
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
    
    // MARK: - Itinerary Update Methods
    
    /// Updates itinerary for the current idea
    /// - Parameters:
    ///   - itineraryItems: The updated itinerary items
    ///   - requiredItems: The updated required items/equipment list
    ///   - groupId: The group ID if this is a shared group idea, nil for personal ideas
    func updateItinerary(
        ideaId: String,
        itineraryItems: [ItineraryItem],
        requiredItems: [String],
        groupId: String? = nil
    ) {
        isUpdatingItinerary = true
        toast.loading("Saving itinerary")
        
        Task {
            do {
                try await ItineraryService.shared.updateItinerary(
                    ideaId: ideaId,
                    groupId: groupId,
                    itineraryItems: itineraryItems,
                    requiredItems: requiredItems
                )
                
                await MainActor.run {
                    isUpdatingItinerary = false
                    updateLocalItineraryData(items: itineraryItems, equipment: requiredItems)
                    toast.success("Itinerary updated!")
                    
                    // Notify other parts of the app that this idea's metadata changed
                    if let updatedIdea = dateIdeaResponse {
                        NotificationCenter.default.post(
                            name: .ideaMetadataUpdated,
                            object: nil,
                            userInfo: ["ideaId": ideaId, "updatedIdea": updatedIdea]
                        )
                    }
                }
            } catch {
                await MainActor.run {
                    isUpdatingItinerary = false
                    toast.error("Failed to update itinerary: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Handles itinerary edit cancellation
    func cancelItineraryEdit() {
        
    }
    
    // MARK: - Private Helper Methods
    
    /// Updates local data after successful server update
    private func updateLocalRecipeData(metadata: RecipeMetadata, items: [String]) {
        guard var response = dateIdeaResponse else { return }
        
        // Update the local data to reflect the changes IN PLACE
        // This preserves object identity to prevent NavigationLink invalidation
        response.summary.recipe_metadata = metadata
        response.summary.required_items = items
        
        dateIdeaResponse = response
        dateIdea = response.summary
        
        print("🔄 Updated recipe data locally without changing object identity")
    }
    
    /// Updates local data after successful itinerary update
    private func updateLocalItineraryData(items: [ItineraryItem], equipment: [String]) {
        guard var response = dateIdeaResponse else { return }
        
        // Update the local data to reflect the changes IN PLACE
        // This preserves object identity to prevent NavigationLink invalidation
        response.summary.suggested_itinerary = items
        response.summary.required_items = equipment
        
        dateIdeaResponse = response
        dateIdea = response.summary
        
        print("🔄 Updated itinerary data locally without changing object identity")
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
    
    /// Updates the visibility of an idea
    /// - Parameters:
    ///   - ideaId: The ID of the idea to update
    ///   - isPublic: The new visibility state
    ///   - groupId: Optional group ID if this is a group idea
    func updateVisibility(ideaId: String, isPublic: Bool, groupId: String? = nil) {
        Task {
            await MainActor.run {
                isUpdatingVisibility = true
            }
            
            do {
                let endpoint = NetworkClient.shared.baseUrl + "/ideas/\(ideaId)"
                let body = VisibilityUpdateRequest(isPublic: isPublic)
                
                let _: EmptyResponse = try await NetworkClient.shared.patchJSON(url: endpoint, body: body)
                
                await MainActor.run {
                    // Update local state immediately
                    if var response = dateIdeaResponse {
                        response = DateIdeaResponse(
                            id: response.id,
                            summary: response.summary,
                            title: response.title,
                            description: response.description,
                            thumbnail_b64: response.thumbnail_b64,
                            thumbnail_url: response.thumbnail_url,
                            video_url: response.video_url,
                            videoMetadata: response.videoMetadata,
                            original_source_url: response.original_source_url,
                            user_id: response.user_id,
                            user_name: response.user_name,
                            created_at: response.created_at,
                            isPublic: isPublic
                        )
                        self.dateIdeaResponse = response
                        self.dateIdea = response.summary
                    }
                    
                    isUpdatingVisibility = false
                    toast.success(isPublic ? "Idea is now public" : "Idea is now private")
                    
                    // Notify other parts of the app that an idea's visibility changed
                    NotificationCenter.default.post(
                        name: .ideaVisibilityUpdated,
                        object: nil,
                        userInfo: ["ideaId": ideaId, "isPublic": isPublic]
                    )
                }
            } catch {
                await MainActor.run {
                    isUpdatingVisibility = false
                    toast.error("Failed to update visibility")
                }
            }
        }
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
    var summary: DateIdea
    let title: String
    let description: String
    let thumbnail_b64: String?
    let thumbnail_url: String?
    let video_url: String?
    let videoMetadata: VideoMetadata?
    let original_source_url: String?
    let user_id: String?
    let user_name: String?
    let created_at: Float?
    let isPublic: Bool
    
    /// Returns the CloudFront CDN URL for the video
    var cloudFrontVideoURL: String {
        guard let video_url = video_url else { return "" }
        return URLHelpers.convertToCloudFrontURL(video_url)
    }
    
    func toGroupIdea() -> GroupIdea {
        return GroupIdea(id: id, dateIdea: summary, videoUrl: cloudFrontVideoURL, originalSourceUrl: original_source_url, thumbnailB64: thumbnail_b64, videoMetadata: videoMetadata, addedBy: "me", addedAt: Date())
    }
    
    static func fromGroupIdea(_ idea: GroupIdea) -> DateIdeaResponse {
        return DateIdeaResponse(id: idea.id, summary: idea.dateIdea, title: idea.dateIdea.title, description: idea.dateIdea.summary, thumbnail_b64: idea.thumbnailB64, thumbnail_url: nil, video_url: idea.cloudFrontVideoURL, videoMetadata: idea.videoMetadata, original_source_url: idea.originalSourceUrl, user_id: nil, user_name: nil, created_at: nil, isPublic: false)
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
        case isPublic = "public"
    }
}

// MARK: - Request Models

struct VisibilityUpdateRequest: Codable {
    let isPublic: Bool
    
    enum CodingKeys: String, CodingKey {
        case isPublic = "public"
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let ideaVisibilityUpdated = Notification.Name("ideaVisibilityUpdated")
    static let ideaMetadataUpdated = Notification.Name("ideaMetadataUpdated")
    static let ideaDeleted = Notification.Name("ideaDeleted")
}
