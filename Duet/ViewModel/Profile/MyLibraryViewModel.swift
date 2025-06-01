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
    
    private var authorId: String?
    private var searchTask: Task<Void, Never>?
    private let pageSize = 20
    
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
        
        NetworkClient.shared.getUserIdeas(userId: authorId, page: 1, pageSize: pageSize) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                switch result {
                case .success(let response):
                    self.userIdeas = response.items
                    self.currentPage = 1
                    self.hasMorePages = response.hasNext
                    print("🔄 Background loaded \(response.items.count) user ideas")
                    
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