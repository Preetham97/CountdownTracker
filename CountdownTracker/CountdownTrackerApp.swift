import SwiftUI
import SwiftData
import UserNotifications

@main
struct CountdownTrackerApp: App {
    @State private var auth = BiometricAuth()
    // Retain the delegate for the lifetime of the app — UNUserNotificationCenter
    // holds it weakly.
    private let notificationDelegate = ForegroundNotificationDelegate()

    /// Owned explicitly so we can hand a `ModelContext` to the launch-time
    /// notification reconciler. The same container is also handed to the
    /// SwiftUI environment via `.modelContainer(_:)` below.
    private let modelContainer: ModelContainer = {
        do {
            return try ModelContainer(for: CountdownSection.self, CountdownItem.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    init() {
        UNUserNotificationCenter.current().delegate = notificationDelegate
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(auth)
                .task {
                    // Heal any zombie notifications left over from the previous
                    // (buggy) hash-based identifier scheme, and keep iOS's
                    // pending queue in sync with the database.
                    let context = ModelContext(modelContainer)
                    await MainActor.run {
                        NotificationScheduler.reconcileAll(context: context)
                    }
                }
        }
        .modelContainer(modelContainer)
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
