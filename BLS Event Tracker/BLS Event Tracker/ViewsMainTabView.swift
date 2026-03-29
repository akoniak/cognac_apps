//
//  MainTabView.swift
//  Community Status App
//
//  Main tab navigation between Map and Reports List
//

import SwiftUI

struct MainTabView: View {
    @StateObject private var navigationCoordinator = NavigationCoordinator()
    @State private var selectedTab = 0
    @State private var showNewReport = false
    @State private var isReportCardVisible = false

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
                    .tag(1)
                
                // Profile View
                ProfileView()
                    .tabItem {
                        Label("Account", systemImage: "person.circle.fill")
                    }
                    .tag(2)
            }
            .environmentObject(navigationCoordinator)
            
            // Floating "New Report" button (only visible on Map and Activity tabs,
            // and hidden when a report detail card is showing on the map)
            if selectedTab != 2 && !(selectedTab == 0 && isReportCardVisible) {
                VStack {
                    Spacer()
                    
                    Button {
                        showNewReport = true
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
