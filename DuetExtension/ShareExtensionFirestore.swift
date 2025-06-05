//
//  ShareExtensionFirestore.swift
//  DuetExtension
//
//  Created by Joshua Ramkissoon on 24/05/2025.
//

import Foundation
import FirebaseAuth

class ShareExtensionAPI {
    private let baseUrl = "https://duet-backend-490xp.kinsta.app"
//    let baseUrl = "https://121c3bb08c2d.ngrok.app"
    
    // MARK: - Public API
    /// Send a video URL for processing for the currently-signed-in user
    func summarizeVideo(url: String) async throws {
        guard let userId = SharedUserManager.shared.currentUserId else {
            throw ShareExtensionError.userNotAuthenticated
        }
        print("🔐 Share Extension using user ID: \(userId)")
        let body: [String: String] = [
            "url": url,
            "user_id": userId
        ]
        try await postRequest(endpoint: "/summarise", body: body)
    }

    /// Add a video URL to a specific group. The backend will start processing and attach the idea to the group.
    func addVideo(url: String, toGroup groupId: String) async throws {
        guard let userId = SharedUserManager.shared.currentUserId else {
            throw ShareExtensionError.userNotAuthenticated
        }
        guard !groupId.isEmpty else {
            throw ShareExtensionError.missingGroupId
        }
        print("🔐 Share Extension using user ID: \(userId) for group: \(groupId)")
        let body: [String: String] = [
            "url": url,
            "user_id": userId,
            "group_id": groupId
        ]
        try await postRequest(endpoint: "/groups/add-url", body: body)
    }
    
    /// Fetch user's groups from the backend
    func getUserGroups() async throws -> [ExtensionGroup] {
        guard let userId = SharedUserManager.shared.currentUserId else {
            throw ShareExtensionError.userNotAuthenticated
        }
        
        guard let requestUrl = URL(string: baseUrl + "/user-groups") else {
            throw ShareExtensionError.invalidURL
        }
        
        // Get fresh Firebase auth token
        let idToken = try await getFreshAuthToken()
        
        print("🔐 Fetching groups for user: \(userId)")
        
        var request = URLRequest(url: requestUrl)
        request.httpMethod = "GET"
        request.addValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            print("❌ Server responded with status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            throw ShareExtensionError.serverError
        }
        
        // Parse the response
        do {
            let groupsData = try JSONDecoder().decode([ExtensionGroup].self, from: data)
            print("✅ Successfully fetched \(groupsData.count) groups")
            return groupsData
        } catch {
            print("❌ Failed to decode groups response: \(error)")
            throw ShareExtensionError.decodingError
        }
    }
    
    // MARK: - Private helpers
    private func postRequest(endpoint: String, body: [String: String]) async throws {
        guard let requestUrl = URL(string: baseUrl + endpoint) else {
            throw ShareExtensionError.invalidURL
        }
        print("📡 POST with Auth: \(requestUrl), body: \(body)")
        
        // Get fresh Firebase auth token
        let idToken = try await getFreshAuthToken()
        
        print("🔐 Using fresh auth token (length: \(idToken.count) chars)")
        
        var request = URLRequest(url: requestUrl)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        
        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            throw ShareExtensionError.encodingError
        }
        
        print("📡 POST with Auth: \(requestUrl)")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            print("❌ Server responded with status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            throw ShareExtensionError.serverError
        }
        print("✅ Request to \(endpoint) completed successfully")
    }
    
    /// Get a fresh Firebase ID token for the current user
    private func getFreshAuthToken() async throws -> String {
        guard let userId = SharedUserManager.shared.currentUserId else {
            throw ShareExtensionError.userNotAuthenticated
        }
        
        // First, try to sign in using the stored auth token to establish the session
        if let storedToken = SharedUserManager.shared.currentAuthToken {
            print("🔐 Using stored firebase token")
            return storedToken
        }
        
        // Check if we have a current user and get fresh token
        guard let currentUser = Auth.auth().currentUser else {
            print("❌ No authenticated Firebase user found")
            // If we have a stored token, try to use it as fallback
            if let storedToken = SharedUserManager.shared.currentAuthToken {
                print("🔄 Falling back to stored token")
                return storedToken
            }
            throw ShareExtensionError.userNotAuthenticated
        }
        
        // Verify the user ID matches what we expect
        guard currentUser.uid == userId else {
            print("❌ Current user UID (\(currentUser.uid)) doesn't match expected UID (\(userId))")
            throw ShareExtensionError.userNotAuthenticated
        }
        
        do {
            print("🔄 Getting fresh Firebase ID token...")
            let freshToken = try await currentUser.getIDToken(forcingRefresh: true)
            print("✅ Got fresh Firebase ID token")
            
            // Update stored token for future use
            SharedUserManager.shared.setAuthToken(freshToken)
            
            return freshToken
        } catch {
            print("❌ Failed to get fresh Firebase ID token: \(error)")
            // Fallback to stored token if available
            if let storedToken = SharedUserManager.shared.currentAuthToken {
                print("🔄 Falling back to stored token")
                return storedToken
            }
            throw ShareExtensionError.userNotAuthenticated
        }
    }
}

enum ShareExtensionError: Error {
    case invalidURL
    case encodingError
    case decodingError
    case serverError
    case userNotAuthenticated
    case missingGroupId
}
