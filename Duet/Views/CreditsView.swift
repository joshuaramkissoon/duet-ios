//
//  CreditsView.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 20/12/2024.
//

import SwiftUI
import UIKit

struct CreditsView: View {
    @StateObject private var creditService = CreditService.shared
    @StateObject private var welcomeCreditService = WelcomeCreditService.shared
    @EnvironmentObject private var creditUIManager: CreditUIManager
    @State private var creditPackages: [CreditPackage] = []
    @State private var currency: String = "gbp"
    @State private var isLoadingPackages = false
    @Environment(\.dismiss) private var dismiss
    
    // Filter state for transaction history
    @State private var selectedTransactionFilter: TransactionFilter = .all
    
    enum TransactionFilter: String, CaseIterable {
        case all = "All"
        case incoming = "In"
        case outgoing = "Out"
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // MARK: - Credit Balance Header
                    creditBalanceCard
                    
                    // MARK: - Quick Actions
                    quickActionsSection
                    
                    // MARK: - Transaction History
                    transactionHistorySection
                    
                    Spacer(minLength: 100) // Bottom padding
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
            }
            .withAppBackground()
            .navigationTitle("Credits")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        creditUIManager.hideCreditsPage()
                    }
                    .foregroundColor(.appPrimary)
                }
            }
            .refreshable {
                await refreshData()
            }
        }
        .task {
            await loadInitialData()
        }
    }
    
    // MARK: - Credit Balance Card
    private var creditBalanceCard: some View {
        VStack(spacing: 16) {
            // Credit icon and balance
            VStack(spacing: 8) {
                Image("duet-star")
                    .resizable()
                    .scaledToFit()
                    .padding(.horizontal, 40)
                
                Text("\(creditService.currentCredits)")
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundColor(.appText)
                
                Text(creditService.currentCredits == 1 ? "Credit" : "Credits")
                    .font(.title3)
                    .foregroundColor(.appText.opacity(0.7))
            }
            
            // Status message
            statusMessage
            
            // Buy More Credits Button
            NavigationLink(destination: PurchaseCreditsView(currency: currency)) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Buy More Credits")
                }
                .font(.headline)
                .foregroundColor(.appPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.appPrimaryLightBackground)
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white)
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 2)
        )
    }
    
    private var statusMessage: some View {
        Group {
            if creditService.currentCredits == 0 {
                Text("You're out of credits! Purchase more to continue processing videos.")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.appError)
                    .multilineTextAlignment(.center)
            } else if creditService.currentCredits < 5 {
                Text("You're running low on credits. Consider purchasing more.")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.appPrimary.opacity(0.8))
                    .multilineTextAlignment(.center)
            } else if creditService.currentCredits <= 20 {
                Text("You're cruising along nicely - but keep an eye on those credits!")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.appAccent)
                    .multilineTextAlignment(.center)
            } else {
                Text("You're loaded! Time to go wild with those video ideas.")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.appAccent)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    // MARK: - Quick Actions Section
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How Credits Work")
                .font(.headline)
                .foregroundColor(.appText)
            
            VStack(spacing: 12) {
                creditInfoRow(
                    iconType: .usage,
                    title: "Process Video",
                    description: "1 credit used per video"
                )
                
                creditInfoRow(
                    iconType: .bonus,
                    title: "Welcome Bonus",
                    description: "+\(welcomeCreditService.welcomeCredits) free credits when you join"
                )
                
                creditInfoRow(
                    iconType: .levelUp,
                    title: "Level Up Bonus",
                    description: "+\(welcomeCreditService.levelUpBonus) credits when you level up"
                )

                creditInfoRow(
                    iconType: .referral,
                    title: "Referral Bonus",
                    description: "+10 credits for each friend you refer"
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white)
                .shadow(color: .black.opacity(0.03), radius: 5, x: 0, y: 1)
        )
    }
    
    private func creditInfoRow(iconType: CreditIconType, title: String, description: String) -> some View {
        HStack(spacing: 12) {
            CreditIcon(type: iconType, size: .footnote)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.appText)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.appText.opacity(0.6))
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Transaction History Section
    private var transactionHistorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Transaction History")
                    .font(.headline)
                    .foregroundColor(.appText)
                
                Spacer()
                
                Button("Refresh") {
                    Task {
                        await creditService.fetchCreditHistory()
                    }
                }
                .font(.caption)
                .foregroundColor(.appPrimary)
            }
            
            // Transaction Filter Toggle
            transactionFilterToggle
            
            if creditService.isLoading {
                loadingTransactionsView
            } else if filteredTransactions.isEmpty {
                emptyTransactionsView
            } else {
                transactionsList
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white)
                .shadow(color: .black.opacity(0.03), radius: 5, x: 0, y: 1)
        )
    }
    
    // MARK: - Transaction Filter Toggle
    private var transactionFilterToggle: some View {
        HStack(spacing: 8) {
            ForEach([TransactionFilter.incoming, TransactionFilter.outgoing], id: \.self) { filter in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTransactionFilter = selectedTransactionFilter == filter ? .all : filter
                    }
                }) {
                    Text(filter.rawValue)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(selectedTransactionFilter == filter ? .white : .appText.opacity(0.7))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(selectedTransactionFilter == filter ? Color.appPrimary : Color.appText.opacity(0.1))
                        .cornerRadius(16)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            Spacer()
        }
    }
    
    // MARK: - Filtered Transactions
    private var filteredTransactions: [CreditTransaction] {
        switch selectedTransactionFilter {
        case .all:
            return creditService.creditHistory
        case .incoming:
            return creditService.creditHistory.filter { $0.isPositive }
        case .outgoing:
            return creditService.creditHistory.filter { !$0.isPositive }
        }
    }
    
    private var loadingTransactionsView: some View {
        VStack(spacing: 16) {
            ForEach(0..<3, id: \.self) { _ in
                HStack {
                    Circle()
                        .fill(.gray.opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.gray.opacity(0.2))
                            .frame(height: 14)
                            .frame(maxWidth: .infinity)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.gray.opacity(0.1))
                            .frame(height: 12)
                            .frame(maxWidth: .infinity)
                    }
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.gray.opacity(0.2))
                        .frame(width: 50, height: 14)
                }
                .padding(.vertical, 8)
            }
        }
        .redacted(reason: .placeholder)
    }
    
    private var emptyTransactionsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.largeTitle)
                .foregroundColor(.gray.opacity(0.5))
            
            Text(emptyTransactionsTitle)
                .font(.headline)
                .foregroundColor(.appText.opacity(0.7))
            
            Text(emptyTransactionsMessage)
                .font(.caption)
                .foregroundColor(.appText.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
    }
    
    private var emptyTransactionsTitle: String {
        switch selectedTransactionFilter {
        case .all:
            return "No transactions yet"
        case .incoming:
            return "No incoming transactions"
        case .outgoing:
            return "No outgoing transactions"
        }
    }
    
    private var emptyTransactionsMessage: String {
        switch selectedTransactionFilter {
        case .all:
            return "Your credit transactions will appear here"
        case .incoming:
            return "Credit purchases and bonuses will appear here"
        case .outgoing:
            return "Credits used for video processing will appear here"
        }
    }
    
    private var transactionsList: some View {
        LazyVStack(spacing: 12) {
            ForEach(filteredTransactions) { transaction in
                TransactionRow(transaction: transaction)
            }
        }
    }
    
    // MARK: - Actions
    private func loadInitialData() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await creditService.refreshCreditData()
            }
            group.addTask {
                await fetchCreditPackages()
            }
        }
    }
    
    private func refreshData() async {
        await loadInitialData()
    }
    
    private func fetchCreditPackages() async {
        await MainActor.run {
            isLoadingPackages = true
        }
        
        await withCheckedContinuation { continuation in
            NetworkClient.shared.getCreditPackages { result in
                DispatchQueue.main.async {
                    self.isLoadingPackages = false
                    
                    switch result {
                    case .success(let packagesResponse):
                        self.creditPackages = packagesResponse.packages
                        self.currency = packagesResponse.effectiveCurrency
                        
                    case .failure(let error):
                        print("❌ Failed to fetch credit packages: \(error.localizedDescription)")
                        self.creditPackages = []
                        self.currency = "gbp" // Default fallback
                    }
                    
                    continuation.resume()
                }
            }
        }
    }
}

