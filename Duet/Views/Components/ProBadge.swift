//
//  ProBadge.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 20/12/2024.
//

import SwiftUI
import RevenueCat
import RevenueCatUI

struct ProBadge: View {
    let subscriptionStatus: SubscriptionStatus
    let showPaywall: () -> Void
    
    init(subscriptionStatus: SubscriptionStatus, showPaywall: @escaping () -> Void) {
        self.subscriptionStatus = subscriptionStatus
        self.showPaywall = showPaywall
    }
    
    var body: some View {
        Button(action: showPaywall) {
            HStack(spacing: 6) {
                // Pro icon
                Image(systemName: "crown.fill")
                    .font(.caption)
                    .foregroundColor(.white)
                
                // Status text
                Text(statusText)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(backgroundGradient)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var statusText: String {
        if subscriptionStatus.isSubscribed && subscriptionStatus.isActive {
            return "PRO"
        } else {
            return "Get Pro"
        }
    }
    
    private var backgroundGradient: LinearGradient {
        if subscriptionStatus.isSubscribed && subscriptionStatus.isActive {
            // Gold gradient for active pro members
            return LinearGradient(
                colors: [
                    Color(red: 0.85, green: 0.65, blue: 0.13), // Gold
                    Color(red: 0.72, green: 0.45, blue: 0.20)  // Darker gold
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            // Premium purple gradient for non-subscribers
            return LinearGradient(
                colors: [
                    Color.appPrimary,
                    Color.appPrimary.opacity(0.8)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - RevenueCat Native Pro Badge

struct RevenueCatProBadge: View {
    let subscriptionStatus: SubscriptionStatus
    
    var body: some View {
        Button(action: {}) { // Empty action since RevenueCat handles the presentation
            HStack(spacing: 6) {
                // Pro icon
                Image(systemName: "crown.fill")
                    .font(.caption)
                    .foregroundColor(.white)
                
                // Status text
                Text(statusText)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(backgroundGradient)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .presentPaywallIfNeeded(
            requiredEntitlementIdentifier: "Pro",
            purchaseCompleted: { customerInfo in
                print("🎉 Purchase completed: \(customerInfo.entitlements)")
                // Subscription status will be updated automatically via AuthenticationViewModel
            },
            restoreCompleted: { customerInfo in
                print("✅ Purchases restored: \(customerInfo.entitlements)")
                // Paywall will be dismissed automatically if "Pro" is now active
            }
        )
    }
    
    private var statusText: String {
        if subscriptionStatus.isSubscribed && subscriptionStatus.isActive {
            return "PRO"
        } else {
            return "Get Pro"
        }
    }
    
    private var backgroundGradient: LinearGradient {
        if subscriptionStatus.isSubscribed && subscriptionStatus.isActive {
            // Gold gradient for active pro members
            return LinearGradient(
                colors: [
                    Color(red: 0.85, green: 0.65, blue: 0.13), // Gold
                    Color(red: 0.72, green: 0.45, blue: 0.20)  // Darker gold
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            // Premium purple gradient for non-subscribers
            return LinearGradient(
                colors: [
                    Color.appPrimary,
                    Color.appPrimary.opacity(0.8)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Pro Member Card for Profile

struct ProMemberCard: View {
    let subscriptionStatus: SubscriptionStatus
    let showPaywall: () -> Void
    
    var body: some View {
        Button(action: showPaywall) {
            HStack(spacing: 16) {
                // Pro icon with background
                ZStack {
                    Circle()
                        .fill(backgroundGradient)
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "crown.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 2) {
                    Text(titleText)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(subtitleText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Status indicator or chevron
                if subscriptionStatus.isSubscribed && subscriptionStatus.isActive {
                    Text("ACTIVE")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.appAccent)
                        .clipShape(Capsule())
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var titleText: String {
        if subscriptionStatus.isSubscribed && subscriptionStatus.isActive {
            return "Duet Pro Member"
        } else {
            return "Upgrade to Duet Pro"
        }
    }
    
    private var subtitleText: String {
        if subscriptionStatus.isSubscribed && subscriptionStatus.isActive {
            if let expirationDate = subscriptionStatus.expirationDate {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                return "Renews \(formatter.string(from: expirationDate))"
            } else {
                return "Unlimited access to all features"
            }
        } else {
            return "Unlimited summaries & features"
        }
    }
    
    private var backgroundGradient: LinearGradient {
        if subscriptionStatus.isSubscribed && subscriptionStatus.isActive {
            // Gold gradient for active pro members
            return LinearGradient(
                colors: [
                    Color(red: 0.85, green: 0.65, blue: 0.13),
                    Color(red: 0.72, green: 0.45, blue: 0.20)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            // App primary gradient for non-subscribers
            return LinearGradient(
                colors: [Color.appPrimary, Color.appPrimary.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - RevenueCat Native Pro Member Card

struct RevenueCatProMemberCard: View {
    let subscriptionStatus: SubscriptionStatus
    
    var body: some View {
        Button(action: {}) { // Empty action since RevenueCat handles the presentation
            HStack(spacing: 16) {
                // Pro icon with background
                ZStack {
                    Circle()
                        .fill(backgroundGradient)
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "crown.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 2) {
                    Text(titleText)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(subtitleText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Status indicator or chevron
                if subscriptionStatus.isSubscribed && subscriptionStatus.isActive {
                    Text("ACTIVE")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.appAccent)
                        .clipShape(Capsule())
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
            )
        }
        .buttonStyle(.plain)
        .presentPaywallIfNeeded(
            requiredEntitlementIdentifier: "Pro",
            purchaseCompleted: { customerInfo in
                print("🎉 Purchase completed: \(customerInfo.entitlements)")
                // Subscription status will be updated automatically via AuthenticationViewModel
            },
            restoreCompleted: { customerInfo in
                print("✅ Purchases restored: \(customerInfo.entitlements)")
                // Paywall will be dismissed automatically if "Pro" is now active
            }
        )
    }
    
    private var titleText: String {
        if subscriptionStatus.isSubscribed && subscriptionStatus.isActive {
            return "Duet Pro Member"
        } else {
            return "Upgrade to Duet Pro"
        }
    }
    
    private var subtitleText: String {
        if subscriptionStatus.isSubscribed && subscriptionStatus.isActive {
            if let expirationDate = subscriptionStatus.expirationDate {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                return "Renews \(formatter.string(from: expirationDate))"
            } else {
                return "Unlimited access to all features"
            }
        } else {
            return "Unlimited summaries & features"
        }
    }
    
    private var backgroundGradient: LinearGradient {
        if subscriptionStatus.isSubscribed && subscriptionStatus.isActive {
            // Gold gradient for active pro members
            return LinearGradient(
                colors: [
                    Color(red: 0.85, green: 0.65, blue: 0.13),
                    Color(red: 0.72, green: 0.45, blue: 0.20)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            // App primary gradient for non-subscribers
            return LinearGradient(
                colors: [Color.appPrimary, Color.appPrimary.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        // Custom paywall versions
        Text("Custom Paywall Versions")
            .font(.headline)
        
        // Active subscription
        ProBadge(
            subscriptionStatus: SubscriptionStatus(
                isSubscribed: true,
                entitlementId: "Pro",
                isActive: true
            ),
            showPaywall: {}
        )
        
        // No subscription
        ProBadge(
            subscriptionStatus: SubscriptionStatus(),
            showPaywall: {}
        )
        
        // RevenueCat native versions
        Text("RevenueCat Native Versions")
            .font(.headline)
        
        RevenueCatProBadge(
            subscriptionStatus: SubscriptionStatus(
                isSubscribed: true,
                entitlementId: "Pro",
                isActive: true
            )
        )
        
        RevenueCatProBadge(
            subscriptionStatus: SubscriptionStatus()
        )
        
        // Pro member cards
        RevenueCatProMemberCard(
            subscriptionStatus: SubscriptionStatus()
        )
    }
    .padding()
} 
