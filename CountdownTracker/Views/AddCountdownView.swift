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

    /// Create mode — add a new countdown to the given section.
    init(section: CountdownSection) {
        self.section = section
        self.editingItem = nil
        _title = State(initialValue: "")
        _targetDate = State(
            initialValue: Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
        )
        _notify15d = State(initialValue: false)
        _notify7d = State(initialValue: false)
        _notify1d = State(initialValue: true)
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
    }

    private var isEditing: Bool { editingItem != nil }

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
                Section {
                    Toggle("15 days before", isOn: $notify15d)
                    Toggle("1 week before", isOn: $notify7d)
                    Toggle("1 day before", isOn: $notify1d)
                } header: {
                    Label("Notifications", systemImage: "bell")
                } footer: {
                    Text("Notifications fire at the same time of day as the deadline.")
                }
            }
            .navigationTitle(isEditing ? "Edit Countdown" : "New Countdown")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") {
                        Task { await save() }
                    }
                    .fontWeight(.semibold)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    @MainActor
    private func save() async {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        let item: CountdownItem
        if let existing = editingItem {
            existing.title = trimmed
            existing.targetDate = targetDate
            existing.notify15d = notify15d
            existing.notify7d = notify7d
            existing.notify1d = notify1d
            item = existing
        } else {
            let new = CountdownItem(
                title: trimmed,
                targetDate: targetDate,
                notify15d: notify15d,
                notify7d: notify7d,
                notify1d: notify1d
            )
            new.section = section
            section.items.append(new)
            modelContext.insert(new)
            item = new
        }

        // Make sure SwiftData flushes so the item's persistentModelID is
        // stable before we hash it for the notification identifier.
        try? modelContext.save()

        // Ask for permission on first notification opt-in, then schedule.
        if notify15d || notify7d || notify1d {
            _ = await NotificationScheduler.requestAuthorizationIfNeeded()
        }
        NotificationScheduler.reschedule(for: item)

        dismiss()
    }
}
