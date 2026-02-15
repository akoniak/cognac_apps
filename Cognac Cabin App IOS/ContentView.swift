import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Monitoring", systemImage: "video.fill") {
                MonitoringView()
            }
            Tab("Checklist", systemImage: "checklist") {
                ChecklistView()
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [ChecklistSection.self, ChecklistItem.self], inMemory: true)
}
