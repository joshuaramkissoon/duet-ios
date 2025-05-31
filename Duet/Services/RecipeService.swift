//
//  RecipeService.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 31/05/2025.
//

import Foundation
import FirebaseFirestore

// MARK: - Request Models for Backend Updates

struct RecipeUpdateRequest: Codable {
    let recipe_metadata: RecipeMetadataUpdate?
    let required_items: [String]?
    
    init(recipeMetadata: RecipeMetadata?, requiredItems: [String]?) {
        self.recipe_metadata = recipeMetadata != nil ? RecipeMetadataUpdate(from: recipeMetadata!) : nil
        self.required_items = requiredItems
    }
}

struct RecipeMetadataUpdate: Codable {
    let cuisine_type: String?
    let difficulty_level: String?
    let servings: String?
    let prep_time: String?
    let cook_time: String?
    let ingredients: [String]?
    let instructions: [String]?
    
    init(from metadata: RecipeMetadata) {
        self.cuisine_type = metadata.cuisine_type
        self.difficulty_level = metadata.difficulty_level
        self.servings = metadata.servings
        self.prep_time = metadata.prep_time
        self.cook_time = metadata.cook_time
        self.ingredients = metadata.ingredients
        self.instructions = metadata.instructions
    }
}

final class RecipeService {
    static let shared = RecipeService()
    private let db = Firestore.firestore()
    private let networkClient = NetworkClient.shared
    
    private init() {}
    
    // MARK: - Update Recipe Metadata
    
    /// Updates recipe metadata either in Firestore (for group ideas) or backend (for non-group ideas)
    /// - Parameters:
    ///   - ideaId: The ID of the idea/recipe to update
    ///   - groupId: The group ID if this is a shared group idea, nil for personal ideas
    ///   - recipeMetadata: The updated recipe metadata
    ///   - requiredItems: The updated required items/equipment list
    ///   - completion: Completion handler with error if any
    func updateRecipeMetadata(
        ideaId: String,
        groupId: String? = nil,
        recipeMetadata: RecipeMetadata,
        requiredItems: [String],
        completion: @escaping (Error?) -> Void
    ) {
        if let groupId = groupId {
            // Update in Firestore for group ideas
            updateRecipeInFirestore(
                ideaId: ideaId,
                groupId: groupId,
                recipeMetadata: recipeMetadata,
                requiredItems: requiredItems,
                completion: completion
            )
        } else {
            // Update in backend for personal ideas
            updateRecipeInBackend(
                ideaId: ideaId,
                recipeMetadata: recipeMetadata,
                requiredItems: requiredItems,
                completion: completion
            )
        }
    }
    
    // MARK: - Firestore Updates (Group Ideas)
    
    private func updateRecipeInFirestore(
        ideaId: String,
        groupId: String,
        recipeMetadata: RecipeMetadata,
        requiredItems: [String],
        completion: @escaping (Error?) -> Void
    ) {
        let ideaRef = db.collection("groups")
            .document(groupId)
            .collection("ideas")
            .document(ideaId)
        
        // Prepare the update data
        var updateData: [String: Any] = [:]
        
        // Update recipe metadata fields in the dateIdea object
        if let cuisineType = recipeMetadata.cuisine_type {
            updateData["dateIdea.recipe_metadata.cuisine_type"] = cuisineType
        }
        if let difficultyLevel = recipeMetadata.difficulty_level {
            updateData["dateIdea.recipe_metadata.difficulty_level"] = difficultyLevel
        }
        if let servings = recipeMetadata.servings {
            updateData["dateIdea.recipe_metadata.servings"] = servings
        }
        if let prepTime = recipeMetadata.prep_time {
            updateData["dateIdea.recipe_metadata.prep_time"] = prepTime
        }
        if let cookTime = recipeMetadata.cook_time {
            updateData["dateIdea.recipe_metadata.cook_time"] = cookTime
        }
        if let ingredients = recipeMetadata.ingredients {
            updateData["dateIdea.recipe_metadata.ingredients"] = ingredients
        }
        if let instructions = recipeMetadata.instructions {
            updateData["dateIdea.recipe_metadata.instructions"] = instructions
        }
        
        // Update required items
        updateData["dateIdea.required_items"] = requiredItems
        
        print("🔄 Updating recipe in Firestore for group \(groupId), idea \(ideaId)")
        
        ideaRef.updateData(updateData) { error in
            if let error = error {
                print("❌ Failed to update recipe in Firestore: \(error.localizedDescription)")
                completion(error)
            } else {
                print("✅ Successfully updated recipe in Firestore")
                completion(nil)
            }
        }
    }
    
    // MARK: - Backend Updates (Personal Ideas)
    
    private func updateRecipeInBackend(
        ideaId: String,
        recipeMetadata: RecipeMetadata,
        requiredItems: [String],
        completion: @escaping (Error?) -> Void
    ) {
        let endpoint = networkClient.baseUrl + "/ideas/\(ideaId)"
        
        // Create the update request with proper Encodable structure
        let updateRequest = RecipeUpdateRequest(
            recipeMetadata: recipeMetadata,
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
        
        print("🔄 Updating recipe in backend for idea \(ideaId)")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Failed to update recipe in backend: \(error.localizedDescription)")
                    completion(error)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ Invalid response from backend")
                    completion(NetworkError.invalidResponse)
                    return
                }
                
                if httpResponse.statusCode == 200 || httpResponse.statusCode == 204 {
                    print("✅ Successfully updated recipe in backend")
                    completion(nil)
                } else {
                    print("❌ Backend returned status code: \(httpResponse.statusCode)")
                    completion(NetworkError.unexpectedStatusCode(httpResponse.statusCode))
                }
            }
        }.resume()
    }
    
    // MARK: - Async Methods (for future use)
    
    /// Async version of updateRecipeMetadata for modern Swift concurrency
    func updateRecipeMetadata(
        ideaId: String,
        groupId: String? = nil,
        recipeMetadata: RecipeMetadata,
        requiredItems: [String]
    ) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            updateRecipeMetadata(
                ideaId: ideaId,
                groupId: groupId,
                recipeMetadata: recipeMetadata,
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