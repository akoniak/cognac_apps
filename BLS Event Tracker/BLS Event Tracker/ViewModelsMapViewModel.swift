//
//  MapViewModel.swift
//  Community Status App
//
//  ViewModel for main map view
//

import Foundation
import MapKit
import SwiftUI
import Combine

extension Notification.Name {
    static let reportSubmitted = Notification.Name("reportSubmitted")
}

/// A GeoJSON road segment paired with a road status for map rendering.
struct ColoredRoadSegment: Identifiable {
    let id: Int
    let roadID: String
    let coordinates: [CLLocationCoordinate2D]
    let status: RoadStatus

    /// Midpoint of the segment for placing tap targets
    var midpoint: CLLocationCoordinate2D {
        guard !coordinates.isEmpty else {
            return CLLocationCoordinate2D()
        }
        let mid = coordinates.count / 2
        return coordinates[mid]
    }
}

@MainActor
class MapViewModel: ObservableObject {
    @Published var reports: [Report] = []
    @Published var roads: [Road] = []
    @Published var cameraPosition: MapCameraPosition = .automatic
    @Published var selectedReport: Report?
    @Published var selectedRoad: Road?
    @Published var selectedFilter: ReportFilterOption = .all
    @Published var showError = false
    @Published var errorMessage: String?
    /// True while the 60-second cooldown after a manual refresh is active.
    @Published var refreshCoolingDown = false

    /// Road segments paired with their current status color, recomputed when road statuses change.
    @Published var coloredRoadSegments: [ColoredRoadSegment] = []

    private let dataService = AppDataService.shared
    private let authManager = AuthenticationManager.shared
    /// Timestamp of the last manual refresh, used to enforce the 60-second cooldown.
    private var lastManualRefresh: Date?
    /// Opaque token identifying this view model's listener registration.
    private var listenerToken: UUID?
    
    var filteredReports: [Report] {
        // Filter reports by category
        let categoryFilteredReports = reports.filter { report in
            selectedFilter.matches(category: report.category) && report.isVisible
        }
        
        // Exclude road status reports from the filtered list
        // (they're shown as road icons instead)
        return categoryFilteredReports.filter { !$0.category.isRoadStatus }
    }
    
    var outageCount: Int {
        reports.filter { report in
            report.isVisible &&
            (report.category == .powerOut)
        }.count
    }
    
    var blockedRoadCount: Int {
        roads.filter { $0.status == .blocked }.count
    }
    
    var hasActiveIssues: Bool {
        outageCount > 0 || blockedRoadCount > 0
    }
    
    /// Returns the most recent visible report for a given road
    func latestReport(for road: Road) -> Report? {
        latestReport(forRoadID: road.id)
    }

    /// Returns the most recent visible report for a given road ID
    func latestReport(forRoadID roadID: String) -> Report? {
        reports
            .filter { $0.roadID == roadID && $0.isVisible }
            .sorted { $0.createdAt > $1.createdAt }
            .first
    }
    
    init() {
        setCameraToDefault()
        loadRoads()
        GeoJSONService.shared.loadRoads()
    }

    // MARK: - Listener lifecycle

    /// Starts the real-time Firestore listener for the given community.
    /// Stops any existing registration first so re-entrant calls don't accumulate callbacks.
    func startListening(for communityID: String) {
        stopListening()
        listenerToken = dataService.startListeningToReports(for: communityID) { [weak self] updatedReports in
            guard let self else { return }
            self.reports = updatedReports
            // Keep the open detail card in sync so its confidence badge reflects live changes
            // (e.g. another user verifying or disputing while this card is visible).
            if let selected = self.selectedReport,
               let updated = updatedReports.first(where: { $0.id == selected.id }) {
                self.selectedReport = updated
            }
            self.updateRoadStatuses()
        }
    }

    /// Tears down this view model's listener registration.
    func stopListening() {
        dataService.stopListeningToReports(token: listenerToken)
        listenerToken = nil
    }

    // MARK: - Report loading

    /// Initial load: starts the listener (Firebase) or does a one-shot fetch (mock).
    func loadReports() async {
        // If the profile isn't loaded yet, return silently.
        // The map view's .onChange(of: userProfile?.communityID) will retry
        // once the profile arrives from Firestore.
        guard let communityID = authManager.userProfile?.communityID,
              !communityID.isEmpty else {
            return
        }

        if useMockData {
            // Mock mode: one-shot fetch as before
            do {
                reports = try await dataService.fetchReports(for: communityID)
                updateRoadStatuses()
            } catch {
                errorMessage = "Failed to load reports: \(error.localizedDescription)"
                showError = true
            }
        } else {
            // Firebase mode: attach listener — updates arrive automatically from here on
            startListening(for: communityID)
        }
    }

    /// Manual refresh triggered by the refresh button.
    /// Enforces a 60-second cooldown between taps to limit Firestore reads.
    /// In Firebase mode this re-attaches the listener (which fires an immediate snapshot);
    /// in mock mode it does a fresh one-shot fetch.
    func manualRefresh() async {
        let cooldown: TimeInterval = 60
        if let last = lastManualRefresh, Date().timeIntervalSince(last) < cooldown {
            return  // Still within cooldown window — ignore
        }
        lastManualRefresh = Date()
        refreshCoolingDown = true

        await loadReports()

        // Release the cooldown indicator after 60 seconds
        try? await Task.sleep(for: .seconds(cooldown))
        refreshCoolingDown = false
    }
    
