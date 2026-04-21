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
    @State private var now: Date = .now

    private let reorderTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

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

    /// Upcoming items closest-first, followed by past items most-recent-first.
    /// Recomputed whenever `now` ticks forward (every 60s or on resume).
    private func orderedItems(for section: CountdownSection) -> [CountdownItem] {
        let upcoming = section.items
            .filter { $0.targetDate > now }
            .sorted { $0.targetDate < $1.targetDate }
        let past = section.items
            .filter { $0.targetDate <= now }
            .sorted { $0.targetDate > $1.targetDate }
        return upcoming + past
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
        if !section.isExpanded {
            EmptyView()
        } else if section.isLocked && !auth.isUnlocked(section) {
            LockedSectionRow(section: section)
        } else {
            let ordered = orderedItems(for: section)
            if ordered.isEmpty {
                Text("No countdowns yet")
                    .foregroundStyle(.tertiary)
                    .font(.subheadline)
                    .padding(.vertical, 4)
            }
            ForEach(ordered) { item in
                CountdownRow(item: item)
                    .contentShape(Rectangle())
                    .onTapGesture { itemToEdit = item }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            NotificationScheduler.cancel(for: item)
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
        HStack(spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    section.isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(section.isExpanded ? 90 : 0))
                    if section.isLocked {
                        Image(systemName: auth.isUnlocked(section) ? "lock.open.fill" : "lock.fill")
                            .font(.caption)
                            .foregroundStyle(auth.isUnlocked(section) ? .green : .secondary)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(section.name)
                            .font(.headline)
                            .textCase(nil)
                            .foregroundStyle(.primary)
                        if !section.isExpanded, let summary = collapsedSummary(for: section) {
                            Text(summary)
                                .font(.caption)
                                .textCase(nil)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

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

    /// Summary line shown under the section name when collapsed. Hidden for
    /// locked sections that haven't been unlocked (don't leak count/dates).
    private func collapsedSummary(for section: CountdownSection) -> String? {
        if section.isLocked && !auth.isUnlocked(section) {
            return nil
        }
        let count = section.items.count
        if count == 0 {
            return "Empty"
        }
        let countStr = count == 1 ? "1 countdown" : "\(count) countdowns"
        let upcoming = section.items
            .filter { $0.targetDate > now }
            .sorted { $0.targetDate < $1.targetDate }
        guard let next = upcoming.first else {
            return "\(countStr) · all passed"
        }
        return "\(countStr) · next \(relativeDescription(for: next.targetDate))"
    }

    private func relativeDescription(for date: Date) -> String {
        let diff = date.timeIntervalSince(now)
        let days = Int(diff / 86400)
        if days >= 1 { return "in \(days)d" }
        let hours = Int(diff / 3600)
        if hours >= 1 { return "in \(hours)h" }
        let minutes = max(Int(diff / 60), 1)
        return "in \(minutes)m"
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
