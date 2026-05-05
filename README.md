# CountdownTracker

A simple, native iOS app for tracking time remaining until important dates — bills, trips, birthdays, deadlines — organized into custom sections, with optional Face ID protection for sensitive entries.

## Features

- **Sections list + detail** — The home screen is a compact list of every section, each showing a one-liner preview (*"3 active · next in 2d"*, *"2 active · 1 overdue"*, *"All cleared"*, or *"Empty"*). Locked sections show the same preview so you know what's coming up without having to unlock first; only the individual countdown titles are gated. Tap a section to push into its detail page with the full countdown list, back button to return.
- **Live countdowns** — Real-time display of days, hours, minutes, and seconds remaining, updated every second.
- **Auto-ordering by urgency** — Within each section, active items are sorted by deadline ascending — past-deadline items bubble to the top (shown in red as *"Today passed"* or *"Xd ago"*) so you're prompted to either check them off or push the deadline, then upcoming items follow closest-first. Only items the user explicitly marks done drop into the Completed sub-bucket.
- **Mark as done** — Tap the circle at the start of any row (Reminders-style) to complete it before the deadline. Completed items strike through, grey out, move to the Completed bucket, and have their pending notifications cancelled. Tap the filled checkmark — or left-swipe the row — to reopen (restores notifications if the deadline is still ahead).
- **Collapsible Completed bucket** — Inside a section's detail, completed and past-deadline items tuck under a *"Completed · N"* row you can expand or collapse. Default collapsed so active items stay at the top.
- **Time-bucketed active items** — In a section's detail, active items are grouped into collapsible **Overdue** (red), **Within a Week** (orange), **Within a Month** (green), and **Later** (secondary) buckets — rolling windows from now, not calendar periods. Header colors mirror the per-row countdown coloring so urgency reads the same in either view. The topmost non-empty bucket always opens expanded so the section never appears empty; Overdue and Within-a-Week additionally auto-expand when populated. Within-a-Month and Later collapse otherwise so a section with dozens of countdowns stays scannable. Empty buckets hide their headers entirely.
- **App-icon-style progress ring as the completion toggle** — Each row's leading element is a miniature of the app icon: a glowing trim over a gray track that starts full when the countdown was created and depletes clockwise to empty at the deadline. Tint mirrors the day-count text (red overdue / red <1d / orange <7d / green ≥7d). The ring is also tappable — tap to mark complete, at which point the ring "closes" Apple-Watch-Activity-style into a solid green disc with a white checkmark. Tap again to reopen. The ring sits on the left where todo-list convention puts a checkbox, consolidating the row's status indicator and primary action into one element. Legacy rows that pre-date the per-item `createdAt` field fall back to a 30-day rolling window so they still animate sensibly.
- **Completed sections auto-bucket** — On the home screen, when every countdown in a section is marked done, the whole section drops into its own collapsible *"Completed · N"* bucket at the bottom so active sections stay front-and-center. Adding a new countdown (or reopening a completed one) lifts the section back into the active list automatically.
- **Urgency color coding** — Row color shifts as the target approaches:
  - Green: more than 7 days away
  - Orange: less than 7 days
  - Red: less than 1 day
  - Grey: already passed
