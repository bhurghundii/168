import Foundation
import SwiftData

@Model
final class Category {
    var id: UUID
    var name: String
    var weeklyHours: Double
    var sortOrder: Int

    @Relationship(deleteRule: .cascade, inverse: \Session.category)
    var sessions: [Session] = []

    init(id: UUID = UUID(), name: String, weeklyHours: Double, sortOrder: Int) {
        self.id = id
        self.name = name
        self.weeklyHours = weeklyHours
        self.sortOrder = sortOrder
    }
}
