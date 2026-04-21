import SwiftUI
import SwiftData

struct AddSectionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(BiometricAuth.self) private var auth
    @Query(sort: \CountdownSection.sortOrder) private var sections: [CountdownSection]

    @State private var name = ""
    @State private var requireFaceID = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Section Name") {
                    TextField("e.g. Work, Credit Cards, Travel", text: $name)
                        .autocorrectionDisabled()
                }

                Section {
                    Toggle(isOn: $requireFaceID) {
                        Label("Require Face ID", systemImage: "faceid")
                    }
                    .disabled(!auth.isAuthenticationAvailable)
                } footer: {
                    if auth.isAuthenticationAvailable {
                        Text("You'll need to authenticate with Face ID, Touch ID, or your device passcode to view countdowns in this section.")
                    } else {
                        Text("Set up Face ID, Touch ID, or a device passcode in Settings to enable locking.")
                    }
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
                        let section = CountdownSection(
                            name: trimmed,
                            sortOrder: sections.count,
                            isLocked: requireFaceID
                        )
                        modelContext.insert(section)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
