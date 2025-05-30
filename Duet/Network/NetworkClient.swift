//
//  NetworkManager.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 17/05/2025.
//

import Foundation
import UIKit

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
//    let baseUrl = "https://8dca7b206740.ngrok.app"
    
    private override init() {}
    
    private var pendingCompletions: [Int: (Result<DateIdeaResponse, NetworkError>) -> Void] = [:]
    
    private lazy var backgroundSession: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: "com.duet.videosummarization")
        config.sessionSendsLaunchEvents = true
        config.timeoutIntervalForRequest = 300 // 5 minutes
        config.timeoutIntervalForResource = 600 // 10 minutes
        config.isDiscretionary = false // Don't wait for optimal conditions
        config.allowsCellularAccess = true
        config.waitsForConnectivity = true // Wait for network connectivity if needed
        config.shouldUseExtendedBackgroundIdleMode = true // Allow longer background processing
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()
    
    private var receivedDataForTasks: [Int: Data] = [:]
    
    // MARK: - Generic Request Methods
    
    private func decodeFromJSON<T: Decodable>(data: Data) throws -> T {
        let decoder = JSONDecoder()
        // Configure date decoding if needed
        let decodedObject = try decoder.decode(T.self, from: data)
        return decodedObject
    }
    
    private func getJSON<T: Decodable>(url: String, completion: @escaping (Result<T, NetworkError>) -> Void) {
        guard let url = URL(string: url) else {
            completion(.failure(.invalidUrl))
            return
        }
        
        let request = URLRequest(url: url)
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
        let url = baseUrl + "/feed?page=\(page)&page_size=\(pageSize)"
        getJSON(url: url, completion: completion)
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
    
    func searchActivities(query: String, completion: @escaping (Result<[DateIdeaResponse], NetworkError>) -> Void) {
        let url = baseUrl + "/search"
        let body = ["query": query]
        print("📡 Searching for: \(query)")
        
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
        
        let endpoint = baseUrl + "/summarise"
        let body = ["url": url, "user_id": userId]
        
        guard let requestUrl = URL(string: endpoint) else {
            completion(.failure(.invalidUrl))
            return
        }
        
        var request = URLRequest(url: requestUrl)
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
        
        print("📡 Background POST: \(requestUrl)")
        
        let task = backgroundSession.dataTask(with: request)
        
        // Store completion handler with task identifier
        pendingCompletions[task.taskIdentifier] = completion
        
        task.resume()
    }
    
    func createUser(user: User, completion: @escaping (Result<User, NetworkError>) -> Void) {
        let endpoint = baseUrl + "/users"
        postJSON(url: endpoint, body: user) { (result: Result<User, NetworkError>) in
            switch result {
            case .success(let createdUser):
                // Cache the newly created user
                UserCache.shared.cacheUser(createdUser)
                print("🟢 Created and cached new user: \(createdUser.displayName)")
                completion(.success(createdUser))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func getUsers(with ids: [String], completion: @escaping (Result<[User], NetworkError>) -> Void) {
        // Remove duplicates and empty strings
        let uniqueIds = Array(Set(ids)).filter { !$0.isEmpty }
        
        guard !uniqueIds.isEmpty else {
            completion(.success([]))
            return
        }
        
        // First, get all cached users
        let cachedUsers = UserCache.shared.getUsers(ids: uniqueIds)
        
        // Find which user IDs are missing from cache
        let cachedUserIds = Set(cachedUsers.map { $0.id })
        let missingIds = uniqueIds.filter { !cachedUserIds.contains($0) }
        
        // If all users are cached, return immediately
        if missingIds.isEmpty {
            print("🟢 All \(cachedUsers.count) users loaded from cache")
            completion(.success(cachedUsers))
            return
        }
        
        // Fetch missing users from network
        print("🔍 Cache hit: \(cachedUsers.count), fetching \(missingIds.count) from network")
        
        let endpoint = baseUrl + "/users/by-ids"
        let body = ["ids": missingIds]
        
        postJSON(url: endpoint, body: body) { (result: Result<[User], NetworkError>) in
            switch result {
            case .success(let networkUsers):
                // Cache the newly fetched users
                UserCache.shared.cacheUsers(networkUsers)
                
                // Combine cached and network users
                let allUsers = cachedUsers + networkUsers
                print("🟢 Successfully fetched \(networkUsers.count) users from network, cached for future use")
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
}

extension NetworkClient: URLSessionDataDelegate {
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        let taskId = dataTask.taskIdentifier
        
        if receivedDataForTasks[taskId] == nil {
            receivedDataForTasks[taskId] = Data()
        }
        receivedDataForTasks[taskId]?.append(data)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let taskId = task.taskIdentifier
        
        if let error = error {
            print("📱 Background task \(taskId) completed with error: \(error)")
            
            // Check for specific background transfer errors
            if let urlError = error as? URLError {
                switch urlError.code {
                case .backgroundSessionInUseByAnotherProcess:
                    print("⚠️ Background session in use by another process")
                case .backgroundSessionWasDisconnected:
                    print("⚠️ Background session was disconnected")
                case .networkConnectionLost:
                    print("⚠️ Network connection lost during background transfer")
                default:
                    print("⚠️ URLError: \(urlError.localizedDescription)")
                }
            }
        } else {
            print("📱 Background task \(taskId) completed successfully")
        }
        
        guard let completion = pendingCompletions[taskId] else {
            print("⚠️ No completion handler found for task \(taskId)")
            return
        }
        
        // Remove completion handler and get data
        pendingCompletions.removeValue(forKey: taskId)
        let data = receivedDataForTasks.removeValue(forKey: taskId)
        
        DispatchQueue.main.async {
            if let error = error {
                completion(.failure(.unknown(error.localizedDescription)))
                return
            }
            
            guard let httpResponse = task.response as? HTTPURLResponse else {
                completion(.failure(.invalidResponse))
                return
            }
            
            if httpResponse.statusCode != 200 {
                print("⚠️ HTTP Status Code: \(httpResponse.statusCode)")
                completion(.failure(.unexpectedStatusCode(httpResponse.statusCode)))
                return
            }
            
            guard let data = data else {
                completion(.failure(.noData))
                return
            }
            
            do {
                let decodedObject: DateIdeaResponse = try self.decodeFromJSON(data: data)
                print("✅ Successfully decoded background response")
                completion(.success(decodedObject))
            } catch {
                print("❌ Decoding error: \(error)")
                completion(.failure(.decodingError))
            }
        }
    }
    
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        print("📱 Background URL session finished all events")
        
        DispatchQueue.main.async {
            // Call the app's background completion handler to tell iOS we're done
            if let appDelegate = UIApplication.shared.delegate as? AppDelegate,
               let completionHandler = appDelegate.backgroundCompletionHandler {
                print("📱 Calling background completion handler")
                completionHandler()
                appDelegate.backgroundCompletionHandler = nil
            }
        }
    }
}
