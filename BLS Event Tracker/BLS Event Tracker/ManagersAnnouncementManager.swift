//
//  AnnouncementManager.swift
//  Community Status App
//
//  Manages admin announcements and updates
//

import Foundation
import Combine

@MainActor
class AnnouncementManager: ObservableObject {
    static let shared = AnnouncementManager()

    /// The default "standard" message shown when no admin update has been set.
    /// Exposed so the template store and admin UI can always reference it.
    static let standardMessage = "Welcome to the Blue Lake Springs event tracker. Reports come from residents and may not always be accurate. Do not rely on this app for emergencies. If you are in danger, please call 911."

    @Published var message: String = AnnouncementManager.standardMessage

    @Published var lastUpdated: Date = Date()

    /// Flips to true the first time Firestore delivers a value.
    /// RootView observes this to trigger the launch dialog even when the
    /// message hasn't changed from its initial default value.
    @Published var hasReceivedFirstMessage = false

    private let dataService = AppDataService.shared

    /// Retains the Firestore listener so it stays active for the app lifetime.
    private var listenerToken: AnyObject?

    private init() {}

    /// Attaches a real-time Firestore listener so the announcement updates
    /// automatically on all devices whenever an admin saves a change.
    /// Safe to call multiple times — only one listener is ever attached.
    func startListening() {
        guard listenerToken == nil else { return }
        listenerToken = dataService.startListeningToAnnouncement { [weak self] announcement in
            Task { @MainActor in
                self?.message = announcement.message
                self?.lastUpdated = announcement.lastUpdated
                self?.hasReceivedFirstMessage = true
            }
        }
    }

    /// One-time fetch — kept for use in the admin editor to reload the draft.
    func loadLatestAnnouncement() async {
        do {
            let announcement = try await dataService.fetchAnnouncement()
            self.message = announcement.message
            self.lastUpdated = announcement.lastUpdated
        } catch {
            print("Error loading announcement: \(error)")
            // Keep default values on error
        }
    }
}

// MARK: - Admin Functions (for admin app/panel)

extension AnnouncementManager {
    /// Update the announcement (admin only)
    func updateAnnouncement(message: String) async throws {
        let announcement = Announcement(
            message: message,
            lastUpdated: Date()
        )
        try await dataService.updateAnnouncement(announcement)
        
        // Update local state
        self.message = message
        self.lastUpdated = Date()
    }
}
// MARK: - Announcement Model

struct Announcement {
    let message: String
    let lastUpdated: Date
}

