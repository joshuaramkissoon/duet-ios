//
//  ActivityViewModels.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 17/05/2025.
//

import Foundation
import Combine

class ActivityHistoryViewModel: ObservableObject {
    @Published var activities: [DateIdeaResponse] = []
    @Published var isLoading = false
    @Published var error: Error? = nil
    @Published var searchQuery: String = ""
    @Published var searchResults: [DateIdeaResponse] = []
    @Published var isSearching: Bool = false
    @Published var hasSearched: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init(activities: [DateIdeaResponse] = [], isLoading: Bool = false, error: Error? = nil) {
        self.activities = activities
        self.isLoading = isLoading
        self.error = error
        loadActivities()
        setupNotificationListeners()
    }
    
    private func setupNotificationListeners() {
        // Listen for visibility updates
        NotificationCenter.default.publisher(for: .ideaVisibilityUpdated)
            .sink { [weak self] notification in
                guard let self = self,
                      let ideaId = notification.userInfo?["ideaId"] as? String,
                      let isPublic = notification.userInfo?["isPublic"] as? Bool else { return }
                
                self.updateIdeaVisibility(ideaId: ideaId, isPublic: isPublic)
            }
            .store(in: &cancellables)
        
        // Listen for metadata updates
        NotificationCenter.default.publisher(for: .ideaMetadataUpdated)
            .sink { [weak self] notification in
                guard let self = self,
                      let ideaId = notification.userInfo?["ideaId"] as? String,
                      let updatedIdea = notification.userInfo?["updatedIdea"] as? DateIdeaResponse else { return }
                
                self.updateIdeaMetadata(ideaId: ideaId, updatedIdea: updatedIdea)
            }
            .store(in: &cancellables)
    }
    
    private func updateIdeaVisibility(ideaId: String, isPublic: Bool) {
        // Update in main activities array
        if let index = activities.firstIndex(where: { $0.id == ideaId }) {
            var updatedActivity = activities[index]
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
            activities[index] = updatedActivity
            print("🔄 ActivityHistoryViewModel: Updated visibility for idea \(ideaId): \(isPublic ? "Public" : "Private")")
        }
        
        // Update in search results array if it exists there too
        if let searchIndex = searchResults.firstIndex(where: { $0.id == ideaId }) {
            var updatedActivity = searchResults[searchIndex]
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
            searchResults[searchIndex] = updatedActivity
        }
    }
    
    private func updateIdeaMetadata(ideaId: String, updatedIdea: DateIdeaResponse) {
        // Update in main activities array
        if let index = activities.firstIndex(where: { $0.id == ideaId }) {
            activities[index] = updatedIdea
            print("🔄 ActivityHistoryViewModel: Updated metadata for idea \(ideaId)")
        }
        
        // Update in search results array if it exists there too
        if let searchIndex = searchResults.firstIndex(where: { $0.id == ideaId }) {
            searchResults[searchIndex] = updatedIdea
        }
    }
    
    func loadActivities() {
        isLoading = true
        error = nil
        
        NetworkClient.shared.getRecentActivities { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                switch result {
                case .success(let activities):
                    self.activities = activities
                case .failure(let error):
                    self.error = error
                    print("Error loading activities: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func performSearch() {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isLoading = true
        isSearching = true
        hasSearched = true
        error = nil

        NetworkClient.shared.searchActivities(query: trimmed) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                self.isSearching = false
                switch result {
                case .success(let ideas):
                    self.searchResults = ideas
                case .failure(let error):
                    self.error = error
                }
            }
        }
    }
}

class ActivityDetailViewModel: ObservableObject {
    @Published var dateIdea: DateIdeaResponse? = nil
    @Published var isLoading = false
    @Published var error: Error? = nil
    
    func loadActivity(id: String) {
        isLoading = true
        error = nil
        
        NetworkClient.shared.getActivity(id: id) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                
                switch result {
                case .success(let dateIdea):
                    self.dateIdea = dateIdea
                case .failure(let error):
                    self.error = error
                    print("Error loading activity details: \(error.localizedDescription)")
                }
            }
        }
    }
}
