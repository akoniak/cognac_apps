import SwiftUI
import SwiftData

@main
struct Cognac_Cabin_App_IOSApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [ChecklistSection.self, ChecklistItem.self])
    }
}
