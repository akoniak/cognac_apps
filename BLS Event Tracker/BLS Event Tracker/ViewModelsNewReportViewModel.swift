//
//  NewReportViewModel.swift
//  Community Status App
//
//  ViewModel for creating new reports
//

import Foundation
import SwiftUI
import Combine

@MainActor
class NewReportViewModel: ObservableObject {
    @Published var selectedCategory: ReportCategory = .powerOut
    @Published var note: String = ""
    @Published var selectedRoadID: String?

    @Published var isSubmitting = false
    @Published var submitSuccess = false
    @Published var showError = false
    @Published var errorMessage: String?

    private let dataService = AppDataService.shared
    private let authManager = AuthenticationManager.shared

    let availableRoads = Road.bluelakeSpringsRoads

    var canSubmit: Bool {
        selectedRoadID != nil
    }

    func submitReport() async {
        guard let userProfile = authManager.userProfile,
              let userID = authManager.user?.uid else {
            errorMessage = "Missing required information"
            showError = true
            return
        }

        guard let roadID = selectedRoadID,
              let road = availableRoads.first(where: { $0.id == roadID }) else {
            errorMessage = "Please select a road"
            showError = true
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let expirationHours = Report.defaultExpirationHours(for: selectedCategory)
            let expiresAt = Calendar.current.date(
                byAdding: .hour,
                value: expirationHours,
                to: Date()
            ) ?? Date().addingTimeInterval(86400)

            // Check if an active report for this road+category already exists.
            if let existing = try? await dataService.fetchActiveReportForRoad(
                roadID: roadID,
                category: selectedCategory,
                communityID: userProfile.communityID
               ), let existingID = existing.id {

                // Block self-corroboration: the user already authored this report.
                if existing.authorID == userID {
                    errorMessage = "You already have an active \(selectedCategory.displayName) report for this road."
                    showError = true
                    return
                }

                // Block duplicate corroboration: already confirmed this one.
                if existing.corroboratingSubmitterIDs.contains(userID) {
                    errorMessage = "You've already corroborated this report."
                    showError = true
                    return
                }

                try await dataService.submitCorroboratingReport(
                    existingReportID: existingID,
                    communityID: userProfile.communityID,
                    submitterID: userID
                )
                await authManager.refreshUserProfile()
                NotificationCenter.default.post(name: .reportSubmitted, object: existing)
                submitSuccess = true
                return
            }

            let report = Report(
                communityID: userProfile.communityID,
                category: selectedCategory,
                status: .active,
                address: road.name,
                latitude: road.centerLatitude,
                longitude: road.centerLongitude,
                roadID: roadID,
                note: note.isEmpty ? nil : note,
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

            _ = try await dataService.createReport(report)

            // Atomically increment the author's report_count without touching other
            // reputation fields, then refresh the in-memory profile from Firestore.
            try await dataService.incrementReportCount(userID: userID)
            await authManager.refreshUserProfile()

            // Notify map to reload and zoom to the new report's location
            NotificationCenter.default.post(name: .reportSubmitted, object: report)

            submitSuccess = true
        } catch {
            errorMessage = "Failed to submit report: \(error.localizedDescription)"
            showError = true
        }
    }
}
