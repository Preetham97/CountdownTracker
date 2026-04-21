import Foundation
import LocalAuthentication
import SwiftUI

/// Wraps LAContext with a simple async API and tracks which sections the user
/// has unlocked in the current foreground session. Unlocked state is cleared
/// whenever the app backgrounds.
@Observable
final class BiometricAuth {
    /// Persistent identifiers of sections currently unlocked.
    private var unlockedSectionIDs: Set<PersistentIdentifier> = []

    /// Whether the current device supports biometrics or passcode at all.
    /// If this is false, locking a section is meaningless.
    var isAuthenticationAvailable: Bool {
        let ctx = LAContext()
        var error: NSError?
        return ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    func isUnlocked(_ section: CountdownSection) -> Bool {
        !section.isLocked || unlockedSectionIDs.contains(section.persistentModelID)
    }

    /// Prompts Face ID / Touch ID, falling back to device passcode.
    /// Returns true on success.
    @MainActor
    func unlock(_ section: CountdownSection, reason: String) async -> Bool {
        if !section.isLocked { return true }
        if unlockedSectionIDs.contains(section.persistentModelID) { return true }

        let ctx = LAContext()
        var error: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return false
        }
        do {
            let ok = try await ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            if ok {
                unlockedSectionIDs.insert(section.persistentModelID)
            }
            return ok
        } catch {
            return false
        }
    }

    /// Clear all unlocked sections — call on app backgrounding.
    func lockAll() {
        unlockedSectionIDs.removeAll()
    }
}
