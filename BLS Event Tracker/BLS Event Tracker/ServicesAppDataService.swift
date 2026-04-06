//
//  AppDataService.swift
//  BLS Event Tracker
//
//  Single toggle between MockDataService and FirebaseDataService.
//  To switch to Firebase, change useMockData to false.
//

import Foundation

/// Set to `true` to use in-memory mock data, `false` to use Firestore.
let useMockData = false

/// The active data service used across the app.
/// View models call `AppDataService.shared.*` instead of referencing
/// MockDataService or FirebaseDataService directly.
@MainActor
class AppDataService {
    static let shared = AppDataService()

    // Forward calls to whichever backend is active
    private let mock = MockDataService.shared
    private let firebase = FirebaseDataService.shared

    private init() {}

    // MARK: - Community

    func fetchDefaultCommunityID() async throws -> String {
        if useMockData {
            return try await mock.fetchDefaultCommunityID()
        } else {
            return try await firebase.fetchDefaultCommunityID()
        }
    }

    func fetchCommunity(communityID: String) async throws -> Community {
        if useMockData {
            return try await mock.fetchCommunity(communityID: communityID)
        } else {
            return try await firebase.fetchCommunity(communityID: communityID)
        }
    }

    // MARK: - User Profiles

    func fetchUserProfile(userID: String) async throws -> UserProfile {
        if useMockData {
            return try await mock.fetchUserProfile(userID: userID)
        } else {
            return try await firebase.fetchUserProfile(userID: userID)
        }
    }

    func fetchAllUsersInCommunity(communityID: String) async throws -> [UserProfile] {
        if useMockData {
            return try await mock.fetchAllUsersInCommunity(communityID: communityID)
        } else {
            return try await firebase.fetchAllUsersInCommunity(communityID: communityID)
        }
    }

    func createUserProfile(_ profile: UserProfile) async throws {
        if useMockData {
            try await mock.createUserProfile(profile)
        } else {
            try await firebase.createUserProfile(profile)
        }
    }

    func updateUserProfile(_ profile: UserProfile) async throws {
        if useMockData {
            try await mock.updateUserProfile(profile)
        } else {
            try await firebase.updateUserProfile(profile)
        }
    }

    func deleteUserProfile(userID: String) async throws {
        guard !useMockData else { return }
        try await firebase.deleteUserProfile(userID: userID)
    }

    /// Anonymizes all reports the user authored. No-op in mock mode.
    func anonymizeReports(authorID: String, communityID: String) async throws {
        guard !useMockData else { return }
        try await firebase.anonymizeReports(authorID: authorID, communityID: communityID)
    }

    /// Atomically increments a user's report_count by 1 without touching other profile fields.
    func incrementReportCount(userID: String) async throws {
        if useMockData {
            try await mock.incrementReportCount(userID: userID)
        } else {
            try await firebase.incrementReportCount(userID: userID)
        }
    }

    // MARK: - Real-time listener

    /// Starts a Firestore real-time listener for reports in the given community.
    /// Returns an opaque token that must be passed to stopListeningToReports.
    /// In mock mode this is a no-op and returns nil.
    @discardableResult
    func startListeningToReports(for communityID: String, onUpdate: @escaping ([Report]) -> Void) -> UUID? {
        guard !useMockData else { return nil }
        return firebase.startListeningToReports(for: communityID, onUpdate: onUpdate)
    }

    /// Removes the callback associated with the given token.
    /// Pass nil (mock mode) and the call is a no-op.
    func stopListeningToReports(token: UUID?) {
        guard !useMockData, let token else { return }
        firebase.stopListeningToReports(token: token)
    }

    // MARK: - Issue Reports

    /// Submits a user issue flag for a report. No-op in mock mode.
    func submitIssueReport(reportID: String?, communityID: String, category: String, address: String, authorID: String, reportedByUserID: String, reason: String, note: String?) async throws {
        guard !useMockData else { return }
        try await firebase.submitIssueReport(reportID: reportID, communityID: communityID, category: category, address: address, authorID: authorID, reportedByUserID: reportedByUserID, reason: reason, note: note)
    }

    // MARK: - Reports

    func fetchReports(for communityID: String, includeExpired: Bool = false) async throws -> [Report] {
        if useMockData {
            return try await mock.fetchReports(for: communityID, includeExpired: includeExpired)
        } else {
            return try await firebase.fetchReports(for: communityID, includeExpired: includeExpired)
        }
    }

