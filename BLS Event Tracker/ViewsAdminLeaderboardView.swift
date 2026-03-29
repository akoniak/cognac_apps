//
//  AdminLeaderboardView.swift
//  BLS Event Tracker
//
//  Admin-only view showing all community members ranked by reputation.
//

import SwiftUI
import Observation

// MARK: - Sort Order

private enum SortOrder: String, CaseIterable, Identifiable {
    case weightedTrust   = "Trust Score"
    case reportCount     = "Reports"
    case accuracy        = "Accuracy"

    var id: String { rawValue }
}

// MARK: - View Model

@Observable
@MainActor
private class AdminLeaderboardViewModel {
    var users: [UserProfile] = []
    var isLoading = false
    var errorMessage: String?
    var sortOrder: SortOrder = .weightedTrust
    var searchText = ""

    private let dataService = AppDataService.shared
    private let authManager = AuthenticationManager.shared

    func load() async {
        guard let communityID = authManager.userProfile?.communityID else { return }
        isLoading = true
        errorMessage = nil
        do {
            users = try await dataService.fetchAllUsersInCommunity(communityID: communityID)
        } catch {
            errorMessage = "Failed to load users: \(error.localizedDescription)"
        }
        isLoading = false
    }

    var sortedUsers: [UserProfile] {
        let filtered: [UserProfile]
        if searchText.isEmpty {
            filtered = users
        } else {
            let q = searchText.lowercased()
            filtered = users.filter {
                ($0.displayName ?? "").lowercased().contains(q) ||
                ($0.email ?? "").lowercased().contains(q)
            }
        }

        switch sortOrder {
        case .weightedTrust:
            return filtered.sorted { $0.weightedTrust > $1.weightedTrust }
        case .reportCount:
            return filtered.sorted { $0.reportCount > $1.reportCount }
        case .accuracy:
            return filtered.sorted { $0.accuracyPercent > $1.accuracyPercent }
        }
    }
}

// MARK: - Main View

struct AdminLeaderboardView: View {
    @State private var viewModel = AdminLeaderboardViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading members…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.errorMessage {
                ContentUnavailableView(
                    "Could Not Load",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            } else if viewModel.sortedUsers.isEmpty {
                ContentUnavailableView.search
            } else {
                List {
                    ForEach(Array(viewModel.sortedUsers.enumerated()), id: \.element.id) { index, user in
                        LeaderboardRowView(rank: index + 1, user: user)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Member Reputation")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $viewModel.searchText, prompt: "Search members")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Picker("Sort by", selection: $viewModel.sortOrder) {
                        ForEach(SortOrder.allCases) { order in
                            Text(order.rawValue).tag(order)
                        }
                    }
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                Button {
                    Task { await viewModel.load() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
        }
        .task {
            await viewModel.load()
        }
    }
}

// MARK: - Row

private struct LeaderboardRowView: View {
    let rank: Int
    let user: UserProfile

    private var trustLabel: String {
        switch user.weightedTrust {
        case 0.8...: return "Highly Trusted"
        case 0.5..<0.8: return "Trusted"
        case 0.2..<0.5: return "Building"
        default: return "New"
        }
    }

    private var trustColor: Color {
        switch user.weightedTrust {
        case 0.8...: return .green
        case 0.5..<0.8: return .blue
        case 0.2..<0.5: return .orange
        default: return .secondary
        }
    }

    private var accuracyText: String {
        guard user.reportCount > 0 else { return "—" }
        return "\(Int((user.accuracyPercent * 100).rounded()))%"
    }

    var body: some View {
        HStack(spacing: 12) {
            // Rank number
            Text("\(rank)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .trailing)

            // Name + role + trust bar
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(user.displayName ?? user.email ?? "Unknown")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)

                    // Role badge (only for non-general roles)
                    if user.role != .general {
                        Text(user.role.displayName)
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.15))
                            .foregroundStyle(.purple)
                            .clipShape(Capsule())
                    }
                }

                // Trust progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.secondary.opacity(0.15))
                            .frame(height: 4)
                        Capsule()
                            .fill(trustColor)
                            .frame(width: geo.size.width * user.weightedTrust, height: 4)
                    }
                }
                .frame(height: 4)
            }

            Spacer(minLength: 0)

            // Stats column
            VStack(alignment: .trailing, spacing: 2) {
                Text(trustLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(trustColor)
                HStack(spacing: 4) {
                    Image(systemName: "doc.text")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(user.reportCount)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    Text(accuracyText)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
