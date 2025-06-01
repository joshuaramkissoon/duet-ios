//
//  ProfileView.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 20/05/2025.
//

import SwiftUI
import FirebaseAuth
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject private var authVM: AuthenticationViewModel
    @EnvironmentObject private var toast: ToastManager
    @StateObject private var vm = ProfileViewModel()
    @StateObject private var libraryVM = MyLibraryViewModel()

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
                        
                        // Player Level Pill
                        PlayerLevelPill(level: currentUser.playerLevelInfo)
                    } else {
                        Text("Member since recently")
                            .font(.caption).monospaced()
                            .foregroundColor(.secondary)
                        
                        // Default level pill
                        PlayerLevelPill(level: .ideaSpark)
                    }
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
        }
        .padding()
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
                UserProfileImage(user: User(id: user.uid, name: user.displayName), diam: 80)
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
                        .offset(x: -5, y: -5)
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
