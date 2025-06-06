//
//  ContentReport.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 20/12/2024.
//

import Foundation
import FirebaseFirestore

struct ContentReport: Codable {
    @DocumentID var id: String?
    let ideaId: String
    let reporterUserId: String
    let reason: ContentReportReason
    let description: String
    let timestamp: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case ideaId = "idea_id"
        case reporterUserId = "reporter_user_id"
        case reason
        case description
        case timestamp
    }
}

enum ContentReportReason: String, CaseIterable, Codable {
    case inappropriateContent = "inappropriate_content"
    case spam = "spam"
    case harassment = "harassment"
    case copyright = "copyright"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .inappropriateContent:
            return "Inappropriate Content"
        case .spam:
            return "Spam"
        case .harassment:
            return "Harassment"
        case .copyright:
            return "Copyright Violation"
        case .other:
            return "Other"
        }
    }
} 