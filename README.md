# CountdownTracker

A simple, native iOS app for tracking time remaining until important dates — bills, trips, birthdays, deadlines — organized into custom sections, with optional Face ID protection for sensitive entries.

## Features

- **Sections** — Group related countdowns (e.g., "Work", "Travel", "Credit Cards"). Rename, reconfigure, or delete at any time.
- **Live countdowns** — Real-time display of days, hours, minutes, and seconds remaining, updated every second.
- **Auto-ordering by urgency** — Within each section, upcoming deadlines are sorted closest-first (most urgent at top), with past deadlines below in most-recent-first order. Re-evaluates every minute, so a row slides down into the "past" group as its deadline ticks by.
- **Collapsible sections** — Tap a section header (or its chevron) to collapse or expand it. Collapsed headers show the item count and a preview of the next upcoming deadline (e.g. *"5 countdowns · next in 2d"*). Expansion state persists across launches per section. Locked sections hide the preview until unlocked.
- **Urgency color coding** — Row color shifts as the target approaches:
  - Green: more than 7 days away
  - Orange: less than 7 days
  - Red: less than 1 day
  - Grey: already passed
- **Face ID / Touch ID locking (per-section)** — Opt-in when creating or editing a section. Locked sections hide their contents until you authenticate; removing a lock itself requires authentication.
- **Opt-in notifications** — Each countdown can schedule local reminders at 15 days, 1 week, and/or 1 day before its deadline. Defaults to 1-day-only so users aren't bombarded; turn the others on per-countdown if you want earlier heads-ups. Reminders fire at the exact time-of-day of the deadline. For items in Face ID–locked sections, the notification shows the section name but hides the countdown title.
- **Edit anything** — Tap a countdown to edit its title or date; use a section's menu (•••) to rename or toggle its lock.
- **Safe section delete** — Deleting a section prompts for confirmation and tells you how many countdowns will be destroyed with it.
- **Swipe to delete countdowns** — Individual countdowns delete instantly (iOS convention); sections are guarded by a confirmation dialog.
- **Date + time precision** — Target a specific moment, not just a day.
- **Input validation** — Empty titles and section names are rejected.
- **Local persistence** — Data stored on-device via SwiftData; no accounts, no network.

## Requirements

- Xcode 16 or later
- iOS 18.0+
- Swift 5.9+
- Supported device families: iPhone, iPad, Apple Vision Pro
- For Face ID locking: a device with biometrics or a passcode set

## Getting Started

1. Clone the repo.
2. Open `CountdownTracker.xcodeproj` in Xcode.
3. Select a simulator or connected device.
4. Build and run (`⌘R`).

No dependencies, no package manager setup, no secrets.

### Testing Face ID on the simulator

In the iOS Simulator: **Features → Face ID → Enrolled**, then during the prompt use **Features → Face ID → Matching Face** to succeed or **Non-matching Face** to fail.

## Architecture

The app follows a minimal MVVM-ish pattern with SwiftUI views reading directly from SwiftData via `@Query`. A single `@Observable` class (`BiometricAuth`) tracks per-session unlock state and is injected via the SwiftUI environment. There is no separate view-model layer — the views are thin enough that one isn't needed.

```
CountdownTracker/
├── CountdownTrackerApp.swift    # @main entry, ModelContainer + BiometricAuth
├── ContentView.swift            # Root view
├── Models/
│   ├── CountdownItem.swift      # @Model: title, targetDate, section
│   ├── CountdownSection.swift   # @Model: name, sortOrder, isLocked, items[]
│   └── BiometricAuth.swift      # @Observable: Face ID / passcode gate
├── Services/
│   └── NotificationScheduler.swift  # Local notifications (UNUserNotificationCenter)
└── Views/
    ├── HomeView.swift           # Main sectioned list with menus + confirmations
    ├── AddSectionView.swift     # Create/edit section (name + Face ID toggle)
    ├── AddCountdownView.swift   # Create/edit countdown (title + date)
    └── CountdownRow.swift       # Live-updating row with color-coded timer
```

### Data Model

**CountdownSection** (container)
- `name: String`
- `sortOrder: Int`
- `isLocked: Bool` — when `true`, contents are hidden until unlocked via biometrics
- `isExpanded: Bool` — per-section collapse state, persisted across launches
- `items: [CountdownItem]` — cascade delete

