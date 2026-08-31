import SwiftData
import XCTest
@testable import Burndown

@MainActor
final class CategoryDeletionTests: XCTestCase {
    // Disambiguates from `objc_category *Category`, which `ObjectiveC`
    // (pulled in transitively by XCTest) also declares at global scope.
    private typealias Category = Burndown.Category

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Category.self, Session.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    func testDeletingCategoryCascadeDeletesItsSessions() throws {
        let container = try makeContainer()
        let store = TimeStore(modelContext: container.mainContext)
        let category = Category(name: "Work", weeklyHours: 10, sortOrder: 0)
        container.mainContext.insert(category)
        try store.start(category: category)
        try store.stop(category: category)
        XCTAssertEqual(category.sessions.count, 1)

        try store.delete(category)

        let remainingSessions = try container.mainContext.fetch(FetchDescriptor<Session>())
        XCTAssertTrue(remainingSessions.isEmpty)
    }

    func testDeletingCategoryWithRunningSessionDoesNotCrash() throws {
        let container = try makeContainer()
        let fake = FakeLiveActivityManager()
        let store = TimeStore(modelContext: container.mainContext, liveActivityManager: fake)
        let category = Category(name: "Work", weeklyHours: 10, sortOrder: 0)
        container.mainContext.insert(category)
        try store.start(category: category)

        XCTAssertNoThrow(try store.delete(category))

        let remainingSessions = try container.mainContext.fetch(FetchDescriptor<Session>())
        XCTAssertTrue(remainingSessions.isEmpty)
        // Without this, the Live Activity would be orphaned on the lock
        // screen indefinitely — its session was cascade-deleted, but
        // nothing ever called stop() to end the Activity.
        XCTAssertTrue(fake.endedCategoryIds.contains(category.id))
    }

    func testDeletingOneCategoryDoesNotAffectOthers() throws {
        let container = try makeContainer()
        let store = TimeStore(modelContext: container.mainContext)
        let a = Category(name: "A", weeklyHours: 10, sortOrder: 0)
        let b = Category(name: "B", weeklyHours: 10, sortOrder: 1)
        container.mainContext.insert(a)
        container.mainContext.insert(b)
        try store.start(category: b)
        try store.stop(category: b)

        try store.delete(a)

        let remainingCategories = try container.mainContext.fetch(FetchDescriptor<Category>())
        XCTAssertEqual(remainingCategories.map(\.name), ["B"])
        XCTAssertEqual(b.sessions.count, 1)
    }
}
