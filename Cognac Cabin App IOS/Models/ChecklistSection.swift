import Foundation
import SwiftData

@Model
final class ChecklistSection {
    var id: UUID
    var title: String
    var colorName: String
    var sortOrder: Int
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \ChecklistItem.section)
    var items: [ChecklistItem] = []

    var sectionColor: SectionColor {
        SectionColor(rawValue: colorName) ?? .blue
    }

    var sortedItems: [ChecklistItem] {
        items.sorted { $0.sortOrder < $1.sortOrder }
    }

    var checkedCount: Int {
        items.filter(\.isChecked).count
    }

    var totalCount: Int {
        items.count
    }

    var isComplete: Bool {
        !items.isEmpty && items.allSatisfy(\.isChecked)
    }

    init(title: String, colorName: String = "blue", sortOrder: Int = 0) {
        self.id = UUID()
        self.title = title
        self.colorName = colorName
        self.sortOrder = sortOrder
        self.createdAt = Date()
    }
}
