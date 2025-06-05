//
//  MyLibraryViewModel.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 20/05/2025.
//

import Foundation
import Combine

@MainActor
class MyLibraryViewModel: ObservableObject {
    @Published var userIdeas: [DateIdeaResponse] = []
    @Published var searchResults: [DateIdeaResponse] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var query = "" {
        didSet {
            handleQueryChange()
        }
    }
    @Published var isSearchFieldVisible = false
    @Published var hasSearched = false
    
    // Pagination properties
    @Published private(set) var currentPage: Int = 1
    @Published private(set) var hasMorePages: Bool = false
    @Published private(set) var isLoadingUserIdeas: Bool = false
    
    // Total user ideas count from API
    @Published private(set) var totalUserIdeas: Int = 0
    
    private var authorId: String?
    private var searchTask: Task<Void, Never>?
    private let pageSize = 20
    private var cancellables = Set<AnyCancellable>()
    
    // Search state computed properties
    var isSearchActive: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var displayItems: [DateIdeaResponse] {
        isSearchActive ? searchResults : userIdeas
    }
    
    // Combined loading state
    var isLoadingAny: Bool {
        isSearchActive ? isLoading : isLoadingUserIdeas
    }
    
    // Preset queries for library search
    let presetQueries = [
        "🍷 Romantic dinner",
        "🏃‍♂️ Outdoor adventure",
        "🏠 Cozy night in",
        "✈️ Weekend getaway",
        "🎨 Creative activities",
        "💪 Fitness and health"
    ]
    
    init() {
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
        
        // Listen for idea deletions
        NotificationCenter.default.publisher(for: .ideaDeleted)
            .sink { [weak self] notification in
                guard let self = self,
                      let ideaId = notification.userInfo?["ideaId"] as? String else { return }
                
                self.removeDeletedIdea(ideaId: ideaId)
            }
            .store(in: &cancellables)
    }
    
