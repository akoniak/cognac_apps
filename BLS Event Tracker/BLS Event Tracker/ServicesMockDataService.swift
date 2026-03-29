//
//  MockDataService.swift
//  Community Status App
//
//  Mock data service to replace Firestore
//

import Foundation

@MainActor
class MockDataService {
    static let shared = MockDataService()
    
    // In-memory storage
    private var reports: [Report] = []
    private var communities: [Community] = []
    private var userProfiles: [String: UserProfile] = [:]
    private var announcement: Announcement?
    
    private init() {
        setupMockData()
    }
    
    // MARK: - Mock Data Setup
    
    private func setupMockData() {
        // Create a mock community - Blue Lake Springs
        let mockCommunity = Community(
            id: "mock-community-1",
            name: "blue-lake-springs",
            displayName: "Blue Lake Springs",
            description: "Blue Lake Springs community in Arnold, CA",
            centerLatitude: 38.2453,  // Arnold, CA
            centerLongitude: -120.3459,
            radiusMeters: 3000,
            adminUserIDs: ["mock-user-123"],
            moderatorUserIDs: [],
            isActive: true,
            createdAt: Date(),
            updatedAt: Date(),
            settings: nil
        )
        communities.append(mockCommunity)
        
        // Create a default announcement
        announcement = Announcement(
            message: "Welcome to the Blue Lake Springs event tracker. Reports come from residents and may not always be accurate. Do not rely on this app for emergencies. If you are in danger, please call 911.",
            lastUpdated: Date().addingTimeInterval(-7200) // 2 hours ago
        )
        
        // Create some sample reports
        createSampleReports()
    }
    
    private func createSampleReports() {
        // Each report is crafted to represent a distinct confidence tier:
        // .unconfirmed — no verifications yet
        // .mixed        — has both verifications and disputes
        // .verified     — has verifications and no disputes

        struct SampleReport {
            let address: String
            let lat: Double
            let lng: Double
            let category: ReportCategory
            let verificationCount: Int
            let disputeCount: Int
            let note: String
            let hoursAgo: Double
        }

        let samples: [SampleReport] = [
            // Unconfirmed: newly submitted, no one has weighed in yet
            SampleReport(
                address: "571 Mauna Kea Dr, Arnold, CA",
                lat: 38.24500, lng: -120.34590,
                category: .powerOut,
                verificationCount: 0, disputeCount: 0,
                note: "Power seems to be out on this block",
                hoursAgo: 0.5
            ),
            // Mixed: some confirm, some dispute
            SampleReport(
                address: "Blue Lake Springs Dr, Arnold, CA",
                lat: 38.24640, lng: -120.34450,
                category: .powerOut,
                verificationCount: 2, disputeCount: 1,
                note: "Power outage reported — neighbors have mixed experiences",
                hoursAgo: 2
            ),
            // Verified: multiple confirmations, no disputes
            SampleReport(
                address: "Mauna Loa Dr, Arnold, CA",
                lat: 38.24400, lng: -120.34800,
                category: .powerOut,
                verificationCount: 3, disputeCount: 0,
                note: "Confirmed outage — multiple households affected",
                hoursAgo: 4
            ),
        ]

        for (index, sample) in samples.enumerated() {
            let expirationHours = Report.defaultExpirationHours(for: sample.category)

            let report = Report(
                id: "mock-report-\(index + 1)",
                communityID: "mock-community-1",
                category: sample.category,
                status: .active,
                address: sample.address,
                latitude: sample.lat,
                longitude: sample.lng,
                roadID: nil,
                note: sample.note,
                photoURL: nil,
                authorID: "mock-user-\(index + 1)",
                authorDisplayName: "User \(index + 1)",
                verificationCount: sample.verificationCount,
                disputeCount: sample.disputeCount,
                verifiedByUserIDs: [],
                disputedByUserIDs: [],
                createdAt: Date().addingTimeInterval(-sample.hoursAgo * 3600),
                expiresAt: Date().addingTimeInterval(Double(expirationHours) * 3600),
                updatedAt: Date(),
                isHidden: false,
                hiddenByModeratorID: nil,
                hiddenReason: nil,
                corroboratingWeight: 1.0,
                corroboratingSubmitterIDs: [],
                corroboratorsRewarded: false,
                authorReputationEarned: 0.0,
                authorWeightedTrust: 0.0
            )

            reports.append(report)
        }

        // Add road status reports
        createSampleRoadReports()
    }
    
