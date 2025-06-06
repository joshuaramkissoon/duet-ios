//
//  BlockUserView.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 20/12/2024.
//

import SwiftUI

struct BlockUserView: View {
    let user: User
    @Binding var isPresented: Bool
    @EnvironmentObject private var toast: ToastManager
    
    @State private var isBlocking: Bool = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // Header Section
                    VStack(spacing: 20) {
                        // Beautiful icon
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.red.opacity(0.15), Color.red.opacity(0.05)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 100, height: 100)
                            
                            Image(systemName: "person.slash.fill")
                                .font(.system(size: 40, weight: .medium))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.red.opacity(0.8), Color.red],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        
                        VStack(spacing: 12) {
                            Text("Block User")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Text("Are you sure you want to block **\(user.displayName)**?")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(3)
                        }
                    }
                    .padding(.top, 20)
                    
                    // Information Card
                    VStack(spacing: 20) {
                        Text("What happens when you block this user:")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        VStack(spacing: 16) {
                            BlockInfoRow(
                                icon: "eye.slash.fill",
                                text: "Their content will be hidden from your feed",
                                color: .blue
                            )
                            
                            BlockInfoRow(
                                icon: "shield.fill",
                                text: "They won't be able to see your public content",
                                color: .green
                            )
                            
                            BlockInfoRow(
                                icon: "arrow.uturn.left.circle.fill",
                                text: "You can unblock them later in Settings",
                                color: .orange
                            )
                        }
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(.secondary)
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 12) {
                    // Block button
                    Button(action: blockUser) {
                        HStack(spacing: 12) {
                            if isBlocking {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.9)
                                
                                Text("Blocking User...")
                                    .fontWeight(.semibold)
                            } else {
                                Image(systemName: "person.slash.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                
                                Text("Block User")
                                    .fontWeight(.semibold)
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                colors: [Color.red.opacity(0.9), Color.red],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: Color.red.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .disabled(isBlocking)
                    .scaleEffect(isBlocking ? 0.98 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: isBlocking)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
                .background(
                    Color(.systemGroupedBackground)
                        .ignoresSafeArea()
                )
            }
        }
        .toast($toast.state)
    }
    
    private func blockUser() {
        guard !isBlocking else { return }
        
        withAnimation(.easeInOut(duration: 0.2)) {
            isBlocking = true
        }
        
        ContentModerationService.shared.blockUsers(userIds: [user.id]) { result in
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isBlocking = false
                }
                
                switch result {
                case .success:
                    toast.success("User blocked successfully. Their content will no longer appear in your feed.")
                    
                    // Post notification to update UI throughout the app
                    NotificationCenter.default.post(
                        name: .userBlocked,
                        object: nil,
                        userInfo: ["blockedUserId": user.id]
                    )
                    
                    // Delay dismissal to allow toast to appear
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isPresented = false
                    }
                    
                case .failure(let error):
                    toast.error("Failed to block user: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - Block Info Row

struct BlockInfoRow: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(color)
            }
            
            Text(text)
                .font(.body)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let userBlocked = Notification.Name("userBlocked")
}

#Preview {
    BlockUserView(
        user: User(id: "test-id", name: "Test User"),
        isPresented: .constant(true)
    )
    .environmentObject(ToastManager())
} 