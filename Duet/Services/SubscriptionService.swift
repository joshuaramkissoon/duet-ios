//
//  SubscriptionService.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 20/12/2024.
//

import Foundation
import SwiftUI
import RevenueCat

final class SubscriptionService: ObservableObject {
    static let shared = SubscriptionService()
    
    @Published var subscriptionStatus: SubscriptionStatus = SubscriptionStatus()
    @Published var currentOfferings: [SubscriptionOffering] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showPaywall: Bool = false
    
    private let proEntitlementId = "Pro"
    private var isInitialized = false
    
    private init() {}
    
    // MARK: - Initialization
    
    func configure(apiKey: String) {
        guard !isInitialized else { return }
        
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: apiKey)
        isInitialized = true
        
        print("🟢 RevenueCat configured with API key")
    }
    
    // MARK: - User Management
    
    func login(userId: String) async {
        guard isInitialized else {
            print("❌ RevenueCat not initialized")
            return
        }
        
        await withCheckedContinuation { continuation in
            Purchases.shared.logIn(userId) { customerInfo, created, error in
                if let error = error {
                    print("❌ RevenueCat login error: \(error.localizedDescription)")
                } else {
                    print("🟢 RevenueCat user logged in: \(userId), created: \(created)")
                    if let customerInfo = customerInfo {
                        Task { @MainActor in
                            self.updateSubscriptionStatus(from: customerInfo)
                        }
                    }
                }
                continuation.resume()
            }
        }
    }
    
    func logout() async {
        guard isInitialized else { return }
        
        await withCheckedContinuation { continuation in
            Purchases.shared.logOut { customerInfo, error in
                if let error = error {
                    print("❌ RevenueCat logout error: \(error.localizedDescription)")
                } else {
                    print("🟢 RevenueCat user logged out")
                }
                
                Task { @MainActor in
                    self.subscriptionStatus = SubscriptionStatus()
                }
                continuation.resume()
            }
        }
    }
    
    // MARK: - Subscription Status
    
    @MainActor
    func refreshSubscriptionStatus() async {
        guard isInitialized else {
            errorMessage = SubscriptionError.notInitialized.localizedDescription
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        await withCheckedContinuation { continuation in
            Purchases.shared.getCustomerInfo { [weak self] customerInfo, error in
                DispatchQueue.main.async {
                    guard let self = self else {
                        continuation.resume()
                        return
                    }
                    
                    self.isLoading = false
                    
                    if let error = error {
                        self.errorMessage = error.localizedDescription
                        print("❌ Failed to get customer info: \(error.localizedDescription)")
                    } else if let customerInfo = customerInfo {
                        self.updateSubscriptionStatus(from: customerInfo)
                        print("🟢 Subscription status refreshed")
                    }
                    
                    continuation.resume()
                }
            }
        }
    }
    
    private func updateSubscriptionStatus(from customerInfo: CustomerInfo) {
        let proEntitlement = customerInfo.entitlements[proEntitlementId]
        let isActive = proEntitlement?.isActive == true
        
        subscriptionStatus = SubscriptionStatus(
            isSubscribed: isActive,
            entitlementId: isActive ? proEntitlementId : nil,
            productId: proEntitlement?.productIdentifier,
            expirationDate: proEntitlement?.expirationDate,
            isActive: isActive,
            willRenew: proEntitlement?.willRenew == true,
            purchaseDate: proEntitlement?.latestPurchaseDate
        )
    }
    
    // MARK: - Offerings
    
    @MainActor
    func fetchOfferings() async {
        guard isInitialized else {
            errorMessage = SubscriptionError.notInitialized.localizedDescription
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        await withCheckedContinuation { continuation in
            Purchases.shared.getOfferings { [weak self] offerings, error in
                DispatchQueue.main.async {
                    guard let self = self else {
                        continuation.resume()
                        return
                    }
                    
                    self.isLoading = false
                    
                    if let error = error {
                        self.errorMessage = error.localizedDescription
                        print("❌ Failed to fetch offerings: \(error.localizedDescription)")
                    } else if let offerings = offerings {
                        self.currentOfferings = self.convertOfferings(offerings)
                        print("🟢 Fetched \(self.currentOfferings.count) offerings")
                    }
                    
                    continuation.resume()
                }
            }
        }
    }
    
    private func convertOfferings(_ offerings: Offerings) -> [SubscriptionOffering] {
        var result: [SubscriptionOffering] = []
        
        // Add default offering first if available
        if let defaultOffering = offerings.current {
            result.append(convertOffering(defaultOffering, isDefault: true))
        }
        
        // Add other offerings
        for (_, offering) in offerings.all {
            if offering.identifier != offerings.current?.identifier {
                result.append(convertOffering(offering, isDefault: false))
            }
        }
        
        return result
    }
    
    private func convertOffering(_ offering: Offering, isDefault: Bool) -> SubscriptionOffering {
        let packages = offering.availablePackages.compactMap { package -> SubscriptionPackage? in
            let product = package.storeProduct
            
            let billingPeriod: SubscriptionPackage.BillingPeriod
            switch package.packageType {
            case .monthly:
                billingPeriod = .monthly
            case .annual:
                billingPeriod = .yearly
            case .weekly:
                billingPeriod = .weekly
            default:
                billingPeriod = .monthly
            }
            
            return SubscriptionPackage(
                id: package.identifier,
                productId: product.productIdentifier,
                title: product.localizedTitle,
                description: product.localizedDescription,
                price: product.localizedPriceString,
                priceAmount: product.price,
                currencyCode: product.priceFormatter?.currencyCode ?? "USD",
                billingPeriod: billingPeriod,
                isPopular: package.packageType == .annual // Mark yearly as popular
            )
        }
        
        return SubscriptionOffering(
            id: offering.identifier,
            title: offering.metadata["title"] as? String ?? "Duet Pro",
            description: offering.metadata["description"] as? String ?? "Unlock unlimited access to Duet",
            packages: packages,
            isDefault: isDefault
        )
    }
    
    // MARK: - Purchase
    
    func purchase(package: SubscriptionPackage) async -> PurchaseResult {
        guard isInitialized else {
            return .failed(SubscriptionError.notInitialized)
        }
        
        // Find the RevenueCat package
        guard let rcOffering = await findRevenueCatOffering(for: package),
              let rcPackage = rcOffering.availablePackages.first(where: { $0.identifier == package.id }) else {
            return .failed(SubscriptionError.purchaseFailed("Package not found"))
        }
        
        return await withCheckedContinuation { continuation in
            Purchases.shared.purchase(package: rcPackage) { [weak self] transaction, customerInfo, error, userCancelled in
                DispatchQueue.main.async {
                    if userCancelled {
                        continuation.resume(returning: .cancelled)
                    } else if let error = error {
                        continuation.resume(returning: .failed(SubscriptionError.purchaseFailed(error.localizedDescription)))
                    } else if let customerInfo = customerInfo {
                        self?.updateSubscriptionStatus(from: customerInfo)
                        continuation.resume(returning: .success(self?.subscriptionStatus ?? SubscriptionStatus()))
                    } else {
                        continuation.resume(returning: .pending)
                    }
                }
            }
        }
    }
    
    private func findRevenueCatOffering(for package: SubscriptionPackage) async -> Offering? {
        return await withCheckedContinuation { continuation in
            Purchases.shared.getOfferings { offerings, error in
                if let offerings = offerings {
                    for (_, offering) in offerings.all {
                        if offering.availablePackages.contains(where: { $0.identifier == package.id }) {
                            continuation.resume(returning: offering)
                            return
                        }
                    }
                }
                continuation.resume(returning: nil)
            }
        }
    }
    
    // MARK: - Restore Purchases
    
    func restorePurchases() async -> PurchaseResult {
        guard isInitialized else {
            return .failed(SubscriptionError.notInitialized)
        }
        
        return await withCheckedContinuation { continuation in
            Purchases.shared.restorePurchases { [weak self] customerInfo, error in
                DispatchQueue.main.async {
                    if let error = error {
                        continuation.resume(returning: .failed(SubscriptionError.restoreFailed(error.localizedDescription)))
                    } else if let customerInfo = customerInfo {
                        self?.updateSubscriptionStatus(from: customerInfo)
                        continuation.resume(returning: .success(self?.subscriptionStatus ?? SubscriptionStatus()))
                    } else {
                        continuation.resume(returning: .failed(SubscriptionError.restoreFailed("Unknown error")))
                    }
                }
            }
        }
    }
    
    // MARK: - Usage Check and Paywall Management
    
    /// Check if user has active subscription
    func hasActiveSubscription() -> Bool {
        return subscriptionStatus.isSubscribed && subscriptionStatus.isActive
    }
    
    /// Check if user can perform action (subscription required)
    func canPerformAction() -> Bool {
        return hasActiveSubscription()
    }
    
    /// Check access for action and show paywall if needed
    func requiresSubscriptionWithPaywall() -> Bool {
        if hasActiveSubscription() {
            return false
        }
        showPaywall = true
        return true
    }
    
    /// Show paywall manually
    func presentPaywall() {
        showPaywall = true
    }
    
    /// Hide paywall
    func dismissPaywall() {
        showPaywall = false
    }
} 
