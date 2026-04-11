//
//  Report.swift
//  Community Status App
//
//  Core status report model
//

import Foundation
import CoreLocation
import SwiftUI

enum ReportCategory: String, Codable, CaseIterable {
    case powerOut = "power_out"
    case roadPlowed = "road_plowed"
    case roadBlocked = "road_blocked"

    var displayName: String {
        switch self {
        case .powerOut: return "Power Out"
        case .roadPlowed: return "Road Plowed"
        case .roadBlocked: return "Road Blocked"
        }
    }

    var iconName: String {
        switch self {
        case .powerOut: return "bolt.slash.fill"
        case .roadPlowed: return "checkmark.circle.fill"
        case .roadBlocked: return "xmark.circle.fill"
        }
    }

    var isPositiveStatus: Bool {
        switch self {
        case .roadPlowed: return true
        case .powerOut, .roadBlocked: return false
        }
    }

    var isRoadStatus: Bool {
        switch self {
        case .roadPlowed, .roadBlocked: return true
        case .powerOut: return false
        }
    }

    /// All categories use the road picker — no free-text address entry anywhere.
    var usesRoadPicker: Bool { true }

    /// True when this category has a natural opposing category (e.g. roadBlocked ↔ roadPlowed,
    /// powerOut ↔ power restored). Disputes on these reports typically mean "the opposite
    /// condition is now true" rather than "the original reporter was wrong", so they should not
    /// penalise the author's reputation.
    var hasOpposingCategory: Bool {
        switch self {
        case .roadPlowed, .roadBlocked, .powerOut: return true
        }
    }
}

enum ReportStatus: String, Codable {
    case active = "active"
    case expired = "expired"
    case disputed = "disputed"
    case removed = "removed"
}

struct Report: Codable, Identifiable, Equatable {
    var id: String?
    
    // Core data
    var communityID: String
    var category: ReportCategory
    var status: ReportStatus
    
    // Location
    var address: String
    var latitude: Double
    var longitude: Double
    
    // Road-specific (for road status reports)
    var roadID: String? // Links to Road.id for road status reports
    
    // Content
    var note: String?
    var photoURL: String? // Storage URL
    
    // Author
    var authorID: String
    var authorDisplayName: String?
    
    // Verification system
    var verificationCount: Int
    var disputeCount: Int
    var verifiedByUserIDs: [String]
    var disputedByUserIDs: [String]
    
    // Timestamps
    var createdAt: Date
    var expiresAt: Date
    var updatedAt: Date
    
    // Moderation
    var isHidden: Bool
    var hiddenByModeratorID: String?
    var hiddenReason: String?

    /// Reputation credit weight for the author when this report is verified.
    /// Primary reports (first report for a road+category) = 1.0.
    /// Corroborating reports (duplicate road+category already active) = 0.5.
    var corroboratingWeight: Double

    /// UIDs of users who submitted a corroborating report for this road+category
    /// while this report was active. They earn 0.5 reputation points each the first
    /// time any external verifier confirms this report (see corroboratorsRewarded).
    var corroboratingSubmitterIDs: [String]

    /// Set to true the first time verifyReport credits the corroborators.
    /// Prevents awarding the 0.5 points more than once regardless of how many
    /// verifications the report accumulates.
    var corroboratorsRewarded: Bool

    /// Running total of confirmed_report_points that have been credited to the author
    /// specifically because of this report. Incremented by verifyReport (by corroboratingWeight)
    /// and decremented by disputeReport when a flip-to-dispute revokes a confirmation.
    /// Used by deleteOwnReport to subtract exactly the right amount — no reconstruction needed.
    var authorReputationEarned: Double

    /// Snapshot of the author's weightedTrust at the moment this report was submitted.
    /// Used by confidenceTier to grant auto-Verified status to highly-trusted reporters
    /// without requiring community confirmations. Disputes can still override this.
    var authorWeightedTrust: Double

    enum CodingKeys: String, CodingKey {
        case id
        case communityID = "community_id"
        case category
        case status
        case address
        case latitude
        case longitude
        case roadID = "road_id"
        case note
        case photoURL = "photo_url"
        case authorID = "author_id"
        case authorDisplayName = "author_display_name"
        case verificationCount = "verification_count"
        case disputeCount = "dispute_count"
        case verifiedByUserIDs = "verified_by_user_ids"
        case disputedByUserIDs = "disputed_by_user_ids"
        case createdAt = "created_at"
        case expiresAt = "expires_at"
        case updatedAt = "updated_at"
        case isHidden = "is_hidden"
        case hiddenByModeratorID = "hidden_by_moderator_id"
        case hiddenReason = "hidden_reason"
        case corroboratingWeight = "corroborating_weight"
        case corroboratingSubmitterIDs = "corroborating_submitter_ids"
        case corroboratorsRewarded = "corroborators_rewarded"
        case authorReputationEarned = "author_reputation_earned"
        case authorWeightedTrust = "author_weighted_trust"
    }
}