// MARK: - Transaction Row
struct TransactionRow: View {
    let transaction: CreditTransaction
    
    var body: some View {
        HStack(spacing: 12) {
            // Transaction icon
            transactionIcon
            
            // Transaction details
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.description)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.appText)
                    .lineLimit(2)
                
                Text(transaction.formattedDate)
                    .font(.caption)
                    .foregroundColor(.appText.opacity(0.6))
            }
            
            Spacer()
            
            // Amount
            Text(transaction.formattedAmount)
                .font(.body)
                .fontWeight(.semibold)
                .foregroundColor(transaction.isPositive ? .appAccent : .appText.opacity(0.8))
        }
        .padding(.vertical, 8)
    }
    
    private var transactionIcon: some View {
        CreditIcon(type: CreditIconType.from(transactionType: transaction.transactionType), size: .footnote)
    }
}

// MARK: - Purchase Credits View (for Navigation)
struct PurchaseCreditsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var creditPackages: [CreditPackage] = []
    @State private var currency: String = "gbp"
    @State private var isLoadingPackages = false
    
    let initialCurrency: String?
    
    init(currency: String? = nil) {
        self.initialCurrency = currency
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "creditcard.and.123")
                    .font(.system(size: 48))
                    .foregroundColor(.appPrimary)
                
                Text("Buy Credits")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.appText)
                
                Text("Purchase credits to continue processing videos")
                    .font(.body)
                    .foregroundColor(.appText.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 20)
            
            // Credit packages
            if isLoadingPackages {
                ProgressView("Loading packages...")
                    .padding()
            } else if creditPackages.isEmpty {
                Text("No packages available")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                VStack(spacing: 16) {
                    ForEach(creditPackages, id: \.id) { package in
                        CreditPackageCard(package: package, currency: currency)
                    }
                }
                .padding(.horizontal, 20)
            }
            
            Spacer()
            
            if creditPackages.isEmpty && !isLoadingPackages {
                // Coming Soon Notice (fallback)
                VStack(spacing: 12) {
                    Text("Payment integration coming soon!")
                        .font(.headline)
                        .foregroundColor(.appText)
                    
                    Text("We're working on integrating secure payments. Stay tuned!")
                        .font(.body)
                        .foregroundColor(.appText.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .withAppBackground()
        .navigationTitle("Buy Credits")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.medium))
                        Text("Back")
                    }
                    .foregroundColor(.appPrimary)
                }
            }
        }
        .task {
            await fetchCreditPackages()
        }
        .onAppear {
            // Set initial currency if provided
            if let initialCurrency = initialCurrency {
                currency = initialCurrency
            }
        }
    }
    
    private func fetchCreditPackages() async {
        await MainActor.run {
            isLoadingPackages = true
        }
        
        await withCheckedContinuation { continuation in
            NetworkClient.shared.getCreditPackages { result in
                DispatchQueue.main.async {
                    self.isLoadingPackages = false
                    
                    switch result {
                    case .success(let packagesResponse):
                        self.creditPackages = packagesResponse.packages
                        self.currency = packagesResponse.effectiveCurrency
                        
                    case .failure(let error):
                        print("❌ Failed to fetch credit packages: \(error.localizedDescription)")
                        self.creditPackages = []
                        self.currency = "gbp" // Default fallback
                    }
                    
                    continuation.resume()
                }
            }
        }
    }
}

