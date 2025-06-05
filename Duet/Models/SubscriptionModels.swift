//
//  SubscriptionModels.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 20/12/2024.
//

import Foundation

// MARK: - Subscription Status
struct SubscriptionStatus: Codable {
    let isSubscribed: Bool
    let entitlementId: String?
    let productId: String?
    let expirationDate: Date?
    let isActive: Bool
    let willRenew: Bool
    let purchaseDate: Date?
    
    init(
        isSubscribed: Bool = false,
        entitlementId: String? = nil,
        productId: String? = nil,
        expirationDate: Date? = nil,
        isActive: Bool = false,
        willRenew: Bool = false,
        purchaseDate: Date? = nil
    ) {
        self.isSubscribed = isSubscribed
        self.entitlementId = entitlementId
        self.productId = productId
        self.expirationDate = expirationDate
        self.isActive = isActive
        self.willRenew = willRenew
        self.purchaseDate = purchaseDate
    }
}

// MARK: - Subscription Package Info
struct SubscriptionPackage: Identifiable, Codable {
    let id: String
    let productId: String
    let title: String
    let description: String
    let price: String
    let priceAmount: Decimal
    let currencyCode: String
    let billingPeriod: BillingPeriod
    let isPopular: Bool
    
    enum BillingPeriod: String, Codable, CaseIterable {
        case monthly = "monthly"
        case yearly = "yearly"
        case weekly = "weekly"
        
        var displayName: String {
            switch self {
            case .monthly: return "Monthly"
            case .yearly: return "Yearly"
            case .weekly: return "Weekly"
            }
        }
        
        var suffix: String {
            switch self {
            case .monthly: return "/month"
            case .yearly: return "/year"
            case .weekly: return "/week"
            }
        }
    }
}

// MARK: - Subscription Offering
struct SubscriptionOffering: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let packages: [SubscriptionPackage]
    let isDefault: Bool
    
    var monthlyPackage: SubscriptionPackage? {
        packages.first { $0.billingPeriod == .monthly }
    }
    
    var yearlyPackage: SubscriptionPackage? {
        packages.first { $0.billingPeriod == .yearly }
    }
    
    var popularPackage: SubscriptionPackage? {
        packages.first { $0.isPopular }
    }
}

// MARK: - Purchase Result
enum PurchaseResult {
    case success(SubscriptionStatus)
    case cancelled
    case failed(Error)
    case pending
}

// MARK: - Subscription Error
enum SubscriptionError: LocalizedError {
    case notInitialized
    case noOfferings
    case purchaseFailed(String)
    case restoreFailed(String)
    case userNotFound
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "RevenueCat not initialized"
        case .noOfferings:
            return "No subscription offerings available"
        case .purchaseFailed(let message):
            return "Purchase failed: \(message)"
        case .restoreFailed(let message):
            return "Restore failed: \(message)"
        case .userNotFound:
            return "User not found"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
} 