//
//  ProfileView.swift
//  Community Status App
//
//  User profile and settings
//

import SwiftUI
import Combine

// MARK: - Announcement Template

struct AnnouncementTemplate: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var message: String
    /// Built-in templates (like "Standard") cannot be deleted.
    var isBuiltIn: Bool = false
}

// MARK: - Template Store

class AnnouncementTemplateStore: ObservableObject {
    static let shared = AnnouncementTemplateStore()
    private let key = "announcementTemplates"

    /// The fixed ID for the built-in standard template so it is stable across launches.
    static let standardTemplateID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    @Published var templates: [AnnouncementTemplate] = []

    /// The always-present built-in "Standard" template.
    var standardTemplate: AnnouncementTemplate {
        AnnouncementTemplate(
            id: Self.standardTemplateID,
            name: "Standard",
            message: AnnouncementManager.standardMessage,
            isBuiltIn: true
        )
    }

    /// All templates with the Standard template pinned first.
    var allTemplates: [AnnouncementTemplate] {
        [standardTemplate] + templates
    }

    init() {
        load()
    }

    func save(name: String, message: String) {
        let template = AnnouncementTemplate(name: name, message: message)
        templates.append(template)
        persist()
    }

    func delete(_ template: AnnouncementTemplate) {
        guard !template.isBuiltIn else { return }
        templates.removeAll { $0.id == template.id }
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(templates) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let saved = try? JSONDecoder().decode([AnnouncementTemplate].self, from: data) else { return }
        templates = saved
    }
}

// MARK: - Profile View

struct ProfileView: View {
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var announcementManager = AnnouncementManager.shared
    @StateObject private var templateStore = AnnouncementTemplateStore.shared
    @State private var showSignOutConfirmation = false
    @State private var showDeleteAccountConfirmation = false
    @State private var deleteAccountInProgress = false
    @State private var deleteAccountError: String? = nil

    // Admin - announcement
    @State private var announcementDraft = ""
    @State private var announcementSaving = false
    @State private var announcementSaved = false
    @FocusState private var announcementFocused: Bool

    // Admin - templates
    @State private var showSaveTemplateAlert = false
    @State private var templateNameDraft = ""

    // Admin - clear reports
    @State private var clearOption: ClearReportsOption? = nil
    @State private var showClearConfirmation = false
    @State private var clearInProgress = false
    @State private var clearResult: String? = nil

