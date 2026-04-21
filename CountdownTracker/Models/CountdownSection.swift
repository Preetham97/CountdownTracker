import Foundation
import SwiftData

@Model
class CountdownSection {
    var name: String
    var sortOrder: Int
    var isLocked: Bool = false
    @Relationship(deleteRule: .cascade, inverse: \CountdownItem.section)
    var items: [CountdownItem] = []

    init(name: String, sortOrder: Int = 0, isLocked: Bool = false) {
        self.name = name
        self.sortOrder = sortOrder
        self.isLocked = isLocked
    }
}
