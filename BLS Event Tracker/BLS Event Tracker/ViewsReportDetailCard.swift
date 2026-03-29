//
//  ReportDetailCard.swift
//  Community Status App
//
//  Detail card shown when a report is selected
//

import SwiftUI

struct ReportDetailCard: View {
    let report: Report
    let onVerify: () async -> Void
    let onDispute: () async -> Void
    /// Called when the user indicates the road has since been cleared.
    /// Only shown for roadBlocked reports. Submits a counter road_plowed report
    /// without penalising the original author's reputation.
    let onRoadCleared: (() async -> Void)?
    /// Called when the user indicates power has been restored.
    /// Only shown for powerOut reports. Marks the report expired
    /// without penalising the original author's reputation.
    let onPowerRestored: (() async -> Void)?
    let onDismiss: () -> Void
    /// Called when the author taps "Delete Report". Nil hides the button.
    /// Returns true if the delete succeeded (card should dismiss), false if blocked (card stays open).
    let onDelete: (() async -> Bool)?
    
    @StateObject private var authManager = AuthenticationManager.shared
    @State private var isProcessing = false
    @State private var confirmationMessage: String? = nil
    @State private var deleteErrorMessage: String? = nil
    @State private var showReportIssueSheet = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // TOP: Icon + Title, Location, Dismiss Button
            HStack(alignment: .top) {
                Image(systemName: report.category.iconName)
                    .font(.title2)
                    .foregroundStyle(statusColor)
                    .frame(width: 32, height: 32)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(report.category.displayName)
                        .font(.headline)
                    
                    Text(report.address)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
            
            Divider()
            
            // MIDDLE: Note and Time
            VStack(alignment: .leading, spacing: 8) {
                if let note = report.note, !note.isEmpty {
                    Text(note)
                        .font(.body)
                        .foregroundStyle(.primary)
                }
                
                HStack(spacing: 8) {
                    Label("Updated \(timeAgoString)", systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    // Staleness warning for old reports
                    if report.isPossiblyOutdated {
                        HStack(spacing: 3) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                            Text("Possibly Outdated")
                                .font(.caption2.weight(.medium))
                        }
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(6)
                    }
                    
                    Spacer()
                    
                    if let displayName = report.authorDisplayName {
                        Label(displayName, systemImage: "person")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Divider()
            
            // BOTTOM: Votes + Status
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 20) {
                    // Confirmation count
                    HStack(spacing: 4) {
                        Image(systemName: "hand.thumbsup.fill")
                            .foregroundStyle(.green)
                        Text("\(report.verificationCount)")
                            .font(.subheadline.bold())
                    }
                    
                    // Dispute count
                    HStack(spacing: 4) {
                        Image(systemName: "hand.thumbsdown.fill")
                            .foregroundStyle(.red)
                        Text("\(report.disputeCount)")
                            .font(.subheadline.bold())
                    }
                    
                    Spacer()
                    
                    // Status badge
                    ConfidenceTierBadge(tier: report.confidenceTier)
                }
                
                // Own-report: show delete option instead of vote buttons (locked once externally confirmed)
                if canDeleteReport, let onDelete {
                    VStack(spacing: 8) {
                        Button {
                            Task {
                                isProcessing = true
                                deleteErrorMessage = nil
                                let succeeded = await onDelete()
                                isProcessing = false
                                if succeeded {
                                    onDismiss()
                                } else {
                                    deleteErrorMessage = "Cannot delete — this report has already been corroborated by another user."
                                }
                            }
                        } label: {
                            Label("Delete My Report", systemImage: "trash")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.red.opacity(0.12))
                                .foregroundStyle(.red)
                                .cornerRadius(10)
                        }
                        .disabled(isProcessing)

                        if let errorMsg = deleteErrorMessage {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.caption)
                                Text(errorMsg)
                                    .font(.caption)
                                    .multilineTextAlignment(.leading)
                            }
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                        }
                    }
                }

