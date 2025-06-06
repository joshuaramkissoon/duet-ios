//
//  AuthenticationViewModel.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 19/05/2025.
//

import Foundation
import Firebase
import FirebaseAuth
import GoogleSignIn
import AuthenticationServices
import CryptoKit

@MainActor
class AuthenticationViewModel: ObservableObject {
    enum State {
        case unauthenticated, authenticating, authenticated
    }

    @Published var state: State = .unauthenticated
    @Published var errorMessage: String?
    @Published var user: FirebaseAuth.User? {
        didSet { handleNewUser(oldValue: oldValue, newValue: user) }
    }
    @Published var currentUser: User? // Current user object with profile data
    @Published var isSigningInAnonymously = false
    
    private var currentNonce: String?
    private var handle: AuthStateDidChangeListenerHandle?

    init() {
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }
            let previousUser = self.user
            self.user = user
            
            if let user {
                SharedUserManager.shared.setCurrentUserId(user.uid)
                self.fetchCurrentUserInfo(for: user)
                // Store/refresh the Firebase ID token
                self.refreshAndStoreAuthToken()
                
                // Configure RevenueCat with user ID
                Task {
                    await SubscriptionService.shared.login(userId: user.uid)
                    // Refresh subscription status immediately after login
                    await SubscriptionService.shared.refreshSubscriptionStatus()
                    print("🟢 RevenueCat user logged in: \(user.uid)")
                }
                
                // Post notification for user login (only if this is a new user or first login)
                if previousUser?.uid != user.uid {
                    NotificationCenter.default.post(
                        name: .userLoggedIn, 
                        object: nil, 
                        userInfo: ["userId": user.uid]
                    )
                    print("🔄 Posted userLoggedIn notification for user: \(user.uid)")
                }
            }
            else {
                SharedUserManager.shared.clearCurrentUser()
                self.currentUser = nil
                UserCache.shared.cleanupExpired()
                
                // Clear RevenueCat user
                Task {
                    await SubscriptionService.shared.logout()
                    print("🟢 RevenueCat user logged out")
                }
                
                // Post notification for user logout (only if there was a previous user)
                if previousUser != nil {
                    NotificationCenter.default.post(name: .userLoggedOut, object: nil)
                    print("🔄 Posted userLoggedOut notification")
                }
            }
            self.state = (user == nil ? .unauthenticated : .authenticated)
        }
    }

    deinit {
        if let h = handle { Auth.auth().removeStateDidChangeListener(h) }
    }
    
    private func handleNewUser(oldValue: FirebaseAuth.User?, newValue: FirebaseAuth.User?) {
        guard
            let user = newValue,
            oldValue?.uid != user.uid
        else { return }
        
        createRemoteUserRecord(for: user)
        
        // Store the Firebase ID token for Share Extension use
        Task {
            do {
                let idToken = try await user.getIDToken()
                SharedUserManager.shared.setAuthToken(idToken)
                print("🟢 Stored Firebase ID token for Share Extension")
            } catch {
                print("❌ Failed to get/store Firebase ID token: \(error)")
            }
        }
    }
    
    private func fetchCurrentUserInfo(for firebaseUser: FirebaseAuth.User) {
        // First check cache
        if let cachedUser = UserCache.shared.getUser(id: firebaseUser.uid) {
            self.currentUser = cachedUser
            print("🟢 Loaded current user from cache: \(cachedUser.displayName)")
            return
        }
        
        // Fallback to network
        NetworkClient.shared.getUsers(with: [firebaseUser.uid]) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let users):
                    if let user = users.first {
                        self?.currentUser = user
                        UserCache.shared.cacheUser(user)
                        print("🟢 Fetched and cached current user: \(user.displayName)")
                    }
                case .failure(let error):
                    print("❌ Failed to fetch current user info: \(error)")
                    // Create fallback user object from Firebase user data
                    let fallbackUser = User(id: firebaseUser.uid, name: firebaseUser.displayName)
                    self?.currentUser = fallbackUser
                }
            }
        }
    }
    
    private func createRemoteUserRecord(for user: FirebaseAuth.User) {
        let name  = user.displayName
        
        NetworkClient.shared.createUser(user: User(id: user.uid, name: name)) { result in
            switch result {
            case .success:
                print("🟢 Remote user record created for \(user.uid)")
            case .failure(let err):
                DispatchQueue.main.async {
                    self.state = .unauthenticated
                    self.errorMessage = "Failed to create user"
                }
            }
        }
    }
    
    func signOut() {
        do { 
            try Auth.auth().signOut()
            // Clear user cache on sign out for privacy and data management
            UserCache.shared.clearAll()
            print("🟢 Signed out and cleared user cache")
        }
        catch { errorMessage = error.localizedDescription }
    }
    
    func deleteAccount() async throws {
        guard let currentUser = Auth.auth().currentUser else {
            throw NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No authenticated user found"])
        }
        
        // Delete the Firebase user account
        try await currentUser.delete()
        
        // Clear all local data
        SharedUserManager.shared.clearCurrentUser()
        UserCache.shared.clearAll()
        
        // Reset the authentication state
        await MainActor.run {
            self.user = nil
            self.currentUser = nil
            self.state = .unauthenticated
        }
        
        print("🟢 Successfully deleted user account and cleared all data")
    }
    
    /// Refresh current user data from network (useful after profile updates)
    func refreshCurrentUser() {
        guard let firebaseUser = user else { return }
        
        // Force refresh from network, bypassing cache
        NetworkClient.shared.getUsers(with: [firebaseUser.uid]) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let users):
                    if let user = users.first {
                        self?.currentUser = user
                        UserCache.shared.cacheUser(user) // Update cache with fresh data
                        print("🟢 Refreshed current user data: \(user.displayName)")
                    }
                case .failure(let error):
                    print("❌ Failed to refresh current user info: \(error)")
                }
            }
        }
    }
    
    /// Force refresh current user data from network, bypassing cache completely
    func forceRefreshCurrentUser() {
        guard let firebaseUser = user else { return }
        
        // Use direct getUserById endpoint to always fetch fresh data from network
        NetworkClient.shared.getUserById(firebaseUser.uid) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let user):
                    self?.currentUser = user
                    // Cache is already updated in NetworkClient.getUserById
                    print("🟢 Force refreshed current user data: \(user.displayName) - Level: \(user.playerLevel ?? "none")")
                    
                case .failure(let error):
                    print("❌ Failed to force refresh current user info: \(error)")
                }
            }
        }
    }
    
    /// Update current user object directly (useful after successful profile updates)
    func updateCurrentUser(_ updatedUser: User) {
        self.currentUser = updatedUser
        UserCache.shared.cacheUser(updatedUser) // Update cache with new data
        print("🟢 Updated current user: \(updatedUser.displayName)")
    }
    
    func signInAnonymously() {
        isSigningInAnonymously = true
        Auth.auth().signInAnonymously { [weak self] res, err in
            DispatchQueue.main.async { self?.isSigningInAnonymously = false }
            if let err = err { self?.errorMessage = err.localizedDescription }
        }
    }
    
    func prepareAppleSignIn(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
        let nonce = randomNonceString()
        currentNonce = nonce
        request.nonce = sha256(nonce)
    }
    
    func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .failure(let err):
            errorMessage = err.localizedDescription
            
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8),
                  let nonce = currentNonce
            else {
                errorMessage = "Apple sign in failed"
                return
            }
            let cred = OAuthProvider.appleCredential(
                withIDToken: idToken,
                rawNonce: nonce,
                fullName: credential.fullName
            )
            Task {
                do {
                    try await Auth.auth().signIn(with: cred)
                }
                catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    /// Refresh and store the current user's Firebase ID token for Share Extension use
    func refreshAndStoreAuthToken() {
        guard let user = user else { return }
        
        Task {
            do {
                let idToken = try await user.getIDToken(forcingRefresh: true)
                SharedUserManager.shared.setAuthToken(idToken)
                print("🟢 Refreshed and stored Firebase ID token")
            } catch {
                print("❌ Failed to refresh/store Firebase ID token: \(error)")
            }
        }
    }
}

// MARK: — Helpers for Apple nonce

fileprivate func randomNonceString(length: Int = 32) -> String {
    precondition(length > 0)
    let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
    var result = ""
    var remaining = length
    while remaining > 0 {
        let randoms = (0..<16).compactMap { _ -> UInt8? in
            var b: UInt8 = 0
            return SecRandomCopyBytes(kSecRandomDefault, 1, &b) == errSecSuccess ? b : nil
        }
        randoms.forEach { b in
            if remaining > 0, Int(b) < charset.count {
                result.append(charset[Int(b)])
                remaining -= 1
            }
        }
    }
    return result
}

fileprivate func sha256(_ input: String) -> String {
    let data = Data(input.utf8)
    let hash = SHA256.hash(data: data)
    return hash.compactMap { String(format: "%02x", $0) }.joined()
}

