//
//  ManageSubscriptionView.swift
//  Duet
//
//  Created by Assistant on ${new Date().toLocaleDateString()}
//

import SwiftUI
import MessageUI

struct ManageSubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var subscriptionService: SubscriptionService
    @EnvironmentObject private var toast: ToastManager
    @State private var isLoading = true
    @State private var showMailComposer = false
    @State private var showCancelInstructions = false
    
    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    if isLoading {
                        loadingView
                    } else {
                        // Current Plan Status Card
                        currentPlanCard
                        
                        // Trial Status Card (if applicable)
                        if subscriptionService.subscriptionStatus.isSubscribed && isInTrial {
                            trialStatusCard
                        }
                        
                        // Quick Actions
                        quickActionsSection
                        
                        // Premium Benefits
                        premiumBenefitsSection
                        
                        Spacer(minLength: 40)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .withAppBackground()
            .navigationTitle("Subscription")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.appPrimary)
                }
            }
        }
        .sheet(isPresented: $showMailComposer) {
            MailComposeView(
                subject: "Duet Pro Support Request",
                toRecipients: ["help@duetai.com"],
                messageBody: """
                Hi Duet Support Team,
                
                I need help with my Duet Pro subscription.
                
                Current Plan: \(planDisplayName)
                Subscription Status: \(subscriptionStatusText)
                
                Please describe your issue below:
                
                """
            )
        }
        .sheet(isPresented: $showCancelInstructions) {
            CancelInstructionsView()
        }
        .toast($toast.state)
        .task {
            await loadSubscriptionData()
        }
        .refreshable {
            await loadSubscriptionData()
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(.appPrimary)
            
            Text("Loading subscription details...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
    
    // MARK: - Current Plan Card
    
    private var currentPlanCard: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Plan")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(subscriptionStatusText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Status badge
                statusBadge
            }
            
            Divider()
                .background(Color.appDivider)
            
            // Plan details
            VStack(spacing: 16) {
                planDetailRow(
                    title: "Plan",
                    value: planDisplayName,
                    icon: "crown.fill"
                )
                
                if let price = currentPrice {
                    planDetailRow(
                        title: "Price",
                        value: price,
                        icon: "creditcard.fill"
                    )
                }
                
                if let nextBillingDate = nextBillingDate {
                    planDetailRow(
                        title: "Next Billing",
                        value: nextBillingDate,
                        icon: "calendar"
                    )
                }
                
                planDetailRow(
                    title: "Auto-Renewal",
                    value: subscriptionService.subscriptionStatus.willRenew ? "Enabled" : "Disabled",
                    icon: "arrow.clockwise"
                )
                
                if let purchaseDate = subscriptionService.subscriptionStatus.purchaseDate {
                    planDetailRow(
                        title: "Started",
                        value: DateFormatter.localizedString(from: purchaseDate, dateStyle: .medium, timeStyle: .none),
                        icon: "clock"
                    )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
    
    // MARK: - Trial Status Card
    
    private var trialStatusCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "gift.fill")
                    .font(.title2)
                    .foregroundColor(.appAccent)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Free Trial Active")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    if let expirationDate = subscriptionService.subscriptionStatus.expirationDate {
                        Text(trialTimeRemaining(until: expirationDate))
                            .font(.subheadline)
                            .foregroundColor(.appAccent)
                    }
                }
                
                Spacer()
            }
            
            Text("Your free trial includes all premium features. You can cancel anytime before it ends.")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.appAccent.opacity(0.1))
                .stroke(Color.appAccent.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Quick Actions Section
    
    private var quickActionsSection: some View {
        VStack(spacing: 16) {
            Text("Manage Subscription")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                // Cancel/Manage Subscription
                ActionButton(
                    title: "Manage in App Store",
                    subtitle: "Cancel, change plan, or update billing",
                    icon: "gear",
                    iconColor: .appPrimary,
                    action: {
                        showCancelInstructions = true
                    }
                )
                
                // Restore Purchases
                ActionButton(
                    title: "Restore Purchases",
                    subtitle: "Recover your subscription on this device",
                    icon: "arrow.clockwise",
                    iconColor: .appSecondary,
                    action: {
                        Task {
                            await handleRestorePurchases()
                        }
                    }
                )
                
                // Contact Support
                ActionButton(
                    title: "Contact Support",
                    subtitle: "Get help with your subscription",
                    icon: "envelope",
                    iconColor: .appAccent,
                    action: {
                        if MFMailComposeViewController.canSendMail() {
                            showMailComposer = true
                        } else {
                            toast.error("Mail not configured. Please email help@duetai.com")
                        }
                    }
                )
            }
        }
    }
    
    // MARK: - Premium Benefits Section
    
    private var premiumBenefitsSection: some View {
        VStack(spacing: 16) {
            Text("Your Pro Benefits")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                BenefitRow(
                    icon: "infinity",
                    title: "Unlimited Video Processing",
                    description: "Process as many videos as you want without limits"
                )
                
                BenefitRow(
                    icon: "person.3.fill",
                    title: "Exclusive Group Features",
                    description: "Share and collaborate on ideas with private groups"
                )
                
                BenefitRow(
                    icon: "bolt.fill",
                    title: "Priority AI Processing",
                    description: "Faster processing with advanced AI models"
                )
                
                BenefitRow(
                    icon: "sparkles",
                    title: "Early Access Features",
                    description: "Get new features before everyone else"
                )
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.appPrimary.opacity(0.05))
                    .stroke(Color.appPrimary.opacity(0.2), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Helper Views
    
    private func planDetailRow(title: String, value: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(.appPrimary)
                .frame(width: 20)
            
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
    
    private var statusBadge: some View {
        Text(subscriptionService.subscriptionStatus.isActive ? "ACTIVE" : "INACTIVE")
            .font(.caption)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(subscriptionService.subscriptionStatus.isActive ? Color.appAccent : Color.red)
            )
    }
    
    // MARK: - Computed Properties
    
    private var isInTrial: Bool {
        // Check if subscription has an expiration date in the future (indicating trial)
        if let expirationDate = subscriptionService.subscriptionStatus.expirationDate {
            return expirationDate > Date()
        }
        return false
    }
    
    private var planDisplayName: String {
        guard let productId = subscriptionService.subscriptionStatus.productId else {
            return "Duet Pro"
        }
        
        if productId.lowercased().contains("annual") || productId.lowercased().contains("yearly") {
            return "Annual Pro"
        } else if productId.lowercased().contains("monthly") {
            return "Monthly Pro"
        } else {
            return "Duet Pro"
        }
    }
    
    private var currentPrice: String? {
        // This would need to be fetched from current offerings
        // For now, return a placeholder based on plan type
        if planDisplayName.contains("Annual") {
            return "£49.99/year"
        } else if planDisplayName.contains("Monthly") {
            return "£4.99/month"
        }
        return nil
    }
    
    private var nextBillingDate: String? {
        guard let expirationDate = subscriptionService.subscriptionStatus.expirationDate,
              subscriptionService.subscriptionStatus.willRenew else {
            return nil
        }
        
        return DateFormatter.localizedString(from: expirationDate, dateStyle: .medium, timeStyle: .none)
    }
    
    private var subscriptionStatusText: String {
        if subscriptionService.subscriptionStatus.isActive {
            if isInTrial {
                return "Free trial active"
            } else {
                return "Active subscription"
            }
        } else {
            return "No active subscription"
        }
    }
    
    private func trialTimeRemaining(until date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        let components = calendar.dateComponents([.day], from: now, to: date)
        let daysRemaining = components.day ?? 0
        
        if daysRemaining > 1 {
            return "\(daysRemaining) days left in trial"
        } else if daysRemaining == 1 {
            return "1 day left in trial"
        } else if daysRemaining == 0 {
            return "Trial ends today"
        } else {
            return "Trial expired"
        }
    }
    
    // MARK: - Actions
    
    private func loadSubscriptionData() async {
        isLoading = true
        await subscriptionService.refreshSubscriptionStatus()
        await subscriptionService.fetchOfferings()
        isLoading = false
    }
    
    private func handleRestorePurchases() async {
        // Show loading toast immediately
        toast.loading("Restoring purchases...")
        
        let result = await subscriptionService.restorePurchases()
        
        switch result {
        case .success(let status):
            if status.isSubscribed {
                toast.success("✅ Subscription restored successfully!")
            } else {
                toast.error("No active subscriptions found to restore.")
            }
        case .cancelled:
            toast.dismiss() // Clear loading toast if cancelled
            break
        case .failed(let error):
            toast.error("Failed to restore: \(error.localizedDescription)")
        case .pending:
            toast.loading("Restore in progress...")
        }
    }
}

// MARK: - Supporting Views

struct ActionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(iconColor)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.systemBackground))
                    .stroke(Color.appDivider, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct BenefitRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(.appPrimary)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Cancel Instructions View

struct CancelInstructionsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "gear")
                        .font(.largeTitle)
                        .foregroundColor(.appPrimary)
                    
                    Text("Manage Your Subscription")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("To cancel or modify your subscription, please follow these steps:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Instructions
                VStack(spacing: 16) {
                    InstructionStep(
                        number: 1,
                        title: "Open Settings",
                        description: "Go to your iPhone Settings app"
                    )
                    
                    InstructionStep(
                        number: 2,
                        title: "Tap Your Name",
                        description: "At the top of the Settings screen"
                    )
                    
                    InstructionStep(
                        number: 3,
                        title: "Select Subscriptions",
                        description: "Find and tap 'Subscriptions'"
                    )
                    
                    InstructionStep(
                        number: 4,
                        title: "Choose Duet",
                        description: "Select Duet from your active subscriptions"
                    )
                    
                    InstructionStep(
                        number: 5,
                        title: "Manage or Cancel",
                        description: "Cancel subscription or change your plan"
                    )
                }
                
                Spacer()
                
                // Quick action button
                Button(action: {
                    // Open general settings instead of app-specific settings
                    if let settingsUrl = URL(string: "App-prefs:") {
                        UIApplication.shared.open(settingsUrl)
                    } else if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsUrl)
                    }
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: "gear")
                        Text("Open Settings")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.appPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                Text("Note: Cancelling will take effect at the end of your current billing period.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(20)
            .withAppBackground()
            .navigationTitle("Cancel Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.appPrimary)
                }
            }
        }
    }
}

struct InstructionStep: View {
    let number: Int
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Text("\(number)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color.appSecondary))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Mail Compose View

struct MailComposeView: UIViewControllerRepresentable {
    let subject: String
    let toRecipients: [String]
    let messageBody: String
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        composer.setSubject(subject)
        composer.setToRecipients(toRecipients)
        composer.setMessageBody(messageBody, isHTML: false)
        return composer
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            controller.dismiss(animated: true)
        }
    }
}

#Preview {
    ManageSubscriptionView()
        .environmentObject(SubscriptionService.shared)
        .environmentObject(ToastManager())
} 