import UIKit

/// Thin wrapper over `UIFeedbackGenerator` so callsites read like intent
/// rather than UIKit boilerplate. Generators are created on each call —
/// the cost is negligible and avoids any global state.
enum Haptics {
    /// Subtle bump for routine actions (checkbox toggle, lock/unlock).
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// "Done" confirmation — used after saving a countdown or section.
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Heavier bump for slightly more consequential actions (delete confirm,
    /// recurrence expansion creating multiple items).
    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}
