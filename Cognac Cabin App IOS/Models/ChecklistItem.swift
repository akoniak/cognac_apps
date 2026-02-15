import Foundation
import SwiftData

@Model
final class ChecklistItem {
    var id: UUID
    var title: String
    var isChecked: Bool
    var sortOrder: Int
    var createdAt: Date

    var section: ChecklistSection?

    init(title: String, isChecked: Bool = false, sortOrder: Int = 0) {
        self.id = UUID()
        self.title = title
        self.isChecked = isChecked
        self.sortOrder = sortOrder
        self.createdAt = Date()
    }
}
