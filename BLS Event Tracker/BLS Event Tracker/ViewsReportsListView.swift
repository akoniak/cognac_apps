//
//  ReportsListView.swift
//  Community Status App
//
//  List view showing all community reports with sorting and filtering
//

import SwiftUI

enum ReportSortOption: String, CaseIterable {
    case mostRecent = "Most Recent"
    case oldest = "Oldest"
    case category = "By Category"
    case mostVerified = "Most Verified"
    
    var icon: String {
        switch self {
        case .mostRecent: return "clock.arrow.circlepath"
        case .oldest: return "clock"
        case .category: return "list.bullet"
        case .mostVerified: return "checkmark.circle"
        }
    }
}

enum ReportFilterOption: String, CaseIterable, Identifiable {
    case all = "All"
    case power = "Power"
    case roads = "Roads"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .power: return "bolt.fill"
        case .roads: return "road.lanes"
        }
    }
    
    func matches(category: ReportCategory) -> Bool {
        switch self {
        case .all: return true
        case .power: return category == .powerOut
        case .roads: return category == .roadPlowed || category == .roadBlocked
        }
    }
}

struct ReportsListView: View {
    @StateObject private var viewModel = ReportsListViewModel()
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @State private var showSortOptions = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with title and filters
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
                    
                    // Sort and count
                    HStack {
                        Text("\(viewModel.filteredReports.count) Reports")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        // Sort button
                        Button {
                            showSortOptions = true
                        } label: {
                            Label(viewModel.sortOption.rawValue, systemImage: viewModel.sortOption.icon)
                                .font(.subheadline)
                                .foregroundStyle(.blue)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                
                Divider()
                
                // Reports list
                if viewModel.filteredReports.isEmpty {
                    EmptyReportsView(filter: viewModel.selectedFilter)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(viewModel.filteredReports) { report in
                                ReportRowView(
                                    report: report,
                                    navigationCoordinator: navigationCoordinator,
                                    onDelete: { _ = await viewModel.deleteOwnReport(report) },
                                    onRoadCleared: { await viewModel.markRoadCleared(report) },
                                    onPowerRestored: { await viewModel.markPowerRestored(report) },
                                    onRoadNeedsPlowing: { await viewModel.markRoadNeedsPlowing(report) }
                                )
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                    .background(Color(.systemGroupedBackground))
                    .refreshable {
                        await viewModel.loadReports()
                    }
                }
            }
            .confirmationDialog("Sort Reports", isPresented: $showSortOptions) {
                ForEach(ReportSortOption.allCases, id: \.self) { option in
                    Button {
                        viewModel.sortOption = option
                    } label: {
                        Label(option.rawValue, systemImage: option.icon)
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .task {
                await viewModel.loadReports()
            }
            .onChange(of: AuthenticationManager.shared.userProfile?.communityID) { _, newCommunityID in
                if newCommunityID != nil {
                    Task { await viewModel.loadReports() }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .reportSubmitted)) { _ in
                // Listener picks up new reports automatically in Firebase mode;
                // in mock mode do a one-shot refresh.
                if useMockData {
                    Task { await viewModel.loadReports() }
                }
            }
        }
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let filter: ReportFilterOption
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: filter.icon)
                    .font(.caption)
                Text(filter.rawValue)
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color(.systemGray5))
            .foregroundStyle(isSelected ? .white : .primary)
            .cornerRadius(20)
        }
    }
}

// MARK: - Report Row