                // Action buttons (only for general users and above, never for the report's author)
                if authManager.userProfile?.role.canSubmitReports == true && !isOwnReport {
                    if let message = confirmationMessage {
                        // Confirmation message shown after voting
                        HStack(spacing: 8) {
                            Image(systemName: message.contains("Confirmed") ? "hand.thumbsup.fill" : (message.contains("Cleared") || message.contains("Restored") ? "checkmark.circle.fill" : "hand.thumbsdown.fill"))
                                .foregroundStyle(message.contains("Confirmed") ? .green : (message.contains("Cleared") || message.contains("Restored") ? .blue : .red))
                            Text(message)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(message.contains("Confirmed") ? Color.green.opacity(0.12) : (message.contains("Cleared") || message.contains("Restored") ? Color.blue.opacity(0.12) : Color.red.opacity(0.12)))
                        .cornerRadius(10)
                    } else if report.category == .roadBlocked, let onRoadCleared {
                        // Road blocked: 3-button layout
                        // Row 1: Confirm (still blocked)
                        Button {
                            Task {
                                isProcessing = true
                                await onVerify()
                                isProcessing = false
                                confirmationMessage = "Confirmed — Still Blocked (Thank you!)"
                                try? await Task.sleep(for: .seconds(2))
                                onDismiss()
                            }
                        } label: {
                            Label("Still Blocked", systemImage: "hand.thumbsup")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(userHasVerified ? Color.green.opacity(0.2) : Color.green)
                                .foregroundStyle(userHasVerified ? .green : .white)
                                .cornerRadius(10)
                        }
                        .disabled(isProcessing || userHasVerified)

                        // Row 2: Road has been cleared (situation changed, no rep penalty)
                        Button {
                            Task {
                                isProcessing = true
                                await onRoadCleared()
                                isProcessing = false
                                confirmationMessage = "Road Cleared — Thanks for the update!"
                                try? await Task.sleep(for: .seconds(2))
                                onDismiss()
                            }
                        } label: {
                            Label("Road Has Been Cleared", systemImage: "checkmark.circle")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.blue)
                                .foregroundStyle(.white)
                                .cornerRadius(10)
                        }
                        .disabled(isProcessing)

                        // Row 3: Was never accurate (rep penalty applies)
                        Button {
                            Task {
                                isProcessing = true
                                await onDispute()
                                isProcessing = false
                                confirmationMessage = "Marked Inaccurate (Thank you!)"
                                try? await Task.sleep(for: .seconds(2))
                                onDismiss()
                            }
                        } label: {
                            Label("Was Never Blocked", systemImage: "hand.thumbsdown")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(userHasDisputed ? Color.red.opacity(0.2) : Color.red)
                                .foregroundStyle(userHasDisputed ? .red : .white)
                                .cornerRadius(10)
                        }
                        .disabled(isProcessing || userHasDisputed)
                    } else if report.category == .powerOut, let onPowerRestored {
                        // Power out: 3-button layout
                        // Row 1: Still out (confirm the report)
                        Button {
                            Task {
                                isProcessing = true
                                await onVerify()
                                isProcessing = false
                                confirmationMessage = "Confirmed — Still Out (Thank you!)"
                                try? await Task.sleep(for: .seconds(2))
                                onDismiss()
                            }
                        } label: {
                            Label("Still Out", systemImage: "hand.thumbsup")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(userHasVerified ? Color.green.opacity(0.2) : Color.green)
                                .foregroundStyle(userHasVerified ? .green : .white)
                                .cornerRadius(10)
                        }
                        .disabled(isProcessing || userHasVerified)

                        // Row 2: Power has been restored (situation changed, no rep penalty)
                        Button {
                            Task {
                                isProcessing = true
                                await onPowerRestored()
                                isProcessing = false
                                confirmationMessage = "Power Restored — Thanks for the update!"
                                try? await Task.sleep(for: .seconds(2))
                                onDismiss()
                            }
                        } label: {
                            Label("Power Has Been Restored", systemImage: "bolt.circle")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.blue)
                                .foregroundStyle(.white)
                                .cornerRadius(10)
                        }
                        .disabled(isProcessing)

                        // Row 3: Was never accurate (rep penalty applies)
                        Button {
                            Task {
                                isProcessing = true
                                await onDispute()
                                isProcessing = false
                                confirmationMessage = "Marked Inaccurate (Thank you!)"
                                try? await Task.sleep(for: .seconds(2))
                                onDismiss()
                            }
                        } label: {
                            Label("Was Never Out", systemImage: "hand.thumbsdown")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(userHasDisputed ? Color.red.opacity(0.2) : Color.red)
                                .foregroundStyle(userHasDisputed ? .red : .white)
                                .cornerRadius(10)
                        }
                        .disabled(isProcessing || userHasDisputed)
                    } else if report.category == .roadPlowed {
                        // Road Plowed: situational labels matching Power/Road Blocked style
                        HStack(spacing: 12) {
                            Button {
                                Task {
                                    isProcessing = true
                                    await onVerify()
                                    isProcessing = false
                                    confirmationMessage = "Confirmed — Still Plowed (Thank you!)"
                                    try? await Task.sleep(for: .seconds(2))
                                    onDismiss()
                                }
                            } label: {
                                Label("Still Plowed", systemImage: "hand.thumbsup")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(userHasVerified ? Color.green.opacity(0.2) : Color.green)
                                    .foregroundStyle(userHasVerified ? .green : .white)
                                    .cornerRadius(10)
                            }
                            .disabled(isProcessing || userHasVerified)

                            Button {
                                Task {
                                    isProcessing = true
                                    await onDispute()
                                    isProcessing = false
                                    confirmationMessage = "Marked Inaccurate (Thank you!)"
                                    try? await Task.sleep(for: .seconds(2))
                                    onDismiss()
                                }
                            } label: {
                                Label("Not Plowed", systemImage: "hand.thumbsdown")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(userHasDisputed ? Color.red.opacity(0.2) : Color.red)
                                    .foregroundStyle(userHasDisputed ? .red : .white)
                                    .cornerRadius(10)
                            }
                            .disabled(isProcessing || userHasDisputed)
                        }
                    } else {
                        // All other reports: standard 2-button layout
                        HStack(spacing: 12) {
                            Button {
                                Task {
                                    isProcessing = true
                                    await onVerify()
                                    isProcessing = false
                                    confirmationMessage = "Confirmed (Thank you!)"
                                    try? await Task.sleep(for: .seconds(2))
                                    onDismiss()
                                }
                            } label: {
                                Label("Confirm", systemImage: "hand.thumbsup")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(userHasVerified ? Color.green.opacity(0.2) : Color.green)
                                    .foregroundStyle(userHasVerified ? .green : .white)
                                    .cornerRadius(10)
                            }
                            .disabled(isProcessing || userHasVerified)

                            Button {
                                Task {
                                    isProcessing = true
                                    await onDispute()
                                    isProcessing = false
                                    confirmationMessage = "Marked Inaccurate (Thank you!)"
                                    try? await Task.sleep(for: .seconds(2))
                                    onDismiss()
                                }
                            } label: {
                                Label("Not Accurate", systemImage: "hand.thumbsdown")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(userHasDisputed ? Color.red.opacity(0.2) : Color.red)
                                    .foregroundStyle(userHasDisputed ? .red : .white)
                                    .cornerRadius(10)
                            }
                            .disabled(isProcessing || userHasDisputed)
                        }
                    }
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
            }
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(16)
        .shadow(radius: 8)
        .padding()
        .sheet(isPresented: $showReportIssueSheet) {
            ReportIssueSheet(report: report)
        }
    }
    
    private var statusColor: Color {
        report.category.isPositiveStatus ? .green : .red
    }
    
    private var timeAgoString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: report.createdAt, relativeTo: Date())
    }
    
    private var isOwnReport: Bool {
        guard let userID = authManager.user?.uid else { return false }
        return report.authorID == userID
    }

    /// Delete is only available to the author, and only while the report has no external confirmations.
    /// Once another user has confirmed it the report is considered community-validated and locked.
    private var canDeleteReport: Bool {
        isOwnReport && report.verificationCount == 0
    }

    private var userHasVerified: Bool {
        guard let userID = authManager.user?.uid else { return false }
        return report.verifiedByUserIDs.contains(userID)
    }

    private var userHasDisputed: Bool {
        guard let userID = authManager.user?.uid else { return false }
        return report.disputedByUserIDs.contains(userID)
    }
}

