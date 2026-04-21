import SwiftUI
import SwiftData
import LocalAuthentication

struct AddSectionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(BiometricAuth.self) private var auth
    @Query(sort: \CountdownSection.sortOrder) private var sections: [CountdownSection]

    private let editingSection: CountdownSection?

    @State private var name: String
    @State private var requireFaceID: Bool
    @State private var unlockFailed = false

    /// Create mode.
    init() {
        self.editingSection = nil
        _name = State(initialValue: "")
        _requireFaceID = State(initialValue: false)
    }

    /// Edit mode.
    init(section: CountdownSection) {
        self.editingSection = section
        _name = State(initialValue: section.name)
        _requireFaceID = State(initialValue: section.isLocked)
    }

    private var isEditing: Bool { editingSection != nil }

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
            .navigationTitle(isEditing ? "Edit Section" : "New Section")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Couldn't Disable Lock", isPresented: $unlockFailed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Authentication is required to remove the lock from this section.")
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") {
                        Task { await save() }
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    @MainActor
    private func save() async {
        let trimmed = name.trimmingCharacters(in: .whitespaces)

        if let section = editingSection {
            // If the user is disabling the lock, require authentication first.
            if section.isLocked && !requireFaceID {
                let ctx = LAContextWrapper()
                let ok = await ctx.authenticate(reason: "Authenticate to remove the lock on \"\(section.name)\".")
                if !ok {
                    unlockFailed = true
                    return
                }
            }
            let lockChanged = section.isLocked != requireFaceID
            section.name = trimmed
            section.isLocked = requireFaceID
            // Lock state affects notification privacy — reschedule so the
            // body text (with or without the item title) matches.
            if lockChanged {
                NotificationScheduler.rescheduleAll(in: section)
            }
        } else {
            let section = CountdownSection(
                name: trimmed,
                sortOrder: sections.count,
                isLocked: requireFaceID
            )
            modelContext.insert(section)
        }
        dismiss()
    }
}

// Minimal LAContext shim just for the lock-removal prompt.
// BiometricAuth tracks per-section unlock state; here we just need a one-shot check.
private struct LAContextWrapper {
    @MainActor
    func authenticate(reason: String) async -> Bool {
        let ctx = LAContext()
        var error: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return false
        }
        do {
            return try await ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        } catch {
            return false
        }
    }
}
