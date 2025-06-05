//
//  User.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 20/05/2025.
//

import Foundation
import SwiftUI

// MARK: - Player Level Enum
enum PlayerLevel: CaseIterable {
    case ideaSpark
    case ideaIgniter
    case creativeFlame
    case innovationStar
    
    init(ideaCount: Int) {
        switch ideaCount {
        case 0..<15:
            self = .ideaSpark
        case 16..<40:
            self = .ideaIgniter
        case 41..<90:
            self = .creativeFlame
        default:
            self = .innovationStar
        }
    }
    
    var title: String {
        switch self {
        case .ideaSpark:
            return "Idea Spark"
        case .ideaIgniter:
            return "Idea Igniter"
        case .creativeFlame:
            return "Creative Flame"
        case .innovationStar:
            return "Innovation Star"
        }
    }
    
    var icon: String {
        switch self {
        case .ideaSpark:
            return "lightbulb"
        case .ideaIgniter:
            return "bolt.fill"
        case .creativeFlame:
            return "flame"
        case .innovationStar:
            return "sparkles"
        }
    }
    
    var color: Color {
        backgroundColor
    }
    
    var backgroundColor: Color {
        switch self {
        case .ideaSpark:
            return Color(red: 1.0, green: 0.95, blue: 0.8).opacity(0.3) // Soft yellow cream
        case .ideaIgniter:
            return Color(red: 0.8, green: 0.9, blue: 1.0).opacity(0.3) // Sky blue
        case .creativeFlame:
            return Color(red: 1.0, green: 0.75, blue: 0.6).opacity(0.3) // Warm coral
        case .innovationStar:
            return Color(red: 0.9, green: 0.85, blue: 1.0).opacity(0.3) // Lavender mist
        }
    }

    var foregroundColor: Color {
        switch self {
        case .ideaSpark:
            return Color(red: 0.9, green: 0.7, blue: 0.2) // Bright golden
        case .ideaIgniter:
            return Color(red: 0.2, green: 0.5, blue: 0.8) // Deep blue
        case .creativeFlame:
            return Color(red: 0.9, green: 0.4, blue: 0.2) // Vibrant orange
        case .innovationStar:
            return Color(red: 0.6, green: 0.4, blue: 0.8) // Rich purple
        }
    }
}

struct User: Identifiable, Encodable, Decodable {
    let id: String
    let name: String?
    var profileImageUrl: String?
    let createdAt: String?
    let playerLevel: String?
    let credits: Int
    
    // Custom initializer for backward compatibility
    init(id: String, name: String?, profileImageUrl: String? = nil, createdAt: String? = nil, playerLevel: String? = nil, credits: Int = 0) {
        self.id = id
        self.name = name
        self.profileImageUrl = profileImageUrl
        self.createdAt = createdAt
        self.playerLevel = playerLevel
        self.credits = credits
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, name, credits
        case profileImageUrl = "profile_image_url"
        case createdAt = "created_at"
        case playerLevel = "player_level"
    }
    
    var initials: String {
        if let name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            let parts = name.split(separator: " ")
            if parts.count >= 2 {
                return String(parts[0].first!) + String(parts[1].first!)
            } else {
                return name.first?.uppercased() ?? ""
            }
        }
        // fallback: use first two characters of the UID
        return "G"
    }
    
    var displayName: String {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "Guest user" : trimmed
    }
    
    var memberSinceText: String {
        guard let createdAtString = createdAt else {
            return "Member since recently"
        }
        
        // Try multiple parsing approaches
        var date: Date?
        
        // 1. Try ISO8601DateFormatter with fractional seconds
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        date = iso8601Formatter.date(from: createdAtString)
        
        // 2. Try ISO8601DateFormatter without fractional seconds
        if date == nil {
            iso8601Formatter.formatOptions = [.withInternetDateTime]
            date = iso8601Formatter.date(from: createdAtString)
        }
        
        // 3. Try custom DateFormatter for the exact format
        if date == nil {
            let customFormatter = DateFormatter()
            customFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"
            customFormatter.timeZone = TimeZone(abbreviation: "UTC")
            date = customFormatter.date(from: createdAtString)
        }
        
        // 4. Try custom DateFormatter without microseconds
        if date == nil {
            let customFormatter = DateFormatter()
            customFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
            customFormatter.timeZone = TimeZone(abbreviation: "UTC")
            date = customFormatter.date(from: createdAtString)
        }
        
        guard let parsedDate = date else {
            return "Member since recently"
        }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MMMM yyyy"
        return "Member since \(displayFormatter.string(from: parsedDate))"
    }
    
    var playerLevelInfo: PlayerLevel {
        guard let levelString = playerLevel?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) else {
            return .ideaSpark // Default level
        }
        
        // Parse level names from backend
        switch levelString {
        case "innovation_star", "innovation star", "innovationstar":
            return .innovationStar
        case "creative_flame", "creative flame", "creativeflame":
            return .creativeFlame
        case "idea_igniter", "idea igniter", "ideaigniter":
            return .ideaIgniter
        case "idea_spark", "idea spark", "ideaspark":
            return .ideaSpark
        default:
            // Fallback for any unrecognized level names
            return .ideaSpark
        }
    }
    
    // MARK: - Credit Properties
    var creditsCount: Int {
        return credits
    }
    
    var hasLowCredits: Bool {
        return creditsCount < 5
    }
}
