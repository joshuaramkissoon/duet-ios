//
//  WelcomeCreditService.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 20/05/2025.
//

import Foundation

class WelcomeCreditService: ObservableObject {
    static let shared = WelcomeCreditService()
    
    @Published private(set) var welcomeCredits: Int = 10 // Default fallback
    @Published private(set) var levelUpBonus: Int = 20 // Default fallback
    @Published private(set) var isLoading: Bool = false
    private var hasFetched: Bool = false
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Gets the cached welcome credits value. If not fetched yet, returns default and triggers fetch.
    var credits: Int {
        if !hasFetched {
            Task {
                await fetchWelcomeCreditsIfNeeded()
            }
        }
        return welcomeCredits
    }
    
    /// Fetches welcome credits if not already fetched or forces a refresh
    @MainActor
    func fetchWelcomeCreditsIfNeeded(forceRefresh: Bool = false) async {
        guard !isLoading && (!hasFetched || forceRefresh) else { return }
        
        isLoading = true
        
        await withCheckedContinuation { continuation in
            NetworkClient.shared.getWelcomeCredits { result in
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.hasFetched = true
                    
                    switch result {
                    case .success(let welcomeCreditsResponse):
                        self.welcomeCredits = welcomeCreditsResponse.welcomeCredits
                        self.levelUpBonus = welcomeCreditsResponse.levelUpBonus
                        print("🟢 WelcomeCreditService: Successfully fetched welcome credits: \(welcomeCreditsResponse.welcomeCredits), level up bonus: \(welcomeCreditsResponse.levelUpBonus)")
                        
                    case .failure(let error):
                        print("❌ WelcomeCreditService: Failed to fetch welcome credits: \(error.localizedDescription)")
                        // Keep existing values or default fallbacks
                        if self.welcomeCredits == 10 && !forceRefresh {
                            self.welcomeCredits = 10 // Ensure default is set
                        }
                        if self.levelUpBonus == 20 && !forceRefresh {
                            self.levelUpBonus = 20 // Ensure default is set
                        }
                    }
                    
                    continuation.resume()
                }
            }
        }
    }
    
    /// Forces a refresh of welcome credits data
    func refreshWelcomeCredits() async {
        await fetchWelcomeCreditsIfNeeded(forceRefresh: true)
    }
} 