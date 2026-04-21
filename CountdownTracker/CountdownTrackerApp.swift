import SwiftUI
import SwiftData

@main
struct CountdownTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [CountdownSection.self, CountdownItem.self])
    }
}