    func createReport(_ report: Report) async throws -> String {
        if useMockData {
            return try await mock.createReport(report)
        } else {
            return try await firebase.createReport(report)
        }
    }

    /// Returns the first active report for the given road and category, if one exists.
    func fetchActiveReportForRoad(roadID: String, category: ReportCategory, communityID: String) async throws -> Report? {
        if useMockData {
            return try await mock.fetchActiveReportForRoad(roadID: roadID, category: category, communityID: communityID)
        } else {
            return try await firebase.fetchActiveReportForRoad(roadID: roadID, category: category, communityID: communityID)
        }
    }

    /// Adds the submitter to an existing report's verifiedByUserIDs and awards 0.5 confirmed_report_points.
    func submitCorroboratingReport(existingReportID: String, communityID: String, submitterID: String) async throws {
        if useMockData {
            try await mock.submitCorroboratingReport(existingReportID: existingReportID, communityID: communityID, submitterID: submitterID)
        } else {
            try await firebase.submitCorroboratingReport(existingReportID: existingReportID, communityID: communityID, submitterID: submitterID)
        }
    }

    func updateReport(_ report: Report) async throws {
        if useMockData {
            try await mock.updateReport(report)
        } else {
            try await firebase.updateReport(report)
        }
    }

    func verifyReport(reportID: String, communityID: String, userID: String, authorID: String) async throws {
        if useMockData {
            try await mock.verifyReport(reportID: reportID, communityID: communityID, userID: userID, authorID: authorID)
        } else {
            try await firebase.verifyReport(reportID: reportID, communityID: communityID, userID: userID, authorID: authorID)
        }
    }

    func disputeReport(reportID: String, communityID: String, userID: String, authorID: String) async throws {
        if useMockData {
            try await mock.disputeReport(reportID: reportID, communityID: communityID, userID: userID, authorID: authorID)
        } else {
            try await firebase.disputeReport(reportID: reportID, communityID: communityID, userID: userID, authorID: authorID)
        }
    }

    func deleteOwnReport(reportID: String, communityID: String, authorID: String) async throws {
        guard !useMockData else { return }
        try await firebase.deleteOwnReport(reportID: reportID, communityID: communityID, authorID: authorID)
    }

    /// Marks a power outage report resolved without penalising the original author.
    func markPowerRestored(reportID: String, communityID: String, resolvedByUserID: String) async throws {
        guard !useMockData else { return }
        try await firebase.markPowerRestored(reportID: reportID, communityID: communityID, resolvedByUserID: resolvedByUserID)
    }

    func hideReport(reportID: String, communityID: String, moderatorID: String, reason: String) async throws {
        if useMockData {
            try await mock.hideReport(reportID: reportID, communityID: communityID, moderatorID: moderatorID, reason: reason)
        } else {
            try await firebase.hideReport(reportID: reportID, communityID: communityID, moderatorID: moderatorID, reason: reason)
        }
    }

    func deleteReports(in communityID: String, olderThan date: Date) async throws {
        if useMockData {
            try await mock.deleteReports(in: communityID, olderThan: date)
        } else {
            try await firebase.deleteReports(in: communityID, olderThan: date)
        }
    }

    func deleteAllReports(in communityID: String) async throws {
        if useMockData {
            try await mock.deleteAllReports(in: communityID)
        } else {
            try await firebase.deleteAllReports(in: communityID)
        }
    }

    // MARK: - Announcements

    func fetchAnnouncement() async throws -> Announcement {
        if useMockData {
            return try await mock.fetchAnnouncement()
        } else {
            return try await firebase.fetchAnnouncement()
        }
    }

    func updateAnnouncement(_ announcement: Announcement) async throws {
        if useMockData {
            try await mock.updateAnnouncement(announcement)
        } else {
            try await firebase.updateAnnouncement(announcement)
        }
    }

    /// Attaches a real-time listener to the announcement document.
    /// Returns a registration token — call `.remove()` on it to stop listening.
    /// In mock mode this is a no-op and returns nil.
    func startListeningToAnnouncement(onUpdate: @escaping (Announcement) -> Void) -> AnyObject? {
        guard !useMockData else { return nil }
        return firebase.startListeningToAnnouncement(onUpdate: onUpdate)
    }
}
