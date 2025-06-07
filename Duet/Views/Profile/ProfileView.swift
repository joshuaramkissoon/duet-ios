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
    @EnvironmentObject private var myLibraryVM: MyLibraryViewModel
    @EnvironmentObject private var subscriptionService: SubscriptionService

    @StateObject private var vm = ProfileViewModel()
    @State private var showPlayerLevelRoadmap = false
    
    // MARK: - Name Editing State
    @State private var isEditingName = false
    @State private var editingName = ""
    @State private var isUpdatingName = false
    @FocusState private var isNameFieldFocused: Bool
    
    // MARK: - Computed Properties
    
    /// Calculate the current player level based on actual idea count (more reliable than backend level)
    private var calculatedPlayerLevel: PlayerLevel {
        let level = PlayerLevel(ideaCount: myLibraryVM.totalUserIdeas)
        let backendLevel = authVM.currentUser?.playerLevelInfo ?? .ideaSpark
        return level
    }
    
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
                    .padding(.horizontal, 20)

                // MARK: — Settings Section
                settingsSection
                    .padding(.horizontal, 20)

                Spacer(minLength: 60)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("")
        .navigationBarHidden(true)
        .sheet(isPresented: $vm.isSharing) {
            if let image = vm.qrImage {
                ActivityView(activityItems: [image])
            }
        }
        .sheet(isPresented: $showPlayerLevelRoadmap) {
            PlayerLevelRoadmapView(
                currentLevel: calculatedPlayerLevel,
                totalUserIdeas: myLibraryVM.totalUserIdeas
            )
            .onAppear {
                // Force refresh user data when roadmap appears to ensure latest level
                authVM.forceRefreshCurrentUser()
                // Also refresh library count to ensure accuracy
                myLibraryVM.refreshTotalCount()
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
            
            // Ensure MyLibraryViewModel is properly initialized for current user
            if let userId = authVM.user?.uid {
                if myLibraryVM.totalUserIdeas == 0 { // Only load if not already loaded
                    myLibraryVM.setAuthorId(userId)
                    myLibraryVM.backgroundLoadUserIdeas()
                }
            }
            
            // Refresh subscription status
            Task {
                await subscriptionService.refreshSubscriptionStatus()
            }
            
            // Force refresh current user data to ensure we have latest player_level
            if authVM.state == .authenticated {
                authVM.forceRefreshCurrentUser()
            }
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
                // User Display Name - Inline Editable
                HStack {
                    if isEditingName {
                        // Editing State
                        HStack {
                            TextField("Enter name", text: $editingName)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                                .textFieldStyle(.plain)
                                .submitLabel(.done)
                                .disabled(isUpdatingName)
                                .focused($isNameFieldFocused)
                                .onSubmit {
                                    saveNameEdit()
                                }
                            
                            // Save/Cancel buttons
                            HStack(spacing: 4) {
                                // Cancel button
                                Button {
                                    cancelNameEdit()
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title3)
                                        .foregroundColor(.secondary)
                                }
                                .disabled(isUpdatingName)
                                .buttonStyle(.plain)
                                
                                // Save button
                                Button {
                                    saveNameEdit()
                                } label: {
                                    if isUpdatingName {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.title3)
                                            .foregroundColor(.appPrimary)
                                    }
                                }
                                .disabled(editingName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isUpdatingName)
                                .buttonStyle(.plain)
                            }
                        }
                    } else {
                        // Display State
                        Button {
                            startNameEdit(currentName: authVM.currentUser?.displayName ?? user.displayName ?? "")
                        } label: {
                            HStack {
                                Text(authVM.currentUser?.displayName ?? user.displayName ?? "Guest User")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                
                                Image(systemName: "pencil.circle")
                                    .font(.caption)
                                    .foregroundColor(.secondary.opacity(0.6))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // Stats Section
                VStack(alignment: .leading, spacing: 8) {
                    // Member Since
                    if let currentUser = authVM.currentUser {
                        Text(currentUser.memberSinceText)
                            .font(.caption).monospaced()
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 8) {
                            // Simple Pro Badge
                            SimpleProBadge()
                            
                            // Player Level Pill - flexible to avoid wrapping, now tappable
                            Button(action: {
                                HapticFeedbacks.soft()
                                showPlayerLevelRoadmap = true
                            }) {
                                PlayerLevelPill(level: calculatedPlayerLevel)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                            .buttonStyle(.plain)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text("Member since recently")
                            .font(.caption).monospaced()
                            .foregroundColor(.secondary)
                        
                        // Default badges
                        HStack(spacing: 8) {
                            SimpleProBadge()
                            
                            Button(action: {
                                HapticFeedbacks.soft()
                                showPlayerLevelRoadmap = true
                            }) {
                                PlayerLevelPill(level: calculatedPlayerLevel)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                            .buttonStyle(.plain)
                        }
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
        NavigationLink(destination: MyLibraryView(viewModel: myLibraryVM)) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: "folder")
                    .font(.title2)
                    .foregroundColor(.appPrimary)
                    .frame(width: 32, height: 32)
                
                // Content
                VStack(alignment: .leading, spacing: 2) {
                    Text(libraryTitle)
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
                    .fill(Color.adaptiveCardBackground)
                    .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var libraryTitle: String {
        if myLibraryVM.totalUserIdeas > 0 {
            return "My Library (\(myLibraryVM.totalUserIdeas))"
        } else {
            return "My Library"
        }
    }
    
    // MARK: - Settings Section
    @ViewBuilder
    private var settingsSection: some View {
        NavigationLink(destination: SettingsView()) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: "gearshape")
                    .font(.title2)
                    .foregroundColor(.appPrimary)
                    .frame(width: 32, height: 32)
                
                // Content
                VStack(alignment: .leading, spacing: 2) {
                    Text("Settings")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("Manage your preferences")
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
                    .fill(Color.adaptiveCardBackground)
                    .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
            )
        }
        .buttonStyle(.plain)
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
                        // Fallback to initials using backend user data
                        ProfileImage(user: User(id: user.uid, name: authVM.currentUser?.name ?? user.displayName), diam: 80)
                    @unknown default:
                        EmptyView()
                    }
                }
            }
            // Lowest priority: Initials fallback
            else {
                ProfileImage(user: User(id: user.uid, name: authVM.currentUser?.name ?? user.displayName), diam: 80)
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
                    ProfileImage(user: User(id: user.uid, name: authVM.currentUser?.name ?? user.displayName), diam: 80)
                @unknown default:
                    EmptyView()
                }
            }
        } else {
            ProfileImage(user: User(id: user.uid, name: authVM.currentUser?.name ?? user.displayName), diam: 80)
        }
    }
    
    // MARK: - Name Editing Methods
    
    private func startNameEdit(currentName: String) {
        editingName = currentName == "Guest User" ? "" : currentName
        isEditingName = true
        isNameFieldFocused = true
        HapticFeedbacks.soft()
    }
    
    private func cancelNameEdit() {
        editingName = ""
        isEditingName = false
        isNameFieldFocused = false
        HapticFeedbacks.soft()
    }
    
    private func saveNameEdit() {
        let trimmedName = editingName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty else {
            toast.error("Name cannot be empty")
            return
        }
        
        // Don't save if name hasn't changed - use the correct current name
        let currentName = authVM.currentUser?.displayName ?? authVM.user?.displayName ?? ""
        if trimmedName == currentName {
            cancelNameEdit()
            return
        }
        
        isUpdatingName = true
        isNameFieldFocused = false
        HapticFeedbacks.soft()
        
        NetworkClient.shared.updateUser(name: trimmedName) { result in
            DispatchQueue.main.async {
                self.isUpdatingName = false
                
                switch result {
                case .success(let updatedUser):
                    // Update the authentication view model with the new user data
                    self.authVM.updateCurrentUser(updatedUser)
                    
                    // Reset editing state
                    self.isEditingName = false
                    self.editingName = ""
                    
                    // Show success toast
                    self.toast.success("Name updated")
                    
                    // Haptic feedback for success
                    HapticFeedbacks.success()
                    
                case .failure(let error):
                    // Show error toast
                    self.toast.error("Failed to update name")
                    
                    // Haptic feedback for error
                    HapticFeedbacks.error()
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
