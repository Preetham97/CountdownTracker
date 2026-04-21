import Foundation
import SwiftData

@Model
class CountdownItem {
    var title: String
    var targetDate: Date
    var section: CountdownSection?

    // Notification opt-ins. Default: 1-day-before only.
    var notify15d: Bool = false
    var notify7d: Bool = false
    var notify1d: Bool = true

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
    }
}
