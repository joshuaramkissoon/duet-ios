//
//  UserProfileView.swift
//  Duet
//
//  Created by Joshua Ramkissoon on [Date].
//

import SwiftUI

struct UserProfileView: View {
    let user: User
    @EnvironmentObject private var authVM: AuthenticationViewModel
    @EnvironmentObject private var toast: ToastManager
    @StateObject private var libraryVM = MyLibraryViewModel()
    @Environment(\.dismiss) private var dismiss
    
    private var calculatedPlayerLevel: PlayerLevel {
        PlayerLevel(ideaCount: libraryVM.totalUserIdeas)
    }
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
                // Profile Header Section
                profileHeaderSection
                    .padding(.top, 20)

                // User's Ideas Section (similar to My Library)
                userIdeasSection
                    .padding(.horizontal, 20)

                Spacer(minLength: 60)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(user.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .withAppBackground()
        .onAppear {
            // Load user's public ideas
            libraryVM.setAuthorId(user.id)
            libraryVM.loadUserIdeas()
        }
    }
    
    // MARK: - Profile Header Section
    @ViewBuilder
    private var profileHeaderSection: some View {
        HStack(alignment: .top, spacing: 16) {
            // Left: Profile Image (non-interactive)
            ProfileImage(user: user, diam: 80)
            
            // Right: User Info
            VStack(alignment: .leading, spacing: 3) {
                // User Display Name
                Text(user.displayName)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                // Stats Section
                VStack(alignment: .leading, spacing: 8) {
                    // Member Since
                    Text(user.memberSinceText)
                        .font(.caption).monospaced()
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        // Player Level Pill
                        PlayerLevelPill(level: calculatedPlayerLevel)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .padding(.trailing, 10) // Ensure 10pt padding from trailing edge
    }
    
    // MARK: - User's Ideas Section
    @ViewBuilder
    private var userIdeasSection: some View {
        NavigationLink(destination: MyLibraryView(viewModel: libraryVM)) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: "folder")
                    .font(.title2)
                    .foregroundColor(.appPrimary)
                    .frame(width: 32, height: 32)
                
                // Content
                VStack(alignment: .leading, spacing: 2) {
                    Text(ideasTitle)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("Browse \(user.displayName)'s ideas")
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
    
    private var ideasTitle: String {
        if libraryVM.totalUserIdeas > 0 {
            return "\(user.displayName)'s Ideas (\(libraryVM.totalUserIdeas))"
        } else {
            return "\(user.displayName)'s Ideas"
        }
    }
}

#Preview {
    NavigationView {
        UserProfileView(user: User(id: UUID().uuidString, name: "John Doe"))
            .environmentObject(AuthenticationViewModel())
            .environmentObject(ToastManager())
    }
}