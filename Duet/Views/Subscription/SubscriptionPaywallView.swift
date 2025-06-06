//
//  SubscriptionPaywallView.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 20/12/2024.
//

import SwiftUI

struct SubscriptionPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: SubscriptionViewModel
    @EnvironmentObject private var toast: ToastManager
    @State private var currentCarouselIndex: Int = 0
    
    // Carousel content data
    private let carouselItems = [
        CarouselItem(
            title: "Unlock unlimited AI video ideas",
            description: "Get endless inspiration! Access unlimited AI-powered activity, date, and recipe ideas from your favourite videos. Never run out of fun things to do.",
            imageName: "duet-landing",
            backgroundColor: Color(hex: "E8F4FD") // Light blue
        ),
        CarouselItem(
            title: "Exclusive group sharing",
            description: "Share your best ideas with private groups. Collaborate on adventures, surprise dates or new recipes - exclusively for Duet Pro users.",
            imageName: "duet-group",
            backgroundColor: Color(hex: "F0F9E8") // Light green
        ),
        CarouselItem(
            title: "Priority AI with no boundaries",
            description: "Enjoy faster video processing with advanced AI models and early access to new features. Your experience, upgraded.",
            imageName: "duet-star",
            backgroundColor: Color(hex: "FFF4E6") // Light orange
        )
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()
                
                // Main content in scroll view
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        // Hero title
                        heroTitleView
                            .padding(.top, 12)
                            .padding(.horizontal, 20)
                        
                        // Feature carousel with bleeding edges
                        carouselSection
                        
                        // Subscription plans section
                        subscriptionPlansSection
                            .padding(.horizontal, 20)
                        
                        Spacer(minLength: 60)
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.appText)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await handleRestorePurchases()
                        }
                    }) {
                        if viewModel.isRestoring {
                            ProgressView()
                                .scaleEffect(0.7)
                                .tint(.appPrimary)
                        } else {
                            Text("Restore")
                                .foregroundColor(.appPrimary)
                        }
                    }
                    .disabled(viewModel.isRestoring)
                }
            }
        }
        .toast($toast.state) // Add toast to the sheet itself
        .task {
            await viewModel.loadOfferings()
            // Set yearly as default when offerings are loaded
            if let offering = viewModel.defaultOffering,
               let yearlyPackage = offering.yearlyPackage {
                viewModel.selectPackage(yearlyPackage)
            }
        }
        .onChange(of: viewModel.showSuccessAlert) { _, showSuccess in
            if showSuccess {
                // Auto-dismiss the paywall after successful purchase
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    dismiss()
                }
            }
        }
        .alert("Welcome to Duet Pro!", isPresented: $viewModel.showSuccessAlert) {
            Button("Continue") {
                viewModel.dismissSuccessAlert()
                dismiss()
            }
        } message: {
            Text(viewModel.successMessage ?? "")
        }
        .onChange(of: viewModel.errorMessage) { _, error in
            if let error = error {
                toast.error(error)
                viewModel.clearError()
            }
        }
    }
    
    // MARK: - Hero Title
    
    private var heroTitleView: some View {
        VStack(spacing: 12) {
            Text("Unlock Unlimited")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text("AI Video Ideas")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.appPrimary)
        }
        .multilineTextAlignment(.center)
    }
    
    // MARK: - Carousel Section with Bleeding Edges
    
    private var carouselSection: some View {
        VStack(spacing: 8) {
            // Bleeding carousel with inset padding
            TabView(selection: $currentCarouselIndex) {
                ForEach(Array(carouselItems.enumerated()), id: \.offset) { index, item in
                    CarouselCard(item: item)
                        .padding(.horizontal, 20) // Inset padding from bleeding edges
                        .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .frame(height: 380)
            
            // Custom page indicator with current page highlighting
            HStack(spacing: 8) {
                ForEach(0..<carouselItems.count, id: \.self) { index in
                    Circle()
                        .fill(index == currentCarouselIndex ? Color.appPrimary : Color.appPrimary.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .scaleEffect(index == currentCarouselIndex ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: currentCarouselIndex)
                }
            }
            .padding(.top, 4)
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Handle Restore Purchases with Toast Feedback
    
    private func handleRestorePurchases() async {
        let result = await viewModel.restorePurchases()
        
        // Add toast feedback based on result
        switch result {
        case .success(let status):
            if status.isSubscribed {
                toast.success("Subscription restored successfully!")
            } else {
                toast.error("No active subscriptions found to restore.")
            }
        case .cancelled:
            // Don't show anything for user cancellation
            break
        case .failed(let error):
            toast.error("Failed to restore: \(error.localizedDescription)")
        case .pending:
            toast.loading("Restore in progress...")
        }
    }
    
    // MARK: - Subscription Plans Section
    
    private var subscriptionPlansSection: some View {
        VStack(spacing: 32) {
            // Plans title
            VStack(spacing: 8) {
                Text("Choose Your Plan")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Start your free trial today")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Loading state
            if viewModel.isLoading {
                loadingPlansView
            }
            // Plans available
            else if let offering = viewModel.defaultOffering, !offering.packages.isEmpty {
                planSelectionView(offering: offering)
            }
            // Error state
            else {
                errorPlansView
            }
        }
    }
    
    // MARK: - Loading Plans View
    
    private var loadingPlansView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(.appPrimary)
            
            Text("Loading subscription plans...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(height: 120)
    }
    
    // MARK: - Error Plans View
    
    private var errorPlansView: some View {
        VStack(spacing: 20) {
            // Error illustration
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.1))
                    .frame(width: 64, height: 64)
                
                Image(systemName: "wifi.slash")
                    .font(.title2)
                    .foregroundColor(.red)
            }
            
            VStack(spacing: 8) {
                Text("Connection Issue")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("We're having trouble loading subscription plans. Please check your internet connection and try again.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            
            // Retry button
            Button(action: {
                Task {
                    await viewModel.loadOfferings()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.subheadline)
                    
                    Text("Try Again")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.appPrimary)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 20)
    }
    
    // MARK: - Plan Selection View
    
    private func planSelectionView(offering: SubscriptionOffering) -> some View {
        VStack(spacing: 24) {
            // Plans grid
            VStack(spacing: 16) {
                ForEach(offering.packages.sorted(by: { $0.billingPeriod == .yearly && $1.billingPeriod != .yearly })) { package in
                    SubscriptionPlanCard(
                        package: package,
                        isSelected: viewModel.isPackageSelected(package),
                        isPurchasing: viewModel.isPurchasing && viewModel.selectedPackage?.id == package.id,
                        savingsText: savingsText(for: package, in: offering),
                        onTap: {
                            viewModel.selectPackage(package)
                        }
                    )
                }
            }
            
            // Free trial info
            VStack(spacing: 8) {
                Text("✨ 2 weeks free, cancel anytime")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.appPrimary)
                
                Text("Your subscription will start after the free trial ends. You can cancel anytime in Settings.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding(.horizontal, 16)
            
            // Purchase button
            purchaseButton(offering: offering)
        }
    }
    
    private func purchaseButton(offering: SubscriptionOffering) -> some View {
        Button(action: {
            guard let selectedPackage = viewModel.selectedPackage ?? offering.yearlyPackage ?? offering.packages.first else { return }
            
            Task {
                await viewModel.purchase(package: selectedPackage)
            }
        }) {
            HStack(spacing: 12) {
                if viewModel.isPurchasing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)
                    
                    Text("Processing...")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "crown.fill")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("Start Free Trial")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(
                    colors: [Color.appPrimary, Color.appPrimary.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.appPrimary.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .disabled(viewModel.isPurchasing)
    }
    
    private func savingsText(for package: SubscriptionPackage, in offering: SubscriptionOffering) -> String? {
        if package.billingPeriod == .yearly,
           let monthlyPackage = offering.monthlyPackage {
            return viewModel.savingsText(for: package, compared: monthlyPackage)
        }
        return nil
    }
}

// MARK: - Carousel Models

struct CarouselItem: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let imageName: String
    let backgroundColor: Color
}

// MARK: - Carousel Card

struct CarouselCard: View {
    let item: CarouselItem
    
    var body: some View {
        VStack(spacing: 20) {
            // Image container with pastel background
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(item.backgroundColor)
                    .frame(height: 160)
                
                Image(item.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 120)
            }
            .padding(.horizontal, 16) // Add padding around the colored background
            
            // Content
            VStack(spacing: 10) {
                Text(item.title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(item.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)
            }
            .frame(maxWidth: .infinity)
            
            Spacer()
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        )
    }
}

// MARK: - Subscription Plan Card (Enhanced)

struct SubscriptionPlanCard: View {
    let package: SubscriptionPackage
    let isSelected: Bool
    let isPurchasing: Bool
    let savingsText: String?
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.appPrimary : Color.gray.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Circle()
                            .fill(Color.appPrimary)
                            .frame(width: 14, height: 14)
                    }
                }
                
                // Plan details
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(package.billingPeriod.displayName)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        if let savingsText = savingsText {
                            Text(savingsText)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.appAccent)
                                .clipShape(Capsule())
                        }
                        
                        Spacer()
                    }
                    
                    Text(package.price + package.billingPeriod.suffix)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Loading indicator for this specific plan
                if isPurchasing {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.appPrimary)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        isSelected ? Color.appPrimary : Color.gray.opacity(0.2),
                        lineWidth: isSelected ? 2 : 1
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(isSelected ? Color.appPrimary.opacity(0.05) : Color(.systemBackground))
                    )
            )
            .shadow(
                color: isSelected ? Color.appPrimary.opacity(0.1) : Color.black.opacity(0.03),
                radius: isSelected ? 8 : 4,
                x: 0,
                y: isSelected ? 4 : 2
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

#Preview {
    SubscriptionPaywallView()
        .environmentObject(ToastManager())
} 