    private func createSampleRoadReports() {
        // Road status reports - linked to specific roads
        let roadReports: [(roadID: String, roadName: String, category: ReportCategory, hoursAgo: Double)] = [
            ("blue-lake-springs-dr", "Blue Lake Springs Dr", .roadPlowed, 2),
            ("mauna-kea-dr", "Mauna Kea Dr", .roadPlowed, 3),
            ("mauna-loa-dr", "Mauna Loa Dr", .roadBlocked, 1),
            ("highway-4", "Highway 4", .roadPlowed, 4),
        ]
        
        for (index, roadReport) in roadReports.enumerated() {
            let road = Road.bluelakeSpringsRoads.first(where: { $0.id == roadReport.roadID })!
            let expirationHours = Report.defaultExpirationHours(for: roadReport.category)
            
            let report = Report(
                id: "mock-road-report-\(index + 1)",
                communityID: "mock-community-1",
                category: roadReport.category,
                status: .active,
                address: roadReport.roadName,
                latitude: road.centerLatitude,
                longitude: road.centerLongitude,
                roadID: roadReport.roadID,
                note: roadReport.category == .roadPlowed ? "Road has been plowed and is passable" : "Road is currently blocked",
                photoURL: nil,
                authorID: "mock-user-road-\(index + 1)",
                authorDisplayName: "Road User \(index + 1)",
                verificationCount: 3,
                disputeCount: 0,
                verifiedByUserIDs: [],
                disputedByUserIDs: [],
                createdAt: Date().addingTimeInterval(-roadReport.hoursAgo * 3600),
                expiresAt: Date().addingTimeInterval(Double(expirationHours) * 3600),
                updatedAt: Date(),
                isHidden: false,
                hiddenByModeratorID: nil,
                hiddenReason: nil,
                corroboratingWeight: 1.0,
                corroboratingSubmitterIDs: [],
                corroboratorsRewarded: false,
                authorReputationEarned: 0.0,
                authorWeightedTrust: 0.0
            )

            reports.append(report)
        }
    }
    
    // MARK: - Community Operations
    
    func fetchDefaultCommunityID() async throws -> String {
        try await Task.sleep(for: .milliseconds(200)) // Simulate network
        guard let community = communities.first else {
            throw DataServiceError.noCommunityFound
        }
        return community.id ?? "mock-community-1"
    }
    
    func fetchCommunity(communityID: String) async throws -> Community {
        try await Task.sleep(for: .milliseconds(200))
        guard let community = communities.first(where: { $0.id == communityID }) else {
            throw DataServiceError.noCommunityFound
        }
        return community
    }
    
    // MARK: - User Profile Operations
    
    func fetchUserProfile(userID: String) async throws -> UserProfile {
        try await Task.sleep(for: .milliseconds(200))
        guard let profile = userProfiles[userID] else {
            throw DataServiceError.userNotFound
        }
        return profile
    }

    func fetchAllUsersInCommunity(communityID: String) async throws -> [UserProfile] {
        try await Task.sleep(for: .milliseconds(200))
        return userProfiles.values.filter { $0.communityID == communityID }
    }
    
    func createUserProfile(_ profile: UserProfile) async throws {
        try await Task.sleep(for: .milliseconds(200))
        guard let userID = profile.id else {
            throw DataServiceError.invalidUserID
        }
        userProfiles[userID] = profile
    }
    
    func updateUserProfile(_ profile: UserProfile) async throws {
        try await Task.sleep(for: .milliseconds(200))
        guard let userID = profile.id else {
            throw DataServiceError.invalidUserID
        }
        userProfiles[userID] = profile
    }

    func incrementReportCount(userID: String) async throws {
        try await Task.sleep(for: .milliseconds(50))
        userProfiles[userID]?.reportCount += 1
    }

    // MARK: - Report Operations
    
