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
    
    var filteredReports: [Report] {
        let filtered = reports.filter { report in
            selectedFilter.matches(category: report.category) && report.isVisible
        }
        return sortedReports(filtered)
    }

    // MARK: - Listener lifecycle

    func startListening(for communityID: String) {
        dataService.startListeningToReports(for: communityID) { [weak self] updatedReports in
            self?.reports = updatedReports
        }
    }

    func stopListening() {
        dataService.stopListeningToReports()
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
    
    func deleteOwnReport(_ report: Report) async -> Bool {
        guard let userID = authManager.user?.uid,
              let reportID = report.id,
              report.authorID == userID else { return false }
        do {
            try await dataService.deleteOwnReport(reportID: reportID, communityID: report.communityID, authorID: userID)
            await authManager.refreshUserProfile()
            return true
        } catch DataServiceError.reportAlreadyConfirmed {
            errorMessage = "This report has already been confirmed by another user and can no longer be deleted."
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
