//
//  RootView.swift
//  Community Status App
//
//  Main root view that handles authentication state
//

import SwiftUI

struct RootView: View {
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var announcementManager = AnnouncementManager.shared
    /// Stores the last message the user acknowledged so we can detect changes.
    @AppStorage("lastSeenAnnouncementMessage") private var lastSeenMessage = ""
    @State private var showWelcome = false
    @Environment(\.scenePhase) private var scenePhase

    /// Shows the dialog whenever the current message differs from what the user last acknowledged.
    /// Used on both initial load and whenever the message changes (live or on foreground).
    private func checkAnnouncement(_ message: String) {
        if message != lastSeenMessage {
            showWelcome = true
            NotificationManager.shared.markAnnouncementPending()
        }
    }

    private var welcomeMessage: String {
        let separator = "****************************"
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let timestamp = formatter.string(from: announcementManager.lastUpdated)
        let header = "\(separator)\nLast Updated: \(timestamp)\n\(separator)"
        return "\(header)\n\n\(announcementManager.message)"
    }

    var body: some View {
        Group {
            if authManager.isCheckingAuth {
                // Auth state not yet resolved — show splash to avoid flashing the login screen
                SplashView()
            } else if authManager.isAuthenticated {
                MainTabView()
                    .alert("BLS Community Powered Status", isPresented: $showWelcome) {
                        Button("I Understand", role: .none) {
                            lastSeenMessage = announcementManager.message
                            NotificationManager.shared.clearAnnouncementBadge()
                            // Request permission after the announcement is dismissed
                            // so the two system dialogs don't compete on first launch.
                            Task { await NotificationManager.shared.requestPermission() }
                        }
                    } message: {
                        Text(welcomeMessage)
                    }
                    .task {
                        announcementManager.startListening()
                    }
                    .onChange(of: announcementManager.hasReceivedFirstMessage) { _, received in
                        if received {
                            checkAnnouncement(announcementManager.message)
                            // If no announcement dialog is showing, request permission now.
                            // If it is showing, the "I Understand" button requests it after dismissal.
                            if !showWelcome {
                                Task { await NotificationManager.shared.requestPermission() }
                            }
                        }
                    }
                    .onChange(of: announcementManager.message) { _, newMessage in
                        guard announcementManager.hasReceivedFirstMessage else { return }
                        checkAnnouncement(newMessage)
                    }
            } else if !useMockData {
                // In Firebase mode, show the real login screen when signed out
                LoginView()
            } else {
                // Mock mode: show a loading indicator while auto-login completes
                ProgressView()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            // When the app returns to the foreground, do a one-time fetch so we
            // catch any announcement change that happened while the app was suspended
            // (the real-time listener can't fire when the process is frozen by iOS).
            guard phase == .active, authManager.isAuthenticated else { return }
            Task { await announcementManager.loadLatestAnnouncement() }
        }
    }
}

#Preview {
    RootView()
}

#Preview {
    RootView()
}