    func fetchReports(for communityID: String, includeExpired: Bool = false) async throws -> [Report] {
        try await Task.sleep(for: .milliseconds(300)) // Simulate network
        
        return reports.filter { report in
            report.communityID == communityID &&
            !report.isHidden &&
            report.status == .active &&
            (includeExpired || !report.isExpired)
        }
    }
    
    func createReport(_ report: Report) async throws -> String {
        try await Task.sleep(for: .milliseconds(300))
        
        var newReport = report
        let newID = "mock-report-\(UUID().uuidString)"
        newReport.id = newID
        
        reports.append(newReport)
        return newID
    }
    
    /// Returns the first active, non-hidden, non-expired report for the given road and category, if any.
    func fetchActiveReportForRoad(roadID: String, category: ReportCategory, communityID: String) async throws -> Report? {
        try await Task.sleep(for: .milliseconds(200))
        return reports.first {
            $0.roadID == roadID &&
            $0.category == category &&
            $0.communityID == communityID &&
            !$0.isHidden &&
            $0.status == .active &&
            !$0.isExpired
        }
    }

    /// Records a corroborating submission: adds the submitter to corroboratingSubmitterIDs
    /// and increments their report_count. The 0.5 point award is deferred until the first
    /// external verification of the parent report (see verifyReport).
    func submitCorroboratingReport(existingReportID: String, communityID: String, submitterID: String) async throws {
        try await Task.sleep(for: .milliseconds(200))

        guard let index = reports.firstIndex(where: { $0.id == existingReportID }) else {
            throw DataServiceError.invalidReportID
        }

        var report = reports[index]

        // Prevent duplicate entries
        guard !report.corroboratingSubmitterIDs.contains(submitterID) else { return }

        report.corroboratingSubmitterIDs.append(submitterID)
        report.updatedAt = Date()
        reports[index] = report

        // Increment report_count only — points come when the report is first verified.
        if var submitterProfile = userProfiles[submitterID] {
            submitterProfile.reportCount += 1
            userProfiles[submitterID] = submitterProfile
        }
    }

    func updateReport(_ report: Report) async throws {
        try await Task.sleep(for: .milliseconds(200))
        
        guard let reportID = report.id,
              let index = reports.firstIndex(where: { $0.id == reportID }) else {
            throw DataServiceError.invalidReportID
        }
        
        reports[index] = report
    }
    
    func verifyReport(reportID: String, communityID: String, userID: String, authorID: String) async throws {
        try await Task.sleep(for: .milliseconds(200))

        guard let index = reports.firstIndex(where: { $0.id == reportID }) else {
            throw DataServiceError.invalidReportID
        }

        var report = reports[index]
        let wasAlreadyVerified = report.verifiedByUserIDs.contains(userID)
        let isFirstVerification = !report.corroboratorsRewarded && !wasAlreadyVerified

        report.disputedByUserIDs.removeAll { $0 == userID }
        if !wasAlreadyVerified { report.verifiedByUserIDs.append(userID) }

        report.verificationCount = report.verifiedByUserIDs.count
        report.disputeCount = report.disputedByUserIDs.count
        report.updatedAt = Date()

        // Mark corroborators as rewarded so future verifications don't re-award them
        if isFirstVerification {
            report.corroboratorsRewarded = true
        }
        reports[index] = report

        if !wasAlreadyVerified {
            // Increment the voter's own verification count
            if var voterProfile = userProfiles[userID] {
                voterProfile.verificationCount += 1
                userProfiles[userID] = voterProfile
            }
            // Credit the report author and keep the report ledger in sync.
            // confirmed_report_count only increments the first time this report earns points.
            if userID != authorID, var authorProfile = userProfiles[authorID] {
                let isFirstEarnedForReport = report.authorReputationEarned == 0.0
                if isFirstEarnedForReport {
                    authorProfile.confirmedReportCount += 1
                }
                authorProfile.confirmedReportPoints += report.corroboratingWeight
                userProfiles[authorID] = authorProfile
                report.authorReputationEarned += report.corroboratingWeight
                reports[index] = report
            }
        }

        // On the first external verification, pay out 0.5 points to each corroborator
        if isFirstVerification {
            for cid in report.corroboratingSubmitterIDs where cid != userID {
                if var corrobProfile = userProfiles[cid] {
                    corrobProfile.confirmedReportPoints += 0.5
                    userProfiles[cid] = corrobProfile
                }
            }
        }
    }