    private func updateIdeaVisibility(ideaId: String, isPublic: Bool) {
        // Update in user ideas array
        if let index = userIdeas.firstIndex(where: { $0.id == ideaId }) {
            var updatedActivity = userIdeas[index]
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
            userIdeas[index] = updatedActivity
            print("🔄 MyLibraryViewModel: Updated visibility for idea \(ideaId): \(isPublic ? "Public" : "Private")")
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
        // Update in user ideas array
        if let index = userIdeas.firstIndex(where: { $0.id == ideaId }) {
            userIdeas[index] = updatedIdea
            print("🔄 MyLibraryViewModel: Updated metadata for idea \(ideaId)")
        }
        
        // Update in search results array if it exists there too
        if let searchIndex = searchResults.firstIndex(where: { $0.id == ideaId }) {
            searchResults[searchIndex] = updatedIdea
        }
    }
    
    private func removeDeletedIdea(ideaId: String) {
        // Remove from user ideas array
        let initialCount = userIdeas.count
        userIdeas.removeAll { $0.id == ideaId }
        
        // Update total count if an idea was actually removed
        if userIdeas.count < initialCount {
            totalUserIdeas = max(0, totalUserIdeas - 1)
            print("🗑️ MyLibraryViewModel: Removed deleted idea \(ideaId) (total: \(totalUserIdeas))")
        }
        
        // Remove from search results array if it exists there too
        searchResults.removeAll { $0.id == ideaId }
    }
    
    func setAuthorId(_ id: String) {
        authorId = id
    }
    
    func loadUserIdeas() {
        currentPage = 1
        userIdeas = []
        loadUserIdeasPage(page: currentPage)
    }
    
    func backgroundLoadUserIdeas() {
        // Silent background loading - don't show loading state or clear existing data
        guard let authorId = authorId else { return }
        
        print("🔄 Starting background refresh of user ideas")
        
        NetworkClient.shared.getUserIdeas(userId: authorId, page: 1, pageSize: pageSize) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                switch result {
                case .success(let response):
                    self.userIdeas = response.items
                    self.totalUserIdeas = response.total
                    self.currentPage = 1
                    self.hasMorePages = response.hasNext
                    print("🔄 Background loaded \(response.items.count) user ideas (total: \(response.total))")
                    
                case .failure(let error):
                    print("⚠️ Background load failed (silent): \(error.localizedDescription)")
                    // Don't show error to user for background loads
                }
            }
        }
    }
    
    func loadNextUserIdeasPage() {
        guard hasMorePages && !isLoadingUserIdeas else { return }
        loadUserIdeasPage(page: currentPage + 1)
    }
    
    private func loadUserIdeasPage(page: Int) {
        guard let authorId = authorId else { return }
        
        // Only show loading state if we don't have any data yet
        if userIdeas.isEmpty {
            isLoadingUserIdeas = true
        }
        errorMessage = nil
        
        NetworkClient.shared.getUserIdeas(userId: authorId, page: page, pageSize: pageSize) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoadingUserIdeas = false
                
                switch result {
                case .success(let response):
                    if page == 1 {
                        self.userIdeas = response.items
                    } else {
                        // Filter out duplicates before appending
                        let existingIds = Set(self.userIdeas.map { $0.id })
                        let newItems = response.items.filter { !existingIds.contains($0.id) }
                        self.userIdeas.append(contentsOf: newItems)
                    }
                    self.totalUserIdeas = response.total
                    self.currentPage = page
                    self.hasMorePages = response.hasNext
                    
                case .failure(let error):
                    self.errorMessage = "Failed to load your ideas: \(error.localizedDescription)"
                    print("❌ Error loading user ideas: \(error)")
                }
            }
        }
    }
    
    func performSearch(with searchQuery: String) {
        query = searchQuery
        executeSearch()
    }
    
    func showSearchField() {
        isSearchFieldVisible = true
    }
    
    func hideSearchField() {
        isSearchFieldVisible = false
        query = ""
        searchResults = []
        hasSearched = false
    }
    
    func refresh() {
        if isSearchActive {
            executeSearch()
        } else {
            loadUserIdeas()
        }
    }
    
    /// Adds a new idea to the collection and increments the total count
    /// Used when a video is successfully processed to immediately update the UI
    func addNewIdea(_ idea: DateIdeaResponse) {
        // Add to the beginning of the list if not searching
        if !isSearchActive {
            // Check if idea already exists to avoid duplicates
            if !userIdeas.contains(where: { $0.id == idea.id }) {
                userIdeas.insert(idea, at: 0)
                totalUserIdeas += 1
                print("✅ Added new idea to library: \(idea.title) (total: \(totalUserIdeas))")
            }
        }
    }
    
    /// Force refresh the total count from the server
    func refreshTotalCount() {
        NetworkClient.shared.getUserLevel { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                switch result {
                case .success(let response):
                    self.totalUserIdeas = response.ideaCount
                    print("🔄 Refreshed idea count from server: \(response.ideaCount) (Level: \(response.playerLevel))")
                    
                case .failure(let error):
                    print("⚠️ Failed to refresh idea count: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func handleQueryChange() {
        // Cancel previous search
        searchTask?.cancel()
        
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            searchResults = []
            hasSearched = false
            return
        }
        
        // Debounce search
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            if !Task.isCancelled {
                await executeSearch()
            }
        }
    }
    
    private func executeSearch() {
        guard let authorId = authorId else { return }
        
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        
        // Only use search endpoint when there's an actual search query
        NetworkClient.shared.searchActivities(query: trimmedQuery, authorId: authorId) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                self?.hasSearched = true
                
                switch result {
                case .success(let ideas):
                    self?.searchResults = ideas
                case .failure(let error):
                    self?.errorMessage = "Search failed: \(error.localizedDescription)"
                    self?.searchResults = []
                    print("❌ Error searching user ideas: \(error)")
                }
            }
        }
    }
} 