//
//  CreditBalanceCard.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 20/12/2024.
//

import SwiftUI
import UIKit

struct CreditBalanceCard: View {
    @StateObject private var creditService = CreditService.shared
    @EnvironmentObject private var creditUIManager: CreditUIManager
    @State private var quickPurchasePackage: CreditPackage?
    @State private var currency: String = "gbp"
    
    let showFullDetails: Bool
    
    init(showFullDetails: Bool = false) {
        self.showFullDetails = showFullDetails
    }
    
    var body: some View {
        Button(action: {
            HapticFeedbacks.soft()
            creditUIManager.showCreditsPage()
        }) {
            HStack(spacing: 12) {
                // Credit icon
                CreditIcon(type: .creditBalance, size: .footnote)
                
                // Credit info
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("\(creditService.currentCredits)")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.appText)
                        
                        Text(creditService.currentCredits == 1 ? "Credit" : "Credits")
                            .font(.body)
                            .foregroundColor(.appText.opacity(0.7))
                    }
                    
                    if showFullDetails {
                        statusText
                    } else {
                        Text("Tap to manage")
                            .font(.caption)
                            .foregroundColor(.appText.opacity(0.6))
                    }
                }
                
                Spacer()
                
                if showFullDetails && creditService.currentCredits < 5 {
                    // Quick buy button for low credits
                    Button(action: {
                        if let package = quickPurchasePackage {
                            quickPurchaseCredits(package: package)
                        } else {
                            creditUIManager.showPurchaseSheet()
                        }
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(.appPrimary)
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    // Arrow indicator
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.appText.opacity(0.4))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .task {
            await creditService.fetchUserCredits()
            await fetchQuickPurchasePackage()
        }
    }
    
    private func fetchQuickPurchasePackage() async {
        await withCheckedContinuation { continuation in
            NetworkClient.shared.getCreditPackages { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let packagesResponse):
                        // Find the smallest package for quick purchase
                        self.quickPurchasePackage = packagesResponse.packages.min { $0.credits < $1.credits }
                        self.currency = packagesResponse.effectiveCurrency
                        
                    case .failure(let error):
                        print("❌ Failed to fetch quick purchase package: \(error.localizedDescription)")
                        self.quickPurchasePackage = nil
                        self.currency = "gbp" // Default fallback
                    }
                    
                    continuation.resume()
                }
            }
        }
    }
    
    private func quickPurchaseCredits(package: CreditPackage) {
        NetworkClient.shared.createStripeCheckoutSession(packageId: package.id) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let checkoutResponse):
                    // Open Stripe checkout URL
                    if let url = URL(string: checkoutResponse.url) {
                        if UIApplication.shared.canOpenURL(url) {
                            UIApplication.shared.open(url)
                        }
                    }
                case .failure:
                    // Fallback to showing purchase sheet on error
                    creditUIManager.showPurchaseSheet()
                }
            }
        }
    }
    
    private var statusText: some View {
        Group {
            if creditService.currentCredits == 0 {
                Text("Out of credits")
                    .font(.caption)
                    .foregroundColor(.appError)
            } else if creditService.currentCredits < 5 {
                Text("Running low")
                    .font(.caption)
                    .foregroundColor(.orange)
            } else {
                Text("Good balance")
                    .font(.caption)
                    .foregroundColor(.appAccent)
            }
        }
    }
}

// MARK: - Compact Credit Badge
struct CreditBadge: View {
    @StateObject private var creditService = CreditService.shared
    @EnvironmentObject private var creditUIManager: CreditUIManager
    
    var body: some View {
        Button(action: {
            HapticFeedbacks.soft()
            creditUIManager.showCreditsPage()
        }) {
            HStack(spacing: 6) {
                Image(systemName: "creditcard.fill")
                    .font(.caption)
                    .foregroundColor(.appPrimary)
                
                Text("\(creditService.currentCredits)")
                    .font(.caption.monospaced())
                    .fontWeight(.medium)
                    .foregroundColor(.appText)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.appPrimary.opacity(0.1))
                    .stroke(Color.appPrimary.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .task {
            await creditService.fetchUserCredits()
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        CreditBalanceCard()
        CreditBalanceCard(showFullDetails: true)
        CreditBadge()
    }
    .padding()
    .withAppBackground()
    .environmentObject(CreditUIManager())
} 
