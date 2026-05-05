import Foundation
import SwiftData

@Model
class CountdownSection {
    // CloudKit constraint: every property must have a default value or be
    // optional. The "" / 0 sentinels are never user-visible — `init`
    // always sets a real value before the section is saved.
    var name: String = ""
    var sortOrder: Int = 0
    var isLocked: Bool = false

    /// Stable per-section identifier used as a key for device-local UI
    /// state (e.g. the Completed bucket's expand/collapse state in
    /// UserDefaults). UUID-based so it survives serialization and never
    /// collides across iCloud-synced devices. Mirrors the same pattern
    /// `CountdownItem.notificationID` uses.
    var stableID: String = UUID().uuidString

    @Relationship(deleteRule: .cascade, inverse: \CountdownItem.section)
    var items: [CountdownItem] = []

    init(
        name: String,
        sortOrder: Int = 0,
        isLocked: Bool = false
    ) {
        self.name = name
        self.sortOrder = sortOrder
        self.isLocked = isLocked
    }
}
