import SwiftUI
import SwiftData

struct ChecklistView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ChecklistSection.sortOrder) private var sections: [ChecklistSection]

    @State private var checklistVM: ChecklistViewModel?
    @State private var showingAddSection = false

    var body: some View {
        NavigationStack {
            Group {
                if sections.isEmpty {
                    ContentUnavailableView(
                        "No Sections",
                        systemImage: "checklist",
                        description: Text("Tap + to add a checklist section.")
                    )
                } else {
                    List {
                        ForEach(sections) { section in
                            if let vm = checklistVM {
                                ChecklistSectionView(section: section, viewModel: vm)
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                checklistVM?.deleteSection(sections[index])
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Closing Checklist")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddSection = true
                    } label: {
                        Image(systemName: "plus.circle")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button {
                            checklistVM?.uncheckAllItems()
                        } label: {
                            Label("Uncheck All", systemImage: "arrow.counterclockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingAddSection) {
                EditSectionSheet(mode: .add) { title, color in
                    checklistVM?.addSection(title: title, colorName: color)
                }
            }
            .onAppear {
                if checklistVM == nil {
                    checklistVM = ChecklistViewModel(modelContext: modelContext)
                    checklistVM?.seedDefaultSectionsIfEmpty()
                }
            }
        }
    }
}

#Preview {
    ChecklistView()
        .modelContainer(for: [ChecklistSection.self, ChecklistItem.self], inMemory: true)
}