// MARK: - Report Issue Sheet

struct ReportIssueSheet: View {
    let report: Report
    @Environment(\.dismiss) private var dismiss
    @State private var selectedReason = IssueReason.inaccurate
    @State private var note = ""
    @State private var isSubmitting = false
    @State private var submitted = false
    @State private var submitError: String? = nil

    enum IssueReason: String, CaseIterable {
        case inaccurate = "Inaccurate information"
        case duplicate = "Spam or duplicate"
        case inappropriate = "Inappropriate content"
        case other = "Other"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Reason") {
                    Picker("Reason", selection: $selectedReason) {
                        ForEach(IssueReason.allCases, id: \.self) { reason in
                            Text(reason.rawValue).tag(reason)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section("Additional details (optional)") {
                    TextField("Add a note…", text: $note, axis: .vertical)
                        .lineLimit(3...5)
                }

                if let error = submitError {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Report Issue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        Task { await submit() }
                    }
                    .disabled(isSubmitting || submitted)
                }
            }
            .overlay {
                if submitted {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.green)
                        Text("Report Submitted")
                            .font(.headline)
                        Text("Thank you for helping keep the community accurate.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.regularMaterial)
                }
            }
        }
    }

    @MainActor
    private func submit() async {
        guard let userID = AuthenticationManager.shared.user?.uid else {
            submitError = "User not signed in. Please try again."
            return
        }
        isSubmitting = true
        submitError = nil
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try await AppDataService.shared.submitIssueReport(
                reportID: report.id,
                communityID: report.communityID,
                category: report.category.rawValue,
                address: report.address,
                authorID: report.authorID,
                reportedByUserID: userID,
                reason: selectedReason.rawValue,
                note: trimmedNote.isEmpty ? nil : trimmedNote
            )
            isSubmitting = false
            submitted = true
            try? await Task.sleep(for: .seconds(1.5))
            dismiss()
        } catch {
            isSubmitting = false
            submitError = "Failed to submit: \(error.localizedDescription)"
            print("⚠️ ReportIssueSheet submit error: \(error)")
        }
    }
}

// MARK: - Confidence Tier Badge

struct ConfidenceTierBadge: View {
    let tier: ConfidenceTier
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: tier.iconName)
                .font(.caption)
            
            Text(tier.displayName)
                .font(.caption.bold())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tier.color.opacity(0.15))
        .foregroundStyle(tier.color)
        .cornerRadius(8)
    }
}
