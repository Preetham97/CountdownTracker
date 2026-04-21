import Foundation
import SwiftData

@Model
class CountdownItem {
    var title: String
    var targetDate: Date
    var section: CountdownSection?

    init(title: String, targetDate: Date) {
        self.title = title
        self.targetDate = targetDate
    }
}
