import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CountdownSection.sortOrder) private var sections: [CountdownSection]

    @State private var showAddSection = false
    @State private var sectionForNewItem: CountdownSection?
    @State private var itemToEdit: CountdownItem?

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
                            .onTapGesture {
                                itemToEdit = item
                            }
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
                } header: {
                    HStack {
                        Text(section.name)
                            .font(.headline)
                            .textCase(nil)
                            .foregroundStyle(.primary)
                        Spacer()
                        Button(role: .destructive) {
                            modelContext.delete(section)
                        } label: {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundStyle(.red.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}
