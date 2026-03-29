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
    
    private let dataService = AppDataService.shared
    
    private init() {}
    
    /// Load the latest announcement from data service
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

