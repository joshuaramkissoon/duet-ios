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
    
    // Output
    @Published private(set) var results: [DateIdeaResponse] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var hasSearched: Bool = false

    private var cancellables = Set<AnyCancellable>()
    
    func performSearch() {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        
        // Kick off loading state
        isLoading = true
        errorMessage = nil
        hasSearched = true
        
        NetworkClient.shared.searchActivities(query: trimmed) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                switch result {
                case .success(let ideas):
                    self.results = ideas
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}