struct ReportRowView: View {
    let report: Report
    let navigationCoordinator: NavigationCoordinator
    let onDelete: (() async -> Void)?
    let onRoadCleared: () async -> Void
    let onPowerRestored: () async -> Void
    let onRoadNeedsPlowing: () async -> Void
    @State private var isExpanded = false
    @State private var isDeleting = false
    @State private var isUpdating = false
    @State private var confirmationMessage: String? = nil
    @State private var showReportIssueSheet = false
    @State private var now = Date()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Compact row (always visible) - THIS NEVER MOVES
            Button {
                withAnimation(.easeInOut(duration: 0.35)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    // Category icon
                    Image(systemName: report.category.iconName)
                        .font(.body)
                        .foregroundStyle(categoryColor)
                        .frame(width: 28, height: 28)
                        .background(categoryColor.opacity(0.15))
                        .cornerRadius(6)
                    
                    // Main info
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(report.category.displayName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            
                            // Indicators
                            HStack(spacing: 4) {
                                if hasNote {
                                    Image(systemName: "text.alignleft")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        
                        HStack(spacing: 6) {
                            Text(report.address)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            
                            Text("•")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Text(timeAgoString)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            // Staleness indicator for old reports
                            if report.isPossiblyOutdated {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                    
                    Spacer(minLength: 8)
                    
                    // Confidence and expand indicator
                    HStack(spacing: 8) {
                        CompactConfidenceBadge(report: report)
                        
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // Expanded details - ONLY THIS PART APPEARS/DISAPPEARS
            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    Divider()
                        .padding(.horizontal, 12)
                        .padding(.top, 2)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        // Note (if exists)
                        if let note = report.note, !note.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Label("Note", systemImage: "text.alignleft")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                
                                Text(note)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                            }
                        }
                        

                        // Full address
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(report.address)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        
                        // Stats
                        HStack(spacing: 20) {
                            HStack(spacing: 6) {
                                Image(systemName: "hand.thumbsup.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(.green)
                                Text("\(report.verificationCount) Verified")
                                    .font(.caption)
                            }
                            
                            HStack(spacing: 6) {
                                Image(systemName: "hand.thumbsdown.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(.red)
                                Text("\(report.disputeCount) Disputed")
                                    .font(.caption)
                            }
                            
                            Spacer()
                        }
                        .foregroundStyle(.secondary)
                        
                        // Author
                        if let author = report.authorDisplayName {
                            HStack(spacing: 4) {
                                Image(systemName: "person.fill")
                                    .font(.caption)
                                Text("Reported by \(author)")
                                    .font(.caption)
                            }
                            .foregroundStyle(.secondary)
                        }
                        
                        // Show on Map button
                        Button {
                            navigationCoordinator.showReportOnMap(report)
                        } label: {
                            HStack {
                                Image(systemName: "map.fill")
                                    .font(.subheadline)
                                Text("Show on Map")
                                    .font(.subheadline.weight(.medium))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .cornerRadius(8)
                        }

                        // Delete button — only visible to the author, locked once externally confirmed
                        if let onDelete, canDeleteReport {
                            Button {
                                Task {
                                    isDeleting = true
                                    await onDelete()
                                    isDeleting = false
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "trash")
                                        .font(.subheadline)
                                    Text("Delete My Report")
                                        .font(.subheadline.weight(.medium))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.red.opacity(0.12))
                                .foregroundStyle(.red)
                                .cornerRadius(8)
                            }
                            .disabled(isDeleting)
                        }

                        // Status-update buttons for the author — available any time regardless of grace period
                        if isOwnReport {
                            if let message = confirmationMessage {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.blue)
                                    Text(message)
                                        .font(.subheadline.weight(.medium))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.blue.opacity(0.12))
                                .cornerRadius(8)
                            } else if report.category == .roadBlocked {
                                Button {
                                    Task {
                                        isUpdating = true
                                        await onRoadCleared()
                                        isUpdating = false
                                        confirmationMessage = "Road Cleared — Thanks for the update!"
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: "checkmark.circle")
                                            .font(.subheadline)
                                        Text("Road Has Been Cleared")
                                            .font(.subheadline.weight(.medium))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color.blue)
                                    .foregroundStyle(.white)
                                    .cornerRadius(8)
                                }
                                .disabled(isUpdating)
                            } else if report.category == .powerOut {
                                Button {
                                    Task {
                                        isUpdating = true
                                        await onPowerRestored()
                                        isUpdating = false
                                        confirmationMessage = "Power Restored — Thanks for the update!"
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: "bolt.circle")
                                            .font(.subheadline)
                                        Text("Power Has Been Restored")
                                            .font(.subheadline.weight(.medium))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color.blue)
                                    .foregroundStyle(.white)
                                    .cornerRadius(8)
                                }
                                .disabled(isUpdating)
                            } else if report.category == .roadPlowed {
                                Button {
                                    Task {
                                        isUpdating = true
                                        await onRoadNeedsPlowing()
                                        isUpdating = false
                                        confirmationMessage = "Road Blocked — Thanks for the update!"
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: "xmark.circle")
                                            .font(.subheadline)
                                        Text("Road Blocked")
                                            .font(.subheadline.weight(.medium))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color.orange)
                                    .foregroundStyle(.white)
                                    .cornerRadius(8)
                                }
                                .disabled(isUpdating)
                            }
                        }

                        // Report Issue link — only shown for other users' reports (App Store UGC compliance)
                        if !isOwnReport {
                            Button {
                                showReportIssueSheet = true
                            } label: {
                                Text("Report Issue")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                            .sheet(isPresented: $showReportIssueSheet) {
                                ReportIssueSheet(report: report)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                    .padding(.bottom, 12)
                }
                .transition(.opacity.combined(with: .scale(scale: 1.0, anchor: .top)))
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        .task {
            // Tick every 30 s so canDeleteReport re-evaluates as the grace period elapses.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                now = Date()
            }
        }
    }
    
    private var categoryColor: Color {
        report.category.isPositiveStatus ? .green : .red
    }
    
    private var timeAgoString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: report.createdAt, relativeTo: Date())
    }
    
    private var hasNote: Bool {
        report.note != nil && !report.note!.isEmpty
    }

    private var isOwnReport: Bool {
        guard let userID = AuthenticationManager.shared.user?.uid else { return false }
        return report.authorID == userID
    }

    /// Delete is only available to the author, within the 10-minute grace period, and only while
    /// the report has no external confirmations. Uses `now` so the view reacts when time passes.
    private var canDeleteReport: Bool {
        isOwnReport && report.verificationCount == 0 && report.corroboratingSubmitterIDs.isEmpty && now.timeIntervalSince(report.createdAt) < 10 * 60
    }
}

// MARK: - Compact Confidence Badge

struct CompactConfidenceBadge: View {
    let report: Report
    
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: report.confidenceTier.iconName)
                .font(.caption2)
            Text(report.confidenceTier.displayName)
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(report.confidenceTier.color)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(report.confidenceTier.color.opacity(0.15))
        .cornerRadius(6)
    }
}

// MARK: - Confidence Badge (for expanded view)

struct ConfidenceBadge: View {
    let report: Report
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: report.confidenceTier.iconName)
                .font(.caption)
            Text(report.confidenceTier.displayName)
                .font(.caption.bold())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(report.confidenceTier.color.opacity(0.15))
        .foregroundStyle(report.confidenceTier.color)
        .cornerRadius(8)
    }
}

// MARK: - Empty State

struct EmptyReportsView: View {
    let filter: ReportFilterOption
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("No Reports")
                .font(.title2.bold())
            
            Text(emptyMessage)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxHeight: .infinity)
    }
    
    private var emptyMessage: String {
        if filter == .all {
            return "No reports yet. Be the first to submit a status update!"
        } else {
            return "No \(filter.rawValue.lowercased()) reports at this time."
        }
    }
}

// MARK: - Preview

#Preview {
    ReportsListView()
}