    private func loadRoads() {
        // Load Blue Lake Springs roads
        roads = Road.bluelakeSpringsRoads
        // Geocode roads that only have the fallback community center coordinate
        Task { await geocodeRoadsIfNeeded() }
    }
    
    private func geocodeRoadsIfNeeded() async {
        let geocoder = CLGeocoder()
        let fallbackLat = 38.2453
        let fallbackLon = -120.3459
        let tolerance = 0.0001
        
        for index in roads.indices {
            let road = roads[index]
            // Skip roads that already have real coordinates
            guard abs(road.centerLatitude - fallbackLat) < tolerance &&
                  abs(road.centerLongitude - fallbackLon) < tolerance else { continue }
            
            let query = "\(road.name), Arnold, CA 95223"
            do {
                // CLGeocoder rate-limits to ~1 req/sec; add a small delay
                try await Task.sleep(for: .milliseconds(300))
                let placemarks = try await geocoder.geocodeAddressString(query)
                if let location = placemarks.first?.location {
                    roads[index].centerLatitude = location.coordinate.latitude
                    roads[index].centerLongitude = location.coordinate.longitude
                }
            } catch {
                // Keep fallback coordinate if geocoding fails
            }
        }
        
        // Re-apply road statuses after coordinates are updated
        updateRoadStatuses()
    }
    
    private func updateRoadStatuses() {
        // Update each road's status based on current reports
        for index in roads.indices {
            roads[index].updateStatus(from: reports)
        }
        rebuildColoredSegments()
    }

    /// Rebuilds the colored road segments from roads that have an active status.
    private func rebuildColoredSegments() {
        let service = GeoJSONService.shared
        var segments: [ColoredRoadSegment] = []
        for road in roads where road.status != .unknown {
            let geoSegments = service.segments(forRoadID: road.id)
            for seg in geoSegments {
                segments.append(ColoredRoadSegment(
                    id: seg.id,
                    roadID: road.id,
                    coordinates: seg.coordinates,
                    status: road.status
                ))
            }
        }
        coloredRoadSegments = segments
    }
    
    func verifyReport(_ report: Report) async {
        guard let userID = authManager.user?.uid,
              let reportID = report.id else {
            return
        }

        do {
            try await dataService.verifyReport(reportID: reportID, communityID: report.communityID, userID: userID, authorID: report.authorID)
            await loadReports()
            await authManager.refreshUserProfile()
        } catch {
            print("⚠️ verifyReport error: \(error)")
            errorMessage = "Failed to verify report"
            showError = true
        }
    }

    func disputeReport(_ report: Report) async {
        guard let userID = authManager.user?.uid,
              let reportID = report.id else {
            return
        }

        do {
            try await dataService.disputeReport(reportID: reportID, communityID: report.communityID, userID: userID, authorID: report.authorID)
            await loadReports()
            await authManager.refreshUserProfile()
        } catch {
            errorMessage = "Failed to dispute report"
            showError = true
        }
    }

    /// Submits a roadPlowed counter-report for a roadBlocked report.
    /// This does not penalise the original author — the road was blocked at the time,
    /// it has simply since been cleared.
    func markRoadCleared(_ report: Report) async {
        guard let userProfile = authManager.userProfile,
              let userID = authManager.user?.uid,
              let road = roads.first(where: { $0.id == report.roadID }) else {
            return
        }

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
            // Atomically increment report_count without touching reputation fields
            try await dataService.incrementReportCount(userID: userID)
            await authManager.refreshUserProfile()
        } catch {
            errorMessage = "Failed to submit road cleared update"
            showError = true
        }
    }
    
    /// Submits a roadBlocked counter-report for a roadPlowed report.
    /// This does not penalise the original author — the road was plowed at the time,
    /// it simply needs plowing again (e.g. new snowfall).
    func markRoadNeedsPlowing(_ report: Report) async {
        guard let userProfile = authManager.userProfile,
              let userID = authManager.user?.uid,
              let road = roads.first(where: { $0.id == report.roadID }) else {
            return
        }

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

    /// Marks a power outage report as resolved (power has been restored).
    /// This does not penalise the original author — power was out when reported,
    /// it has simply since been restored.
    func markPowerRestored(_ report: Report) async {
        guard let userID = authManager.user?.uid,
              let reportID = report.id else { return }
        do {
            try await dataService.markPowerRestored(reportID: reportID, communityID: report.communityID, resolvedByUserID: userID)
            selectedReport = nil
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
            selectedReport = nil
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

    func focusOnReport(_ report: Report) {
        // Zoom to the report location with animation
        let region = MKCoordinateRegion(
            center: report.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        
        withAnimation {
            cameraPosition = .region(region)
        }
    }
    
    private func setCameraToDefault() {
        // Blue Lake Springs community in Arnold, CA
        let defaultRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 38.2453, longitude: -120.3459), // Arnold, CA
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        )
        cameraPosition = .region(defaultRegion)
    }
}
