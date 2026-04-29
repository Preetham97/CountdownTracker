import SwiftUI
import SwiftData

struct AddCountdownView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let section: CountdownSection
    private let editingItem: CountdownItem?

    @State private var title: String
    @State private var targetDate: Date
    @State private var notify15d: Bool
    @State private var notify7d: Bool
    @State private var notify1d: Bool

    // Recurrence (create-mode only). Generates N independent countdown items
    // — one per occurrence — so each can be checked off / deleted on its own.
    @State private var recurrence: Recurrence = .none
    @State private var recurrenceEnd: Date

    /// Hard cap — without it, picking "daily" with a far-future end date would
    /// silently create thousands of rows. 100 is more than enough for normal
    /// use (e.g. ~8 years of monthly bills, ~2 years of weekly checkins).
    private static let maxOccurrences = 100

    enum Recurrence: String, CaseIterable, Identifiable {
        case none, daily, weekly, monthly, quarterly, yearly
        var id: String { rawValue }
        var label: String {
            switch self {
            case .none:      return "Never"
            case .daily:     return "Daily"
            case .weekly:    return "Weekly"
            case .monthly:   return "Monthly"
            case .quarterly: return "Quarterly"
            case .yearly:    return "Yearly"
            }
        }
        var calendarComponent: Calendar.Component? {
            switch self {
            case .none:                                  return nil
            case .daily:                                 return .day
            case .weekly:                                return .weekOfYear
            case .monthly, .quarterly:                   return .month
            case .yearly:                                return .year
            }
        }
        /// Step size in `calendarComponent` units. Quarterly is just monthly × 3.
        var step: Int {
            switch self {
            case .quarterly: return 3
            default:         return 1
            }
        }
        /// Singular noun for the cadence — used in inline copy like
        /// "one per month".
        var unitLabel: String {
            switch self {
            case .none:      return ""
            case .daily:     return "day"
            case .weekly:    return "week"
            case .monthly:   return "month"
            case .quarterly: return "quarter"
            case .yearly:    return "year"
            }
        }
    }

    /// Create mode — add a new countdown to the given section.
    init(section: CountdownSection) {
        self.section = section
        self.editingItem = nil
        let initialTarget = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
        _title = State(initialValue: "")
        _targetDate = State(initialValue: initialTarget)
        _notify15d = State(initialValue: false)
        _notify7d = State(initialValue: false)
        _notify1d = State(initialValue: true)
        // Default end date = 6 months out, a sensible mid-point for most
        // recurring bills/check-ins.
        _recurrenceEnd = State(
            initialValue: Calendar.current.date(byAdding: .month, value: 6, to: initialTarget) ?? initialTarget
        )
    }

    /// Edit mode — edit an existing countdown.
    init(item: CountdownItem) {
        self.section = item.section ?? CountdownSection(name: "")
        self.editingItem = item
        _title = State(initialValue: item.title)
        _targetDate = State(initialValue: item.targetDate)
        _notify15d = State(initialValue: item.notify15d)
        _notify7d = State(initialValue: item.notify7d)
        _notify1d = State(initialValue: item.notify1d)
        _recurrenceEnd = State(initialValue: item.targetDate)
    }

    private var isEditing: Bool { editingItem != nil }

    /// Live-computed list of dates (including the seed targetDate) that will
    /// be inserted on save. Capped at `maxOccurrences`.
    private var occurrenceDates: [Date] {
        guard let component = recurrence.calendarComponent else { return [targetDate] }
        var dates: [Date] = [targetDate]
        var current = targetDate
        let calendar = Calendar.current
        while dates.count < Self.maxOccurrences {
            guard let next = calendar.date(byAdding: component, value: recurrence.step, to: current) else { break }
            if next > recurrenceEnd { break }
            dates.append(next)
            current = next
        }
        return dates
    }

    private var isRecurring: Bool { recurrence != .none && !isEditing }

    private var endDateIsInvalid: Bool {
        isRecurring && recurrenceEnd < targetDate
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("e.g. Project deadline, Card payment", text: $title)
                        .autocorrectionDisabled()
                    DatePicker(
                        "Date & Time",
                        selection: $targetDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }
                Section {
                    HStack {
                        Image(systemName: "folder")
                            .foregroundStyle(.secondary)
                        Text(section.name)
                            .foregroundStyle(.secondary)
                    }
                }

                if !isEditing {
                    Section {
                        Picker("Repeat", selection: $recurrence) {
                            ForEach(Recurrence.allCases) { option in
                                Text(option.label).tag(option)
                            }
                        }
                        if isRecurring {
                            DatePicker(
                                "Until",
                                selection: $recurrenceEnd,
                                in: targetDate...,
                                displayedComponents: [.date]
                            )
                        }
                    } header: {
                        Label("Repeat", systemImage: "repeat")
                    } footer: {
                        if isRecurring {
                            let count = occurrenceDates.count
                            if count >= Self.maxOccurrences {
                                Text("Will create \(count) countdowns (capped — pick a closer end date for fewer).")
                                    .foregroundStyle(.orange)
                            } else if count <= 1 {
                                Text("End date is before the next occurrence — only the first countdown will be created.")
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Will create \(count) countdowns, one per \(recurrence.unitLabel).")
                            }
                        }
                    }
                }

                Section {
                    Toggle("15 days before", isOn: $notify15d)
                    Toggle("1 week before", isOn: $notify7d)
                    Toggle("1 day before", isOn: $notify1d)
                } header: {
                    Label("Notifications", systemImage: "bell")
                } footer: {
                    Text(isRecurring
                         ? "Each occurrence gets its own notifications, fired at the same time of day as the deadline."
                         : "Notifications fire at the same time of day as the deadline.")
                }
            }
            .navigationTitle(isEditing ? "Edit Countdown" : "New Countdown")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : addButtonLabel) {
                        Task { await save() }
                    }
                    .fontWeight(.semibold)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var addButtonLabel: String {
        if isRecurring {
            let count = occurrenceDates.count
            return count > 1 ? "Add \(count)" : "Add"
        }
        return "Add"
    }

    @MainActor
    private func save() async {
        let trimmed = title.trimmingCharacters(in: .whitespaces)

        if let existing = editingItem {
            existing.title = trimmed
            existing.targetDate = targetDate
            existing.notify15d = notify15d
            existing.notify7d = notify7d
            existing.notify1d = notify1d
            try? modelContext.save()

            if notify15d || notify7d || notify1d {
                _ = await NotificationScheduler.requestAuthorizationIfNeeded()
            }
            NotificationScheduler.reschedule(for: existing)
        } else {
            let dates = occurrenceDates
            var inserted: [CountdownItem] = []
            for date in dates {
                let new = CountdownItem(
                    title: trimmed,
                    targetDate: date,
                    notify15d: notify15d,
                    notify7d: notify7d,
                    notify1d: notify1d
                )
                new.section = section
                section.items.append(new)
                modelContext.insert(new)
                inserted.append(new)
            }
            // Flush so each item's persistentModelID is stable before we
            // schedule notifications keyed on its notificationID.
            try? modelContext.save()

            if (notify15d || notify7d || notify1d) && !inserted.isEmpty {
                _ = await NotificationScheduler.requestAuthorizationIfNeeded()
            }
            for item in inserted {
                NotificationScheduler.reschedule(for: item)
            }
        }

        dismiss()
    }
}
