//
//  BlockedUsersView.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 20/12/2024.
//

import SwiftUI

struct BlockedUsersView: View {
    @StateObject private var viewModel = BlockedUsersViewModel()
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var toast: ToastManager
    
    var body: some View {
        NavigationView {
            ZStack {
                // Beautiful gradient background
                LinearGradient(
                    colors: [
                        Color.adaptiveBackground,
                        Color.adaptiveBackground.opacity(0.8)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                if viewModel.isLoading {
                    loadingView
                } else if viewModel.blockedUsers.isEmpty {
                    emptyStateView
                } else {
                    blockedUsersContent
                }
            }
            .navigationTitle("Blocked Users")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.appPrimary)
                    .fontWeight(.medium)
                }
            }
            .refreshable {
                await viewModel.loadBlockedUsers()
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") { }
            } message: {
                Text(viewModel.errorMessage)
            }
            .toast($toast.state)
        }
        .task {
            await viewModel.loadBlockedUsers()
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.1), Color.blue.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .appPrimary))
                    .scaleEffect(1.2)
            }
            
            Text("Loading blocked users...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.green.opacity(0.15), Color.mint.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 50, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.green, Color.mint],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 12) {
                Text("No Blocked Users")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Great! You haven't blocked anyone yet. Users you block will appear here, and you can unblock them anytime.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                    .padding(.horizontal, 20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }
    
    // MARK: - Blocked Users Content
    
    private var blockedUsersContent: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 16) {
                // Header info card
                headerInfoCard
                
                // Blocked users list
                ForEach(viewModel.blockedUsers) { user in
                    BlockedUserCard(
                        user: user,
                        isUnblocking: viewModel.isUnblockingUser == user.id,
                        onUnblock: {
                            Task {
                                await viewModel.unblockUser(userId: user.id, toast: toast)
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Header Info Card
    
    private var headerInfoCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.orange.opacity(0.2), Color.yellow.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.orange)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Blocked Users (\(viewModel.blockedUsers.count))")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("Tap \"Unblock\" to restore a user's access")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.adaptiveCardBackground,
                            Color.adaptiveCardBackground.opacity(0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.orange.opacity(0.2), Color.yellow.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
}

// MARK: - BlockedUserCard

struct BlockedUserCard: View {
    let user: User
    let isUnblocking: Bool
    let onUnblock: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Profile section with beautiful styling
            HStack(spacing: 12) {
                // Profile image with gradient border
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.2), Color.pink.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                    
                    Circle()
                        .fill(Color(.systemBackground))
                        .frame(width: 52, height: 52)
                    
                    // Profile image or initials
                    if let imageUrl = user.profileImageUrl, let url = URL(string: imageUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            profileInitials
                        }
                        .frame(width: 48, height: 48)
                        .clipShape(Circle())
                    } else {
                        profileInitials
                    }
                }
                
                // User info
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.displayName)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "person.slash.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.red.opacity(0.7))
                        
                        Text("Blocked")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.red.opacity(0.7))
                    }
                }
            }
            
            Spacer()
            
            // Unblock button with beautiful styling
            Button(action: onUnblock) {
                HStack(spacing: 8) {
                    if isUnblocking {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color.green.opacity(0.8)))
                            .scaleEffect(0.8)
                    }
                    
                    Text(isUnblocking ? "Unblocking..." : "Unblock")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(Color.green.opacity(0.8))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.green.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .disabled(isUnblocking)
            .scaleEffect(isUnblocking ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isUnblocking)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.adaptiveCardBackground,
                            Color.adaptiveCardBackground.opacity(0.9)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.1), Color.pink.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
    
    private var profileInitials: some View {
        Text(user.initials)
            .font(.body)
            .fontWeight(.semibold)
            .foregroundStyle(
                LinearGradient(
                    colors: [Color.purple, Color.pink],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 48, height: 48)
            .background(
                LinearGradient(
                    colors: [Color.purple.opacity(0.1), Color.pink.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(Circle())
    }
}

#Preview {
    BlockedUsersView()
        .environmentObject(ToastManager())
} 
