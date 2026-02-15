import SwiftUI

struct EditSectionSheet: View {
    enum Mode {
        case add
        case edit(ChecklistSection)

        var title: String {
            switch self {
            case .add: "New Section"
            case .edit: "Edit Section"
            }
        }

        var buttonLabel: String {
            switch self {
            case .add: "Add"
            case .edit: "Save"
            }
        }
    }

    let mode: Mode
    let onSave: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var sectionTitle: String = ""
    @State private var selectedColor: String = "blue"

    var body: some View {
        NavigationStack {
            Form {
                Section("Section Name") {
                    TextField("Enter section name", text: $sectionTitle)
                }

                Section("Color") {
                    ColorPickerGrid(selectedColor: $selectedColor)
                        .padding(.vertical, 4)
                }
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(mode.buttonLabel) {
                        let trimmed = sectionTitle.trimmingCharacters(in: .whitespaces)
                        if !trimmed.isEmpty {
                            onSave(trimmed, selectedColor)
                            dismiss()
                        }
                    }
                    .disabled(sectionTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if case .edit(let section) = mode {
                    sectionTitle = section.title
                    selectedColor = section.colorName
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview("Add") {
    EditSectionSheet(mode: .add) { title, color in
        print("Added: \(title) with color \(color)")
    }
}
