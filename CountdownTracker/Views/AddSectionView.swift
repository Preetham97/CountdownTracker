import SwiftUI
import SwiftData

struct AddSectionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \CountdownSection.sortOrder) private var sections: [CountdownSection]

    @State private var name = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Section Name") {
                    TextField("e.g. Work, Credit Cards, Travel", text: $name)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle("New Section")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        let section = CountdownSection(name: trimmed, sortOrder: sections.count)
                        modelContext.insert(section)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.height(200)])
    }
}
