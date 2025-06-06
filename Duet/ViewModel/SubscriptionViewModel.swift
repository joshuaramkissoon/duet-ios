//
//  SubscriptionViewModel.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 20/12/2024.
//

import Foundation
import SwiftUI

@MainActor
class SubscriptionViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var isPurchasing = false
    @Published var isRestoring = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var showSuccessAlert = false
    @Published var selectedPackage: SubscriptionPackage?
    
    private let subscriptionService = SubscriptionService.shared
    
    // MARK: - Subscription Status
    
    var isSubscribed: Bool {
        subscriptionService.subscriptionStatus.isSubscribed
    }
    
    var subscriptionStatus: SubscriptionStatus {
        subscriptionService.subscriptionStatus
    }
    
    var currentOfferings: [SubscriptionOffering] {
        subscriptionService.currentOfferings
    }
    
    var defaultOffering: SubscriptionOffering? {
        currentOfferings.first { $0.isDefault } ?? currentOfferings.first
    }
    
    // MARK: - Load Offerings
    
    func loadOfferings() async {
        isLoading = true
        errorMessage = nil
        
        await subscriptionService.fetchOfferings()
        await subscriptionService.refreshSubscriptionStatus()
        
        isLoading = false
        
        if let error = subscriptionService.errorMessage {
            errorMessage = error
        }
    }
    
    // MARK: - Purchase
    
    func purchase(package: SubscriptionPackage) async {
        isPurchasing = true
        errorMessage = nil
        selectedPackage = package
        
        let result = await subscriptionService.purchase(package: package)
        
        isPurchasing = false
        selectedPackage = nil
        
        switch result {
        case .success(let status):
            if status.isSubscribed {
                successMessage = "🎉 Welcome to Duet Pro! You now have unlimited access."
                showSuccessAlert = true
            } else {
                errorMessage = "Purchase completed but subscription not active. Please try again or contact support."
            }
            
        case .cancelled:
            // User cancelled - no error message needed
            break
            
        case .failed(let error):
            errorMessage = error.localizedDescription
            
        case .pending:
            errorMessage = "Purchase is pending. Please check your App Store account."
        }
    }
    
    // MARK: - Restore Purchases
    
    func restorePurchases() async -> PurchaseResult {
        isRestoring = true
        errorMessage = nil
        
        let result = await subscriptionService.restorePurchases()
        
        isRestoring = false
        
        switch result {
        case .success(let status):
            if status.isSubscribed {
                successMessage = "Subscription restored successfully!"
                showSuccessAlert = true
            }
            // Don't show error for no subscriptions found - let the caller handle it
            
        case .cancelled:
            break
            
        case .failed(let error):
            errorMessage = "Failed to restore purchases: \(error.localizedDescription)"
            
        case .pending:
            errorMessage = "Restore is pending. Please check your App Store account."
        }
        
        return result
    }
    
    // MARK: - Dismiss Alerts
    
    func dismissSuccessAlert() {
        showSuccessAlert = false
        successMessage = nil
    }
    
    func clearError() {
        errorMessage = nil
    }
    
    // MARK: - Package Selection Helpers
    
    func selectPackage(_ package: SubscriptionPackage) {
        selectedPackage = package
    }
    
    func isPackageSelected(_ package: SubscriptionPackage) -> Bool {
        selectedPackage?.id == package.id
    }
    
    // MARK: - Pricing Helpers
    
    func savingsText(for yearlyPackage: SubscriptionPackage, compared monthlyPackage: SubscriptionPackage) -> String? {
        // Convert Decimal to Double for calculations
        let yearlyPriceDouble = Double(truncating: yearlyPackage.priceAmount as NSNumber)
        let monthlyPriceDouble = Double(truncating: monthlyPackage.priceAmount as NSNumber)
        
        let yearlyMonthlyPrice = yearlyPriceDouble / 12.0
        
        if monthlyPriceDouble > yearlyMonthlyPrice {
            let savings = monthlyPriceDouble - yearlyMonthlyPrice
            let percentage = Int((savings / monthlyPriceDouble) * 100)
            return "Save \(percentage)%"
        }
        
        return nil
    }
} 