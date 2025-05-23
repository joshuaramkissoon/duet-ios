//
//  User.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 20/05/2025.
//

import Foundation

struct User: Identifiable, Encodable, Decodable {
    let id: String
    let name: String?
    
    private enum CodingKeys: String, CodingKey {
        case id, name
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
}
