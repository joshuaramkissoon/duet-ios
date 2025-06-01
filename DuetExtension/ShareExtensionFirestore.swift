//
//  ShareExtensionFirestore.swift
//  DuetExtension
//
//  Created by Joshua Ramkissoon on 24/05/2025.
//

import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore

class ShareExtensionAPI {
    private let baseUrl = "https://duet-backend-490xp.kinsta.app"
//    let baseUrl = "https://8dca7b206740.ngrok.app"
    
    // MARK: - Public API
    /// Send a video URL for processing for the currently-signed-in user
    func summarizeVideo(url: String) async throws {
        guard let userId = SharedUserManager.shared.currentUserId else {
            throw ShareExtensionError.userNotAuthenticated
        }
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
        let body: [String: String] = [
            "url": url,
            "user_id": userId,
            "group_id": groupId
        ]
        try await postRequest(endpoint: "/groups/add-url", body: body)
    }
    
    // MARK: - Private helpers
    private func postRequest(endpoint: String, body: [String: String]) async throws {
        guard let requestUrl = URL(string: baseUrl + endpoint) else {
            throw ShareExtensionError.invalidURL
        }
        
        // Get Firebase auth token
        guard let currentUser = Auth.auth().currentUser else {
            throw ShareExtensionError.userNotAuthenticated
        }
        
        let idToken = try await currentUser.getIDToken()
        
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
            throw ShareExtensionError.serverError
        }
        print("✅ Request to \(endpoint) completed successfully")
    }
}

enum ShareExtensionError: Error {
    case invalidURL
    case encodingError
    case serverError
    case userNotAuthenticated
    case missingGroupId
}