- **Face ID / Touch ID locking (per-section)** — Opt-in when creating or editing a section. Locked sections hide their contents until you authenticate; removing a lock itself requires authentication. After unlocking, the home-list lock icon turns green + open — tap it to re-lock on demand without backgrounding the app (Notes-app pattern). All unlocked sections re-lock automatically when the app goes to the background.
- **Opt-in notifications** — Each countdown can schedule local reminders at 15 days, 1 week, and/or 1 day before its deadline. Defaults to 1-day-only so users aren't bombarded; turn the others on per-countdown if you want earlier heads-ups. Reminders fire at the exact time-of-day of the deadline. If a deadline is created or edited to land *inside* one of the opted-in windows (e.g. you change a countdown to be 5 minutes away with the 1-day reminder on), the scheduler fires an immediate catch-up notification with a time-aware phrase (*"in 5 minutes"*, *"in 2 hours"*) instead of silently missing the window. For items in Face ID–locked sections, the notification shows the section name but hides the countdown title.
- **Edit anything** — Tap a countdown in the detail view to edit its title/date; use the detail view's menu (•••) to rename the section, toggle its lock, or delete it. Swipe actions on the home list give shortcuts for Edit/Delete Section.
- **Recurring countdowns** — When creating a countdown, pick a Repeat cadence (Daily / Weekly / Monthly / Quarterly / Yearly) and an end date. The app expands the recurrence into independent countdowns — one per occurrence — at save time, so each can be checked off, edited, or deleted on its own (e.g. mark March's rent done without affecting April's). Capped at 100 occurrences to keep things sane.
- **Search** — Pull down on the home screen to search across every countdown by title or notes. Locked sections stay hidden from results until they've been unlocked in the current session, so search can't leak protected titles. Tap a result to jump straight into editing it.
- **Per-countdown notes** — Each countdown has a free-text notes field for the things you'd otherwise hunt for in another app when it comes due — account numbers, gate codes, links, addresses. Rows show a small note icon when notes are present.
- **Haptics** — Subtle feedback on routine actions (check-off, lock toggle) and a success bump on save, so the app feels alive on real hardware.
- **Safe deletes** — Both section and countdown deletes prompt for confirmation. Section deletes tell you how many countdowns will be destroyed with them.
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
    ├── HomeView.swift           # Top-level list of section summary rows (navigates to detail)
    ├── SectionDetailView.swift  # Per-section page: Active + Completed buckets, toolbar
    ├── AddSectionView.swift     # Create/edit section (name + Face ID toggle)
    ├── AddCountdownView.swift   # Create/edit countdown (title + date + notifications)
    └── CountdownRow.swift       # Live-updating row with color-coded timer
