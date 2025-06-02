//
//  ProfileView.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 20/05/2025.
//

import SwiftUI
import FirebaseAuth
import PhotosUI
import UIKit

struct ProfileView: View {
    @EnvironmentObject private var authVM: AuthenticationViewModel
    @EnvironmentObject private var toast: ToastManager
    @EnvironmentObject private var creditUIManager: CreditUIManager
    @StateObject private var vm = ProfileViewModel()
    @StateObject private var libraryVM = MyLibraryViewModel()
    @StateObject private var creditService = CreditService.shared
    @State private var quickPurchasePackage: CreditPackage?
    @State private var currency: String = "gbp"

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
                // MARK: — Profile Header Section
                if let user = authVM.user {
                    profileHeaderSection(user: user)
                        .padding(.top, 20)
                }

                // MARK: — My Library Section
                myLibrarySection

                // MARK: — Recent Transactions Section
                recentTransactionsSection

                Spacer(minLength: 200)

                // MARK: — Actions
                Button(role: .destructive) {
                    authVM.signOut()
                } label: {
                    Label("Sign Out", systemImage: "arrow.backward.circle")
                        .font(.headline)
                }
                .padding()
            }
            .padding(.horizontal)
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .sheet(isPresented: $vm.isSharing) {
            if let image = vm.qrImage {
                ActivityView(activityItems: [image])
            }
        }
        .withAppBackground()
        .onChange(of: vm.selectedImageItem) { _, _ in
            vm.handleImageSelection()
        }
        .onAppear {
            // Set the references when view appears
            vm.authViewModel = authVM
            vm.toastManager = toast
            
            // Background load user's library for faster access
            if let userId = authVM.user?.uid {
                libraryVM.setAuthorId(userId)
                libraryVM.backgroundLoadUserIdeas()
            }
            
            // Fetch quick purchase package for "Buy More" button
            Task {
                await fetchQuickPurchasePackage()
            }
            
            // Note: We rely on CreditService.shared local cache instead of fetching every time
            // Credit data gets updated automatically when:
            // - User performs credit-consuming actions
            // - Payment succeeds
            // - App initially loads and fetches user data
        }
    }
    
    // MARK: - Profile Header Section
    @ViewBuilder
    private func profileHeaderSection(user: FirebaseAuth.User) -> some View {
        HStack(alignment: .top, spacing: 16) {
            // Left: Profile Image (tappable)
            PhotosPicker(
                selection: $vm.selectedImageItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                profileImageSection(user: user)
            }
            
            // Right: User Info
            VStack(alignment: .leading, spacing: 3) {
                // User Display Name
                Text(user.displayName ?? "Guest User")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                // Stats Section
                VStack(alignment: .leading, spacing: 8) {
                    // Member Since
                    if let currentUser = authVM.currentUser {
                        Text(currentUser.memberSinceText)
                            .font(.caption).monospaced()
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 8) {
                            // Credits Badge
                            CreditBadge()
                            
                            // Player Level Pill - flexible to avoid wrapping
                            PlayerLevelPill(level: currentUser.playerLevelInfo)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text("Member since recently")
                            .font(.caption).monospaced()
                            .foregroundColor(.secondary)
                        
                        // Default level pill
                        PlayerLevelPill(level: .ideaSpark)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .padding(.trailing, 10) // Ensure 10pt padding from trailing edge
    }
    
    // MARK: - My Library Section
    @ViewBuilder
    private var myLibrarySection: some View {
        NavigationLink(destination: MyLibraryView(viewModel: libraryVM)) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: "folder")
                    .font(.title2)
                    .foregroundColor(.appPrimary)
                    .frame(width: 32, height: 32)
                
                // Content
                VStack(alignment: .leading, spacing: 2) {
                    Text("My Library")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("Browse all your ideas")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
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
    
    // MARK: - Recent Transactions Section
    @ViewBuilder
    private var recentTransactionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Transactions")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: {
                    creditUIManager.showCreditsPage()
                }) {
                    Text("View All")
                        .font(.subheadline)
                        .foregroundColor(.appPrimary)
                }
                .buttonStyle(.plain)
            }
            
            if creditService.isLoading {
                loadingTransactionsView
            } else if recentTransactions.isEmpty {
                emptyTransactionsView
            } else {
                transactionsListView
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
        )
    }
    
    private var recentTransactions: [CreditTransaction] {
        Array(creditService.creditHistory.prefix(3))
    }
    
    private var loadingTransactionsView: some View {
        VStack(spacing: 12) {
            ForEach(0..<2, id: \.self) { _ in
                HStack {
                    Circle()
                        .fill(.gray.opacity(0.2))
                        .frame(width: 24, height: 24)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.gray.opacity(0.2))
                            .frame(height: 12)
                            .frame(maxWidth: .infinity)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.gray.opacity(0.1))
                            .frame(height: 10)
                            .frame(width: 100)
                    }
                    
                    Spacer()
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.gray.opacity(0.2))
                        .frame(width: 40, height: 12)
                }
            }
        }
        .redacted(reason: .placeholder)
    }
    
    private var emptyTransactionsView: some View {
        VStack(spacing: 8) {
            Image(systemName: "creditcard")
                .font(.title2)
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No transactions yet")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("Your credit activity will appear here")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
    }
    
    private var transactionsListView: some View {
        VStack(spacing: 12) {
            ForEach(recentTransactions) { transaction in
                ProfileTransactionRow(transaction: transaction)
            }
        }
    }
    
    // MARK: - Profile Image Section
    @ViewBuilder
    private func profileImageSection(user: FirebaseAuth.User) -> some View {
        ZStack {
            // Highest priority: Immediately selected image (before upload completes)
            if let selectedImage = vm.selectedUIImage {
                Image(uiImage: selectedImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
            }
            // Second priority: Custom uploaded profile image from backend
            else if let customUser = authVM.currentUser,
                    let profileImageUrl = customUser.profileImageUrl,
                    !profileImageUrl.isEmpty {
                AsyncImage(url: URL(string: profileImageUrl)) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: 80, height: 80)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                    case .failure:
                        // Fallback to Firebase photo or initials
                        fallbackProfileImage(user: user)
                    @unknown default:
                        EmptyView()
                    }
                }
            }
            // Third priority: Firebase photo URL
            else if let url = user.photoURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: 80, height: 80)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                    case .failure:
                        // Fallback to initials
                        ProfileImage(user: User(id: user.uid, name: user.displayName), diam: 80)
                    @unknown default:
                        EmptyView()
                    }
                }
            }
            // Lowest priority: Initials fallback
            else {
                ProfileImage(user: User(id: user.uid, name: user.displayName), diam: 80)
            }
            
            // Camera icon overlay to indicate tappability
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Image(systemName: "camera.fill")
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(6)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                        .offset(x: 3, y: -1)
                }
            }
            .frame(width: 80, height: 80)
        }
    }
    
    @ViewBuilder
    private func fallbackProfileImage(user: FirebaseAuth.User) -> some View {
        if let url = user.photoURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(width: 80, height: 80)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                case .failure:
                    ProfileImage(user: User(id: user.uid, name: user.displayName), diam: 80)
                @unknown default:
                    EmptyView()
                }
            }
        } else {
            ProfileImage(user: User(id: user.uid, name: user.displayName), diam: 80)
        }
    }
    
    private func refreshData() async {
        await creditService.refreshCreditData()
    }
    
    // MARK: - Quick Purchase Credits
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
                        } else {
                            toast.error("Unable to open payment page")
                        }
                    } else {
                        toast.error("Invalid payment URL received")
                    }
                    
                case .failure(let error):
                    toast.error("Payment failed: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: — Profile Transaction Row (Compact Version)
struct ProfileTransactionRow: View {
    let transaction: CreditTransaction
    
    var body: some View {
        HStack(spacing: 12) {
            // Transaction icon (smaller than full view)
            transactionIcon
            
            // Transaction details
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.description)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(transaction.formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Amount
            Text(transaction.formattedAmount)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(transaction.isPositive ? .appAccent : .primary)
        }
    }
    
    private var transactionIcon: some View {
        CreditIcon(
            type: CreditIconType.from(transactionType: transaction.transactionType),
            size: .caption,
            frameSize: 24
        )
    }
}

// MARK: — Share Sheet Representable
struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationView {
        ProfileView()
            .environmentObject(AuthenticationViewModel())
            .environmentObject(ToastManager())
    }
}