**CountdownItem** (leaf)
- `title: String`
- `targetDate: Date`
- `section: CountdownSection?` — inverse relationship
- `notify15d`, `notify7d`, `notify1d: Bool` — per-countdown notification opt-ins (default: 1d only)

Deleting a section cascades to its countdowns.

### Persistence

SwiftData's `ModelContainer` is configured in [CountdownTrackerApp.swift](CountdownTracker/CountdownTrackerApp.swift) for both model types. Views use `@Query` to observe data and `modelContext` to insert/delete.

### Live Timer

[CountdownRow.swift](CountdownTracker/Views/CountdownRow.swift) uses a `TimelineView(.periodic)` to recompute time remaining every second and update its color based on how far the target date is.

### Ordering

[HomeView.swift](CountdownTracker/Views/HomeView.swift) partitions each section's items into upcoming (target date in the future, sorted ascending) and past (target date in the past, sorted descending), concatenated. A 60-second `Timer.publish` keeps a `now` state variable fresh so the partition re-runs as deadlines cross without the user navigating away. `scenePhase` observation also refreshes `now` on app resume.

### Biometric Locking

[BiometricAuth.swift](CountdownTracker/Models/BiometricAuth.swift) wraps `LAContext` with an async `unlock(_:reason:)` API using `.deviceOwnerAuthentication` (Face ID → Touch ID → device passcode fallback). Unlocked sections are tracked by `PersistentIdentifier` in memory and cleared on app backgrounding via `scenePhase` observation in `HomeView`. A locked section's name remains visible but its items render as a single "Tap to unlock" row.

The usage string is declared via the `INFOPLIST_KEY_NSFaceIDUsageDescription` build setting ("Use Face ID to unlock protected sections.").

### Notifications

[NotificationScheduler.swift](CountdownTracker/Services/NotificationScheduler.swift) wraps `UNUserNotificationCenter`. Each countdown can schedule up to three local reminders (15d / 7d / 1d before) using deterministic identifiers (`<item-hash>-<offset>`) so rescheduling is idempotent and cancellation is just `removePendingNotificationRequests(withIdentifiers:)`. Notifications fire via `UNCalendarNotificationTrigger` at the exact time-of-day of the deadline.

Authorization is requested lazily — on the first save where any notification opt-in is enabled — rather than at launch, to avoid a cold-start prompt before the user has seen the app.

Privacy for locked sections: the notification title is the section name (non-sensitive) and the body is scrubbed to `"A countdown is 7 days away"` rather than revealing the item title. Toggling a section's lock flag reschedules all its items so the content matches the new privacy setting.

## Design Choices

- **SwiftData over Core Data** — Less boilerplate, better SwiftUI integration, sufficient for a single-user local app.
- **No view-model layer** — Views are simple enough that adding one would be over-engineering.
- **Per-section locking, not per-app** — Some countdowns aren't sensitive (birthdays); others are (credit card payments). Always-on app locking would be wrong for a reference app you glance at frequently.
- **Lock lifetime = foreground session** — Standard banking-app pattern. Unlock persists until the app backgrounds, then re-locks.
- **Disabling a lock requires auth** — Otherwise anyone holding an unlocked phone could trivially strip protection.
- **Section delete is confirmed, countdown delete is not** — Matches iOS conventions (Mail, Reminders): destructive bulk actions confirm; swipe-to-delete on individual items stays instant.
- **No networking, no auth accounts** — Offline-first, private by default.
- **Native components only** — Standard `List`, `Form`, `DatePicker`, `Menu`, and `confirmationDialog` keep the UI predictable and accessible.
- **Local notifications, opt-in per countdown** — Three reminders (15d/7d/1d) would be noisy by default and would quickly hit iOS's 64-pending cap. Defaulting to 1-day-before and letting users opt in to earlier pings respects attention and stays well under the limit.

## Testing

- `CountdownTrackerTests/` — Unit tests (XCTest)
- `CountdownTrackerUITests/` — UI tests, including launch performance

Run tests with `⌘U` in Xcode.

## Roadmap Ideas

- Home Screen and Lock Screen widgets
- iCloud sync across devices
- Recurring countdowns (birthdays, anniversaries)
- Customizable color themes per section
- Reordering sections via drag-and-drop
