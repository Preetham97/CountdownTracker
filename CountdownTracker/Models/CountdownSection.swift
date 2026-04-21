import Foundation
import SwiftData

@Model
class CountdownSection {
    var name: String
    var sortOrder: Int
    var isLocked: Bool = false
    var isExpanded: Bool = true
    @Relationship(deleteRule: .cascade, inverse: \CountdownItem.section)
    var items: [CountdownItem] = []

    init(name: String, sortOrder: Int = 0, isLocked: Bool = false, isExpanded: Bool = true) {
        self.name = name
        self.sortOrder = sortOrder
        self.isLocked = isLocked
        self.isExpanded = isExpanded
    }
}
