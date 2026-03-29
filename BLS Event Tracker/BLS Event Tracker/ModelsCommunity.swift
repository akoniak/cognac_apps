//
//  Community.swift
//  Community Status App
//
//  Core data model for a community/neighborhood
//

import Foundation

struct Community: Codable, Identifiable {
    var id: String?
    var name: String
    var displayName: String
    var description: String
    
    // Geographic bounds for the community
    var centerLatitude: Double
    var centerLongitude: Double
    var radiusMeters: Double // Approximate radius for display purposes
    
    // Admin/moderation
    var adminUserIDs: [String]
    var moderatorUserIDs: [String]
    
    // Settings
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date
    
    // Future expansion readiness
    var settings: [String: String]? // Flexible key-value for future config
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case displayName = "display_name"
        case description
        case centerLatitude = "center_lat"
        case centerLongitude = "center_lng"
        case radiusMeters = "radius_meters"
        case adminUserIDs = "admin_user_ids"
        case moderatorUserIDs = "moderator_user_ids"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case settings
    }
}

