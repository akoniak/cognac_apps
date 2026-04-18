//
//  MainTabView.swift
//  Community Status App
//
//  Main tab navigation between Map and Reports List
//

import SwiftUI

struct MainTabView: View {
    @StateObject private var navigationCoordinator = NavigationCoordinator()
    @ObservedObject private var notificationManager = NotificationManager.shared
    @ObservedObject private var authManager = AuthenticationManager.shared
    @State private var selectedTab = 0
    @State private var showNewReport = false
    @State private var isReportCardVisible = false
    /// Set when the user taps "New Report" without being signed in.
    /// After login completes, NewReportView opens automatically.
    @State private var pendingNewReport = false

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                // Map View
                MainMapView(isReportCardVisible: $isReportCardVisible)
                    .tabItem {
                        Label("Map", systemImage: "map.fill")
                    }
                    .tag(0)
                
                // Reports List View
                ReportsListView()
                    .tabItem {
                        Label("Activity", systemImage: "list.bullet")
                    }
                    .badge(notificationManager.activityBadgeCount)
                    .tag(1)
                
                // Account tab: full profile when signed in, sign-in prompt otherwise
                Group {
                    if authManager.isAuthenticated {
                        ProfileView()
                    } else {
                        VStack(spacing: 20) {
                            Spacer()
                            Image(systemName: "person.circle")
                                .font(.system(size: 64))
                                .foregroundStyle(.secondary)
                            Text("Sign In to Access Your Account")
                                .font(.title3.bold())
                            Text("View your reputation, report history, and community standing.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                            Button("Sign In") {
                                authManager.isShowingLoginSheet = true
                            }
                            .buttonStyle(.borderedProminent)
                            Spacer()
                        }
                    }
                }
                .tabItem {
                    Label("Account", systemImage: "person.circle.fill")
                }
                .badge(notificationManager.accountBadgeCount)
                .tag(2)
            }
            .environmentObject(navigationCoordinator)
            
            // Floating "New Report" button (only visible on Map and Activity tabs,
            // and hidden when a report detail card is showing on the map)
            if selectedTab != 2 && !(selectedTab == 0 && isReportCardVisible) {
                VStack {
                    Spacer()
                    
                    Button {
                        if authManager.canTakeActions {
                            showNewReport = true
                        } else {
                            pendingNewReport = true
                            authManager.isShowingLoginSheet = true
                        }
                    } label: {
                        Label("New Report", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .background(.blue)
                            .cornerRadius(25)
                            .shadow(radius: 8)
                    }
                    .padding(.bottom, 80) // Above tab bar
                }
            }
        }
        .sheet(isPresented: $showNewReport) {
            NewReportView()
        }
        .sheet(isPresented: $authManager.isShowingLoginSheet) {
            LoginView()
        }
        .onChange(of: authManager.isAuthenticated) { _, isAuth in
            // If the user just signed in and had tapped "New Report" before logging in,
            // open the report form now that they are authenticated.
            if isAuth && pendingNewReport {
                pendingNewReport = false
                showNewReport = true
            }
        }
        .onChange(of: selectedTab) { _, tab in
            switch tab {
            case 1: NotificationManager.shared.clearActivityBadge()
            case 2: NotificationManager.shared.clearReputationBadge()
            default: break
            }
        }
        .onChange(of: navigationCoordinator.shouldShowOnMap) { _, shouldShow in
            if shouldShow {
                // Switch to map tab
                selectedTab = 0
                
                // Reset navigation flag after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    navigationCoordinator.resetNavigation()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .reportSubmitted)) { notification in
            // If the notification carries a report, switch to the map and zoom to it
            guard let report = notification.object as? Report else { return }
            selectedTab = 0
            // Small delay lets the map tab finish appearing before the camera moves
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                navigationCoordinator.showReportOnMap(report)
            }
        }
    }
}

#Preview {
    MainTabView()
}
