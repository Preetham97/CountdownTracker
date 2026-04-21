import SwiftUI
import SwiftData

@main
struct CountdownTrackerApp: App {
    @State private var auth = BiometricAuth()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(auth)
        }
        .modelContainer(for: [CountdownSection.self, CountdownItem.self])
    }
}
