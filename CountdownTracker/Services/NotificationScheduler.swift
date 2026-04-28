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

        // Completed items never get reminders, regardless of opt-ins.
        guard !item.isCompleted else { return }

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

        // Skip entirely if the deadline has already passed.
        guard item.targetDate > now else { return }

        // Partition: offsets whose fire date is still in the future schedule
        // normally; offsets whose fire date has passed (but the deadline is
        // still in the future) mean "we missed this reminder window — fire
        // an immediate catch-up so the user knows time is tight."
        var futureScheduled: [(Offset, Date)] = []
        var overdueOffsets: [Offset] = []

        for offset in enabledOffsets {
            guard let fireDate = Calendar.current.date(
                byAdding: .day,
                value: -offset.rawValue,
                to: item.targetDate
            ) else { continue }

            if fireDate > now {
                futureScheduled.append((offset, fireDate))
            } else {
                overdueOffsets.append(offset)
            }
        }

        // Schedule any offsets still in the future at their exact fire time.
        for (offset, fireDate) in futureScheduled {
            let content = buildContent(
                for: item,
                offset: offset,
                isLocked: isLocked,
                sectionName: sectionName
            )
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

        // Fire exactly one immediate catch-up for the tightest overdue offset
        // (smallest days value). Firing all three would spam with redundant
        // pings — e.g. "a week away" and "tomorrow" for the same 5-min deadline.
        if let tightest = overdueOffsets.min(by: { $0.rawValue < $1.rawValue }) {
            let content = UNMutableNotificationContent()
            let phrase = imminentPhrase(until: item.targetDate, now: now)
            if isLocked {
                content.title = sectionName.isEmpty ? "Countdown" : sectionName
                content.body = "A countdown is \(phrase)"
            } else {
                content.title = item.title
                content.body = "\(item.title) is \(phrase)"
            }
            content.sound = .default
            // 1-second trigger rather than `nil` — trigger-less requests can
            // be suppressed when the app is foregrounded, which we don't want.
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(
                identifier: "\(itemID)-\(tightest.identifierSuffix)-now",
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
    }

    /// Human-readable "how close is it?" string for the immediate catch-up
    /// notification — more accurate than the fixed per-offset phrase when
    /// the deadline is only minutes or hours away.
    private static func imminentPhrase(until target: Date, now: Date) -> String {
        let secs = target.timeIntervalSince(now)
        if secs < 60 { return "less than a minute away" }
        let minutes = Int(secs / 60)
        if minutes < 60 {
            return minutes == 1 ? "in 1 minute" : "in \(minutes) minutes"
        }
        let hours = Int(secs / 3600)
        if hours < 24 {
            return hours == 1 ? "in 1 hour" : "in \(hours) hours"
        }
        let days = Int(secs / 86400)
        return days == 1 ? "in 1 day" : "in \(days) days"
    }

    private static func buildContent(
        for item: CountdownItem,
        offset: Offset,
        isLocked: Bool,
        sectionName: String
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        if isLocked {
            content.title = sectionName.isEmpty ? "Countdown" : sectionName
            content.body = "A countdown is \(offset.phrase)"
        } else {
            content.title = item.title
            content.body = "\(item.title) is \(offset.phrase)"
        }
        content.sound = .default
        return content
    }

    /// Cancel all pending notifications for a single item.
    static func cancel(for item: CountdownItem) {
        let itemID = stableID(for: item)
        var ids = Offset.allCases.map { "\(itemID)-\($0.identifierSuffix)" }
        // Also sweep any immediate-catch-up requests that might still be pending.
        ids.append(contentsOf: Offset.allCases.map { "\(itemID)-\($0.identifierSuffix)-now" })
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

    /// Stable per-item identifier prefix. Backed by `CountdownItem.notificationID`
    /// (a UUID generated once at insert time) so it survives process restarts.
    /// Previously this used `String(describing: persistentModelID).hashValue`,
    /// but Swift randomizes string hashing per launch, so a notification scheduled
    /// in one process couldn't be cancelled in the next — leaving zombie
    /// reminders for deleted items.
    private static func stableID(for item: CountdownItem) -> String {
        return "cd-\(item.notificationID)"
    }

    // MARK: - Launch reconciliation

    /// Wipe every pending notification and reschedule from the live model. Called
    /// once at app launch to: (a) heal any zombie notifications scheduled with
    /// the old (unstable) hash-based IDs, and (b) keep iOS's pending queue in
    /// sync with the database in case anything drifted.
    @MainActor
    static func reconcileAll(context: ModelContext) {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        let descriptor = FetchDescriptor<CountdownItem>()
        let items = (try? context.fetch(descriptor)) ?? []
        for item in items {
            reschedule(for: item)
        }
    }
}
