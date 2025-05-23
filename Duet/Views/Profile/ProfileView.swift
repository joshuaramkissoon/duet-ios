//
//  ProfileView.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 20/05/2025.
//

import SwiftUI

import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    @EnvironmentObject private var authVM: AuthenticationViewModel
    @StateObject private var vm = ProfileViewModel()

    var body: some View {
        VStack(spacing: 24) {
            // MARK: — User Info
            if let user = authVM.user {
                VStack(spacing: 12) {
                    if let url = user.photoURL {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                // Placeholder while loading
                                ProgressView()
                                    .frame(width: 80, height: 80)
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipShape(Circle())
                            case .failure:
                                // Fallback image
                                ProfileImage(user: User(id: user.uid, name: user.displayName), diam: 80)
                            @unknown default:
                                EmptyView()
                            }
                        }
                    }
                    else {
                        UserProfileImage(user: User(id: user.uid, name: user.displayName), diam: 80)
                    }

                    if let email = user.email {
                        Text(email)
                            .font(.footnote).monospaced()
                            .foregroundColor(.secondary)
                    }
                }
            }

            Divider().padding(.horizontal)

            Spacer()

            // MARK: — Actions
            Button(role: .destructive) {
                authVM.signOut()
            } label: {
                Label("Sign Out", systemImage: "arrow.backward.circle")
                    .font(.headline)
            }
            .padding()
        }
        .padding()
        .sheet(isPresented: $vm.isSharing) {
            if let image = vm.qrImage {
                ActivityView(activityItems: [image])
            }
        }
        .withAppBackground()
        .navigationTitle("Profile")
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
    }
}
