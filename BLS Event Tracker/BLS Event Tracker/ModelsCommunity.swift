//
//  Community.swift
//  Community Status App
//
//  Core data model for a community/neighborhood
//

import Foundation

// MARK: - Expiration Settings

/// Per-category report expiration durations, configurable by admins.
struct ExpirationSettings {
    var powerOutHours: Int
    var roadBlockedHours: Int
    var roadPlowedHours: Int

    static let `default` = ExpirationSettings(
        powerOutHours: 7 * 24,   // 7 days
        roadBlockedHours: 48,    // 48 hours
        roadPlowedHours: 12      // 12 hours
    )

    /// The allowed picker options (shared across all categories).
    static let allowedHours: [(hours: Int, label: String)] = [
        (12,      "12 hours"),
        (24,      "24 hours"),
        (48,      "48 hours"),
        (7 * 24,  "7 days")
    ]

    func hours(for category: ReportCategory) -> Int {
        switch category {
        case .powerOut:     return powerOutHours
        case .roadBlocked:  return roadBlockedHours
        case .roadPlowed:   return roadPlowedHours
        }
    }
}

// MARK: - Community Model

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
    
    // Computed from the `settings` dict — no stored property needed.
    /// Returns the admin-configured expiration hours, falling back to defaults
    /// for any key that hasn't been written yet.
    var expirationSettings: ExpirationSettings {
        ExpirationSettings(
            powerOutHours:    settings?["expiration_power_out"].flatMap(Int.init)    ?? ExpirationSettings.default.powerOutHours,
            roadBlockedHours: settings?["expiration_road_blocked"].flatMap(Int.init) ?? ExpirationSettings.default.roadBlockedHours,
            roadPlowedHours:  settings?["expiration_road_plowed"].flatMap(Int.init)  ?? ExpirationSettings.default.roadPlowedHours
        )
    }

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

