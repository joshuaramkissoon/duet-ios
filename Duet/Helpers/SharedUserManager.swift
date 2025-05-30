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
    
    var currentUserId: String? {
        let sharedDefaults = UserDefaults(suiteName: appGroup)
        return sharedDefaults?.string(forKey: userIdKey)
    }
    
    func setCurrentUserId(_ userId: String) {
        let sharedDefaults = UserDefaults(suiteName: appGroup)
        sharedDefaults?.set(userId, forKey: userIdKey)
        sharedDefaults?.synchronize()
    }
    
    func clearCurrentUser() {
        let sharedDefaults = UserDefaults(suiteName: appGroup)
        sharedDefaults?.removeObject(forKey: userIdKey)
        sharedDefaults?.synchronize()
    }
}
