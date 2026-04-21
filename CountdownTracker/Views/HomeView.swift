import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(BiometricAuth.self) private var auth
    @Query(sort: \CountdownSection.sortOrder) private var sections: [CountdownSection]

    @State private var showAddSection = false
    @State private var sectionForNewItem: CountdownSection?
    @State private var itemToEdit: CountdownItem?
    @State private var sectionToEdit: CountdownSection?
    @State private var sectionToDelete: CountdownSection?

    var body: some View {
        NavigationStack {
            Group {
                if sections.isEmpty {
                    emptyState
                } else {
                    countdownList
                }
            }
            .navigationTitle("Countdowns")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddSection = true
                    } label: {
                        Image(systemName: "folder.badge.plus")
                            .fontWeight(.semibold)
                    }
                }
            }
            .sheet(isPresented: $showAddSection) {
                AddSectionView()
            }
            .sheet(item: $sectionForNewItem) { section in
                AddCountdownView(section: section)
            }
            .sheet(item: $itemToEdit) { item in
                AddCountdownView(item: item)
            }
            .sheet(item: $sectionToEdit) { section in
                AddSectionView(section: section)
            }
            .confirmationDialog(
                deleteTitle(sectionToDelete),
                isPresented: deleteDialogBinding,
                titleVisibility: .visible,
                presenting: sectionToDelete
            ) { section in
                Button("Delete Section", role: .destructive) {
                    modelContext.delete(section)
                    sectionToDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    sectionToDelete = nil
                }
            } message: { section in
                Text(deleteMessage(section))
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .background || newPhase == .inactive {
                    auth.lockAll()
                }
            }
        }
    }

    private var deleteDialogBinding: Binding<Bool> {
        Binding(
            get: { sectionToDelete != nil },
            set: { if !$0 { sectionToDelete = nil } }
        )
    }

    private func deleteTitle(_ section: CountdownSection?) -> String {
        guard let section else { return "" }
        return "Delete \"\(section.name)\"?"
    }

    private func deleteMessage(_ section: CountdownSection) -> String {
        let count = section.items.count
        switch count {
        case 0: return "This section has no countdowns."
        case 1: return "This will also delete 1 countdown in this section."
        default: return "This will also delete \(count) countdowns in this section."
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Countdowns", systemImage: "calendar.badge.clock")
        } description: {
            Text("Tap the folder button to create your first section.")
        } actions: {
            Button("Add Section") {
                showAddSection = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var countdownList: some View {
        List {
            ForEach(sections) { section in
                Section {
                    sectionBody(section)
                } header: {
                    sectionHeader(section)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    @ViewBuilder
    private func sectionBody(_ section: CountdownSection) -> some View {
        if section.isLocked && !auth.isUnlocked(section) {
            LockedSectionRow(section: section)
        } else {
            let sorted = section.items.sorted { $0.targetDate < $1.targetDate }
            if sorted.isEmpty {
                Text("No countdowns yet")
                    .foregroundStyle(.tertiary)
                    .font(.subheadline)
                    .padding(.vertical, 4)
            }
            ForEach(sorted) { item in
                CountdownRow(item: item)
                    .contentShape(Rectangle())
                    .onTapGesture { itemToEdit = item }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            modelContext.delete(item)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
            Button {
                sectionForNewItem = section
            } label: {
                Label("Add Countdown", systemImage: "plus")
                    .font(.subheadline)
                    .foregroundStyle(.blue)
            }
        }
    }

    @ViewBuilder
    private func sectionHeader(_ section: CountdownSection) -> some View {
        HStack {
            if section.isLocked {
                Image(systemName: auth.isUnlocked(section) ? "lock.open.fill" : "lock.fill")
                    .font(.caption)
                    .foregroundStyle(auth.isUnlocked(section) ? .green : .secondary)
            }
            Text(section.name)
                .font(.headline)
                .textCase(nil)
                .foregroundStyle(.primary)
            Spacer()
            Menu {
                Button {
                    sectionToEdit = section
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    sectionToDelete = section
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Locked section placeholder row

private struct LockedSectionRow: View {
    @Environment(BiometricAuth.self) private var auth
    let section: CountdownSection
    @State private var isAuthenticating = false

    var body: some View {
        Button {
            guard !isAuthenticating else { return }
            isAuthenticating = true
            Task {
                _ = await auth.unlock(
                    section,
                    reason: "Unlock \"\(section.name)\" to view its countdowns."
                )
                isAuthenticating = false
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Locked")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    Text("Tap to unlock with Face ID")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isAuthenticating {
                    ProgressView()
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