```

### Data Model

**CountdownSection** (container)
- `name: String`
- `sortOrder: Int`
- `isLocked: Bool` — when `true`, contents are hidden until unlocked via biometrics
- `isExpanded: Bool` — per-section collapse state, persisted across launches
- `isCompletedExpanded: Bool` — whether the inline Completed bucket is open (default `false`)
- `items: [CountdownItem]` — cascade delete

**CountdownItem** (leaf)
- `title: String`
- `targetDate: Date`
- `section: CountdownSection?` — inverse relationship
- `isCompleted: Bool` — user marked as done
- `completedAt: Date?` — timestamp used to sort the Completed bucket newest-first
- `notify15d`, `notify7d`, `notify1d: Bool` — per-countdown notification opt-ins (default: 1d only)

Deleting a section cascades to its countdowns.

### Persistence

SwiftData's `ModelContainer` is configured in [CountdownTrackerApp.swift](CountdownTracker/CountdownTrackerApp.swift) for both model types, backed by CloudKit's private database (`iCloud.Bhuma.CountdownTracker`). Countdowns sync automatically across the user's iCloud-signed-in devices — no login UI in the app, since iCloud is a system-level account. If iCloud is signed out or disabled for the app, SwiftData transparently falls back to a local-only store. Views use `@Query` to observe data and `modelContext` to insert/delete.

Model properties all carry default values or are optional to satisfy CloudKit schema constraints, and there are no `@Attribute(.unique)` constraints. Pure UI state (Completed-bucket expand/collapse) is intentionally kept *out* of the synced model and stored in `UserDefaults` keyed by section `stableID`, so a collapse on iPhone doesn't propagate to iPad.

### Live Timer

[CountdownRow.swift](CountdownTracker/Views/CountdownRow.swift) uses a `TimelineView(.periodic)` to recompute time remaining every second and update its color based on how far the target date is.

### Ordering

The home screen is a flat list of section summaries. Tapping a row pushes `SectionDetailView` onto the `NavigationStack` (locked sections land on a Face ID gate that auto-prompts, unlocking in place). The detail view partitions items into **active** (anything the user hasn't marked done — sorted by deadline ascending, so past-deadline items bubble to the top) and **completed** (only items explicitly marked done — sorted by `completedAt ?? targetDate` descending). Past-deadline unchecked items stay active on purpose so the user is prompted to either check them or extend the deadline; they render in red ("Today passed" / "Xd ago"). Active rows render first; the completed bucket is shown under a collapsible "Completed · N" sub-header. A 60-second `Timer.publish` keeps a `now` state variable fresh so the home-screen summary + row colors stay current without navigating away. `scenePhase` observation also refreshes `now` on app resume and re-locks every unlocked section on background.

Marking an item done is a tap on the leading circle (Reminders-style), which sets `isCompleted = true`, stamps `completedAt`, and cancels its pending notifications. Left-edge swipe works too as a shortcut. Reopening — tap the filled checkmark again or swipe — reverses the state and reschedules any offsets still in the future.

### Biometric Locking

[BiometricAuth.swift](CountdownTracker/Models/BiometricAuth.swift) wraps `LAContext` with an async `unlock(_:reason:)` API using `.deviceOwnerAuthentication` (Face ID → Touch ID → device passcode fallback). Unlocked sections are tracked by `PersistentIdentifier` in memory and cleared on app backgrounding via `scenePhase` observation in `HomeView`. A locked section's name remains visible but its items render as a single "Tap to unlock" row.

The usage string is declared via the `INFOPLIST_KEY_NSFaceIDUsageDescription` build setting ("Use Face ID to unlock protected sections.").

### Notifications

[NotificationScheduler.swift](CountdownTracker/Services/NotificationScheduler.swift) wraps `UNUserNotificationCenter`. Each countdown can schedule up to three local reminders (15d / 7d / 1d before) using deterministic identifiers (`<item-hash>-<offset>`) so rescheduling is idempotent and cancellation is just `removePendingNotificationRequests(withIdentifiers:)`. Notifications fire via `UNCalendarNotificationTrigger` at the exact time-of-day of the deadline.

Authorization is requested lazily — on the first save where any notification opt-in is enabled — rather than at launch, to avoid a cold-start prompt before the user has seen the app.

A `UNUserNotificationCenterDelegate` set in `CountdownTrackerApp` returns `[.banner, .list, .sound]` from `willPresent`, so notifications still surface as banners when the app is foregrounded. Without it, iOS silently routes foreground notifications into Notification Center — which would defeat the catch-up notification for a countdown the user just saved minutes away.

Privacy for locked sections: the notification title is the section name (non-sensitive) and the body is scrubbed to `"A countdown is 7 days away"` rather than revealing the item title. Toggling a section's lock flag reschedules all its items so the content matches the new privacy setting.

## Design Choices

- **SwiftData over Core Data** — Less boilerplate, better SwiftUI integration, sufficient for a single-user local app.
- **No view-model layer** — Views are simple enough that adding one would be over-engineering.
- **Per-section locking, not per-app** — Some countdowns aren't sensitive (birthdays); others are (credit card payments). Always-on app locking would be wrong for a reference app you glance at frequently.
- **Lock lifetime = foreground session** — Standard banking-app pattern. Unlock persists until the app backgrounds, then re-locks.
- **Disabling a lock requires auth** — Otherwise anyone holding an unlocked phone could trivially strip protection.
- **Destructive actions confirm** — Both section and countdown deletes route through a confirmation dialog. Accidentally swiping away a countdown you cared about (especially one you've been watching for months) is much worse than an extra tap.
- **No networking, no auth accounts** — Offline-first, private by default.
- **Native components only** — Standard `List`, `Form`, `DatePicker`, `Menu`, and `confirmationDialog` keep the UI predictable and accessible.
- **Local notifications, opt-in per countdown** — Three reminders (15d/7d/1d) would be noisy by default and would quickly hit iOS's 64-pending cap. Defaulting to 1-day-before and letting users opt in to earlier pings respects attention and stays well under the limit.

## Testing

- `CountdownTrackerTests/` — Unit tests (XCTest)
- `CountdownTrackerUITests/` — UI tests, including launch performance

Run tests with `⌘U` in Xcode.

## Roadmap Ideas

- Home Screen and Lock Screen widgets
- Customizable color themes per section
- Reordering sections via drag-and-drop
