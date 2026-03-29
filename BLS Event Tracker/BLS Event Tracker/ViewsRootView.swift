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
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
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
                // Keep hasSeenWelcome for future settings toggle
                hasSeenWelcome = true
            }
        } message: {
            Text(welcomeMessage)
        }
        .onAppear {
            // Show welcome dialog every time the app launches
            // (Can be disabled in settings once that feature is added)
            // Delay slightly to ensure the view is ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showWelcome = true
            }
        }
        .task {
            await announcementManager.loadLatestAnnouncement()
        }
    }
}

#Preview {
    RootView()
}

#Preview {
    RootView()
}

