//
//  ContentModerationService.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 20/12/2024.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

final class ContentModerationService {
    static let shared = ContentModerationService()
    private let db = Firestore.firestore()
    private let networkClient = NetworkClient.shared
    
    private init() {}
    
    // MARK: - Content Reporting
    
    /// Submit a content report to Firestore
    func reportContent(
        ideaId: String,
        reason: ContentReportReason,
        description: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            completion(.failure(ContentModerationError.userNotAuthenticated))
            return
        }
        
        let report = ContentReport(
            ideaId: ideaId,
            reporterUserId: currentUserId,
            reason: reason,
            description: description,
            timestamp: Date()
        )
        
        do {
            try db.collection("content_reports").addDocument(from: report) { error in
                if let error = error {
                    print("❌ Failed to submit content report: \(error.localizedDescription)")
                    completion(.failure(error))
                } else {
                    print("✅ Content report submitted successfully")
                    completion(.success(()))
                }
            }
        } catch {
            print("❌ Failed to encode content report: \(error.localizedDescription)")
            completion(.failure(error))
        }
    }
    
    // MARK: - User Blocking
    
    /// Block one or more users using the backend API
    func blockUsers(
        userIds: [String],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard !userIds.isEmpty else {
            completion(.failure(ContentModerationError.invalidInput))
            return
        }
        
        let body = BlockUsersRequest(userIds: userIds)
        networkClient.authenticatedPost(endpoint: "/block-users", body: body) { result in
            switch result {
            case .success:
                print("✅ Successfully blocked \(userIds.count) user(s)")
                completion(.success(()))
            case .failure(let error):
                print("❌ Failed to block users: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    /// Unblock one or more users using the backend API
    func unblockUsers(
        userIds: [String],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard !userIds.isEmpty else {
            completion(.failure(ContentModerationError.invalidInput))
            return
        }
        
        let body = BlockUsersRequest(userIds: userIds)
        networkClient.authenticatedPost(endpoint: "/unblock-users", body: body) { result in
            switch result {
            case .success:
                print("✅ Successfully unblocked \(userIds.count) user(s)")
                completion(.success(()))
            case .failure(let error):
                print("❌ Failed to unblock users: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    /// Get the current user's blocked users list
    func getBlockedUsers(
        completion: @escaping (Result<[String], Error>) -> Void
    ) {
        networkClient.authenticatedGet(endpoint: "/blocked-users") { (result: Result<BlockedUsersResponse, NetworkError>) in
            switch result {
            case .success(let blockedResponse):
                print("✅ Retrieved \(blockedResponse.blockedUserIds.count) blocked users")
                completion(.success(blockedResponse.blockedUserIds))
            case .failure(let error):
                print("❌ Failed to get blocked users: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
}

// MARK: - Request Models

struct BlockUsersRequest: Codable {
    let userIds: [String]
    
    enum CodingKeys: String, CodingKey {
        case userIds = "user_ids"
    }
}

// MARK: - Response Models

struct BlockedUsersResponse: Codable {
    let blockedUserIds: [String]
    
    enum CodingKeys: String, CodingKey {
        case blockedUserIds = "blocked_user_ids"
    }
}

// MARK: - Error Types

enum ContentModerationError: Error, LocalizedError {
    case userNotAuthenticated
    case invalidInput
    case invalidURL
    case serverError(Int)
    
    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "User not authenticated"
        case .invalidInput:
            return "Invalid input provided"
        case .invalidURL:
            return "Invalid URL"
        case .serverError(let code):
            return "Server error: \(code)"
        }
    }
} 