    var body: some View {
        NavigationStack {
            List {
                // User info
                Section {
                    if let profile = authManager.userProfile {
                        LabeledContent("Name", value: profile.displayName ?? "Not set")
                        LabeledContent("Email", value: profile.email ?? "Not set")
                        LabeledContent("Role", value: profile.role.displayName)
                    }
                }

                // Stats + Reputation
                Section("Activity") {
                    if let profile = authManager.userProfile {
                        LabeledContent("Reports Submitted", value: "\(profile.reportCount)")
                        LabeledContent("Verifications Given", value: "\(profile.verificationCount)")
                        ReputationRow(profile: profile)
                    }
                }

                // Moderator controls
                if authManager.userProfile?.role.canModerateReports == true {
                    Section(header: Label("Moderation", systemImage: "shield")) {
                        NavigationLink {
                            ModerateReportsView()
                        } label: {
                            Label("Manage Reports", systemImage: "list.bullet.clipboard")
                        }
                    }
                }

                // Admin-only controls
                if authManager.userProfile?.role.canManageUsers == true {
                    Section(header: Label("Admin", systemImage: "crown")) {
                        NavigationLink {
                            AdminLeaderboardView()
                        } label: {
                            Label("Member Reputation", systemImage: "chart.bar.xaxis")
                        }
                    }

                    // Announcement editor
                    Section(header: Label("Community Announcement", systemImage: "megaphone")) {
                        VStack(alignment: .leading, spacing: 8) {
                            // Last Updated header
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                                Text("Last Updated: \(announcementManager.lastUpdated.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.bottom, 2)

                            TextEditor(text: $announcementDraft)
                                .frame(minHeight: 80)
                                .font(.body)
                                .focused($announcementFocused)

                            HStack {
                                // Templates menu
                                Menu {
                                    // Load a template (Standard is always first)
                                    Section("Load Template") {
                                        ForEach(templateStore.allTemplates) { template in
                                            Button {
                                                announcementDraft = template.message
                                            } label: {
                                                if template.isBuiltIn {
                                                    Label(template.name, systemImage: "arrow.uturn.backward")
                                                } else {
                                                    Text(template.name)
                                                }
                                            }
                                        }
                                    }
                                    // Delete custom templates
                                    let deletable = templateStore.templates
                                    if !deletable.isEmpty {
                                        Section {
                                            ForEach(deletable) { template in
                                                Button(role: .destructive) {
                                                    templateStore.delete(template)
                                                } label: {
                                                    Label("Delete \"\(template.name)\"", systemImage: "trash")
                                                }
                                            }
                                        }
                                    }
                                    // Save current draft as a new template
                                    Button {
                                        templateNameDraft = ""
                                        showSaveTemplateAlert = true
                                    } label: {
                                        Label("Save Current as Template…", systemImage: "square.and.arrow.down")
                                    }
                                    .disabled(announcementDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if announcementSaved {
                                    Label("Saved", systemImage: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                        .font(.subheadline)
                                } else {
                                    Button {
                                        announcementFocused = false
                                        Task {
                                            announcementSaving = true
                                            try? await announcementManager.updateAnnouncement(message: announcementDraft)
                                            announcementSaving = false
                                            announcementSaved = true
                                            try? await Task.sleep(for: .seconds(2))
                                            announcementSaved = false
                                        }
                                    } label: {
                                        if announcementSaving {
                                            ProgressView()
                                        } else {
                                            Text("Save")
                                                .font(.subheadline.weight(.semibold))
                                        }
                                    }
                                    .disabled(announcementSaving || announcementDraft == announcementManager.message)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    // Clear reports
                    Section(header: Label("Incident Management", systemImage: "trash")) {
                        if let result = clearResult {
                            Label(result, systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.subheadline)
                        } else {
                            Picker("Clear reports", selection: $clearOption) {
                                Text("Select a time range…").tag(Optional<ClearReportsOption>.none)
                                ForEach(ClearReportsOption.allCases) { option in
                                    Text(option.label).tag(Optional(option))
                                }
                            }
                            .pickerStyle(.menu)
                            .font(.footnote)
                            .frame(maxWidth: .infinity, alignment: .leading)

                            Button(role: clearOption == .all ? .destructive : .none) {
                                showClearConfirmation = true
                            } label: {
                                if clearInProgress {
                                    HStack {
                                        ProgressView().tint(.red)
                                        Text("Clearing…")
                                    }
                                } else {
                                    Text("Clear Reports")
                                        .frame(maxWidth: .infinity, alignment: .center)
                                }
                            }
                            .disabled(clearOption == nil || clearInProgress)
                            .alert(
                                clearOption?.confirmationTitle ?? "Clear Reports",
                                isPresented: $showClearConfirmation
                            ) {
                                Button("Delete", role: .destructive) {
                                    guard let option = clearOption,
                                          let communityID = authManager.userProfile?.communityID else { return }
                                    Task {
                                        clearInProgress = true
                                        do {
                                            switch option {
                                            case .all:
                                                try await AppDataService.shared.deleteAllReports(in: communityID)
                                            default:
                                                if let cutoff = option.cutoffDate {
                                                    try await AppDataService.shared.deleteReports(in: communityID, olderThan: cutoff)
                                                }
                                            }
                                            clearResult = option.successMessage
                                            try? await Task.sleep(for: .seconds(3))
                                            clearResult = nil
                                        } catch {
                                            clearResult = "Error: \(error.localizedDescription)"
                                        }
                                        clearInProgress = false
                                        clearOption = nil
                                    }
                                }
                                Button("Cancel", role: .cancel) {}
                            } message: {
                                Text(clearOption?.confirmationBody ?? "")
                            }
                        }
                    }
                }

                // App version + legal
                Section {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                    LabeledContent("Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—")
                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }
                }

                // Sign out / account removal
                Section {
                    Button(role: .destructive) {
                        showSignOutConfirmation = true
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }

                    if deleteAccountInProgress {
                        HStack {
                            ProgressView()
                            Text("Deleting account…")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Button(role: .destructive) {
                            showDeleteAccountConfirmation = true
                        } label: {
                            Label("Delete Account", systemImage: "person.crop.circle.badge.minus")
                        }
                    }

                    if let error = deleteAccountError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await authManager.refreshUserProfile()
                announcementDraft = announcementManager.message
                await announcementManager.loadLatestAnnouncement()
                announcementDraft = announcementManager.message
            }
            .alert("Save as Template", isPresented: $showSaveTemplateAlert) {
                TextField("Template name", text: $templateNameDraft)
                Button("Save") {
                    let name = templateNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !name.isEmpty {
                        templateStore.save(name: name, message: announcementDraft)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Enter a name for this announcement template.")
            }
            .confirmationDialog("Sign Out", isPresented: $showSignOutConfirmation) {
                Button("Sign Out", role: .destructive) {
                    do {
                        try authManager.signOut()
                    } catch {
                        print("Sign out error: \(error)")
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .alert("Delete Account?", isPresented: $showDeleteAccountConfirmation) {
                Button("Delete My Account", role: .destructive) {
                    Task {
                        deleteAccountInProgress = true
                        deleteAccountError = nil
                        do {
                            try await authManager.deleteAccount()
                        } catch {
                            deleteAccountError = error.localizedDescription
                        }
                        deleteAccountInProgress = false
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete your account and profile data. Submitted reports may remain anonymized. This cannot be undone.")
            }
        }
    }
}

// MARK: - Clear Reports Option

enum ClearReportsOption: String, CaseIterable, Identifiable {
    case twelveHours = "12hr"
    case twentyFourHours = "24hr"
    case fortyEightHours = "48hr"
    case oneWeek = "1wk"
    case all = "all"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .twelveHours:     return "Older than 12 hrs"
        case .twentyFourHours: return "Older than 24 hrs"
        case .fortyEightHours: return "Older than 48 hrs"
        case .oneWeek:         return "Older than 1 week"
        case .all:             return "Clear ALL reports"
        }
    }

    var cutoffDate: Date? {
        let now = Date()
        switch self {
        case .twelveHours:     return now.addingTimeInterval(-12 * 3600)
        case .twentyFourHours: return now.addingTimeInterval(-24 * 3600)
        case .fortyEightHours: return now.addingTimeInterval(-48 * 3600)
        case .oneWeek:         return now.addingTimeInterval(-7 * 24 * 3600)
        case .all:             return nil
        }
    }

    var confirmationTitle: String {
        switch self {
        case .all: return "Clear ALL Reports?"
        default:   return "Clear Old Reports?"
        }
    }

    var confirmationBody: String {
        switch self {
        case .twelveHours:     return "This will permanently delete all reports older than 12 hours."
        case .twentyFourHours: return "This will permanently delete all reports older than 24 hours."
        case .fortyEightHours: return "This will permanently delete all reports older than 48 hours."
        case .oneWeek:         return "This will permanently delete all reports older than 1 week."
        case .all:             return "This will permanently delete every report in the community. This cannot be undone."
        }
    }

    var successMessage: String {
        switch self {
        case .all: return "All reports deleted"
        default:   return "Old reports cleared"
        }
    }
}

// MARK: - Reputation Row

struct ReputationRow: View {
    let profile: UserProfile

    private var accuracyText: String {
        guard profile.reportCount > 0 else { return "No reports yet" }
        let pct = Int((profile.accuracyPercent * 100).rounded())
        // Use confirmedReportPoints as the numerator since that's what drives the percentage.
        // Format as integer when it's a whole number, one decimal otherwise (e.g. 27.5).
        let pts = profile.confirmedReportPoints
        let ptsString = pts.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(pts))" : String(format: "%.1f", pts)
        return "\(pct)% (\(ptsString) of \(profile.reportCount) confirmed)"
    }

    private var trustLabel: String {
        switch profile.weightedTrust {
        case 0.8...: return "Highly Trusted"
        case 0.5..<0.8: return "Trusted"
        case 0.2..<0.5: return "Building Reputation"
        default: return "New Reporter"
        }
    }

    private var trustColor: Color {
        switch profile.weightedTrust {
        case 0.8...: return .green
        case 0.5..<0.8: return .blue
        case 0.2..<0.5: return .orange
        default: return .secondary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Standing")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(trustLabel)
                    .foregroundStyle(trustColor)
                    .fontWeight(.semibold)
            }

            HStack {
                Text("Accuracy")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(accuracyText)
                    .foregroundStyle(.primary)
            }

            if profile.reportCount > 0 {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 6)
                        Capsule()
                            .fill(trustColor)
                            .frame(width: geo.size.width * profile.weightedTrust, height: 6)
                    }
                }
                .frame(height: 6)
                .padding(.top, 2)
            }
        }
        .font(.subheadline)
        .padding(.vertical, 4)
    }
}

// MARK: - Privacy Policy View

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Last updated: March 28, 2026")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("BLS Event Tracker (\"the App\") is a community-driven tool for reporting local conditions such as power outages and road status. This Privacy Policy explains what information we collect and how it is used.")
                    .font(.body)

                Group {
                    PolicySection(title: "1. Information We Collect") {
                        Text("We collect only the information necessary to operate the App:")
                        PolicyBullet(heading: "Account Information", detail: "Email address (for login and account management)")
                        PolicyBullet(heading: "User-Generated Content", detail: "Reports you submit (e.g., road status, power outages); optional photos if provided")
                        PolicyBullet(heading: "Usage Data", detail: "Basic app usage and interaction data (for improving the App)")
                    }

                    PolicySection(title: "2. How We Use Information") {
                        Text("We use collected information to:")
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach([
                                "Provide and operate the App",
                                "Display community reports and map data",
                                "Maintain and improve data accuracy (including reputation systems)",
                                "Communicate important updates if needed"
                            ], id: \.self) { item in
                                Text("• \(item)")
                            }
                        }
                        .font(.body)
                    }

                    PolicySection(title: "3. Data Sharing") {
                        Text("We do not sell your personal data.")
                        Text("We may share data:")
                        VStack(alignment: .leading, spacing: 4) {
                            Text("• With service providers (e.g., Firebase) to operate the App")
                            Text("• As required by law")
                        }
                        .font(.body)
                        Text("User-submitted reports may be visible to other users of the App.")
                    }

                    PolicySection(title: "4. Data Storage and Security") {
                        Text("Data is stored using third-party services (e.g., Firebase). We take reasonable steps to protect your information, but no system is completely secure.")
                    }

                    PolicySection(title: "5. Your Choices") {
                        Text("You can:")
                        VStack(alignment: .leading, spacing: 4) {
                            Text("• Delete your account within the App")
                            Text("• Stop using the App at any time")
                        }
                        .font(.body)
                        Text("Deleting your account removes your personal account data. Some submitted reports may remain anonymized.")
                    }

                    PolicySection(title: "6. Children's Privacy") {
                        Text("The App is not intended for children under 13.")
                    }

                    PolicySection(title: "7. Changes to This Policy") {
                        Text("We may update this Privacy Policy from time to time. Updates will be posted within the App or at the provided URL.")
                    }

                    PolicySection(title: "8. Contact") {
                        Text("If you have questions, contact:")
                        Link("support", destination: URL(string: "mailto:akoniak@gmail.com")!)
                            .font(.body)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PolicySection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            content()
                .font(.body)
        }
    }
}

private struct PolicyBullet: View {
    let heading: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("• \(heading)")
                .fontWeight(.medium)
            Text("  \(detail)")
                .foregroundStyle(.secondary)
        }
        .font(.body)
    }
}

#Preview("Privacy Policy") {
    NavigationStack {
        PrivacyPolicyView()
    }
}

#Preview("Reputation Row - Trusted") {
    let profile = UserProfile(
        id: "preview",
        email: "test@example.com",
        displayName: "Jane Doe",
        communityID: "preview-community",
        role: .general,
        address: nil,
        phoneNumber: nil,
        createdAt: Date(),
        lastActiveAt: Date(),
        isActive: true,
        isBanned: false,
        banReason: nil,
        reportCount: 60,
        verificationCount: 12,
        confirmedReportCount: 50,
        confirmedReportPoints: 50.0
    )
    return List {
        Section("Activity") {
            LabeledContent("Reports Submitted", value: "\(profile.reportCount)")
            LabeledContent("Verifications Given", value: "\(profile.verificationCount)")
            ReputationRow(profile: profile)
        }
    }
}
#Preview("Reputation Row - New") {
    let profile = UserProfile(
        id: "preview",
        email: "test@example.com",
        displayName: "New User",
        communityID: "preview-community",
        role: .general,
        address: nil,
        phoneNumber: nil,
        createdAt: Date(),
        lastActiveAt: Date(),
        isActive: true,
        isBanned: false,
        banReason: nil,
        reportCount: 1,
        verificationCount: 0,
        confirmedReportCount: 1,
        confirmedReportPoints: 0.5
    )
    return List {
        Section("Activity") {
            LabeledContent("Reports Submitted", value: "\(profile.reportCount)")
            LabeledContent("Verifications Given", value: "\(profile.verificationCount)")
            ReputationRow(profile: profile)
        }
    }
}