// MARK: - Reporter Alias

/// Derives a stable, anonymous alias from a user UID.
/// The same UID always produces the same label, keeping reporter identity private
/// from the public-facing UI while remaining traceable by admins.
func reporterAlias(for userID: String) -> String {
    var hash = 0
    for scalar in userID.unicodeScalars {
        hash = (hash &* 31 &+ Int(scalar.value)) & 0x7FFF_FFFF
    }
    return "#\((hash % 9000) + 1000)"
}

// MARK: - Computed Properties
extension Report {
    /// Anonymous label shown to regular users instead of the author's real name.
    var authorAlias: String { reporterAlias(for: authorID) }

    var isExpired: Bool {
        Date() > expiresAt
    }
    
    var isVisible: Bool {
        !isHidden && status == .active && !isExpired
    }
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var confidenceLevel: Double {
        let total = verificationCount + disputeCount
        guard total > 0 else { return 0.5 }
        return Double(verificationCount) / Double(total)
    }
    
    var isPossiblyOutdated: Bool {
        // Road plowed reports expire on their own — no staleness warning needed.
        // For persistent reports (power out, road blocked), flag after 7 days
        // as a gentle prompt that conditions may have changed.
        guard category != .roadPlowed else { return false }
        let hoursAgo = Date().timeIntervalSince(createdAt) / 3600
        return hoursAgo > 7 * 24
    }
    
    var ageInHours: Double {
        Date().timeIntervalSince(createdAt) / 3600
    }
    
    var confidenceTier: ConfidenceTier {
        // Trusted Reporter fast-path: reports from highly-trusted authors (weightedTrust ≥ 0.8)
        // get a green "Trusted Reporter" badge without needing community confirmations.
        // Any dispute overrides this — disputed reports fall through to normal tier logic.
        if authorWeightedTrust >= 0.8 && disputeCount == 0 {
            return .trustedReporter
        }

        // Verified: at least 1 community confirmation and zero disputes.
        if verificationCount >= 1 && disputeCount == 0 {
            return .verified
        }

        // Mixed: has both verifications and disputes (any ratio)
        if verificationCount > 0 && disputeCount > 0 {
            return .mixed
        }

        // Unconfirmed: no verifications yet, or has disputes with no verifications
        return .unconfirmed
    }
}

// MARK: - Confidence Tier

enum ConfidenceTier {
    case trustedReporter  // Green - Author is Highly Trusted (weightedTrust ≥ 0.8), no disputes
    case verified         // Green - ≥ 2 community confirmations, no disputes
    case mixed            // Yellow - Has both verifications and disputes
    case unconfirmed      // Orange - No verifications or more disputes

    var displayName: String {
        switch self {
        case .trustedReporter: return "Trusted Reporter"
        case .verified: return "Verified"
        case .mixed: return "Mixed Reports"
        case .unconfirmed: return "Unconfirmed"
        }
    }

    var color: Color {
        switch self {
        case .trustedReporter: return .green
        case .verified: return .green
        case .mixed: return .yellow
        case .unconfirmed: return Color(red: 0.95, green: 0.6, blue: 0.1)
        }
    }

    var iconName: String {
        switch self {
        case .trustedReporter: return "person.badge.shield.checkmark.fill"
        case .verified: return "checkmark.seal.fill"
        case .mixed: return "exclamationmark.triangle.fill"
        case .unconfirmed: return "questionmark.circle.fill"
        }
    }
}

// MARK: - Helper Methods
extension Report {
    // Default expiration times based on category.
    // Power outages and road blocks don't expire automatically — conditions may persist
    // for days. They stay active until a countering report (power restored, road plowed)
    // is submitted, or an admin manually clears old reports.
    // Road plowed reports do expire since a fresh snowfall can reverse them quickly.
    static func defaultExpirationHours(for category: ReportCategory) -> Int {
        switch category {
        case .powerOut:
            return 7 * 24   // 7 days default (admin-configurable)
        case .roadBlocked:
            return 48       // 48 hours default (admin-configurable)
        case .roadPlowed:
            return 12       // 12 hours default — may snow again (admin-configurable)
        }
    }
}
