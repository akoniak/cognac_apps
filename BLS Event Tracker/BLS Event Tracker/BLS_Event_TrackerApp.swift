//
//  BLS_Event_TrackerApp.swift
//  BLS Event Tracker
//
//  Created by Adam Koniak on 3/22/26.
//

import SwiftUI
import FirebaseCore
import GoogleSignIn

@main
struct BLS_Event_TrackerApp: App {

    init() {
        FirebaseApp.configure()

        // Configure GoogleSignIn with the client ID from GoogleService-Info.plist.
        // This is required because GENERATE_INFOPLIST_FILE = YES causes Xcode to ignore
        // any manual Info.plist entries, so the GIDClientID key never reaches the bundle.
        if let clientID = FirebaseApp.app()?.options.clientID {
            let config = GIDConfiguration(clientID: clientID)
            GIDSignIn.sharedInstance.configuration = config
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
