//
//  NetworkManager.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 17/05/2025.
//

import Foundation
import UIKit
import FirebaseAuth

enum NetworkError: Error {
    case invalidUrl
    case noData
    case decodingError
    case encodingError
    case invalidResponse
    case unexpectedStatusCode(Int)
    case unknown(String?)
    
    var localizedDescription: String {
        switch self {
        case .invalidUrl:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .decodingError:
            return "Failed to decode response"
        case .encodingError:
            return "Failed to encode request"
        case .invalidResponse:
            return "Invalid response from server"
        case .unexpectedStatusCode(let code):
            return "Unexpected status code: \(code)"
        case .unknown(let err):
            if let err {
                return "Unknown error: \(err)"
            }
            return "Unknown error occurred"
        }
    }
}

class NetworkClient: NSObject {
    static let shared = NetworkClient()
   let baseUrl = "https://duet-backend-490xp.kinsta.app" // Made public for ProcessingManager
//     let baseUrl = "https://121c3bb08c2d.ngrok.app"
    
    private override init() {}
    
    // MARK: - Generic Request Methods
    
    private func decodeFromJSON<T: Decodable>(data: Data) throws -> T {
        let decoder = JSONDecoder()
        // Configure date decoding if needed
        let decodedObject = try decoder.decode(T.self, from: data)
        return decodedObject
    }
    
    // MARK: - Authenticated Request Methods
    
    /// Generic authenticated GET request that automatically adds Firebase auth token
    func authenticatedGet<T: Decodable>(
        endpoint: String,
        completion: @escaping (Result<T, NetworkError>) -> Void
    ) {
        Task {
            do {
                guard let currentUser = Auth.auth().currentUser else {
                    completion(.failure(.unknown("User not authenticated")))
                    return
                }
                
                let idToken = try await currentUser.getIDToken()
                let fullUrl = baseUrl + endpoint
                
                getJSON(url: fullUrl, authToken: idToken, completion: completion)
            } catch {
                completion(.failure(.unknown("Failed to get auth token: \(error.localizedDescription)")))
            }
        }
    }
    
