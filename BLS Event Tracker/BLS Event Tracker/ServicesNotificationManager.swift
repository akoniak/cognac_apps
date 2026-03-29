//
//  NotificationManager.swift
//  BLS Event Tracker
//
//  Central notification service. Currently uses local notifications for
//  announcement changes (no server required). Structured to support FCM
//  push notifications in the future.
//
//  To add a new notification type:
//    1. Add a case to NotificationCategory
//    2. Add a schedule method below the announcement one
//    3. Update willPresent delegate method if foreground behavior differs
//

import Foundation
import UserNotifications
import UIKit

@MainActor
class NotificationManager: NSObject {
    static let shared = NotificationManager()

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - Permission

    func requestPermission() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
            print("Notification permission granted: \(granted)")
        } catch {
            print("Notification permission error: \(error)")
        }
    }

    // MARK: - Announcement (local notification)
    //
    // Fires only when the app is backgrounded. When active, the in-app
    // dialog already surfaces the change, so we suppress the banner there.

    func scheduleAnnouncementNotification(message: String) {
        guard UIApplication.shared.applicationState != .active else { return }

        let content = UNMutableNotificationContent()
        content.title = "BLS Community Update"
        content.body = String(message.prefix(200))
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.announcement.rawValue

        // Using the category as the identifier ensures only one announcement
        // notification is ever pending — a newer one replaces the old.
        let request = UNNotificationRequest(
            identifier: NotificationCategory.announcement.rawValue,
            content: content,
            trigger: nil // deliver immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error { print("Failed to schedule announcement notification: \(error)") }
        }
    }

    // MARK: - Future: FCM Push Notifications
    //
    // When upgrading to Firebase Blaze, add Cloud Functions and uncomment:
    //   func subscribeToCommunityTopic(_ communityID: String) async
    //   func unsubscribeFromCommunityTopic(_ communityID: String) async
    //   func updateFCMToken(_ token: String) async
}

// MARK: - Notification Categories

extension NotificationManager {
    /// One case per notification type. Add new cases here as the feature grows.
    enum NotificationCategory: String {
        case announcement  = "ANNOUNCEMENT"
        // future: case reportActivity = "REPORT_ACTIVITY"
        // future: case newReport      = "NEW_REPORT"
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {

    /// Called when a notification arrives while the app is foregrounded.
    /// Announcement banners are suppressed — the in-app dialog handles them.
    /// Future notification types that should still appear in-foreground can opt in.
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
