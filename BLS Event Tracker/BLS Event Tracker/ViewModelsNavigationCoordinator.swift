//
//  NavigationCoordinator.swift
//  Community Status App
//
//  Coordinates navigation between Map and Activity views
//

import Foundation
import MapKit
import Combine

@MainActor
class NavigationCoordinator: ObservableObject {
    @Published var selectedReport: Report?
    @Published var shouldShowOnMap: Bool = false
    
    // Call this to show a report on the map
    func showReportOnMap(_ report: Report) {
        selectedReport = report
        shouldShowOnMap = true
    }
    
    // Reset after navigation completes
    func resetNavigation() {
        shouldShowOnMap = false
    }
}
