//
//  BlockedUsersViewModel.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 20/12/2024.
//

import Foundation
import SwiftUI

@MainActor
class BlockedUsersViewModel: ObservableObject {
    @Published var blockedUsers: [User] = []
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var isUnblockingUser: String? = nil // Track which user is being unblocked
    
    private let contentModerationService = ContentModerationService.shared
    private let networkClient = NetworkClient.shared
    
    func loadBlockedUsers() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // First get blocked user IDs
            let blockedUserIds = try await withCheckedThrowingContinuation { continuation in
                contentModerationService.getBlockedUsers { result in
                    continuation.resume(with: result)
                }
            }
            
            if blockedUserIds.isEmpty {
                blockedUsers = []
                return
            }
            
            // Then get user details for blocked users
            let users = try await withCheckedThrowingContinuation { continuation in
                networkClient.getUsers(with: blockedUserIds) { result in
                    continuation.resume(with: result.mapError { $0 as Error })
                }
            }
            
            blockedUsers = users
            print("✅ Loaded \(users.count) blocked users")
            
        } catch {
            showError(message: "Failed to load blocked users: \(error.localizedDescription)")
        }
    }
    
    func unblockUser(userId: String, toast: ToastManager? = nil) async {
        isUnblockingUser = userId
        defer { isUnblockingUser = nil }
        
        do {
            try await withCheckedThrowingContinuation { continuation in
                contentModerationService.unblockUsers(userIds: [userId]) { result in
                    continuation.resume(with: result)
                }
            }
            
            // Remove from local list
            if let removedUser = blockedUsers.first(where: { $0.id == userId }) {
                blockedUsers.removeAll { $0.id == userId }
                
                // Show success toast immediately
                if let toast = toast {
                    toast.success("Unblocked \(removedUser.displayName)")
                }
            }
            
            print("✅ Successfully unblocked user: \(userId)")
            
            // Post notification to update UI throughout the app
            NotificationCenter.default.post(
                name: .userUnblocked,
                object: nil,
                userInfo: ["unblockedUserId": userId]
            )
            
        } catch {
            showError(message: "Failed to unblock user: \(error.localizedDescription)")
        }
    }
    
    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let userUnblocked = Notification.Name("userUnblocked")
} 