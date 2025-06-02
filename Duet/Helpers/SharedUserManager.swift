//
//  SharedUserManager.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 24/05/2025.
//

import Foundation

class SharedUserManager {
    static let shared = SharedUserManager()
    private let appGroup = "group.jram.Duet.Duet"
    private let userIdKey = "duet_current_user_id"
    private let authTokenKey = "duet_firebase_auth_token"
    private let tokenExpiryKey = "duet_token_expiry"
    
    var currentUserId: String? {
        let sharedDefaults = UserDefaults(suiteName: appGroup)
        return sharedDefaults?.string(forKey: userIdKey)
    }
    
    var currentAuthToken: String? {
        let sharedDefaults = UserDefaults(suiteName: appGroup)
        
        // Check if token exists and hasn't expired
        guard let token = sharedDefaults?.string(forKey: authTokenKey),
              let expiryDate = sharedDefaults?.object(forKey: tokenExpiryKey) as? Date,
              expiryDate > Date() else {
            // Token expired or doesn't exist, clear it
            clearAuthToken()
            return nil
        }
        
        return token
    }
    
    func setCurrentUserId(_ userId: String) {
        let sharedDefaults = UserDefaults(suiteName: appGroup)
        sharedDefaults?.set(userId, forKey: userIdKey)
        sharedDefaults?.synchronize()
    }
    
    func setAuthToken(_ token: String, expiresIn: TimeInterval = 3600) {
        let sharedDefaults = UserDefaults(suiteName: appGroup)
        let expiryDate = Date().addingTimeInterval(expiresIn)
        
        sharedDefaults?.set(token, forKey: authTokenKey)
        sharedDefaults?.set(expiryDate, forKey: tokenExpiryKey)
        sharedDefaults?.synchronize()
    }
    
    func clearCurrentUser() {
        let sharedDefaults = UserDefaults(suiteName: appGroup)
        sharedDefaults?.removeObject(forKey: userIdKey)
        sharedDefaults?.removeObject(forKey: authTokenKey)
        sharedDefaults?.removeObject(forKey: tokenExpiryKey)
        sharedDefaults?.synchronize()
    }
    
    private func clearAuthToken() {
        let sharedDefaults = UserDefaults(suiteName: appGroup)
        sharedDefaults?.removeObject(forKey: authTokenKey)
        sharedDefaults?.removeObject(forKey: tokenExpiryKey)
        sharedDefaults?.synchronize()
    }
}
