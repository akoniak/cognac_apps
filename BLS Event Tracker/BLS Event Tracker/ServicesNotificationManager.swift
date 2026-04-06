//
//  NotificationManager.swift
//  BLS Event Tracker
//
//  Central notification service. Manages local notifications and app icon / tab-bar
//  badges for three event types:
//
//    1. Community announcements  → notification banner + account badge
//    2. Report updates (verify / dispute on the user's own reports)
//                                → notification banner + account badge
//    3. New reports from others  → activity badge only (no banner — would be too noisy)
//
//  Badge strategy
//  ──────────────
//  • Activity tab badge  = count of reports created since the user last opened that tab
//  • Account tab badge   = count of unread announcement + reputation changes
//  • App icon badge      = activityBadgeCount + accountBadgeCount
//
//  To add a new notification type:
//    1. Add a case to NotificationCategory
//    2. Add a schedule method (see announcement / reputation examples)
//    3. Update willPresent delegate if foreground behaviour should differ
//

import Foundation
import Combine
import UserNotifications
import UIKit

@MainActor
class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()

    // MARK: - Published badge counts (observed by MainTabView for tab badges)

    @Published private(set) var activityBadgeCount: Int = 0  // unseen new reports
    @Published private(set) var accountBadgeCount: Int = 0   // announcement + reputation

    // Internal sub-counts that feed accountBadgeCount
    private var announcementBadge: Int = 0
    private var reputationBadge: Int = 0

    // MARK: - UserDefaults keys

    private let seenReportIDsKey    = "badge_seen_report_ids"
    private let reputationBadgeKey  = "badge_reputation_count"
    private let reportVerifMapKey   = "badge_report_verif_map"    // [reportID: verificationCount]
    private let reportDisputeMapKey = "badge_report_dispute_map"  // [reportID: disputeCount]
    private let reputInitializedKey = "badge_repute_initialized"

    // Most-recent report IDs delivered by the listener; used by clearActivityBadge()
    // so callers don't need to pass IDs explicitly.
    private var latestReportIDs: Set<String> = []

    // MARK: - Init

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        // Restore persisted reputation badge on launch
        reputationBadge = UserDefaults.standard.integer(forKey: reputationBadgeKey)
        recomputeAccountBadge()
    }

    // MARK: - Permission

    func requestPermission() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            print("Notification permission granted: \(granted)")
        } catch {
            print("Notification permission error: \(error)")
        }
    }

    // MARK: - App Icon Badge

    private func syncAppIconBadge() {
        let total = activityBadgeCount + accountBadgeCount
        if #available(iOS 16, *) {
            UNUserNotificationCenter.current().setBadgeCount(total) { error in
                if let error { print("setBadgeCount error: \(error)") }
            }
        } else {
            UIApplication.shared.applicationIconBadgeNumber = total
        }
    }

    private func recomputeAccountBadge() {
        accountBadgeCount = announcementBadge + reputationBadge
    }

    // MARK: - Announcement

    /// Call whenever a new announcement is delivered (not on initial load).
    /// Schedules a banner if the app is backgrounded and increments the account badge.
    func handleAnnouncementChange(message: String) {
        // Show banner only when the app is not active — the in-app dialog handles it otherwise.
        if UIApplication.shared.applicationState != .active {
            scheduleAnnouncementBanner(message: message)
        }
        markAnnouncementPending()
    }

    /// Raises the announcement badge by 1 (idempotent — capped at 1).
    func markAnnouncementPending() {
        guard announcementBadge == 0 else { return }
        announcementBadge = 1
        recomputeAccountBadge()
        syncAppIconBadge()
    }

    /// Clears the announcement portion of the account badge.
    /// Call when the user taps "I Understand" on the announcement dialog.
    func clearAnnouncementBadge() {
        announcementBadge = 0
        recomputeAccountBadge()
        syncAppIconBadge()
    }

    private func scheduleAnnouncementBanner(message: String) {
        let content = UNMutableNotificationContent()
        content.title = "BLS Community Update"
        content.body = String(message.prefix(200))
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.announcement.rawValue

        // Using the category as identifier ensures only one pending announcement banner —
        // a new one replaces the old.
        let request = UNNotificationRequest(
            identifier: NotificationCategory.announcement.rawValue,
            content: content,
            trigger: nil // deliver immediately
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error { print("Failed to schedule announcement notification: \(error)") }
        }
    }

    // MARK: - Reputation / Report Updates

    /// Inspects the latest reports snapshot for changes to the current user's reports
    /// (verification or dispute count increases). Fires a banner notification and
    /// increments the account badge for each change detected.
    ///
    /// Safe to call on every listener update — skips silently on first delivery so that
    /// existing verif/dispute counts don't trigger phantom notifications on first launch.
    func checkReputationChanges(in reports: [Report], currentUserID: String) {
        let myReports = reports.filter { $0.authorID == currentUserID }
        guard !myReports.isEmpty else { return }

        let isFirstCheck = !UserDefaults.standard.bool(forKey: reputInitializedKey)

        var storedVerif   = (UserDefaults.standard.dictionary(forKey: reportVerifMapKey)   as? [String: Int]) ?? [:]
        var storedDispute = (UserDefaults.standard.dictionary(forKey: reportDisputeMapKey) as? [String: Int]) ?? [:]

        var changeMessages: [String] = []

        for report in myReports {
            guard let reportID = report.id else { continue }

            if !isFirstCheck {
                let prevVerif   = storedVerif[reportID]
                let prevDispute = storedDispute[reportID]

                if let prev = prevVerif, report.verificationCount > prev {
                    changeMessages.append(
                        "Your \(report.category.displayName) report on \(report.address) was confirmed."
                    )
                }
                if let prev = prevDispute, report.disputeCount > prev {
                    changeMessages.append(
                        "Your \(report.category.displayName) report on \(report.address) was disputed."
                    )
                }
            }

            // Always update stored baseline so future calls compare against current state.
            storedVerif[reportID]   = report.verificationCount
            storedDispute[reportID] = report.disputeCount
        }

        UserDefaults.standard.set(storedVerif,   forKey: reportVerifMapKey)
        UserDefaults.standard.set(storedDispute, forKey: reportDisputeMapKey)

        if isFirstCheck {
            UserDefaults.standard.set(true, forKey: reputInitializedKey)
            return
        }

        guard !changeMessages.isEmpty else { return }

        reputationBadge += changeMessages.count
        UserDefaults.standard.set(reputationBadge, forKey: reputationBadgeKey)
        recomputeAccountBadge()
        syncAppIconBadge()

        // Fire one banner summarising the changes (last message if multiple).
        let body = changeMessages.count == 1
            ? changeMessages[0]
            : "\(changeMessages.count) of your reports were updated."
        scheduleReputationBanner(
            title: changeMessages.count > 1 ? "Report Updates" : "Report Update",
            body: body
        )
    }

    /// Clears the reputation portion of the account badge.
    /// Call when the user opens the Account / Profile tab.
    func clearReputationBadge() {
        reputationBadge = 0
        UserDefaults.standard.set(0, forKey: reputationBadgeKey)
        recomputeAccountBadge()
        syncAppIconBadge()
    }

    private func scheduleReputationBanner(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.reputationChange.rawValue

        // Unique identifier so multiple reputation events stack rather than replace.
        let request = UNNotificationRequest(
            identifier: "reputation-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error { print("Failed to schedule reputation notification: \(error)") }
        }
    }

    // MARK: - New Reports Badge

    /// Updates the activity badge to reflect how many reports in `currentIDs` have not
    /// been seen by the user (i.e. are not in the stored seen-set).
    ///
    /// On first call (no stored seen-set), all current IDs are saved as "seen" so the
    /// badge starts at zero on a fresh install.
    func updateNewReportsBadge(currentIDs: Set<String>) {
        latestReportIDs = currentIDs

        guard let storedArray = UserDefaults.standard.array(forKey: seenReportIDsKey) as? [String] else {
            // First delivery — baseline everything as seen; no badge.
            UserDefaults.standard.set(Array(currentIDs), forKey: seenReportIDsKey)
            activityBadgeCount = 0
            syncAppIconBadge()
            return
        }

        let seen = Set(storedArray)
        let newCount = currentIDs.subtracting(seen).count
        if activityBadgeCount != newCount {
            activityBadgeCount = newCount
            syncAppIconBadge()
        }
    }

    /// Marks all currently-known reports as seen and resets the activity badge to zero.
    /// Call when the user opens the Activity tab.
    func clearActivityBadge() {
        // Merge latestReportIDs into the stored seen-set so we don't clobber IDs
        // that arrived before the listener fired for this session.
        var seen: Set<String>
        if let storedArray = UserDefaults.standard.array(forKey: seenReportIDsKey) as? [String] {
            seen = Set(storedArray)
        } else {
            seen = Set<String>()
        }
        seen.formUnion(latestReportIDs)
        UserDefaults.standard.set(Array(seen), forKey: seenReportIDsKey)

        activityBadgeCount = 0
        syncAppIconBadge()
    }
}

// MARK: - Notification Categories

extension NotificationManager {
    /// One case per notification type. Add new cases here as the feature grows.
    enum NotificationCategory: String {
        case announcement    = "ANNOUNCEMENT"
        case reputationChange = "REPUTATION_CHANGE"
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {

    /// Called when a notification arrives while the app is foregrounded.
    /// Announcement banners are suppressed — the in-app dialog handles them.
    /// Reputation-change banners are shown even in the foreground so the user
    /// gets immediate feedback about their reports.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let category = notification.request.content.categoryIdentifier
        if category == NotificationCategory.announcement.rawValue {
            completionHandler([]) // suppress — in-app dialog handles it
        } else {
            completionHandler([.banner, .sound])
        }
    }

    /// Called when the user taps a notification.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Future: navigate to the relevant screen based on category.
        // let category = response.notification.request.content.categoryIdentifier
        completionHandler()
    }
}
