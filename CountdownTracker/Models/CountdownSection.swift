import Foundation
import SwiftData

@Model
class CountdownSection {
    var name: String
    var sortOrder: Int
    var isLocked: Bool = false
    var isExpanded: Bool = true
    /// Whether the inline "Completed" bucket inside this section is expanded.
    /// Defaults to collapsed — finished items are less interesting at a glance.
    var isCompletedExpanded: Bool = false
    @Relationship(deleteRule: .cascade, inverse: \CountdownItem.section)
    var items: [CountdownItem] = []

    init(
        name: String,
        sortOrder: Int = 0,
        isLocked: Bool = false,
        isExpanded: Bool = true,
        isCompletedExpanded: Bool = false
    ) {
        self.name = name
        self.sortOrder = sortOrder
        self.isLocked = isLocked
        self.isExpanded = isExpanded
        self.isCompletedExpanded = isCompletedExpanded
    }
}
