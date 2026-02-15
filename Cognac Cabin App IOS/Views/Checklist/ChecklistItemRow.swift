import SwiftUI
import SwiftData

struct ChecklistItemRow: View {
    @Bindable var item: ChecklistItem
    let accentColor: Color
    let onToggle: () -> Void
    let onDelete: () -> Void
    let onUpdate: (String) -> Void

    @State private var isEditing = false
    @State private var editedTitle = ""

    var body: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    onToggle()
                }
            } label: {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.isChecked ? accentColor : .secondary)
            }
            .buttonStyle(.plain)

            if isEditing {
                TextField("Item name", text: $editedTitle)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        if !editedTitle.trimmingCharacters(in: .whitespaces).isEmpty {
                            onUpdate(editedTitle)
                        }
                        isEditing = false
                    }
            } else {
                Text(item.title)
                    .strikethrough(item.isChecked)
                    .foregroundStyle(item.isChecked ? .secondary : .primary)
                    .contentTransition(.opacity)

                Spacer()
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .trailing) {
            Button {
                editedTitle = item.title
                isEditing = true
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.orange)
        }
    }
}
