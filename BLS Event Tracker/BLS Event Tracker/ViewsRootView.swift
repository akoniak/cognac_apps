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

    /// Called on first Firestore delivery — always show the dialog if the message
    /// hasn't been acknowledged yet this session (i.e. lastSeenMessage differs).
    private func checkLaunchAnnouncement(_ message: String) {
        if message != lastSeenMessage {
            showWelcome = true
        }
    }

    /// Called when the message changes while the app is already open (admin update).
    /// Suppresses the dialog if the admin merely reverted to the standard message.
    private func checkLiveAnnouncement(_ newMessage: String) {
        let isRevert = newMessage == AnnouncementManager.standardMessage
        print("DEBUG live: new='\(newMessage.prefix(30))' lastSeen='\(lastSeenMessage.prefix(30))' isRevert=\(isRevert)")
        if newMessage != lastSeenMessage && !isRevert {
            showWelcome = true
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
            if authManager.isAuthenticated {
                MainTabView()
                    .alert("BLS Community Powered Status", isPresented: $showWelcome) {
                        Button("I Understand", role: .none) {
                            lastSeenMessage = announcementManager.message
                        }
                    } message: {
                        Text(welcomeMessage)
                    }
                    .task {
                        announcementManager.startListening()
                        await NotificationManager.shared.requestPermission()
                    }
                    .onChange(of: announcementManager.hasReceivedFirstMessage) { _, received in
                        if received {
                            checkLaunchAnnouncement(announcementManager.message)
                        }
                    }
                    .onChange(of: announcementManager.message) { _, newMessage in
                        guard announcementManager.hasReceivedFirstMessage else { return }
                        checkLiveAnnouncement(newMessage)
                    }
            } else if !useMockData {
                // In Firebase mode, show the real login screen when signed out
                LoginView()
            } else {
                // Mock mode: show a loading indicator while auto-login completes
                ProgressView()
            }
        }
    }
}

#Preview {
    RootView()
}

#Preview {
    RootView()
}