    /// Generic authenticated POST request that automatically adds Firebase auth token
    func authenticatedPost<T: Encodable>(
        endpoint: String,
        body: T,
        completion: @escaping (Result<Void, NetworkError>) -> Void
    ) {
        Task {
            do {
                guard let currentUser = Auth.auth().currentUser else {
                    completion(.failure(.unknown("User not authenticated")))
                    return
                }
                
                let idToken = try await currentUser.getIDToken()
                let fullUrl = baseUrl + endpoint
                
                guard let url = URL(string: fullUrl) else {
                    completion(.failure(.invalidUrl))
                    return
                }
                
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.addValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                
                do {
                    let encoder = JSONEncoder()
                    encoder.keyEncodingStrategy = .convertToSnakeCase
                    request.httpBody = try encoder.encode(body)
                } catch {
                    completion(.failure(.encodingError))
                    return
                }
                
                print("📡 Authenticated POST \(endpoint): \(fullUrl)")
                
                URLSession.shared.dataTask(with: request) { data, response, error in
                    if let _ = error {
                        completion(.failure(.unknown(nil)))
                        return
                    }
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        completion(.failure(.invalidResponse))
                        return
                    }
                    
                    guard httpResponse.statusCode == 200 else {
                        completion(.failure(.unexpectedStatusCode(httpResponse.statusCode)))
                        return
                    }
                    
                    completion(.success(()))
                }.resume()
                
            } catch {
                completion(.failure(.unknown("Failed to get auth token: \(error.localizedDescription)")))
            }
        }
    }
    
    // MARK: - Basic Request Methods
    
    private func getJSON<T: Decodable>(url: String, completion: @escaping (Result<T, NetworkError>) -> Void) {
        getJSON(url: url, authToken: nil, completion: completion)
    }
    
    private func getJSON<T: Decodable>(url: String, authToken: String?, completion: @escaping (Result<T, NetworkError>) -> Void) {
        guard let url = URL(string: url) else {
            completion(.failure(.invalidUrl))
            return
        }
        
        var request = URLRequest(url: url)
        
        // Add authorization header if token is provided
        if let token = authToken {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        print("📡 GET: \(url)")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let _ = error {
                completion(.failure(.unknown(nil)))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.invalidResponse))
                return
            }
            
            if httpResponse.statusCode != 200 {
                completion(.failure(.unexpectedStatusCode(httpResponse.statusCode)))
                return
            }
            
            guard let data = data else {
                completion(.failure(.noData))
                return
            }
            
            do {
                let decodedObject: T = try self.decodeFromJSON(data: data)
                completion(.success(decodedObject))
            } catch {
                print("Decoding error: \(error)")
                completion(.failure(.decodingError))
            }
        }.resume()
    }
    
    // New async postJSON method for ProcessingManager
    func postJSON<T: Encodable, U: Decodable>(url: String, body: T) async throws -> U {
        guard let requestUrl = URL(string: url) else {
            throw NetworkError.invalidUrl
        }
        
        var request = URLRequest(url: requestUrl)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add Firebase auth header for protected endpoints
        if url.contains("/summarise") || url.contains("/groups/add-url") {
            guard let currentUser = Auth.auth().currentUser else {
                throw NetworkError.unknown("User not authenticated")
            }
            
            let idToken = try await currentUser.getIDToken()
            request.addValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            request.httpBody = try encoder.encode(body)
        } catch {
            throw NetworkError.encodingError
        }
        
        print("📡 Async POST: \(requestUrl)")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            guard 200...299 ~= httpResponse.statusCode else {
                throw NetworkError.unexpectedStatusCode(httpResponse.statusCode)
            }
            
            let decodedObject: U = try decodeFromJSON(data: data)
            return decodedObject
        } catch let error as NetworkError {
            throw error
        } catch {
            throw NetworkError.unknown(error.localizedDescription)
        }
    }
    
    // New async patchJSON method for updating ideas
    func patchJSON<T: Encodable, U: Decodable>(url: String, body: T) async throws -> U {
        guard let requestUrl = URL(string: url) else {
            throw NetworkError.invalidUrl
        }
        
        var request = URLRequest(url: requestUrl)
        request.httpMethod = "PATCH"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add Firebase auth header for protected endpoints
        guard let currentUser = Auth.auth().currentUser else {
            throw NetworkError.unknown("User not authenticated")
        }
        
        let idToken = try await currentUser.getIDToken()
        request.addValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        
        do {
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            request.httpBody = try encoder.encode(body)
        } catch {
            throw NetworkError.encodingError
        }
        
        print("📡 Async PATCH: \(requestUrl)")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            guard 200...299 ~= httpResponse.statusCode else {
                throw NetworkError.unexpectedStatusCode(httpResponse.statusCode)
            }
            
            let decodedObject: U = try decodeFromJSON(data: data)
            return decodedObject
        } catch let error as NetworkError {
            throw error
        } catch {
            throw NetworkError.unknown(error.localizedDescription)
        }
    }
    
    // New async deleteJSON method for deleting ideas
    func deleteJSON<U: Decodable>(url: String) async throws -> U {
        guard let requestUrl = URL(string: url) else {
            throw NetworkError.invalidUrl
        }
        
        var request = URLRequest(url: requestUrl)
        request.httpMethod = "DELETE"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add Firebase auth header for protected endpoints
        guard let currentUser = Auth.auth().currentUser else {
            throw NetworkError.unknown("User not authenticated")
        }
        
        let idToken = try await currentUser.getIDToken()
        request.addValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        
        print("📡 Async DELETE: \(requestUrl)")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            guard 200...299 ~= httpResponse.statusCode else {
                throw NetworkError.unexpectedStatusCode(httpResponse.statusCode)
            }
            
            let decodedObject: U = try decodeFromJSON(data: data)
            return decodedObject
        } catch let error as NetworkError {
            throw error
        } catch {
            throw NetworkError.unknown(error.localizedDescription)
        }
    }
    
    // Old postJSON method for compatibility
    private func postJSON<T: Encodable, U: Decodable>(url: String, body: T, completion: @escaping (Result<U, NetworkError>) -> Void) {
        guard let url = URL(string: url) else {
            completion(.failure(.invalidUrl))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            request.httpBody = try encoder.encode(body)
        } catch {
            completion(.failure(.encodingError))
            return
        }
        
        print("📡 POST: \(url)")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let _ = error {
                completion(.failure(.unknown(nil)))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.invalidResponse))
                return
            }
            
            print(httpResponse.statusCode)
            if httpResponse.statusCode != 200 {
                completion(.failure(.unexpectedStatusCode(httpResponse.statusCode)))
                return
            }
            
            guard let data = data else {
                completion(.failure(.noData))
                return
            }
            
            do {
                let decodedObject: U = try self.decodeFromJSON(data: data)
                completion(.success(decodedObject))
            } catch {
                print("Decoding error: \(error)")
                completion(.failure(.decodingError))
            }
        }.resume()
    }
    
    // MARK: - API Specific Methods
    
    func getRecentActivities(completion: @escaping (Result<[DateIdeaResponse], NetworkError>) -> Void) {
        guard let userId = SharedUserManager.shared.currentUserId else {
            completion(.failure(.unknown("User not authenticated")))
            return
        }
        
        let url = baseUrl + "/activities/\(userId)"
        getJSON(url: url) { (result: Result<[DateIdeaResponse], NetworkError>) in
            switch result {
            case .success(let activityHistory):
                completion(.success(activityHistory))
            case .failure(let error):
                print("Error fetching activity history: \(error)")
                completion(.failure(error))
            }
        }
    }
    
    func getFeed(page: Int = 1, pageSize: Int = 20, completion: @escaping (Result<PaginatedFeedResponse, NetworkError>) -> Void) {
        Task {
            do {
                // Get Firebase auth token
                guard let currentUser = Auth.auth().currentUser else {
                    completion(.failure(.unknown("User not authenticated")))
                    return
                }
                
                let idToken = try await currentUser.getIDToken()
                let url = baseUrl + "/feed?page=\(page)&page_size=\(pageSize)"
                
                getJSON(url: url, authToken: idToken, completion: completion)
            } catch {
                completion(.failure(.unknown("Failed to get auth token: \(error.localizedDescription)")))
            }
        }
    }
    
    func getUserIdeas(userId: String, page: Int = 1, pageSize: Int = 20, completion: @escaping (Result<PaginatedFeedResponse, NetworkError>) -> Void) {
        Task {
            do {
                // Get Firebase auth token
                guard let currentUser = Auth.auth().currentUser else {
                    completion(.failure(.unknown("User not authenticated")))
                    return
                }
                
                let idToken = try await currentUser.getIDToken()
                let url = baseUrl + "/ideas/user/\(userId)?page=\(page)&page_size=\(pageSize)"
                
                getJSON(url: url, authToken: idToken, completion: completion)
            } catch {
                completion(.failure(.unknown("Failed to get auth token: \(error.localizedDescription)")))
            }
        }
    }
    
    // Async getActivity method for ProcessingManager
    func getActivity(id: String) async throws -> DateIdeaResponse {
        let url = baseUrl + "/activity/\(id)"
        guard let requestUrl = URL(string: url) else {
            throw NetworkError.invalidUrl
        }
        
        print("📡 Async GET: \(requestUrl)")
        
        do {
            let (data, response) = try await URLSession.shared.data(from: requestUrl)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                throw NetworkError.unexpectedStatusCode(httpResponse.statusCode)
            }
            
            let decodedObject: DateIdeaResponse = try decodeFromJSON(data: data)
            return decodedObject
        } catch let error as NetworkError {
            throw error
        } catch {
            throw NetworkError.unknown(error.localizedDescription)
        }
    }
    
    // Old getActivity method for compatibility
    func getActivity(id: String, completion: @escaping (Result<DateIdeaResponse, NetworkError>) -> Void) {
        let url = baseUrl + "/activity/\(id)"
        getJSON(url: url, completion: completion)
    }
    
    func searchActivities(query: String, authorId: String? = nil, completion: @escaping (Result<[DateIdeaResponse], NetworkError>) -> Void) {
        let url = baseUrl + "/search"
        var body: [String: String] = ["query": query]
        
        // Add author_id filter if provided
        if let authorId = authorId {
            body["author_id"] = authorId
        }
        
        let searchDescription = authorId != nil ? "author-specific search" : "global search"
        print("📡 \(searchDescription) for: '\(query)'\(authorId != nil ? " by author: \(authorId!)" : "")")
        
        postJSON(url: url, body: body) { (result: Result<[DateIdeaResponse], NetworkError>) in
            switch result {
            case .success(let activities):
                print("🔍 Search returned \(activities.count) activities")
                completion(.success(activities))
            case .failure(let error):
                print("❌ Search failed: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    func summarizeVideo(url: String, completion: @escaping (Result<DateIdeaResponse, NetworkError>) -> Void) {
        guard let userId = SharedUserManager.shared.currentUserId else {
            completion(.failure(.unknown("User not authenticated")))
            return
        }
        
        Task {
            do {
                // Get Firebase auth token
                guard let currentUser = Auth.auth().currentUser else {
                    completion(.failure(.unknown("User not authenticated")))
                    return
                }
                
                let idToken = try await currentUser.getIDToken()
                
                let endpoint = baseUrl + "/summarise"
                let body = ["url": url, "user_id": userId]
                
                guard let requestUrl = URL(string: endpoint) else {
                    completion(.failure(.invalidUrl))
                    return
                }
                
                var request = URLRequest(url: requestUrl)
                request.httpMethod = "POST"
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                request.addValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
                
                do {
                    let encoder = JSONEncoder()
                    encoder.keyEncodingStrategy = .convertToSnakeCase
                    request.httpBody = try encoder.encode(body)
                } catch {
                    completion(.failure(.encodingError))
                    return
                }
                
                print("📡 Regular POST with Auth: \(requestUrl)")
                
                // Use regular URLSession instead of background session
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(.invalidResponse))
                    return
                }
                
                if httpResponse.statusCode != 200 {
                    print("⚠️ HTTP Status Code: \(httpResponse.statusCode)")
                    completion(.failure(.unexpectedStatusCode(httpResponse.statusCode)))
                    return
                }
                
                do {
                    let decodedObject: DateIdeaResponse = try self.decodeFromJSON(data: data)
                    print("✅ Successfully decoded response")
                    completion(.success(decodedObject))
                } catch {
                    print("❌ Decoding error: \(error)")
                    completion(.failure(.decodingError))
                }
                
            } catch {
                completion(.failure(.unknown("Failed to get auth token: \(error.localizedDescription)")))
            }
        }
    }
    
    func getUsers(with ids: [String], completion: @escaping (Result<[User], NetworkError>) -> Void) {
        getUsers(with: ids, forceRefreshStaleProfiles: false, completion: completion)
    }
    
    func getUsers(with ids: [String], forceRefreshStaleProfiles: Bool = false, completion: @escaping (Result<[User], NetworkError>) -> Void) {
        // Remove duplicates and empty strings
        let uniqueIds = Array(Set(ids)).filter { !$0.isEmpty }
        
        guard !uniqueIds.isEmpty else {
            completion(.success([]))
            return
        }
        
        // Get cached users, but force refresh if profile data is stale and we're checking for that
        var cachedUsers: [User] = []
        var missingIds: [String] = []
        
        for id in uniqueIds {
            if forceRefreshStaleProfiles {
                // Check for stale profile data - if stale, treat as missing to force refresh
                if let user = UserCache.shared.getUser(id: id, allowStaleProfileData: false) {
                    cachedUsers.append(user)
                } else {
                    missingIds.append(id)
                }
            } else {
                // Normal cache check
                if let user = UserCache.shared.getUser(id: id) {
                    cachedUsers.append(user)
                } else {
                    missingIds.append(id)
                }
            }
        }
        
        // If all users are cached and fresh, return immediately
        if missingIds.isEmpty {
            print("🟢 All \(cachedUsers.count) users loaded from cache")
            completion(.success(cachedUsers))
            return
        }
        
        // Fetch missing/stale users from network
        let staleCacheCount = cachedUsers.count
        let networkCount = missingIds.count
        print("🔍 Cache hit: \(staleCacheCount), fetching \(networkCount) from network\(forceRefreshStaleProfiles ? " (refreshing stale profile data)" : "")")
        
        let endpoint = baseUrl + "/users/by-ids"
        let body = ["ids": missingIds]
        
        postJSON(url: endpoint, body: body) { (result: Result<[User], NetworkError>) in
            switch result {
            case .success(let networkUsers):
                // Convert S3 profile image URLs to CloudFront URLs before caching
                var usersWithCloudFrontUrls = networkUsers
                for i in 0..<usersWithCloudFrontUrls.count {
                    if let s3ProfileImageUrl = usersWithCloudFrontUrls[i].profileImageUrl {
                        let cloudFrontUrl = URLHelpers.convertToCloudFrontURL(s3ProfileImageUrl)
                        usersWithCloudFrontUrls[i].profileImageUrl = cloudFrontUrl
                    }
                }
                
                // Cache the users with CloudFront URLs
                UserCache.shared.cacheUsers(usersWithCloudFrontUrls)
                
                // Combine cached and network users
                let allUsers = cachedUsers + usersWithCloudFrontUrls
                print("🟢 Successfully fetched \(usersWithCloudFrontUrls.count) users from network")
                completion(.success(allUsers))
                
            case .failure(let error):
                // If network fails but we have some cached users, return those
                if !cachedUsers.isEmpty {
                    print("⚠️ Network failed, returning \(cachedUsers.count) cached users: \(error.localizedDescription)")
                    completion(.success(cachedUsers))
                } else {
                    print("❌ Network failed and no cached users available: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            }
        }
    }
    
    func createUser(user: User, completion: @escaping (Result<User, NetworkError>) -> Void) {
        let endpoint = baseUrl + "/users"
        postJSON(url: endpoint, body: user) { (result: Result<User, NetworkError>) in
            switch result {
            case .success(var createdUser):
                // Convert S3 profile image URL to CloudFront URL if present
                if let s3ProfileImageUrl = createdUser.profileImageUrl {
                    let cloudFrontUrl = URLHelpers.convertToCloudFrontURL(s3ProfileImageUrl)
                    createdUser.profileImageUrl = cloudFrontUrl
                    print("🔄 Converted S3 URL to CloudFront for new user: \(s3ProfileImageUrl) → \(cloudFrontUrl)")
                }
                
                // Cache the newly created user with CloudFront URL
                UserCache.shared.cacheUser(createdUser)
                
                // Update credit cache with fresh user data
                CreditService.shared.updateCreditsFromUser(createdUser)
                
                print("🟢 Created and cached new user: \(createdUser.displayName)")
                completion(.success(createdUser))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Credit Management Methods
    
    func getUserCredits(completion: @escaping (Result<UserCredits, NetworkError>) -> Void) {
        Task {
            do {
                // Get Firebase auth token
                guard let currentUser = Auth.auth().currentUser else {
                    completion(.failure(.unknown("User not authenticated")))
                    return
                }
                
                let idToken = try await currentUser.getIDToken()
                let endpoint = baseUrl + "/user/credits"
                
                getJSON(url: endpoint, authToken: idToken, completion: completion)
            } catch {
                completion(.failure(.unknown("Failed to get auth token: \(error.localizedDescription)")))
            }
        }
    }
    
    func getCreditHistory(completion: @escaping (Result<CreditHistory, NetworkError>) -> Void) {
        Task {
            do {
                // Get Firebase auth token
                guard let currentUser = Auth.auth().currentUser else {
                    completion(.failure(.unknown("User not authenticated")))
                    return
                }
                
                let idToken = try await currentUser.getIDToken()
                let endpoint = baseUrl + "/user/credit-history"
                
                getJSON(url: endpoint, authToken: idToken, completion: completion)
            } catch {
                completion(.failure(.unknown("Failed to get auth token: \(error.localizedDescription)")))
            }
        }
    }
    
    func getCreditPackages(completion: @escaping (Result<CreditPackagesResponse, NetworkError>) -> Void) {
        let endpoint = baseUrl + "/credit-packages"
        getJSON(url: endpoint, completion: completion)
    }
    
    func getWelcomeCredits(completion: @escaping (Result<WelcomeCreditsResponse, NetworkError>) -> Void) {
        let endpoint = baseUrl + "/welcome-credits"
        getJSON(url: endpoint, completion: completion)
    }
    
    func createStripeCheckoutSession(packageId: String, completion: @escaping (Result<CreateCheckoutSessionResponse, NetworkError>) -> Void) {
        Task {
            do {
                // Get Firebase auth token
                guard let currentUser = Auth.auth().currentUser else {
                    completion(.failure(.unknown("User not authenticated")))
                    return
                }
                
                let idToken = try await currentUser.getIDToken()
                let endpoint = baseUrl + "/create-checkout-session"
                
                var request = URLRequest(url: URL(string: endpoint)!)
                request.httpMethod = "POST"
                request.addValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                
                let checkoutRequest = CreateCheckoutSessionRequest(packageId: packageId)
                
                let encoder = JSONEncoder()
                encoder.keyEncodingStrategy = .convertToSnakeCase
                request.httpBody = try encoder.encode(checkoutRequest)
                
                print("📡 POST Create Stripe Checkout: \(endpoint)")
                
                URLSession.shared.dataTask(with: request) { data, response, error in
                    if let _ = error {
                        completion(.failure(.unknown(nil)))
                        return
                    }
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        completion(.failure(.invalidResponse))
                        return
                    }
                    
                    if httpResponse.statusCode != 200 {
                        completion(.failure(.unexpectedStatusCode(httpResponse.statusCode)))
                        return
                    }
                    
                    guard let data = data else {
                        completion(.failure(.noData))
                        return
                    }
                    
                    do {
                        let decodedObject: CreateCheckoutSessionResponse = try self.decodeFromJSON(data: data)
                        completion(.success(decodedObject))
                    } catch {
                        print("Decoding error: \(error)")
                        completion(.failure(.decodingError))
                    }
                }.resume()
                
            } catch {
                completion(.failure(.unknown("Failed to get auth token: \(error.localizedDescription)")))
            }
        }
    }
    
    func addCredits(to userId: String, amount: Int, reason: String, completion: @escaping (Result<AddCreditsResponse, NetworkError>) -> Void) {
        Task {
            do {
                // Get Firebase auth token
                guard let currentUser = Auth.auth().currentUser else {
                    completion(.failure(.unknown("User not authenticated")))
                    return
                }
                
                let idToken = try await currentUser.getIDToken()
                let endpoint = baseUrl + "/admin/add-credits"
                
                var request = URLRequest(url: URL(string: endpoint)!)
                request.httpMethod = "POST"
                request.addValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                
                let addCreditsRequest = AddCreditsRequest(userId: userId, amount: amount, reason: reason)
                let encoder = JSONEncoder()
                encoder.keyEncodingStrategy = .convertToSnakeCase
                request.httpBody = try encoder.encode(addCreditsRequest)
                
                print("📡 POST Admin Add Credits: \(endpoint)")
                
                URLSession.shared.dataTask(with: request) { data, response, error in
                    if let _ = error {
                        completion(.failure(.unknown(nil)))
                        return
                    }
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        completion(.failure(.invalidResponse))
                        return
                    }
                    
                    if httpResponse.statusCode != 200 {
                        completion(.failure(.unexpectedStatusCode(httpResponse.statusCode)))
                        return
                    }
                    
                    guard let data = data else {
                        completion(.failure(.noData))
                        return
                    }
                    
                    do {
                        let decodedObject: AddCreditsResponse = try self.decodeFromJSON(data: data)
                        completion(.success(decodedObject))
                    } catch {
                        print("Decoding error: \(error)")
                        completion(.failure(.decodingError))
                    }
                }.resume()
                
            } catch {
                completion(.failure(.unknown("Failed to get auth token: \(error.localizedDescription)")))
            }
        }
    }
    
    // MARK: - Profile Image Upload
    
    func uploadProfileImage(imageData: Data, completion: @escaping (Result<User, NetworkError>) -> Void) {
        Task {
            do {
                // Get Firebase auth token
                guard let currentUser = Auth.auth().currentUser else {
                    completion(.failure(.unknown("User not authenticated")))
                    return
                }
                
                let idToken = try await currentUser.getIDToken()
                
                // Create multipart/form-data request
                let boundary = "Boundary-\(UUID().uuidString)"
                let endpoint = baseUrl + "/upload-profile-image"
                
                guard let url = URL(string: endpoint) else {
                    completion(.failure(.invalidUrl))
                    return
                }
                
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.addValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
                request.addValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
                
                // Create multipart body
                var body = Data()
                
                // Add file data
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"file\"; filename=\"profile.jpg\"\r\n".data(using: .utf8)!)
                body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
                body.append(imageData)
                body.append("\r\n".data(using: .utf8)!)
                body.append("--\(boundary)--\r\n".data(using: .utf8)!)
                
                request.httpBody = body
                
                print("📡 POST Profile Image: \(endpoint)")
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(.invalidResponse))
                    return
                }
                
                guard 200...299 ~= httpResponse.statusCode else {
                    completion(.failure(.unexpectedStatusCode(httpResponse.statusCode)))
                    return
                }
                
                var updatedUser: User = try decodeFromJSON(data: data)
                
                // Convert S3 profile image URL to CloudFront URL for better performance
                if let s3ProfileImageUrl = updatedUser.profileImageUrl {
                    let cloudFrontUrl = URLHelpers.convertToCloudFrontURL(s3ProfileImageUrl)
                    updatedUser.profileImageUrl = cloudFrontUrl
                    print("🔄 Converted S3 URL to CloudFront: \(s3ProfileImageUrl) → \(cloudFrontUrl)")
                }
                
                // Update cache with new user data (now with CloudFront URL)
                UserCache.shared.cacheUser(updatedUser)
                
                // Update credit cache with fresh user data
                CreditService.shared.updateCreditsFromUser(updatedUser)
                
                print("🟢 Successfully uploaded profile image and updated cache")
                
                completion(.success(updatedUser))
                
            } catch {
                print("❌ Profile image upload error: \(error)")
                completion(.failure(.unknown(error.localizedDescription)))
            }
        }
    }
    
    // MARK: - User Profile Update
    
    func updateUser(name: String, completion: @escaping (Result<User, NetworkError>) -> Void) {
        Task {
            do {
                // Get Firebase auth token
                guard let currentUser = Auth.auth().currentUser else {
                    completion(.failure(.unknown("User not authenticated")))
                    return
                }
                
                let idToken = try await currentUser.getIDToken()
                let endpoint = baseUrl + "/user"
                
                guard let url = URL(string: endpoint) else {
                    completion(.failure(.invalidUrl))
                    return
                }
                
                var request = URLRequest(url: url)
                request.httpMethod = "PUT"
                request.addValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                
                // Create request body with only name field
                let updateRequest = ["name": name]
                
                let encoder = JSONEncoder()
                request.httpBody = try encoder.encode(updateRequest)
                
                print("📡 PUT User Update: \(endpoint)")
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(.invalidResponse))
                    return
                }
                
                guard 200...299 ~= httpResponse.statusCode else {
                    completion(.failure(.unexpectedStatusCode(httpResponse.statusCode)))
                    return
                }
                
                var updatedUser: User = try decodeFromJSON(data: data)
                
                // Convert S3 profile image URL to CloudFront URL if present
                if let s3ProfileImageUrl = updatedUser.profileImageUrl {
                    let cloudFrontUrl = URLHelpers.convertToCloudFrontURL(s3ProfileImageUrl)
                    updatedUser.profileImageUrl = cloudFrontUrl
                    print("🔄 Converted S3 URL to CloudFront for updated user: \(s3ProfileImageUrl) → \(cloudFrontUrl)")
                }
                
                // Update cache with new user data
                UserCache.shared.cacheUser(updatedUser)
                
                print("🟢 Successfully updated user")
                
                completion(.success(updatedUser))
                
            } catch {
                print("❌ User update error: \(error)")
                completion(.failure(.unknown(error.localizedDescription)))
            }
        }
    }
    
    // MARK: - User Level and Idea Count
    
    func getUserLevel(completion: @escaping (Result<UserLevelResponse, NetworkError>) -> Void) {
        Task {
            do {
                // Get Firebase auth token
                guard let currentUser = Auth.auth().currentUser else {
                    completion(.failure(.unknown("User not authenticated")))
                    return
                }
                
                let idToken = try await currentUser.getIDToken()
                let endpoint = baseUrl + "/user-level"
                
                getJSON(url: endpoint, authToken: idToken, completion: completion)
            } catch {
                completion(.failure(.unknown("Failed to get auth token: \(error.localizedDescription)")))
            }
        }
    }
    
    /// Directly fetch a user by ID from the network, bypassing cache completely
    func getUserById(_ userId: String, completion: @escaping (Result<User, NetworkError>) -> Void) {
        let endpoint = baseUrl + "/users/\(userId)"
        
        Task {
            do {
                // Get Firebase auth token for authenticated requests
                guard let currentUser = Auth.auth().currentUser else {
                    completion(.failure(.unknown("User not authenticated")))
                    return
                }
                
                let idToken = try await currentUser.getIDToken()
                
                guard let url = URL(string: endpoint) else {
                    completion(.failure(.invalidUrl))
                    return
                }
                
                var request = URLRequest(url: url)
                request.addValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
                
                print("📡 GET User by ID (force): \(endpoint)")
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(.invalidResponse))
                    return
                }
                
                guard httpResponse.statusCode == 200 else {
                    completion(.failure(.unexpectedStatusCode(httpResponse.statusCode)))
                    return
                }
                
                var user: User = try decodeFromJSON(data: data)
                
                // Convert S3 profile image URL to CloudFront URL if present
                if let s3ProfileImageUrl = user.profileImageUrl {
                    let cloudFrontUrl = URLHelpers.convertToCloudFrontURL(s3ProfileImageUrl)
                    user.profileImageUrl = cloudFrontUrl
                    print("🔄 Converted S3 URL to CloudFront for fetched user: \(s3ProfileImageUrl) → \(cloudFrontUrl)")
                }
                
                // Update cache with fresh data
                UserCache.shared.cacheUser(user)
                
                print("🟢 Force fetched user by ID: \(user.displayName) - Level: \(user.playerLevel ?? "none")")
                completion(.success(user))
                
            } catch {
                print("❌ Force fetch user by ID error: \(error)")
                completion(.failure(.unknown(error.localizedDescription)))
            }
        }
    }
}
