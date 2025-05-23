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
    
    init(activities: [DateIdeaResponse] = [], isLoading: Bool = false, error: Error? = nil) {
        self.activities = activities
        self.isLoading = isLoading
        self.error = error
        loadActivities()
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
