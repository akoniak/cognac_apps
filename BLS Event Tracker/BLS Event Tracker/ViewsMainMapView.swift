//
//  MainMapView.swift
//  Community Status App
//
//  Main map interface showing community reports
//

import SwiftUI
import MapKit

struct MainMapView: View {
    @StateObject private var viewModel = MapViewModel()
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @Binding var isReportCardVisible: Bool
    
    var body: some View {
        ZStack {
            // Map showing all reports
            Map(position: $viewModel.cameraPosition) {
                // User's location
                UserAnnotation()
                
                // Road status icons (show when "All" or "Roads" filter is selected)
                if viewModel.selectedFilter == .all || viewModel.selectedFilter == .roads {
                    ForEach(viewModel.roads.filter { $0.status != .unknown }) { road in
                        Annotation(road.name, coordinate: road.coordinate) {
                            RoadStatusMarker(
                                road: road,
                                isSelected: viewModel.selectedReport?.roadID == road.id
                            )
                            .onTapGesture {
                                viewModel.selectedReport = viewModel.latestReport(for: road)
                            }
                        }
                    }
                }
                
                // Report markers (filtered) - excludes road status reports
                // Power outage markers use a shifted anchor so both the visual and tap target
                // move together — roads sit at center; power shifts up-right.
                ForEach(viewModel.filteredReports) { report in
                    Annotation(
                        report.category.displayName,
                        coordinate: report.coordinate,
                        anchor: report.category == .powerOut
                            ? UnitPoint(x: 0.0, y: 1.0)
                            : .center
                    ) {
                        ReportMarker(
                            report: report,
                            isSelected: viewModel.selectedReport?.id == report.id
                        )
                        .onTapGesture {
                            viewModel.selectedReport = report
                        }
                    }
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .mapControls {
                MapUserLocationButton()
                MapCompass()
            }
            
            // Floating UI elements
            VStack(spacing: 0) {
                // Header with title and filters - matches activity page style
                VStack(spacing: 12) {
                    // Title - Centered
                    Text("Blue Lake Springs - Status")
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal, 16)
                    
                    // Filter chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(ReportFilterOption.allCases) { filter in
                                FilterChip(
                                    filter: filter,
                                    isSelected: viewModel.selectedFilter == filter
                                ) {
                                    viewModel.selectedFilter = filter
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial)
                
                // Summary banner
                if viewModel.hasActiveIssues {
                    StatusSummaryBanner(
                        outageCount: viewModel.outageCount,
                        blockedRoadCount: viewModel.blockedRoadCount
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
                
                Spacer()
                
                // Refresh button - floating on the side
                HStack {
                    Spacer()
                    Button {
                        Task {
                            await viewModel.manualRefresh()
                        }
                    } label: {
                        Image(systemName: viewModel.refreshCoolingDown ? "clock" : "arrow.clockwise")
                            .font(.title3)
                            .foregroundStyle(viewModel.refreshCoolingDown ? .secondary : .primary)
                            .frame(width: 44, height: 44)
                            .background(.regularMaterial)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }
                    .disabled(viewModel.refreshCoolingDown)
                    .padding(.trailing, 16)
                    .padding(.top, 8)
                }
                
                Spacer()
                
                // Report detail card (if selected)
                if let report = viewModel.selectedReport {
                    ReportDetailCard(
                        report: report,
                        onVerify: { await viewModel.verifyReport(report) },
                        onDispute: { await viewModel.disputeReport(report) },
                        onRoadCleared: roadClearedAction(for: report),
                        onPowerRestored: powerRestoredAction(for: report),
                        onRoadNeedsPlowing: roadNeedsPlowingAction(for: report),
                        onDismiss: { viewModel.selectedReport = nil },
                        onDelete: { await viewModel.deleteOwnReport(report) as Bool }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 60) // Space for tab bar
                    .onAppear { isReportCardVisible = true }
                    .onDisappear { isReportCardVisible = false }
                }
            }
        }
        .task {
            await viewModel.loadReports()
        }
        .onChange(of: AuthenticationManager.shared.userProfile?.communityID) { _, newCommunityID in
            // Re-attach the listener once userProfile arrives — the initial .task can fire before auth finishes
            if newCommunityID != nil {
                Task { await viewModel.loadReports() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .reportSubmitted)) { _ in
            // Always reload after submitting — in Firebase mode the Firestore listener
            // can lag on the author's own device due to local index cache, so force a
            // re-attach to guarantee the new report appears immediately for the author.
            Task { await viewModel.loadReports() }
        }
        .onDisappear {
            // Keep the listener alive while the app is running (user just switched tabs);
            // only stop it if you need to free resources on sign-out (handled in auth flow).
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
        .onChange(of: navigationCoordinator.selectedReport) { _, newReport in
            if let report = newReport {
                // Zoom to the report location
                viewModel.focusOnReport(report)
                // Select it to show the detail card
                viewModel.selectedReport = report
            }
        }
    }

    /// Returns a road-cleared callback only for roadBlocked reports; nil otherwise.
    private func roadClearedAction(for report: Report) -> (() async -> Void)? {
        guard report.category == .roadBlocked else { return nil }
        return { await viewModel.markRoadCleared(report) }
    }

    /// Returns a power-restored callback only for powerOut reports; nil otherwise.
    private func powerRestoredAction(for report: Report) -> (() async -> Void)? {
        guard report.category == .powerOut else { return nil }
        return { await viewModel.markPowerRestored(report) }
    }

    /// Returns a road-needs-plowing callback only for roadPlowed reports; nil otherwise.
    private func roadNeedsPlowingAction(for report: Report) -> (() async -> Void)? {
        guard report.category == .roadPlowed else { return nil }
        return { await viewModel.markRoadNeedsPlowing(report) }
    }
}

// MARK: - Report Marker

struct ReportMarker: View {
    let report: Report
    let isSelected: Bool
    
    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 0.8
    
    var body: some View {
        ZStack {
            // Pulsing rings (only when selected) - BEHIND the marker
            if isSelected {
                // First pulse ring
                Circle()
                    .strokeBorder(markerColor, lineWidth: 3)
                    .frame(width: 40, height: 40) // Same size as marker
                    .scaleEffect(pulseScale)
                    .opacity(pulseOpacity)
                
                // Second pulse ring (slightly delayed effect)
                Circle()
                    .strokeBorder(markerColor, lineWidth: 2)
                    .frame(width: 40, height: 40)
                    .scaleEffect(pulseScale * 0.85)
                    .opacity(pulseOpacity * 0.6)
            }
            
            // Main marker circle - ALWAYS the same size
            Circle()
                .fill(markerColor)
                .frame(width: 40, height: 40)
                .shadow(radius: isSelected ? 4 : 2)
            
            // Icon - ALWAYS the same size
            Image(systemName: report.category.iconName)
                .font(.system(size: 18))
                .foregroundStyle(.white)
        }
        .onChange(of: isSelected) { _, selected in
            if selected {
                startPulsing()
            } else {
                stopPulsing()
            }
        }
        .onAppear {
            if isSelected {
                startPulsing()
            }
        }
    }
    
    private var markerColor: Color {
        if report.isExpired {
            return .gray
        }
        
        // Color based on confidence and category
        let baseColor: Color = report.category.isPositiveStatus ? .green : .red
        
        if report.confidenceLevel < 0.3 {
            return .orange // Disputed
        }
        
        return baseColor
    }
    
    private func startPulsing() {
        // Reset to starting state
        pulseScale = 1.0
        pulseOpacity = 0.8
        
        // Create continuous pulsing animation
        withAnimation(
            .easeOut(duration: 1.5)
            .repeatForever(autoreverses: false)
        ) {
            pulseScale = 2.5  // Expand to 2.5x the marker size
            pulseOpacity = 0.0
        }
    }
    
    private func stopPulsing() {
        withAnimation(.easeOut(duration: 0.3)) {
            pulseScale = 1.0
            pulseOpacity = 0.0
        }
    }
}

// MARK: - Road Status Marker

struct RoadStatusMarker: View {
    let road: Road
    let isSelected: Bool
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(road.status.color.opacity(0.3))
                .frame(width: isSelected ? 50 : 40, height: isSelected ? 50 : 40)
            
            // Icon
            Image(systemName: road.status.iconName)
                .font(.system(size: isSelected ? 22 : 18))
                .foregroundStyle(road.status.color)
        }
        .shadow(radius: isSelected ? 4 : 2)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Status Summary Banner

struct StatusSummaryBanner: View {
    let outageCount: Int
    let blockedRoadCount: Int
    
    var body: some View {
        HStack(spacing: 16) {
            if outageCount > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.subheadline)
                    Text("\(outageCount) active outage\(outageCount == 1 ? "" : "s")")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                }
            }
            
            if blockedRoadCount > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.octagon.fill")
                        .foregroundStyle(.red)
                        .font(.subheadline)
                    Text("\(blockedRoadCount) blocked road\(blockedRoadCount == 1 ? "" : "s")")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .cornerRadius(10)
        .shadow(radius: 2)
    }
}

#Preview {
    MainMapView(isReportCardVisible: .constant(false))
}
