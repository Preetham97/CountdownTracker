import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CountdownSection.sortOrder) private var sections: [CountdownSection]

    @State private var selectedSection: CountdownSection?
    @State private var showAddSection = false

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            if let section = selectedSection {
                SectionDetailView(section: section)
            } else {
                detailPlaceholder
            }
        }
        .sheet(isPresented: $showAddSection) {
            AddSectionView()
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selectedSection) {
            ForEach(sections) { section in
                NavigationLink(value: section) {
                    HStack {
                        Label(section.name, systemImage: "folder")
                        Spacer()
                        Text("\(section.items.count)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        delete(section)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle("Sections")
        .overlay {
            if sections.isEmpty {
                sidebarEmptyState
            }
        }
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
    }

    private var sidebarEmptyState: some View {
        ContentUnavailableView {
            Label("No Sections", systemImage: "folder")
        } description: {
            Text("Create a section to start adding countdowns.")
        } actions: {
            Button("Add Section") {
                showAddSection = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var detailPlaceholder: some View {
        ContentUnavailableView(
            "Select a Section",
            systemImage: "sidebar.left",
            description: Text("Pick a section from the sidebar to see its countdowns.")
        )
    }

    private func delete(_ section: CountdownSection) {
        if selectedSection == section {
            selectedSection = nil
        }
        modelContext.delete(section)
    }
}

// MARK: - Section detail

struct SectionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var section: CountdownSection

    @State private var showAddCountdown = false

    private var sortedItems: [CountdownItem] {
        section.items.sorted { $0.targetDate < $1.targetDate }
    }

    var body: some View {
        Group {
            if sortedItems.isEmpty {
                ContentUnavailableView {
                    Label("No Countdowns", systemImage: "calendar.badge.clock")
                } description: {
                    Text("Add your first countdown to this section.")
                } actions: {
                    Button("Add Countdown") {
                        showAddCountdown = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                List {
                    ForEach(sortedItems) { item in
                        CountdownRow(item: item)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    modelContext.delete(item)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle(section.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddCountdown = true
                } label: {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
                }
            }
        }
        .sheet(isPresented: $showAddCountdown) {
            AddCountdownView(section: section)
        }
    }
}