    func disputeReport(reportID: String, communityID: String, userID: String, authorID: String) async throws {
        try await Task.sleep(for: .milliseconds(200))

        guard let index = reports.firstIndex(where: { $0.id == reportID }) else {
            throw DataServiceError.invalidReportID
        }

        var report = reports[index]
        let wasPreviousVerifier = report.verifiedByUserIDs.contains(userID)
        let wasAlreadyDisputing = report.disputedByUserIDs.contains(userID)

        report.verifiedByUserIDs.removeAll { $0 == userID }
        if !wasAlreadyDisputing { report.disputedByUserIDs.append(userID) }

        report.verificationCount = report.verifiedByUserIDs.count
        report.disputeCount = report.disputedByUserIDs.count
        report.updatedAt = Date()

        if report.disputeCount > report.verificationCount && report.disputeCount >= 3 {
            report.status = .disputed
        }
        reports[index] = report

        if !wasAlreadyDisputing {
            // Increment the voter's own verification count
            if var voterProfile = userProfiles[userID] {
                voterProfile.verificationCount += 1
                userProfiles[userID] = voterProfile
            }
        }
        // Revoke the author's credit if this user previously verified the report,
        // and keep the report ledger in sync.
        // Only decrement confirmed_report_count when earned reaches zero — it counts
        // distinct confirmed reports, not individual confirmation events.
        if wasPreviousVerifier && userID != authorID, var authorProfile = userProfiles[authorID] {
            let newEarned = max(0.0, report.authorReputationEarned - report.corroboratingWeight)
            if report.authorReputationEarned > 0 && newEarned == 0.0 {
                authorProfile.confirmedReportCount = max(0, authorProfile.confirmedReportCount - 1)
            }
            authorProfile.confirmedReportPoints = max(0.0, authorProfile.confirmedReportPoints - report.corroboratingWeight)
            userProfiles[authorID] = authorProfile
            report.authorReputationEarned = newEarned
            reports[index] = report
        }
    }
    
    func hideReport(reportID: String, communityID: String, moderatorID: String, reason: String) async throws {
        try await Task.sleep(for: .milliseconds(200))
        
        guard let index = reports.firstIndex(where: { $0.id == reportID }) else {
            throw DataServiceError.invalidReportID
        }
        
        var report = reports[index]
        report.isHidden = true
        report.hiddenByModeratorID = moderatorID
        report.hiddenReason = reason
        report.updatedAt = Date()
        
        reports[index] = report
    }

    func deleteReports(in communityID: String, olderThan date: Date) async throws {
        try await Task.sleep(for: .milliseconds(200))
        reports.removeAll { $0.expiresAt < date }
    }

    func deleteAllReports(in communityID: String) async throws {
        try await Task.sleep(for: .milliseconds(200))
        reports.removeAll()
    }
    
    // MARK: - Announcement Operations
    
    func fetchAnnouncement() async throws -> Announcement {
        try await Task.sleep(for: .milliseconds(200))
        guard let announcement = announcement else {
            throw DataServiceError.announcementNotFound
        }
        return announcement
    }
    
    func updateAnnouncement(_ announcement: Announcement) async throws {
        try await Task.sleep(for: .milliseconds(200))
        self.announcement = announcement
    }
}

// MARK: - Data Service Errors

enum DataServiceError: LocalizedError {
    case noCommunityFound
    case userNotFound
    case invalidUserID
    case invalidReportID
    case announcementNotFound
    case reportAlreadyConfirmed
    
    var errorDescription: String? {
        switch self {
        case .noCommunityFound:
            return "No active community found"
        case .userNotFound:
            return "User profile not found"
        case .invalidUserID:
            return "Invalid user ID"
        case .invalidReportID:
            return "Invalid report ID"
        case .announcementNotFound:
            return "Announcement not found"
        case .reportAlreadyConfirmed:
            return "This report has already been confirmed by another user and can no longer be deleted."
        }
    }
}
