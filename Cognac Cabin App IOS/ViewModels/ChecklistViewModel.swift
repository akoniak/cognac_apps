import Foundation
import SwiftData
import Observation

@Observable
final class ChecklistViewModel {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Section Operations

    func addSection(title: String, colorName: String = "blue") {
        let descriptor = FetchDescriptor<ChecklistSection>(
            sortBy: [SortDescriptor(\.sortOrder, order: .reverse)]
        )
        let maxOrder = (try? modelContext.fetch(descriptor).first?.sortOrder) ?? -1

        let section = ChecklistSection(title: title, colorName: colorName, sortOrder: maxOrder + 1)
        modelContext.insert(section)
        save()
    }

    func deleteSection(_ section: ChecklistSection) {
        modelContext.delete(section)
        save()
    }

    func updateSection(_ section: ChecklistSection, title: String, colorName: String) {
        section.title = title
        section.colorName = colorName
        save()
    }

    // MARK: - Item Operations

    func addItem(to section: ChecklistSection, title: String) {
        let maxOrder = section.items.map(\.sortOrder).max() ?? -1
        let item = ChecklistItem(title: title, sortOrder: maxOrder + 1)
        item.section = section
        section.items.append(item)
        save()
    }

    func toggleItem(_ item: ChecklistItem) {
        item.isChecked.toggle()
        save()
    }

    func deleteItem(_ item: ChecklistItem) {
        modelContext.delete(item)
        save()
    }

    func updateItem(_ item: ChecklistItem, title: String) {
        item.title = title
        save()
    }

    // MARK: - Batch Operations

    func uncheckAllItems() {
        let descriptor = FetchDescriptor<ChecklistItem>(
            predicate: #Predicate { $0.isChecked }
        )
        if let items = try? modelContext.fetch(descriptor) {
            for item in items {
                item.isChecked = false
            }
            save()
        }
    }

    // MARK: - Seed Default Data

    func seedDefaultSectionsIfEmpty() {
        let descriptor = FetchDescriptor<ChecklistSection>()
        let count = (try? modelContext.fetchCount(descriptor)) ?? 0
        guard count == 0 else { return }

        let defaults: [(String, String, [String])] = [
            ("Kitchen", "green", [
                "Turn off stove",
                "Empty refrigerator",
                "Run garbage disposal",
                "Take out trash",
                "Clean countertops",
            ]),
            ("Water & Plumbing", "blue", [
                "Turn off water main",
                "Drain pipes",
                "Set thermostat to 55\u{00B0}F",
                "Flush toilets after shutoff",
            ]),
            ("Electrical", "yellow", [
                "Unplug appliances",
                "Turn off breakers",
                "Check smoke detectors",
                "Set lights on timer",
            ]),
            ("Security", "red", [
                "Lock all doors",
                "Lock all windows",
                "Set alarm system",
                "Verify cameras are online",
            ]),
            ("Exterior", "brown", [
                "Store outdoor furniture",
                "Check gutters",
                "Close shutters",
                "Secure shed/outbuildings",
            ]),
        ]

        for (index, (title, color, items)) in defaults.enumerated() {
            let section = ChecklistSection(title: title, colorName: color, sortOrder: index)
            modelContext.insert(section)
            for (itemIndex, itemTitle) in items.enumerated() {
                let item = ChecklistItem(title: itemTitle, sortOrder: itemIndex)
                item.section = section
            }
        }
        save()
    }

    // MARK: - Private

    private func save() {
        try? modelContext.save()
    }
}
