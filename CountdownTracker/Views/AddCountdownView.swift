import SwiftUI
import SwiftData

struct AddCountdownView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let section: CountdownSection

    @State private var title = ""
    @State private var targetDate = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now

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
            .navigationTitle("New Countdown")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let trimmed = title.trimmingCharacters(in: .whitespaces)
                        let item = CountdownItem(title: trimmed, targetDate: targetDate)
                        item.section = section
                        section.items.append(item)
                        modelContext.insert(item)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
