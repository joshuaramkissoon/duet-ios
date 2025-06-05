//
//  SimpleProBadge.swift
//  Duet
//
//  Created by Assistant on ${new Date().toLocaleDateString()}
//

import SwiftUI

// MARK: - Simple Pro Badge for Header

struct SimpleProBadge: View {
    @EnvironmentObject private var subscriptionService: SubscriptionService
    
    var body: some View {
        Button(action: {
            if !subscriptionService.hasActiveSubscription() {
                subscriptionService.presentPaywall()
            }
        }) {
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
        if subscriptionService.hasActiveSubscription() {
            return "PRO"
        } else {
            return "Get Pro"
        }
    }
    
    private var backgroundGradient: LinearGradient {
        if subscriptionService.hasActiveSubscription() {
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

// MARK: - Simple Pro Member Card for Profile

struct SimpleProMemberCard: View {
    @EnvironmentObject private var subscriptionService: SubscriptionService
    @State private var showManageSubscription = false
    
    var body: some View {
        Button(action: {
            if subscriptionService.hasActiveSubscription() {
                showManageSubscription = true
            } else {
                subscriptionService.presentPaywall()
            }
        }) {
            HStack(spacing: 16) {
                // Pro icon
                VStack {
                    Image(systemName: "crown.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 48, height: 48)
                        .background(backgroundGradient)
                        .clipShape(Circle())
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(titleText)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(subtitleText)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(2)
                }
                
                Spacer()
                
                // Arrow or checkmark
                Image(systemName: subscriptionService.hasActiveSubscription() ? "gear" : "chevron.right")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(20)
            .background(backgroundGradient)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showManageSubscription) {
            ManageSubscriptionView()
                .environmentObject(subscriptionService)
        }
    }
    
    private var titleText: String {
        if subscriptionService.hasActiveSubscription() {
            return "Duet Pro Member"
        } else {
            return "Upgrade to Duet Pro"
        }
    }
    
    private var subtitleText: String {
        if subscriptionService.hasActiveSubscription() {
            if let expirationDate = subscriptionService.subscriptionStatus.expirationDate {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                return "Tap to manage subscription"
            } else {
                return "Tap to manage subscription"
            }
        } else {
            return "Unlimited video processing & group features"
        }
    }
    
    private var backgroundGradient: LinearGradient {
        if subscriptionService.hasActiveSubscription() {
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
        SimpleProBadge()
        SimpleProMemberCard()
    }
    .padding()
    .environmentObject(SubscriptionService.shared)
} 