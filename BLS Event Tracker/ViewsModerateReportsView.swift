//
//  ModerateReportsView.swift
//  Community Status App
//
//  Lets moderators and admins hide individual reports
//

import SwiftUI

struct ModerateReportsView: View {
    @StateObject private var authManager = AuthenticationManager.shared
    @State private var reports: [Report] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var reportToHide: Report? = nil
    @State private var showHideConfirmation = false
    @State private var hidingReportID: String? = nil

    var body: some View {
        List {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView("Loading reports…")
                    Spacer()
                }
                .listRowBackground(Color.clear)
            } else if reports.isEmpty {
                Text("No active reports.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(reports) { report in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: report.category.iconName)
                            .foregroundStyle(report.category.isPositiveStatus ? .green : .red)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(report.category.displayName)
                                .font(.subheadline.weight(.semibold))
                            Text(report.address)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Text(timeAgo(report.createdAt))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }

                        Spacer()

                        if hidingReportID == report.id {
                            ProgressView()
                        } else {
                            Button {
                                reportToHide = report
                                showHideConfirmation = true
                            } label: {
                                Image(systemName: "eye.slash")
                                    .foregroundStyle(.orange)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle("Manage Reports")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadReports() }
        .refreshable { await loadReports() }
        .confirmationDialog("Hide Report?", isPresented: $showHideConfirmation, titleVisibility: .visible) {
            Button("Hide Report", role: .destructive) {
                guard let report = reportToHide,
                      let reportID = report.id,
                      let moderatorID = authManager.user?.uid else { return }
                Task {
                    hidingReportID = reportID
                    try? await AppDataService.shared.hideReport(
                        reportID: reportID,
                        communityID: report.communityID,
                        moderatorID: moderatorID,
                        reason: "Hidden by moderator"
                    )
                    hidingReportID = nil
                    await loadReports()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This report will be hidden from the map. It can be reviewed in Firestore if needed.")
        }
        .overlay {
            if let error = errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .padding()
            }
        }
    }

    private func loadReports() async {
        guard let communityID = authManager.userProfile?.communityID else { return }
        isLoading = true
        errorMessage = nil
        do {
            reports = try await AppDataService.shared.fetchReports(for: communityID)
                .filter { !$0.isHidden }
                .sorted { $0.createdAt > $1.createdAt }
        } catch {
            errorMessage = "Failed to load: \(error.localizedDescription)"
        }
        isLoading = false
    }

    private func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
