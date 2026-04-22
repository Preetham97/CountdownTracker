import SwiftUI
import SwiftData

/// Full-screen detail for a single section. Shows all items partitioned
/// into Active and Completed, with add/edit/delete affordances. Face ID
/// gate is applied inline when the section is locked.
struct SectionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(BiometricAuth.self) private var auth
    @Environment(\.dismiss) private var dismiss
    @Bindable var section: CountdownSection

    @State private var showAddCountdown = false
    @State private var itemToEdit: CountdownItem?
    @State private var showEditSection = false
    @State private var confirmDelete = false
    @State private var itemToDelete: CountdownItem?
    @State private var now: Date = .now

    private let reorderTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if section.isLocked && !auth.isUnlocked(section) {
                LockedSectionGate(section: section)
            } else {
                itemsList
            }
        }
        .navigationTitle(section.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddCountdown = true
                } label: {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
                }
                .disabled(section.isLocked && !auth.isUnlocked(section))
            }
            ToolbarItem(placement: .secondaryAction) {
                Menu {
                    Button {
                        showEditSection = true
                    } label: {
                        Label("Edit Section", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        confirmDelete = true
                    } label: {
                        Label("Delete Section", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showAddCountdown) {
            AddCountdownView(section: section)
        }
        .sheet(item: $itemToEdit) { item in
            AddCountdownView(item: item)
        }
        .sheet(isPresented: $showEditSection) {
            AddSectionView(section: section)
        }
        .confirmationDialog(
            "Delete \"\(section.name)\"?",
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button("Delete Section", role: .destructive) {
                NotificationScheduler.cancelAll(in: section)
                modelContext.delete(section)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(deleteMessage)
        }
        .confirmationDialog(
            itemToDelete.map { "Delete \"\($0.title)\"?" } ?? "",
            isPresented: itemDeleteBinding,
            titleVisibility: .visible,
            presenting: itemToDelete
        ) { item in
            Button("Delete", role: .destructive) {
                NotificationScheduler.cancel(for: item)
                modelContext.delete(item)
                itemToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                itemToDelete = nil
            }
        } message: { _ in
            Text("This countdown will be permanently removed.")
        }
        .onReceive(reorderTimer) { tick in
            now = tick
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                now = .now
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var itemsList: some View {
        let active = activeItems
        let completed = completedItems

        if active.isEmpty && completed.isEmpty {
            ContentUnavailableView {
                Label("No Countdowns", systemImage: "calendar.badge.clock")
            } description: {
                Text("Tap + to add your first countdown to this section.")
            } actions: {
                Button("Add Countdown") {
                    showAddCountdown = true
                }
                .buttonStyle(.borderedProminent)
            }
        } else {
            List {
                if !active.isEmpty {
                    Section {
                        ForEach(active) { item in
                            row(for: item)
                        }
                    }
                }

                if !completed.isEmpty {
                    Section {
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
                                Text("Completed · \(completed.count)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                            .padding(.vertical, 2)
                        }
                        .buttonStyle(.plain)

                        if section.isCompletedExpanded {
                            ForEach(completed) { item in
                                row(for: item)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
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
        .listRowBackground(
            itemToDelete?.persistentModelID == item.persistentModelID
                ? Color.red.opacity(0.12)
                : Color(.secondarySystemGroupedBackground)
        )
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
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            // No `role: .destructive` — that triggers iOS's automatic
            // row-removal animation before the confirmation even fires,
            // which makes the row flicker if the user cancels.
            Button {
                itemToDelete = item
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .tint(.red)
        }
    }

    // MARK: - Derived data

    /// Active = every item the user hasn't marked done, regardless of whether
    /// its deadline has passed. Past-deadline items stay here (and bubble to
    /// the top via ascending-date sort) so the user is prompted to either
    /// check them off or push the deadline.
    private var activeItems: [CountdownItem] {
        section.items
            .filter { !$0.isCompleted }
            .sorted { $0.targetDate < $1.targetDate }
    }

    /// Completed = only items the user has explicitly marked done. Past-deadline
    /// but still-unchecked items live in `activeItems`.
    private var completedItems: [CountdownItem] {
        section.items
            .filter { $0.isCompleted }
            .sorted { lhs, rhs in
                let l = lhs.completedAt ?? lhs.targetDate
                let r = rhs.completedAt ?? rhs.targetDate
                return l > r
            }
    }

    private var itemDeleteBinding: Binding<Bool> {
        Binding(
            get: { itemToDelete != nil },
            set: { if !$0 { itemToDelete = nil } }
        )
    }

    private var deleteMessage: String {
        let count = section.items.count
        switch count {
        case 0: return "This section has no countdowns."
        case 1: return "This will also delete 1 countdown in this section."
        default: return "This will also delete \(count) countdowns in this section."
        }
    }

    private func toggleCompletion(_ item: CountdownItem) {
        if item.isCompleted {
            item.isCompleted = false
            item.completedAt = nil
            NotificationScheduler.reschedule(for: item)
        } else {
            item.isCompleted = true
            item.completedAt = .now
            NotificationScheduler.cancel(for: item)
        }
    }
}

// MARK: - Locked gate

private struct LockedSectionGate: View {
    @Environment(BiometricAuth.self) private var auth
    let section: CountdownSection
    @State private var isAuthenticating = false

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            VStack(spacing: 6) {
                Text(section.name)
                    .font(.title3.weight(.semibold))
                Text("This section is protected. Unlock with Face ID to view its countdowns.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Button {
                authenticate()
            } label: {
                if isAuthenticating {
                    ProgressView()
                        .frame(maxWidth: 180)
                        .padding(.vertical, 6)
                } else {
                    Label("Unlock", systemImage: "faceid")
                        .frame(maxWidth: 180)
                        .padding(.vertical, 6)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isAuthenticating)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .task {
            // Auto-prompt on first arrival so the user doesn't always have
            // to hit the button — matches how Notes/Files handle locked folders.
            if !isAuthenticating {
                authenticate()
            }
        }
    }

    private func authenticate() {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        Task {
            _ = await auth.unlock(
                section,
                reason: "Unlock \"\(section.name)\" to view its countdowns."
            )
            isAuthenticating = false
        }
    }
}
