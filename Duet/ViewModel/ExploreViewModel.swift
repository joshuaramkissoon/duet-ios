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
    }
    
    private func setupSearchDebouncing() {
        $query
            .debounce(for: .milliseconds(1000), scheduler: RunLoop.main) // More conservative: 1 second
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
    
    private func clearSearch() {
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