// MARK: - Purchase Credits Sheet (for standalone sheet presentation)
struct PurchaseCreditsSheet: View {
    @EnvironmentObject private var creditUIManager: CreditUIManager
    
    var body: some View {
        NavigationView {
            PurchaseCreditsView(currency: "gbp") // Default currency for sheet presentation
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            creditUIManager.hidePurchaseSheet()
                        }
                        .foregroundColor(.appPrimary)
                    }
                }
        }
    }
}

// MARK: - Credit Package Card
struct CreditPackageCard: View {
    let package: CreditPackage
    let currency: String
    @State private var showComingSoon = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        Button(action: {
            purchaseCredits()
        }) {
            cardContent
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isLoading)
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }
    
    private func purchaseCredits() {
        isLoading = true
        errorMessage = nil
        
        NetworkClient.shared.createStripeCheckoutSession(packageId: package.id) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                
                switch result {
                case .success(let checkoutResponse):
                    // Open Stripe checkout URL
                    if let url = URL(string: checkoutResponse.url) {
                        if UIApplication.shared.canOpenURL(url) {
                            UIApplication.shared.open(url)
                        } else {
                            self.errorMessage = "Unable to open payment page"
                        }
                    } else {
                        self.errorMessage = "Invalid payment URL received"
                    }
                    
                case .failure(let error):
                    self.errorMessage = "Payment failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private var cardContent: some View {
        HStack {
            leftContent
            Spacer()
            if isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                rightContent
            }
        }
        .padding(20)
        .background(cardBackground)
    }
    
    private var leftContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            creditsHeader
            videoDescription
        }
    }
    
    private var creditsHeader: some View {
        HStack {
            Text("\(package.credits) Credits")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.appText)
            
            if let badge = package.badge {
                badgeView(badge)
            }
        }
    }
    
    private func badgeView(_ badge: String) -> some View {
        Text(badge)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Color.appPrimary)
            .cornerRadius(4)
    }
    
    private var videoDescription: some View {
        Text("Perfect for \(package.videoCount) videos")
            .font(.caption)
            .foregroundColor(.appText.opacity(0.6))
    }
    
    private var rightContent: some View {
        VStack(alignment: .trailing, spacing: 2) {
            priceText
            if package.credits > 10 {
                savingsText
            }
        }
    }
    
    private var priceText: some View {
        Text(package.price(currency: currency))
            .font(.title2)
            .fontWeight(.bold)
            .foregroundColor(.appPrimary)
    }
    
    private var savingsText: some View {
        Text("Save \(package.savingsPercentage)%")
            .font(.caption)
            .foregroundColor(.appAccent)
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(.white)
            .stroke(strokeColor, lineWidth: 1)
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    private var strokeColor: Color {
        package.badge != nil ? .appPrimary.opacity(0.3) : .clear
    }
}

// MARK: - Preview
#Preview {
    TransactionRow(transaction: CreditTransaction(id: 0, amount: 12, transactionType: "purchase", stripePaymentIntentId: nil, description: "Purchased credits", createdAt: "Now"))
    TransactionRow(transaction: CreditTransaction(id: 0, amount: -1, transactionType: "usage", stripePaymentIntentId: nil, description: "Process video", createdAt: "Now"))
    TransactionRow(transaction: CreditTransaction(id: 0, amount: 100, transactionType: "bonus", stripePaymentIntentId: nil, description: "Friendly bonus", createdAt: "Now"))
    TransactionRow(transaction: CreditTransaction(id: 0, amount: 20, transactionType: "level_up_bonus", stripePaymentIntentId: nil, description: "Reached Creative Flame level!", createdAt: "Now"))
}
