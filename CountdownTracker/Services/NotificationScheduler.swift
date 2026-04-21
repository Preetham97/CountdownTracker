import Foundation
import UserNotifications
import SwiftData

/// Schedules local notifications for countdown items.
///
/// Notifications fire at the exact `targetDate − offset` moment (e.g. a
/// deadline at 5pm with the 7-day opt-in sends at 5pm seven days prior).
/// Identifiers are deterministic per (item, offset) so rescheduling is
/// idempotent and cancellation is trivial.
///
/// Privacy: for items inside locked sections the body text is scrubbed
/// (the countdown's title is hidden) but the section name is preserved
/// as the notification title.
enum NotificationScheduler {

    // MARK: - Offsets

    /// Days before the deadline at which a notification can fire.
    enum Offset: Int, CaseIterable {
        case fifteenDays = 15
        case sevenDays = 7
        case oneDay = 1

        var identifierSuffix: String {
            switch self {
            case .fifteenDays: return "15d"
            case .sevenDays:   return "7d"
            case .oneDay:      return "1d"
            }
        }

        var phrase: String {
            switch self {
            case .fifteenDays: return "15 days away"
            case .sevenDays:   return "a week away"
            case .oneDay:      return "tomorrow"
            }
        }
    }

    // MARK: - Authorization

    /// Requests authorization the first time we need it. Idempotent — safe
    /// to call on every save; the system only prompts once.
    static func requestAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .badge, .sound])
            } catch {
                return false
            }
        @unknown default:
            return false
        }
    }

    // MARK: - Scheduling

    /// Cancel any existing notifications for this item, then schedule new
    /// ones for every opt-in offset whose fire date is still in the future.
    static func reschedule(for item: CountdownItem) {
        cancel(for: item)

        let center = UNUserNotificationCenter.current()
        let enabledOffsets: [Offset] = {
            var out: [Offset] = []
            if item.notify15d { out.append(.fifteenDays) }
            if item.notify7d  { out.append(.sevenDays) }
            if item.notify1d  { out.append(.oneDay) }
            return out
        }()

        guard !enabledOffsets.isEmpty else { return }

        let itemID = stableID(for: item)
        let isLocked = item.section?.isLocked ?? false
        let sectionName = item.section?.name ?? ""
        let now = Date()

        for offset in enabledOffsets {
            guard let fireDate = Calendar.current.date(
                byAdding: .day,
                value: -offset.rawValue,
                to: item.targetDate
            ) else { continue }

            // Skip past fire dates — the notification would never deliver anyway.
            guard fireDate > now else { continue }

            let content = UNMutableNotificationContent()
            if isLocked {
                content.title = sectionName.isEmpty ? "Countdown" : sectionName
                content.body = "A countdown is \(offset.phrase)"
            } else {
                content.title = item.title
                content.body = "\(item.title) is \(offset.phrase)"
            }
            content.sound = .default

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: fireDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

            let request = UNNotificationRequest(
                identifier: "\(itemID)-\(offset.identifierSuffix)",
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
    }

    /// Cancel all pending notifications for a single item.
    static func cancel(for item: CountdownItem) {
        let itemID = stableID(for: item)
        let ids = Offset.allCases.map { "\(itemID)-\($0.identifierSuffix)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    /// Cancel pending notifications for every item in a section. Used when a
    /// section is deleted.
    static func cancelAll(in section: CountdownSection) {
        for item in section.items {
            cancel(for: item)
        }
    }

    /// Re-evaluate every item in a section. Used when the section's lock
    /// flag toggles — the notification body text changes with privacy.
    static func rescheduleAll(in section: CountdownSection) {
        for item in section.items {
            reschedule(for: item)
        }
    }

    // MARK: - Identity

    /// SwiftData's `PersistentIdentifier` stringifies reasonably, but we
    /// normalise it by hashing to keep request IDs short and filesystem-safe.
    private static func stableID(for item: CountdownItem) -> String {
        let raw = String(describing: item.persistentModelID)
        return "cd-\(raw.hashValue)"
    }
}
