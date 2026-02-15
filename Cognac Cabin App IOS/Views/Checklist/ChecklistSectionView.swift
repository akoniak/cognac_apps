import SwiftUI
import SwiftData

struct ChecklistSectionView: View {
    @Bindable var section: ChecklistSection
    let viewModel: ChecklistViewModel

    @State private var showingEditSheet = false
    @State private var showingAddItem = false
    @State private var newItemTitle = ""

    var body: some View {
        Section {
            ForEach(section.sortedItems) { item in
                ChecklistItemRow(
                    item: item,
                    accentColor: section.sectionColor.color,
                    onToggle: { viewModel.toggleItem(item) },
                    onDelete: { viewModel.deleteItem(item) },
                    onUpdate: { newTitle in viewModel.updateItem(item, title: newTitle) }
                )
            }

            Button {
                showingAddItem = true
            } label: {
                Label("Add Item", systemImage: "plus")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } header: {
            HStack(spacing: 8) {
                Circle()
                    .fill(section.sectionColor.color)
                    .frame(width: 10, height: 10)

                Text(section.title)

                Spacer()

                Text("\(section.checkedCount)/\(section.totalCount)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                Button {
                    showingEditSheet = true
                } label: {
                    Image(systemName: "pencil.circle")
                        .font(.subheadline)
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditSectionSheet(mode: .edit(section)) { title, color in
                viewModel.updateSection(section, title: title, colorName: color)
            }
        }
        .alert("Add Item", isPresented: $showingAddItem) {
            TextField("Item name", text: $newItemTitle)
            Button("Cancel", role: .cancel) {
                newItemTitle = ""
            }
            Button("Add") {
                let trimmed = newItemTitle.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    viewModel.addItem(to: section, title: trimmed)
                }
                newItemTitle = ""
            }
        } message: {
            Text("Enter the name for the new checklist item.")
        }
    }
}
