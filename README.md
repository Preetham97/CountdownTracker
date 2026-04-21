# CountdownTracker

A simple, native iOS app for tracking time remaining until important dates — bills, trips, birthdays, deadlines — organized into custom sections.

## Features

- **Sections** — Group related countdowns (e.g., "Work", "Travel", "Credit Cards")
- **Live countdowns** — Real-time display of days, hours, minutes, and seconds remaining, updated every second
- **Urgency color coding** — Row color shifts as the target approaches:
  - Blue: more than 7 days away
  - Orange: less than 7 days
  - Red: less than 1 day
  - Grey: already passed
- **Date + time precision** — Target a specific moment, not just a day
- **Swipe to delete** — Remove individual countdowns or whole sections
- **Input validation** — Empty titles and section names are rejected
- **Local persistence** — Data stored on-device via SwiftData; no accounts, no network

## Requirements

- Xcode 16 or later
- iOS 18.0+
- Swift 5.9+
- Supported device families: iPhone, iPad, Apple Vision Pro

## Getting Started

1. Clone the repo.
2. Open `CountdownTracker.xcodeproj` in Xcode.
3. Select a simulator or connected device.
4. Build and run (`⌘R`).

No dependencies, no package manager setup, no secrets.

## Architecture

The app follows a minimal MVVM-ish pattern with SwiftUI views reading directly from SwiftData via `@Query`. There is no separate view-model layer — the views are thin enough that one isn't needed.

```
CountdownTracker/
├── CountdownTrackerApp.swift    # @main entry, sets up ModelContainer
├── ContentView.swift            # Root view
├── Models/
│   ├── CountdownItem.swift      # @Model: title, targetDate, section
│   └── CountdownSection.swift   # @Model: name, sortOrder, items[]
└── Views/
    ├── HomeView.swift           # Main sectioned list of countdowns
    ├── AddSectionView.swift     # Modal form to create a section
    ├── AddCountdownView.swift   # Modal form to add a countdown to a section
    └── CountdownRow.swift       # Live-updating row with color-coded timer
```

### Data Model

**CountdownSection** (container)
- `name: String`
- `sortOrder: Int`
- `items: [CountdownItem]` — cascade delete

**CountdownItem** (leaf)
- `title: String`
- `targetDate: Date`
- `section: CountdownSection?` — inverse relationship

Deleting a section cascades to its countdowns.

### Persistence

SwiftData's `ModelContainer` is configured in [CountdownTrackerApp.swift](CountdownTracker/CountdownTrackerApp.swift) for both model types. Views use `@Query` to observe data and `modelContext` to insert/delete.

### Live Timer

[CountdownRow.swift](CountdownTracker/Views/CountdownRow.swift) uses a `Timer` publisher to recompute time remaining every second and update its color based on how far the target date is.

## Design Choices

- **SwiftData over Core Data** — Less boilerplate, better SwiftUI integration, sufficient for a single-user local app.
- **No view-model layer** — Views are simple enough that adding one would be over-engineering.
- **No networking, no auth** — Keeps the app offline-first and private by default.
- **Native components only** — Standard `List`, `Form`, `DatePicker`, and navigation patterns keep the UI predictable and accessible.

## Testing

- `CountdownTrackerTests/` — Unit tests (XCTest)
- `CountdownTrackerUITests/` — UI tests, including launch performance

Run tests with `⌘U` in Xcode.

## Roadmap Ideas

- Notifications when a countdown is about to hit zero
- Home Screen and Lock Screen widgets
- iCloud sync across devices
- Recurring countdowns (birthdays, anniversaries)
- Customizable color themes per section
