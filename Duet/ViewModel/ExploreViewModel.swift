//
//  ExploreViewModel.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 19/05/2025.
//

import Foundation
import Combine

class ExploreViewModel: ObservableObject {
    // Input
    @Published var query: String = ""
    @Published var isSearchFieldVisible: Bool = false
    
    // Output - Feed State
    @Published private(set) var feedItems: [DateIdeaResponse] = []
    @Published private(set) var currentPage: Int = 1
    @Published private(set) var hasMorePages: Bool = false
    @Published private(set) var isLoadingFeed: Bool = false
    
    // Output - Search State
    @Published private(set) var searchResults: [DateIdeaResponse] = []
    @Published private(set) var isSearching: Bool = false
    @Published private(set) var hasSearched: Bool = false
    
    // General State
    @Published private(set) var errorMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    private let pageSize = 20
    
    // Preset search queries
    let presetQueries = [
        "🍷 Date night ideas",
        "🏃‍♂️ Active adventures", 
        "🍳 Cooking together",
        "🌅 Outdoor activities",
        "🏠 Cozy indoor fun",
        "🎨 Creative projects",
        "🌃 Nightlife & bars",
        "🧘‍♀️ Relaxing activities"
    ]
    
    // Computed property to determine what to display
    var displayItems: [DateIdeaResponse] {
        return isSearchActive ? searchResults : feedItems
    }
    
    var isSearchActive: Bool {
        return isSearchFieldVisible && !query.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var isLoading: Bool {
        return isSearchActive ? isSearching : isLoadingFeed
    }
    
    init() {
        loadInitialFeed()
        setupSearchDebouncing()
        setupNotificationListeners()
    }
    
    private func setupSearchDebouncing() {
        $query
            .debounce(for: .milliseconds(700), scheduler: RunLoop.main) // Wait 0.7s after user stops typing
            .removeDuplicates()
            .sink { [weak self] searchText in
                let trimmed = searchText.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty {
                    self?.clearSearch()
                } else if trimmed.count >= 3 { // Require at least 3 characters
                    self?.performSearch()
                }
            }
            .store(in: &cancellables)
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
        
        // Listen for idea deletions
        NotificationCenter.default.publisher(for: .ideaDeleted)
            .sink { [weak self] notification in
                guard let self = self,
                      let ideaId = notification.userInfo?["ideaId"] as? String else { return }
                
                self.removeDeletedIdea(ideaId: ideaId)
            }
            .store(in: &cancellables)
        
        // Listen for user blocking events
        NotificationCenter.default.publisher(for: .userBlocked)
            .sink { [weak self] notification in
                guard let self = self,
                      let blockedUserId = notification.userInfo?["blockedUserId"] as? String else { return }
                
                self.removeIdeasFromBlockedUser(userId: blockedUserId)
            }
            .store(in: &cancellables)
        
        // Listen for user unblocking events
        NotificationCenter.default.publisher(for: .userUnblocked)
            .sink { [weak self] notification in
                guard let self = self,
                      let unblockedUserId = notification.userInfo?["unblockedUserId"] as? String else { return }
                
                // When a user is unblocked, we should refresh the feed to potentially show their content again
                self.refresh()
            }
            .store(in: &cancellables)
    }
    
    private func updateIdeaVisibility(ideaId: String, isPublic: Bool) {
        // Update in feed items array
        if let index = feedItems.firstIndex(where: { $0.id == ideaId }) {
            var updatedActivity = feedItems[index]
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
            feedItems[index] = updatedActivity
            print("🔄 ExploreViewModel: Updated visibility for idea \(ideaId): \(isPublic ? "Public" : "Private")")
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
        // Update in feed items array
        if let index = feedItems.firstIndex(where: { $0.id == ideaId }) {
            feedItems[index] = updatedIdea
            print("🔄 ExploreViewModel: Updated metadata for idea \(ideaId)")
        }
        
        // Update in search results array if it exists there too
        if let searchIndex = searchResults.firstIndex(where: { $0.id == ideaId }) {
            searchResults[searchIndex] = updatedIdea
        }
    }
    
    private func removeDeletedIdea(ideaId: String) {
        // Remove from feed items array
        feedItems.removeAll { $0.id == ideaId }
        
        // Remove from search results array
        searchResults.removeAll { $0.id == ideaId }
        
        print("🗑️ ExploreViewModel: Removed deleted idea \(ideaId) from feed and search results")
    }
    
    private func removeIdeasFromBlockedUser(userId: String) {
        // Count how many ideas we're removing for logging
        let feedIdeasCount = feedItems.filter { $0.user_id == userId }.count
        let searchIdeasCount = searchResults.filter { $0.user_id == userId }.count
        
        // Remove from feed items array
        feedItems.removeAll { $0.user_id == userId }
        
        // Remove from search results array
        searchResults.removeAll { $0.user_id == userId }
        
        print("🚫 ExploreViewModel: Removed \(feedIdeasCount) feed ideas and \(searchIdeasCount) search ideas from blocked user \(userId)")
    }
    
    // MARK: - Feed Functions
    
    func loadInitialFeed() {
        currentPage = 1
        feedItems = []
        loadFeedPage(page: currentPage)
    }
    
    func loadNextFeedPage() {
        guard hasMorePages && !isLoadingFeed else { return }
        loadFeedPage(page: currentPage + 1)
    }
    
    private func loadFeedPage(page: Int) {
        isLoadingFeed = true
        errorMessage = nil
        
        NetworkClient.shared.getFeed(page: page, pageSize: pageSize) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoadingFeed = false
                
                switch result {
                case .success(let response):
                    if page == 1 {
                        self.feedItems = response.items
                    } else {
                        // Filter out duplicates before appending
                        let existingIds = Set(self.feedItems.map { $0.id })
                        let newItems = response.items.filter { !existingIds.contains($0.id) }
                        self.feedItems.append(contentsOf: newItems)
                    }
                    self.currentPage = page
                    self.hasMorePages = response.hasNext
                    
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    // MARK: - Search Functions
    
    func showSearchField() {
        isSearchFieldVisible = true
    }
    
    func hideSearchField() {
        isSearchFieldVisible = false
        query = ""
        clearSearch()
    }
    
    func performSearch() {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty && trimmed.count >= 3 else { return }
        
        isSearching = true
        errorMessage = nil
        hasSearched = true
        
        NetworkClient.shared.searchActivities(query: trimmed) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isSearching = false
                
                switch result {
                case .success(let ideas):
                    self.searchResults = ideas
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func performSearch(with presetQuery: String) {
        // Extract emoji and text, use just the text for search
        let cleanQuery = presetQuery.replacingOccurrences(of: "🍷 ", with: "")
            .replacingOccurrences(of: "🏃‍♂️ ", with: "")
            .replacingOccurrences(of: "🍳 ", with: "")
            .replacingOccurrences(of: "🌅 ", with: "")
            .replacingOccurrences(of: "🏠 ", with: "")
            .replacingOccurrences(of: "🎨 ", with: "")
            .replacingOccurrences(of: "🌃 ", with: "")
            .replacingOccurrences(of: "🧘‍♀️ ", with: "")
        
        query = cleanQuery
        performSearch()
    }
    
    func clearSearch() {
        searchResults = []
        hasSearched = false
        errorMessage = nil
    }
    
    // MARK: - Refresh Function
    
    func refresh() {
        if isSearchActive {
            performSearch()
        } else {
            loadInitialFeed()
        }
    }
}

