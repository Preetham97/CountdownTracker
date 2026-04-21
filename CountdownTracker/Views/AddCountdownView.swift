import SwiftUI
import SwiftData

struct AddCountdownView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let section: CountdownSection
    private let editingItem: CountdownItem?

    @State private var title: String
    @State private var targetDate: Date

    /// Create mode — add a new countdown to the given section.
    init(section: CountdownSection) {
        self.section = section
        self.editingItem = nil
        _title = State(initialValue: "")
        _targetDate = State(
            initialValue: Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
        )
    }

    /// Edit mode — edit an existing countdown.
    init(item: CountdownItem) {
        self.section = item.section ?? CountdownSection(name: "")
        self.editingItem = item
        _title = State(initialValue: item.title)
        _targetDate = State(initialValue: item.targetDate)
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
            }
            .navigationTitle(isEditing ? "Edit Countdown" : "New Countdown")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") {
                        save()
                    }
                    .fontWeight(.semibold)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        if let item = editingItem {
            item.title = trimmed
            item.targetDate = targetDate
        } else {
            let item = CountdownItem(title: trimmed, targetDate: targetDate)
            item.section = section
            section.items.append(item)
            modelContext.insert(item)
        }
        dismiss()
    }
}
