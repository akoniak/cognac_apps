//
//  UserProfile.swift
//  Community Status App
//
//  User profile with role-based access
//

import Foundation

enum UserRole: String, Codable, CaseIterable {
    case admin = "admin"
    case moderator = "moderator"
    case general = "general"
    case readOnly = "read_only"
    
    var displayName: String {
        switch self {
        case .admin: return "Admin"
        case .moderator: return "Moderator"
        case .general: return "General User"
        case .readOnly: return "Read Only"
        }
    }
    
    var canSubmitReports: Bool {
        switch self {
        case .admin, .moderator, .general: return true
        case .readOnly: return false
        }
    }
    
    var canModerateReports: Bool {
        switch self {
        case .admin, .moderator: return true
        case .general, .readOnly: return false
        }
    }
    
    var canManageUsers: Bool {
        self == .admin
    }
}

struct UserProfile: Codable, Identifiable {
    var id: String? // Auth UID
    var email: String?
    var displayName: String?
    
    // Community membership and role
    var communityID: String
    var role: UserRole
    
    // Profile info
    var address: String? // User's home address (optional)
    var phoneNumber: String?
    
    // Metadata
    var createdAt: Date
    var lastActiveAt: Date
    var isActive: Bool
    
    // Moderation
    var isBanned: Bool
    var banReason: String?
    
    // Stats
    var reportCount: Int
    var verificationCount: Int
    /// Number of the user's submitted reports that were later confirmed (whole number, for display).
    var confirmedReportCount: Int
    /// Weighted reputation points earned from confirmations.
    /// Primary reports earn 1.0 point when confirmed; corroborating reports (submitted when
    /// a same-road same-category report already existed) earn 0.5 points.
    var confirmedReportPoints: Double

    // MARK: - Reputation

    /// Accuracy as a ratio of weighted confirmation points to total reports submitted.
    /// Clamped to [0, 1] so excess corroborating points can never push this above 100%.
    var accuracyPercent: Double {
        guard reportCount > 0 else { return 0 }
        return min(confirmedReportPoints / Double(reportCount), 1.0)
    }

    /// Confidence weight: how much we trust the accuracy sample given submission volume.
    /// Uses sqrt(count / 20) so it ramps quickly at first and flattens near the cap,
    /// reaching 1.0 at 20 reports. Crucially, this is a function of count alone —
    /// it does NOT cancel with the count in accuracyPercent the way a linear ramp did.
    ///
    /// Old linear formula collapsed:
    ///   (points/count) × (count/20)  →  points/20   (accuracy ignored)
    ///
    /// sqrt ramp does NOT collapse:
    ///   accuracy × sqrt(count/20)  — both terms remain meaningful
    var confidenceWeight: Double {
        min(sqrt(Double(reportCount) / 20.0), 1.0)
    }

    /// Weighted trust score (0–1).
    /// = accuracyPercent × confidenceWeight
    /// A perfectly accurate reporter at 5 reports gets ~0.5 trust; at 20+ reports, full trust.
    /// An inaccurate reporter with high volume will have low accuracy pulling the score down.
    var weightedTrust: Double {
        accuracyPercent * confidenceWeight
    }

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case displayName = "display_name"
        case communityID = "community_id"
        case role
        case address
        case phoneNumber = "phone_number"
        case createdAt = "created_at"
        case lastActiveAt = "last_active_at"
        case isActive = "is_active"
        case isBanned = "is_banned"
        case banReason = "ban_reason"
        case reportCount = "report_count"
        case verificationCount = "verification_count"
        case confirmedReportCount = "confirmed_report_count"
        case confirmedReportPoints = "confirmed_report_points"
    }
}

