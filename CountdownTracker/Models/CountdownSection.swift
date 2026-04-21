import Foundation
import SwiftData

@Model
class CountdownSection {
    var name: String
    var sortOrder: Int
    @Relationship(deleteRule: .cascade, inverse: \CountdownItem.section)
    var items: [CountdownItem] = []

    init(name: String, sortOrder: Int = 0) {
        self.name = name
        self.sortOrder = sortOrder
    }
}
