//
//  ItineraryService.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 31/05/2025.
//

import Foundation
import FirebaseFirestore

// MARK: - Request Models for Backend Updates

struct ItineraryUpdateRequest: Codable {
    let suggested_itinerary: [ItineraryItemUpdate]?
    let required_items: [String]?
    
    init(itineraryItems: [ItineraryItem]?, requiredItems: [String]?) {
        self.suggested_itinerary = itineraryItems?.map { ItineraryItemUpdate(from: $0) }
        self.required_items = requiredItems
    }
}

struct ItineraryItemUpdate: Codable {
    let time: String
    let title: String
    let activity: String
    let duration: String?
    let location: String?
    let notes: String?
    
    init(from item: ItineraryItem) {
        self.time = item.time
        self.title = item.title
        self.activity = item.activity
        self.duration = item.duration
        self.location = item.location
        self.notes = item.notes
    }
}

final class ItineraryService {
    static let shared = ItineraryService()
    private let db = Firestore.firestore()
    private let networkClient = NetworkClient.shared
    
    private init() {}
    
    // MARK: - Update Itinerary
    
    /// Updates itinerary either in Firestore (for group ideas) or backend (for non-group ideas)
    /// - Parameters:
    ///   - ideaId: The ID of the idea/itinerary to update
    ///   - groupId: The group ID if this is a shared group idea, nil for personal ideas
    ///   - itineraryItems: The updated itinerary items
    ///   - requiredItems: The updated required items/equipment list
    ///   - completion: Completion handler with error if any
    func updateItinerary(
        ideaId: String,
        groupId: String? = nil,
        itineraryItems: [ItineraryItem],
        requiredItems: [String],
        completion: @escaping (Error?) -> Void
    ) {
        if let groupId = groupId {
            // Update in Firestore for group ideas
            updateItineraryInFirestore(
                ideaId: ideaId,
                groupId: groupId,
                itineraryItems: itineraryItems,
                requiredItems: requiredItems,
                completion: completion
            )
        } else {
            // Update in backend for personal ideas
            updateItineraryInBackend(
                ideaId: ideaId,
                itineraryItems: itineraryItems,
                requiredItems: requiredItems,
                completion: completion
            )
        }
    }
    
    // MARK: - Firestore Updates (Group Ideas)
    
    private func updateItineraryInFirestore(
        ideaId: String,
        groupId: String,
        itineraryItems: [ItineraryItem],
        requiredItems: [String],
        completion: @escaping (Error?) -> Void
    ) {
        let ideaRef = db.collection("groups")
            .document(groupId)
            .collection("ideas")
            .document(ideaId)
        
        // Prepare the update data
        var updateData: [String: Any] = [:]
        
        // Convert itinerary items to dictionaries for Firestore
        let itineraryData = itineraryItems.map { item in
            var itemData: [String: Any] = [
                "time": item.time,
                "title": item.title,
                "activity": item.activity
            ]
            
            if let duration = item.duration {
                itemData["duration"] = duration
            }
            if let location = item.location {
                itemData["location"] = location
            }
            if let notes = item.notes {
                itemData["notes"] = notes
            }
            
            return itemData
        }
        
        updateData["dateIdea.suggested_itinerary"] = itineraryData
        updateData["dateIdea.required_items"] = requiredItems
        
        print("🔄 Updating itinerary in Firestore for group \(groupId), idea \(ideaId)")
        
        ideaRef.updateData(updateData) { error in
            if let error = error {
                print("❌ Failed to update itinerary in Firestore: \(error.localizedDescription)")
                completion(error)
            } else {
                print("✅ Successfully updated itinerary in Firestore")
                completion(nil)
            }
        }
    }
    
    // MARK: - Backend Updates (Personal Ideas)
    
    private func updateItineraryInBackend(
        ideaId: String,
        itineraryItems: [ItineraryItem],
        requiredItems: [String],
        completion: @escaping (Error?) -> Void
    ) {
        let endpoint = networkClient.baseUrl + "/ideas/\(ideaId)"
        
        // Create the update request with proper Encodable structure
        let updateRequest = ItineraryUpdateRequest(
            itineraryItems: itineraryItems,
            requiredItems: requiredItems
        )
        
        guard let url = URL(string: endpoint) else {
            completion(NetworkError.invalidUrl)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH" // Using PATCH for partial updates
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            request.httpBody = try encoder.encode(updateRequest)
        } catch {
            print("❌ Failed to encode update request: \(error)")
            completion(NetworkError.encodingError)
            return
        }
        
        print("🔄 Updating itinerary in backend for idea \(ideaId)")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Failed to update itinerary in backend: \(error.localizedDescription)")
                    completion(error)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ Invalid response from backend")
                    completion(NetworkError.invalidResponse)
                    return
                }
                
                if httpResponse.statusCode == 200 || httpResponse.statusCode == 204 {
                    print("✅ Successfully updated itinerary in backend")
                    completion(nil)
                } else {
                    print("❌ Backend returned status code: \(httpResponse.statusCode)")
                    completion(NetworkError.unexpectedStatusCode(httpResponse.statusCode))
                }
            }
        }.resume()
    }
    
    // MARK: - Async Methods (for future use)
    
    /// Async version of updateItinerary for modern Swift concurrency
    func updateItinerary(
        ideaId: String,
        groupId: String? = nil,
        itineraryItems: [ItineraryItem],
        requiredItems: [String]
    ) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            updateItinerary(
                ideaId: ideaId,
                groupId: groupId,
                itineraryItems: itineraryItems,
                requiredItems: requiredItems
            ) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
} 