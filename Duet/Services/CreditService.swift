//
//  CreditService.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 20/12/2024.
//

import Foundation
import SwiftUI
import FirebaseAuth

final class CreditService: ObservableObject {
    static let shared = CreditService()
    
    @Published var currentCredits: Int = 0
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var creditHistory: [CreditTransaction] = []
    
    // Reference to centralized UI manager (will be set by app)
    private weak var creditUIManager: CreditUIManager?
    
    private init() {}
    
    // MARK: - Setup
    
    /// Configure the service with the centralized UI manager
    func configure(with uiManager: CreditUIManager) {
        self.creditUIManager = uiManager
    }
    
    // MARK: - Fetch User Credits
    @MainActor
    func fetchUserCredits() async {
        isLoading = true
        errorMessage = nil
        
        await withCheckedContinuation { continuation in
            NetworkClient.shared.getUserCredits { [weak self] result in
                DispatchQueue.main.async {
                    guard let self = self else { 
                        continuation.resume()
                        return 
                    }
                    
                    switch result {
                    case .success(let userCredits):
                        self.currentCredits = userCredits.credits
                        self.isLoading = false
                        print("🟢 Successfully fetched user credits: \(userCredits.credits)")
                        
                    case .failure(let error):
                        self.isLoading = false
                        self.errorMessage = error.localizedDescription
                        print("❌ Failed to fetch user credits: \(error.localizedDescription)")
                    }
                    
                    continuation.resume()
                }
            }
        }
    }
    
    // MARK: - Fetch Credit History
    @MainActor
    func fetchCreditHistory() async {
        isLoading = true
        errorMessage = nil
        
        await withCheckedContinuation { continuation in
            NetworkClient.shared.getCreditHistory { [weak self] result in
                DispatchQueue.main.async {
                    guard let self = self else { 
                        continuation.resume()
                        return 
                    }
                    
                    switch result {
                    case .success(let creditHistoryResponse):
                        self.creditHistory = creditHistoryResponse.transactions
                        self.isLoading = false
                        print("🟢 Successfully fetched credit history: \(creditHistoryResponse.transactions.count) transactions")
                        
                    case .failure(let error):
                        self.isLoading = false
                        self.errorMessage = error.localizedDescription
                        print("❌ Failed to fetch credit history: \(error.localizedDescription)")
                    }
                    
                    continuation.resume()
                }
            }
        }
    }
    
    // MARK: - Handle Insufficient Credits Error
    func handleInsufficientCreditsError(_ error: Error) -> Bool {
        // Check if this is a NetworkError with 402 status code
        if let networkError = error as? NetworkError,
           case .unexpectedStatusCode(let statusCode) = networkError,
           statusCode == 402 {
            
            // Trigger the centralized purchase sheet
            creditUIManager?.handleInsufficientCredits()
            return true
        }
        
        // TODO: When NetworkClient is updated to parse error response bodies,
        // we can also check for the specific INSUFFICIENT_CREDITS error_code
        
        return false
    }
    
    // MARK: - Pre-emptive Credit Check
    func hasCreditsForAction(creditsRequired: Int = 1) -> Bool {
        return currentCredits >= creditsRequired
    }
    
    /// Check credits and show purchase sheet if insufficient
    func checkCreditsForAction(creditsRequired: Int = 1) -> Bool {
        let hasCredits = currentCredits >= creditsRequired
        if !hasCredits {
            creditUIManager?.handleInsufficientCredits()
        }
        return hasCredits
    }
    
    // MARK: - Update Credits After Action
    func deductCredits(_ amount: Int) {
        currentCredits = max(0, currentCredits - amount)
    }
    
    // MARK: - Refresh Credits from User Profile
    func updateCreditsFromUser(_ user: User) {
        currentCredits = user.creditsCount
        
        // If we're updating from fresh user data, also refresh history
        // This ensures consistency when user data comes from the backend with updated credits
        Task {
            await fetchCreditHistory()
        }
    }
    
    // MARK: - Manual Refresh (for pull-to-refresh, etc.)
    func refreshCreditData() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await self.fetchUserCredits()
            }
            group.addTask {
                await self.fetchCreditHistory()
            }
        }
    }
    
    // MARK: - Admin Add Credits (Future Use)
    func addCredits(to userId: String, amount: Int, reason: String) async -> Bool {
        return await withCheckedContinuation { continuation in
            NetworkClient.shared.addCredits(to: userId, amount: amount, reason: reason) { result in
                switch result {
                case .success(let response):
                    print("🟢 Successfully added credits: \(response.message)")
                    continuation.resume(returning: response.success)
                    
                case .failure(let error):
                    print("❌ Failed to add credits: \(error.localizedDescription)")
                    continuation.resume(returning: false)
                }
            }
        }
    }
} 