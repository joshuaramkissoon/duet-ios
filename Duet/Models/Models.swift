//
//  Models.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 17/05/2025.
//

import Foundation
import UIKit

struct ItineraryItem: Identifiable, Codable {
    var id: String = UUID().uuidString
    var time: String
    var title: String
    var activity: String
    var duration: String?
    var location: String?
    var notes: String?
    
    // CodingKeys to handle the id that's not in JSON
    private enum CodingKeys: String, CodingKey {
        case time, title, activity, duration, location, notes
    }
}

struct Activity: Identifiable, Codable {
    var id: String = UUID().uuidString
    let title: String
    let icon: String
    
    // CodingKeys to handle the id that's not in JSON
    private enum CodingKeys: String, CodingKey {
        case title, icon
    }
}

struct Tag: Identifiable, Codable {
    var id: String = UUID().uuidString
    let title: String
    let icon: String
    
    // CodingKeys to handle the id that's not in JSON
    private enum CodingKeys: String, CodingKey {
        case title, icon
    }
}

// Helper extension to check if an SFSymbol name exists
extension String {
    var isValidSFSymbol: Bool {
        UIImage(systemName: self) != nil
    }
}

struct ActivitySummary: Identifiable, Codable {
    let id: String
    let title: String
    let videoUrl: String
    let activityType: Activity
    let location: String
    let createdAt: Date
    let costLevel: CostLevel
    
    enum CodingKeys: String, CodingKey {
        case id, title, videoUrl, activityType, location, createdAt, costLevel
    }
}

struct ActivityHistoryResponse: Decodable {
    let activities: [ActivitySummary]
}

struct PaginatedFeedResponse: Decodable {
    let items: [DateIdeaResponse]
    let total: Int
    let page: Int
    let pageSize: Int
    let totalPages: Int
    let hasNext: Bool
    let hasPrevious: Bool
    
    private enum CodingKeys: String, CodingKey {
        case items, total, page
        case pageSize = "page_size"
        case totalPages = "total_pages"
        case hasNext = "has_next"
        case hasPrevious = "has_previous"
    }
}

enum ContentType: String, Codable {
    case recipe = "recipe"
    case dateIdea = "date_idea"
    case activity = "activity"
    case travel = "travel"
}

struct RecipeMetadata: Codable {
    let cuisine_type: String?
    let difficulty_level: String?
    let servings: String?
    let prep_time: String?
    let cook_time: String?
    let ingredients: [String]?
    let instructions: [String]?
}

struct DateIdea: Identifiable, Codable {
    var id: String = UUID().uuidString
    let title: String
    let summary: String
    let content_type: ContentType?
    let sales_pitch: String
    let activity: Activity
    let location: String
    let season: Season
    let duration: String
    let cost_level: CostLevel
    var required_items: [String]
    let tags: [Tag]
    var suggested_itinerary: [ItineraryItem]?
    var recipe_metadata: RecipeMetadata?
    
    // CodingKeys to handle the id that's not in JSON
    private enum CodingKeys: String, CodingKey {
        case title, summary, content_type, sales_pitch, activity, location, season, duration, cost_level, required_items, tags, suggested_itinerary, recipe_metadata
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        title = try container.decode(String.self, forKey: .title)
        summary = try container.decode(String.self, forKey: .summary)
        content_type = try container.decodeIfPresent(ContentType.self, forKey: .content_type)
        sales_pitch = try container.decode(String.self, forKey: .sales_pitch)
        activity = try container.decode(Activity.self, forKey: .activity)
        location = try container.decode(String.self, forKey: .location)
        season = try container.decode(Season.self, forKey: .season)
        duration = try container.decode(String.self, forKey: .duration)
        cost_level = try container.decode(CostLevel.self, forKey: .cost_level)
        required_items = try container.decode([String].self, forKey: .required_items)
        tags = try container.decode([Tag].self, forKey: .tags)
        suggested_itinerary = try container.decodeIfPresent([ItineraryItem].self, forKey: .suggested_itinerary)
        recipe_metadata = try container.decodeIfPresent(RecipeMetadata.self, forKey: .recipe_metadata)
        
        // Set a default UUID string for id since it's not in the JSON
        id = UUID().uuidString
    }
    
    // Custom initializer for previews and testing
    init(id: String = UUID().uuidString,
         title: String,
         summary: String,
         content_type: ContentType? = nil,
         sales_pitch: String,
         activity: Activity,
         location: String,
         season: Season,
         duration: String,
         cost_level: CostLevel,
         required_items: [String],
         tags: [Tag],
         suggested_itinerary: [ItineraryItem]? = nil,
         recipe_metadata: RecipeMetadata? = nil) {
        self.id = id
        self.title = title
        self.summary = summary
        self.content_type = content_type
        self.sales_pitch = sales_pitch
        self.activity = activity
        self.location = location
        self.season = season
        self.duration = duration
        self.cost_level = cost_level
        self.required_items = required_items
        self.tags = tags
        self.suggested_itinerary = suggested_itinerary
        self.recipe_metadata = recipe_metadata
    }
}

enum Season: String, Codable {
    case spring
    case summer
    case autumn
    case winter
    case indoor
    
    var icon: String {
        switch self {
        case .spring:
            return "flower"
        case .summer:
            return "sun.max"
        case .autumn:
            return "leaf.fill"
        case .winter:
            return "snowflake"
        case .indoor:
            return "house"
        }
    }
}

enum CostLevel: String, Codable {
    case low
    case medium
    case high
    
    var icon: String {
        switch self {
        case .low:
            return "dollarsign"
        case .medium:
            return "dollarsign.square"
        case .high:
            return "dollarsign.square.fill"
        }
    }
    
    var displayName: String {
        switch self {
        case .low:
            return "Budget-friendly"
        case .medium:
            return "Moderate"
        case .high:
            return "Splurge"
        }
    }
}
