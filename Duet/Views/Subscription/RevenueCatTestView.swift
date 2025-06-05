//
//  RevenueCatTestView.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 20/12/2024.
//

import SwiftUI
import RevenueCat
import RevenueCatUI

struct RevenueCatTestView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var subscriptionService: SubscriptionService
    @State private var showManualPaywall = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Current subscription status
                    subscriptionStatusSection
                    
                    // Test buttons
                    testButtonsSection
                    
                    // Manual paywall presentation
                    manualPaywallSection
                    
                    // Global paywall section
                    globalPaywallSection
                }
                .padding()
            }
            .navigationTitle("RevenueCat Test")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showManualPaywall) {
            PaywallView(displayCloseButton: true)
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "crown.fill")
                .font(.largeTitle)
                .foregroundColor(.appPrimary)
            
            Text("RevenueCat Paywall Testing")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text("Test different ways to present RevenueCat paywalls")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Subscription Status Section
    
    private var subscriptionStatusSection: some View {
        VStack(spacing: 16) {
            Text("Current Status")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                StatusRow(title: "Subscribed", value: subscriptionService.subscriptionStatus.isSubscribed ? "Yes" : "No")
                StatusRow(title: "Active", value: subscriptionService.subscriptionStatus.isActive ? "Yes" : "No")
                StatusRow(title: "Entitlement", value: subscriptionService.subscriptionStatus.entitlementId ?? "None")
                StatusRow(title: "Product ID", value: subscriptionService.subscriptionStatus.productId ?? "None")
                
                if let expirationDate = subscriptionService.subscriptionStatus.expirationDate {
                    StatusRow(title: "Expires", value: DateFormatter.localizedString(from: expirationDate, dateStyle: .medium, timeStyle: .none))
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
    
    // MARK: - Test Buttons Section
    
    private var testButtonsSection: some View {
        VStack(spacing: 16) {
            Text("Test Methods")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                TestButton(
                    title: "Manual PaywallView",
                    description: "Present PaywallView manually in a sheet",
                    action: {
                        showManualPaywall = true
                    }
                )
                
                TestButton(
                    title: "Refresh Status",
                    description: "Refresh subscription status from RevenueCat",
                    action: {
                        Task {
                            await subscriptionService.refreshSubscriptionStatus()
                        }
                    }
                )
            }
        }
    }
    
    // MARK: - Manual Paywall Section
    
    private var manualPaywallSection: some View {
        VStack(spacing: 16) {
            Text("Manual Paywall")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Use the button above to manually present a PaywallView in a sheet. This gives you full control over when and how the paywall is shown.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.appPrimary.opacity(0.1))
        )
    }
    
    // MARK: - Global Paywall Section
    
    private var globalPaywallSection: some View {
        VStack(spacing: 16) {
            Text("Auto-Presenting Paywall")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("The components in ProfileView use .presentPaywallIfNeeded() which automatically shows the paywall when tapped if the user doesn't have the 'Pro' entitlement.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Text("Try tapping the Pro badges and member cards in the profile to see this in action!")
                .font(.callout)
                .fontWeight(.medium)
                .foregroundColor(.appPrimary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.appSecondary.opacity(0.1))
        )
    }
}

// MARK: - Supporting Views

struct StatusRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
}

struct TestButton: View {
    let title: String
    let description: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(
                LinearGradient(
                    colors: [Color.appPrimary, Color.appPrimary.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    RevenueCatTestView()
        .environmentObject(SubscriptionService.shared)
} 