import Foundation
import SwiftData

@Model
class CountdownItem {
    // CloudKit constraint: every property must have a default value or be
    // optional. The "" / .distantPast sentinels are never user-visible —
    // `init` always sets real values before the item is saved.
    var title: String = ""
    var targetDate: Date = Date.distantPast
    var section: CountdownSection?

    /// Wall-clock timestamp the item was created. Drives the circular
    /// progress ring on each row (full at creation, empty at deadline).
    /// Defaulted to `.distantPast` to satisfy CloudKit; legacy rows that
    /// pre-date this field use a 30-day rolling-window fallback in the
    /// ring view so they still animate sensibly.
    var createdAt: Date = Date.distantPast

    // User-completed flag. When true, the item is struck through, greyed
    // out, moved to the Completed bucket, and its notifications are cancelled.
    var isCompleted: Bool = false
    var completedAt: Date?

    // Notification opt-ins. Default: 1-day-before only.
    var notify15d: Bool = false
    var notify7d: Bool = false
    var notify1d: Bool = true

    /// Free-text notes — account numbers, gate codes, links, anything you'd
    /// otherwise hunt for in another app when this countdown comes due.
    var notes: String = ""

    /// Stable identifier used as the prefix for notification request IDs.
    /// We can't use `persistentModelID.hashValue` because Swift's String/hash
    /// is randomized per process launch — that meant a notification scheduled
    /// in one launch could not be cancelled in the next, so deleted items
    /// kept firing reminders. UUID is generated once and persisted.
    var notificationID: String = UUID().uuidString

    init(
        title: String,
        targetDate: Date,
        notify15d: Bool = false,
        notify7d: Bool = false,
        notify1d: Bool = true
    ) {
        self.title = title
        self.targetDate = targetDate
        self.notify15d = notify15d
        self.notify7d = notify7d
        self.notify1d = notify1d
        self.createdAt = .now
    }
}
