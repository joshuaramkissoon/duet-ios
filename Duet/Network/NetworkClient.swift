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
    private let baseUrl = "https://0f78118f107a.ngrok.app"
    
    private override init() {}
    
    private var pendingCompletions: [Int: (Result<DateIdeaResponse, NetworkError>) -> Void] = [:]
    
    private lazy var backgroundSession: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: "com.yourapp.videosummarization")
        config.sessionSendsLaunchEvents = true
        config.timeoutIntervalForRequest = 300 // 5 minutes
        config.timeoutIntervalForResource = 600 // 10 minutes
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
        let url = baseUrl + "/activities/recent"
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
    
    func getActivity(id: String, completion: @escaping (Result<DateIdeaResponse, NetworkError>) -> Void) {
        let url = baseUrl + "/activity/\(id)"
        getJSON(url: url, completion: completion)
    }
    
    func searchActivities(query: String, completion: @escaping (Result<[DateIdeaResponse], NetworkError>) -> Void) {
        let url = baseUrl + "/search"
        let body = ["query": query]
        postJSON(url: url, body: body, completion: completion)
    }
    
    func summarizeVideo(url: String, completion: @escaping (Result<DateIdeaResponse, NetworkError>) -> Void) {
        let endpoint = baseUrl + "/summarise"
        let body = ["url": url]
        
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
        postJSON(url: endpoint, body: user, completion: completion)
    }
    
    func getUsers(with ids: [String], completion: @escaping (Result<[User], NetworkError>) -> Void) {
        let endpoint = baseUrl + "/users/by-ids"
        let body = ["ids": ids]
        postJSON(url: endpoint, body: body, completion: completion)
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
        
        guard let completion = pendingCompletions[taskId] else {
            print("No completion handler found for task \(taskId)")
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
                completion(.failure(.unexpectedStatusCode(httpResponse.statusCode)))
                return
            }
            
            guard let data = data else {
                completion(.failure(.noData))
                return
            }
            
            do {
                let decodedObject: DateIdeaResponse = try self.decodeFromJSON(data: data)
                completion(.success(decodedObject))
            } catch {
                print("Decoding error: \(error)")
                completion(.failure(.decodingError))
            }
        }
    }
    
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        print("Background URL session finished all events")
        // For SwiftUI apps without AppDelegate, this method can be empty
        // The system will handle completion automatically
    }
}
