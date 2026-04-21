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

    /// Active upcoming items — not completed, deadline still in the future —
    /// sorted closest-first. Recomputed when `now` ticks forward so items
    /// migrate into the Completed bucket as their deadlines pass.
    private func activeItems(for section: CountdownSection) -> [CountdownItem] {
        section.items
            .filter { !$0.isCompleted && $0.targetDate > now }
            .sorted { $0.targetDate < $1.targetDate }
    }

    /// Items that are either user-completed or past their deadline.
    /// Sorted newest-first by whichever event is more recent — this puts
    /// "just-cleared" rows on top of older ones.
    private func completedItems(for section: CountdownSection) -> [CountdownItem] {
        section.items
            .filter { $0.isCompleted || $0.targetDate <= now }
            .sorted { lhs, rhs in
                let l = lhs.completedAt ?? lhs.targetDate
                let r = rhs.completedAt ?? rhs.targetDate
                return l > r
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
        ScrollViewReader { proxy in
            List {
                ForEach(sections) { section in
                    Section {
                        sectionBody(section)
                    } header: {
                        sectionHeader(section)
                    }
                    .id(section.persistentModelID)
                }
            }
            .listStyle(.insetGrouped)
            .toolbar {
                ToolbarItem(placement: .secondaryAction) {
                    sectionJumperMenu(proxy: proxy)
                }
            }
        }
    }

    @ViewBuilder
    private func sectionJumperMenu(proxy: ScrollViewProxy) -> some View {
        Menu {
            let anyExpanded = sections.contains { $0.isExpanded }
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    let newValue = !anyExpanded
                    for section in sections {
                        section.isExpanded = newValue
                    }
                }
            } label: {
                if anyExpanded {
                    Label("Collapse All", systemImage: "chevron.up")
                } else {
                    Label("Expand All", systemImage: "chevron.down")
                }
            }
            if !sections.isEmpty {
                Divider()
                Section("Jump to") {
                    ForEach(sections) { section in
                        Button {
                            jumpTo(section, proxy: proxy)
                        } label: {
                            Label(section.name, systemImage: section.isLocked ? "lock.fill" : "folder")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "list.bullet.indent")
        }
    }

    private func jumpTo(_ section: CountdownSection, proxy: ScrollViewProxy) {
        // Expand if collapsed so there's something to reveal below the header.
        if !section.isExpanded {
            section.isExpanded = true
        }
        withAnimation(.easeInOut(duration: 0.25)) {
            proxy.scrollTo(section.persistentModelID, anchor: .top)
        }
    }

    @ViewBuilder
    private func sectionBody(_ section: CountdownSection) -> some View {
        if !section.isExpanded {
            EmptyView()
        } else if section.isLocked && !auth.isUnlocked(section) {
            LockedSectionRow(section: section)
        } else {
            let active = activeItems(for: section)
            let completed = completedItems(for: section)

            if active.isEmpty && completed.isEmpty {
                Text("No countdowns yet")
                    .foregroundStyle(.tertiary)
                    .font(.subheadline)
                    .padding(.vertical, 4)
            }

            ForEach(active) { item in
                row(for: item)
            }

            if !completed.isEmpty {
                completedHeader(section: section, count: completed.count)
                if section.isCompletedExpanded {
                    ForEach(completed) { item in
                        row(for: item)
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
    private func row(for item: CountdownItem) -> some View {
        HStack(spacing: 12) {
            Button {
                toggleCompletion(item)
            } label: {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.isCompleted ? Color.green.opacity(0.7) : .secondary)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.isCompleted ? "Reopen \(item.title)" : "Mark \(item.title) as done")

            CountdownRow(item: item)
                .contentShape(Rectangle())
                .onTapGesture { itemToEdit = item }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                toggleCompletion(item)
            } label: {
                if item.isCompleted {
                    Label("Reopen", systemImage: "arrow.uturn.backward")
                } else {
                    Label("Done", systemImage: "checkmark")
                }
            }
            .tint(item.isCompleted ? .gray : .green)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                NotificationScheduler.cancel(for: item)
                modelContext.delete(item)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private func completedHeader(section: CountdownSection, count: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                section.isCompletedExpanded.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(section.isCompletedExpanded ? 90 : 0))
                Text("Completed · \(count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .contentShape(Rectangle())
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
    }

    private func toggleCompletion(_ item: CountdownItem) {
        if item.isCompleted {
            item.isCompleted = false
            item.completedAt = nil
            // Resume notifications for any offsets still in the future.
            NotificationScheduler.reschedule(for: item)
        } else {
            item.isCompleted = true
            item.completedAt = .now
            NotificationScheduler.cancel(for: item)
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
        let active = section.items.filter { !$0.isCompleted && $0.targetDate > now }
        let totalCount = section.items.count
        if totalCount == 0 {
            return "Empty"
        }
        if active.isEmpty {
            return "All cleared"
        }
        let countStr = active.count == 1 ? "1 active" : "\(active.count) active"
        let next = active.sorted { $0.targetDate < $1.targetDate }.first!
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
