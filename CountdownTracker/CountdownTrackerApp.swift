import SwiftUI
import SwiftData
import UserNotifications

@main
struct CountdownTrackerApp: App {
    @State private var auth = BiometricAuth()
    // Retain the delegate for the lifetime of the app — UNUserNotificationCenter
    // holds it weakly.
    private let notificationDelegate = ForegroundNotificationDelegate()

    init() {
        UNUserNotificationCenter.current().delegate = notificationDelegate
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(auth)
        }
        .modelContainer(for: [CountdownSection.self, CountdownItem.self])
    }
}

/// Makes notifications present as banners + sound even when the app is in
/// the foreground. Without this, iOS silently drops foreground notifications
/// into Notification Center — which defeats the purpose of our immediate
/// catch-up notification when a user just saved a countdown that's only
/// minutes away.
private final class ForegroundNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }
}
