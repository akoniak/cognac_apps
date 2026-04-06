//
//  ReportsListViewModel.swift
//  Community Status App
//
//  ViewModel for reports list with sorting and filtering
//

import Foundation
import Combine

@MainActor
class ReportsListViewModel: ObservableObject {
    @Published var reports: [Report] = []
    @Published var sortOption: ReportSortOption = .mostRecent
    @Published var selectedFilter: ReportFilterOption = .all
    @Published var showError = false
    @Published var errorMessage: String?
    
    private let dataService = AppDataService.shared
    private let authManager = AuthenticationManager.shared
    /// Opaque token identifying this view model's listener registration.
    private var listenerToken: UUID?
    
    var filteredReports: [Report] {
        let filtered = reports.filter { report in
            selectedFilter.matches(category: report.category) && report.isVisible
        }
        return sortedReports(filtered)
    }

    // MARK: - Listener lifecycle

    func startListening(for communityID: String) {
        stopListening()
        listenerToken = dataService.startListeningToReports(for: communityID) { [weak self] updatedReports in
            self?.reports = updatedReports
            // Update activity badge with the current set of report IDs.
            let ids = Set(updatedReports.compactMap(\.id))
            NotificationManager.shared.updateNewReportsBadge(currentIDs: ids)
            // Check whether any of the current user's reports were verified or disputed.
            if let userID = AuthenticationManager.shared.user?.uid {
                NotificationManager.shared.checkReputationChanges(in: updatedReports, currentUserID: userID)
            }
        }
    }

    func stopListening() {
        dataService.stopListeningToReports(token: listenerToken)
        listenerToken = nil
    }

    // MARK: - Load

    func loadReports() async {
        // If the profile isn't loaded yet, return silently.
        // The view's .onChange(of: userProfile?.communityID) will retry
        // once the profile arrives from Firestore.
        guard let communityID = authManager.userProfile?.communityID,
              !communityID.isEmpty else {
            return
        }

        if useMockData {
            do {
                reports = try await dataService.fetchReports(for: communityID)
            } catch {
                errorMessage = "Failed to load reports: \(error.localizedDescription)"
                showError = true
            }
        } else {
            startListening(for: communityID)
        }
    }
    
    /// Submits a roadPlowed counter-report for a roadBlocked report.
    /// Does not penalise the original author — road was blocked at the time, now cleared.
    func markRoadCleared(_ report: Report) async {
        guard let userProfile = authManager.userProfile,
              let userID = authManager.user?.uid,
              let road = Road.bluelakeSpringsRoads.first(where: { $0.id == report.roadID }) else { return }

        let expiresAt = Calendar.current.date(byAdding: .hour, value: 12, to: Date()) ?? Date().addingTimeInterval(43200)
        let counterReport = Report(
            communityID: report.communityID,
            category: .roadPlowed,
            status: .active,
            address: road.name,
            latitude: road.centerLatitude,
            longitude: road.centerLongitude,
            roadID: road.id,
            note: nil,
            photoURL: nil,
            authorID: userID,
            authorDisplayName: userProfile.displayName,
            verificationCount: 0,
            disputeCount: 0,
            verifiedByUserIDs: [],
            disputedByUserIDs: [],
            createdAt: Date(),
            expiresAt: expiresAt,
            updatedAt: Date(),
            isHidden: false,
            hiddenByModeratorID: nil,
            hiddenReason: nil,
            corroboratingWeight: 1.0,
            corroboratingSubmitterIDs: [],
            corroboratorsRewarded: false,
            authorReputationEarned: 0.0,
            authorWeightedTrust: userProfile.weightedTrust
        )
        do {
            _ = try await dataService.createReport(counterReport)
            try await dataService.incrementReportCount(userID: userID)
            await authManager.refreshUserProfile()
        } catch {
            errorMessage = "Failed to submit road cleared update"
            showError = true
        }
    }

    /// Submits a roadBlocked counter-report for a roadPlowed report.
    /// Does not penalise the original author — road was plowed at the time, now needs plowing again.
    func markRoadNeedsPlowing(_ report: Report) async {
        guard let userProfile = authManager.userProfile,
              let userID = authManager.user?.uid,
              let road = Road.bluelakeSpringsRoads.first(where: { $0.id == report.roadID }) else { return }

        let expiresAt = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date().addingTimeInterval(30 * 24 * 3600)
        let counterReport = Report(
            communityID: report.communityID,
            category: .roadBlocked,
            status: .active,
            address: road.name,
            latitude: road.centerLatitude,
            longitude: road.centerLongitude,
            roadID: road.id,
            note: nil,
            photoURL: nil,
            authorID: userID,
            authorDisplayName: userProfile.displayName,
            verificationCount: 0,
            disputeCount: 0,
            verifiedByUserIDs: [],
            disputedByUserIDs: [],
            createdAt: Date(),
            expiresAt: expiresAt,
            updatedAt: Date(),
            isHidden: false,
            hiddenByModeratorID: nil,
            hiddenReason: nil,
            corroboratingWeight: 1.0,
            corroboratingSubmitterIDs: [],
            corroboratorsRewarded: false,
            authorReputationEarned: 0.0,
            authorWeightedTrust: userProfile.weightedTrust
        )
        do {
            _ = try await dataService.createReport(counterReport)
            try await dataService.incrementReportCount(userID: userID)
            await authManager.refreshUserProfile()
        } catch {
            errorMessage = "Failed to submit road needs plowing update"
            showError = true
        }
    }

    /// Marks a power outage report as resolved.
    /// Does not penalise the original author — power was out when reported, now restored.
    func markPowerRestored(_ report: Report) async {
        guard let userID = authManager.user?.uid,
              let reportID = report.id else { return }
        do {
            try await dataService.markPowerRestored(reportID: reportID, communityID: report.communityID, resolvedByUserID: userID)
            await authManager.refreshUserProfile()
        } catch {
            errorMessage = "Failed to submit power restored update"
            showError = true
        }
    }

    func deleteOwnReport(_ report: Report) async -> Bool {
        guard let userID = authManager.user?.uid,
              let reportID = report.id,
              report.authorID == userID else { return false }
        do {
            try await dataService.deleteOwnReport(reportID: reportID, communityID: report.communityID, authorID: userID)
            await authManager.refreshUserProfile()
            return true
        } catch DataServiceError.reportAlreadyConfirmed {
            errorMessage = "This report has been corroborated or confirmed by another user and can no longer be deleted."
            showError = true
            return false
        } catch {
            errorMessage = "Failed to delete report"
            showError = true
            return false
        }
    }

    private func sortedReports(_ reports: [Report]) -> [Report] {
        switch sortOption {
        case .mostRecent:
            return reports.sorted { $0.createdAt > $1.createdAt }
            
        case .oldest:
            return reports.sorted { $0.createdAt < $1.createdAt }
            
        case .category:
            return reports.sorted { report1, report2 in
                if report1.category.rawValue == report2.category.rawValue {
                    return report1.createdAt > report2.createdAt
                }
                return report1.category.rawValue < report2.category.rawValue
            }
            
        case .mostVerified:
            return reports.sorted { report1, report2 in
                if report1.confidenceLevel == report2.confidenceLevel {
                    return report1.createdAt > report2.createdAt
                }
                return report1.confidenceLevel > report2.confidenceLevel
            }
        }
    }
}
