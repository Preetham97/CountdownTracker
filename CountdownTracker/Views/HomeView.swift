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
    @AppStorage("completedSectionsExpanded") private var completedSectionsExpanded: Bool = false

    private let reorderTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    /// A section is "completed" when it has items and every item is done.
    /// Empty sections stay in the active bucket — there's nothing to clear.
    private func isSectionCompleted(_ section: CountdownSection) -> Bool {
        !section.items.isEmpty && section.items.allSatisfy { $0.isCompleted }
    }

    private var activeSections: [CountdownSection] {
        sections
            .filter { !isSectionCompleted($0) }
            .sorted { lhs, rhs in
                // Sort by earliest unchecked deadline ascending — overdue
                // sections rise above future ones, soonest-future ones above
                // far-future ones. Sections with no unchecked items (either
                // empty or all-cleared) fall to the bottom; ties break by
                // name so order is stable.
                let l = earliestActiveDate(in: lhs)
                let r = earliestActiveDate(in: rhs)
                switch (l, r) {
                case let (l?, r?):       return l < r
                case (_?, nil):          return true
                case (nil, _?):          return false
                case (nil, nil):         return lhs.name.localizedCompare(rhs.name) == .orderedAscending
                }
            }
    }

    private var completedSections: [CountdownSection] {
        sections.filter { isSectionCompleted($0) }
    }

    /// Earliest target date across this section's still-unchecked items.
    /// `nil` if the section has no unchecked items.
    private func earliestActiveDate(in section: CountdownSection) -> Date? {
        section.items
            .filter { !$0.isCompleted }
            .map { $0.targetDate }
            .min()
    }

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
        let active = activeSections
        let completed = completedSections

        return List {
            if !active.isEmpty {
                Section {
                    ForEach(active) { section in
                        sectionRow(for: section)
                    }
                }
            }

            if !completed.isEmpty {
                Section {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            completedSectionsExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .rotationEffect(.degrees(completedSectionsExpanded ? 90 : 0))
                            Text("Completed · \(completed.count)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .padding(.vertical, 2)
                    }
                    .buttonStyle(.plain)

                    if completedSectionsExpanded {
                        ForEach(completed) { section in
                            sectionRow(for: section)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    @ViewBuilder
    private func sectionRow(for section: CountdownSection) -> some View {
        NavigationLink(value: section) {
            SectionSummaryRow(section: section, now: now)
        }
        .listRowBackground(
            sectionToDelete?.persistentModelID == section.persistentModelID
                ? Color.red.opacity(0.12)
                : Color(.secondarySystemGroupedBackground)
        )
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            // No destructive role — avoids iOS's premature row-removal
            // animation before the confirmation dialog fires.
            Button {
                sectionToDelete = section
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .tint(.red)
            Button {
                sectionToEdit = section
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.blue)
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
            if isUnlocked {
                // Tappable: re-lock on demand (Notes-app pattern).
                Button {
                    auth.lock(section)
                } label: {
                    Image(systemName: "lock.open.fill")
                        .font(.title3)
                        .foregroundStyle(Color.green)
                        .frame(width: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Lock \(section.name)")
            } else {
                // Plain image — don't intercept the tap so the row's
                // NavigationLink still triggers and Face ID prompts.
                // Using .orange with full opacity so it reads clearly.
                Image(systemName: "lock.fill")
                    .font(.title3)
                    .foregroundStyle(Color.orange)
                    .frame(width: 28)
            }
        } else {
            Image(systemName: "folder.fill")
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 28)
        }
    }

    private var summary: String {
        let lockedAndHidden = section.isLocked && !auth.isUnlocked(section)
        let prefix = lockedAndHidden ? "Locked · " : ""

        if section.items.isEmpty {
            return "\(prefix)Empty"
        }

        // Active = not marked done (past-deadline items still count — user
        // needs to acknowledge them).
        let active = section.items
            .filter { !$0.isCompleted }
            .sorted { $0.targetDate < $1.targetDate }

        guard let next = active.first else {
            return "\(prefix)All cleared"
        }

        let countStr = active.count == 1 ? "1 active" : "\(active.count) active"

        // If the earliest active item has already passed, flag it instead of
        // computing a misleading "next in -3d" style phrase. We surface the
        // overdue state even if there are also future items, because overdue
        // is the thing that needs attention first.
        if next.targetDate <= now {
            let overdueCount = active.prefix(while: { $0.targetDate <= now }).count
            let overdueStr = overdueCount == 1 ? "1 overdue" : "\(overdueCount) overdue"
            return "\(prefix)\(countStr) · \(overdueStr)"
        }

        return "\(prefix)\(countStr) · next \(relativeDescription(from: now, to: next.targetDate))"
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
