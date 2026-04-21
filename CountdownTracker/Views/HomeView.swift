import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(BiometricAuth.self) private var auth
    @Query(sort: \CountdownSection.sortOrder) private var sections: [CountdownSection]

    @State private var showAddSection = false
    @State private var sectionToEdit: CountdownSection?
    @State private var sectionToDelete: CountdownSection?
    @State private var now: Date = .now

    private let reorderTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            Group {
                if sections.isEmpty {
                    emptyState
                } else {
                    sectionsList
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
            .navigationDestination(for: CountdownSection.self) { section in
                SectionDetailView(section: section)
            }
            .sheet(isPresented: $showAddSection) {
                AddSectionView()
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
                    NotificationScheduler.cancelAll(in: section)
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
                if newPhase == .active {
                    now = .now
                }
            }
            .onReceive(reorderTimer) { tick in
                now = tick
            }
        }
    }

    private var sectionsList: some View {
        List {
            ForEach(sections) { section in
                NavigationLink(value: section) {
                    SectionSummaryRow(section: section, now: now)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        sectionToDelete = section
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    Button {
                        sectionToEdit = section
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.blue)
                }
            }
        }
        .listStyle(.insetGrouped)
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
}

// MARK: - Section summary row (main list)

private struct SectionSummaryRow: View {
    @Environment(BiometricAuth.self) private var auth
    let section: CountdownSection
    let now: Date

    private var isUnlocked: Bool {
        section.isLocked && auth.isUnlocked(section)
    }

    var body: some View {
        HStack(spacing: 12) {
            leadingIcon

            VStack(alignment: .leading, spacing: 2) {
                Text(section.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var leadingIcon: some View {
        if section.isLocked {
            // Tappable lock icon. Unlocked → tap to manually re-lock (Notes
            // app pattern). Locked → tap passes through; the row's
            // NavigationLink will trigger and the detail view handles auth.
            Button {
                if isUnlocked {
                    auth.lock(section)
                }
            } label: {
                Image(systemName: isUnlocked ? "lock.open.fill" : "lock.fill")
                    .font(.title3)
                    .foregroundStyle(isUnlocked ? Color.green : .orange)
                    .frame(width: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!isUnlocked)
            .accessibilityLabel(isUnlocked ? "Lock \(section.name)" : "\(section.name) is locked")
        } else {
            Image(systemName: "folder.fill")
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 28)
        }
    }

    private var summary: String {
        if section.isLocked && !auth.isUnlocked(section) {
            return "Locked"
        }
        let active = section.items
            .filter { !$0.isCompleted && $0.targetDate > now }
            .sorted { $0.targetDate < $1.targetDate }
        if section.items.isEmpty {
            return "Empty"
        }
        guard let next = active.first else {
            return "All cleared"
        }
        let countStr = active.count == 1 ? "1 active" : "\(active.count) active"
        return "\(countStr) · next \(relativeDescription(from: now, to: next.targetDate))"
    }
}

// Shared relative-time formatter used across the home + detail views.
func relativeDescription(from now: Date, to date: Date) -> String {
    let diff = date.timeIntervalSince(now)
    let days = Int(diff / 86400)
    if days >= 1 { return "in \(days)d" }
    let hours = Int(diff / 3600)
    if hours >= 1 { return "in \(hours)h" }
    let minutes = max(Int(diff / 60), 1)
    return "in \(minutes)m"
}
