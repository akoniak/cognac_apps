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
            } else if !useMockData {
                // In Firebase mode, show the real login screen when signed out
                LoginView()
            } else {
                // Mock mode: show a loading indicator while auto-login completes
                ProgressView()
            }
        }
        .alert("BLS Community Powered Status", isPresented: $showWelcome) {
            Button("I Understand", role: .none) {
                lastSeenMessage = announcementManager.message
            }
        } message: {
            Text(welcomeMessage)
        }
        .task {
            announcementManager.startListening()
        }
        .onChange(of: announcementManager.message) { _, newMessage in
            // Show the dialog when the message differs from what the user last acknowledged.
            // Exception: if the user has seen a message before and the new message is the
            // standard default, treat it as a silent reset — no dialog needed.
            let isReset = !lastSeenMessage.isEmpty && newMessage == AnnouncementManager.standardMessage
            if newMessage != lastSeenMessage && !isReset {
                showWelcome = true
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

