//
//  UserCache.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 25/05/2025.
//

import Foundation

class UserCache {
    static let shared = UserCache()
    private let userDefaults = UserDefaults.standard
    private let cacheKey = "duet_user_cache"
    private let maxCacheAge: TimeInterval = 24 * 60 * 60 // 24 hours
    
    private init() {}
    
    // MARK: - Cache Entry Structure
    private struct CachedUser: Codable {
        let user: User
        let timestamp: Date
        
        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > UserCache.shared.maxCacheAge
        }
    }
    
    // MARK: - Public Methods
    
    /// Get a single user from cache
    func getUser(id: String) -> User? {
        guard let cachedUser = getCachedUser(id: id), !cachedUser.isExpired else {
            return nil
        }
        return cachedUser.user
    }
    
    /// Get multiple users from cache
    func getUsers(ids: [String]) -> [User] {
        return ids.compactMap { getUser(id: $0) }
    }
    
    /// Cache a single user
    func cacheUser(_ user: User) {
        var cache = loadCache()
        cache[user.id] = CachedUser(user: user, timestamp: Date())
        saveCache(cache)
    }
    
    /// Cache multiple users
    func cacheUsers(_ users: [User]) {
        var cache = loadCache()
        let timestamp = Date()
        for user in users {
            cache[user.id] = CachedUser(user: user, timestamp: timestamp)
        }
        saveCache(cache)
    }
    
    /// Remove a specific user from cache
    func removeUser(id: String) {
        var cache = loadCache()
        cache.removeValue(forKey: id)
        saveCache(cache)
    }
    
    /// Clear all cached users
    func clearAll() {
        userDefaults.removeObject(forKey: cacheKey)
    }
    
    /// Check if a user is cached and not expired
    func isCached(id: String) -> Bool {
        guard let cachedUser = getCachedUser(id: id) else { return false }
        return !cachedUser.isExpired
    }
    
    /// Get IDs of users that are not cached or expired from the provided list
    func getMissingUserIds(from ids: [String]) -> [String] {
        return ids.filter { !isCached(id: $0) }
    }
    
    /// Clean up expired cache entries
    func cleanupExpired() {
        var cache = loadCache()
        let expiredKeys = cache.compactMap { key, value in
            value.isExpired ? key : nil
        }
        
        for key in expiredKeys {
            cache.removeValue(forKey: key)
        }
        
        if !expiredKeys.isEmpty {
            saveCache(cache)
            print("🧹 Cleaned up \(expiredKeys.count) expired user cache entries")
        }
    }
    
    // MARK: - Private Methods
    
    private func getCachedUser(id: String) -> CachedUser? {
        let cache = loadCache()
        return cache[id]
    }
    
    private func loadCache() -> [String: CachedUser] {
        guard let data = userDefaults.data(forKey: cacheKey) else {
            return [:]
        }
        
        do {
            return try JSONDecoder().decode([String: CachedUser].self, from: data)
        } catch {
            print("❌ Failed to decode user cache: \(error)")
            // Clear corrupted cache
            userDefaults.removeObject(forKey: cacheKey)
            return [:]
        }
    }
    
    private func saveCache(_ cache: [String: CachedUser]) {
        do {
            let data = try JSONEncoder().encode(cache)
            userDefaults.set(data, forKey: cacheKey)
        } catch {
            print("❌ Failed to encode user cache: \(error)")
        }
    }
} 